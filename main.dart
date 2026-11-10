import 'dart:io';

// ---------------------------------------------------------------------------
// Community Learning Center Management System
// ---------------------------------------------------------------------------

/// Mixin: reusable timestamping behavior for any record.
mixin Timestamped {
  DateTime? _createdAt;

  void markCreated() => _createdAt = DateTime.now();

  String get createdLabel {
    final t = _createdAt;
    if (t == null) return 'unknown';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }
}

/// Custom exception so operations can explain why they failed.
class CenterException implements Exception {
  final String message;
  CenterException(this.message);
  @override
  String toString() => message;
}

/// Abstract parent: a general record kept by the center.
abstract class CenterRecord with Timestamped {
  final String _id;
  String _name;

  CenterRecord(this._id, this._name) {
    if (_id.trim().isEmpty || _name.trim().isEmpty) {
      throw CenterException('ID and name cannot be empty.');
    }
    markCreated();
  }

  String get id => _id;
  String get name => _name;

  set name(String value) {
    if (value.trim().isEmpty) throw CenterException('Name cannot be empty.');
    _name = value.trim();
  }

  String get category;

  /// Shared method every subclass implements differently.
  String describe();
}

/// A learning resource (book, laptop, module kit, etc.).
class LearningResource extends CenterRecord {
  final String _format;
  final int _totalCopies;
  int _availableCopies;

  LearningResource(String id, String title, this._format, int copies)
      : _totalCopies = copies,
        _availableCopies = copies,
        super(id, title) {
    if (copies <= 0) throw CenterException('Copies must be at least 1.');
  }

  String get format => _format;
  int get totalCopies => _totalCopies;
  int get availableCopies => _availableCopies;
  bool get isAvailable => _availableCopies > 0;

  @override
  String get category => 'Resource';

  void checkOut() {
    if (!isAvailable) throw CenterException('No copies of "$name" are available.');
    _availableCopies--;
  }

  void checkIn() {
    if (_availableCopies < _totalCopies) _availableCopies++;
  }

  @override
  String describe() =>
      '[Resource] $id | $name | $_format | $_availableCopies/$_totalCopies available | added $createdLabel';
}

/// A participant of the center. Subclasses set different borrowing rules.
class Participant extends CenterRecord {
  Participant(String id, String name) : super(id, name);

  int get borrowLimit => 1;
  int get maxLoanDays => 7;
  double get lateFeePerDay => 5.0;

  @override
  String get category => 'Participant';

  @override
  String describe() =>
      '[Participant] $id | $name | limit $borrowLimit item(s), $maxLoanDays days | joined $createdLabel';
}

class Student extends Participant {
  final String _gradeLevel;

  Student(String id, String name, this._gradeLevel) : super(id, name);

  @override
  int get borrowLimit => 2;
  @override
  int get maxLoanDays => 7;
  @override
  double get lateFeePerDay => 5.0;

  @override
  String get category => 'Student';

  @override
  String describe() =>
      '[Student] $id | $name | $_gradeLevel | limit $borrowLimit item(s), $maxLoanDays days, late fee P$lateFeePerDay/day | joined $createdLabel';
}

class Educator extends Participant {
  final String _subjectArea;

  Educator(String id, String name, this._subjectArea) : super(id, name);

  @override
  int get borrowLimit => 4;
  @override
  int get maxLoanDays => 14;
  @override
  double get lateFeePerDay => 10.0;

  @override
  String get category => 'Educator';

  @override
  String describe() =>
      '[Educator] $id | $name | $_subjectArea | limit $borrowLimit item(s), $maxLoanDays days, late fee P$lateFeePerDay/day | joined $createdLabel';
}

// ---------------------------------------------------------------------------
// Core manager
// ---------------------------------------------------------------------------

class LearningCenter {
  final String _centerName;
  final Map<String, LearningResource> _resources = {}; // resourceId -> resource
  final List<Participant> _participants = [];
  final Map<String, List<String>> _loans = {}; // participantId -> resourceIds
  final List<String> _transactionLog = [];

  LearningCenter(this._centerName);

  String get centerName => _centerName;
  List<String> get transactionLog => List.unmodifiable(_transactionLog);

  void addResource(String id, String title, String format, int copies) {
    if (_resources.containsKey(id)) {
      throw CenterException('Resource ID "$id" already exists.');
    }
    _resources[id] = LearningResource(id, title, format, copies);
    _log('Added resource $id ($title, $copies copies)');
  }

  void registerParticipant(Participant p) {
    if (findParticipant(p.id) != null) {
      throw CenterException('Participant ID "${p.id}" already exists.');
    }
    _participants.add(p);
    _loans[p.id] = [];
    _log('Registered ${p.category} ${p.id} (${p.name})');
  }

  Participant? findParticipant(String id) {
    for (final p in _participants) {
      if (p.id == id) return p;
    }
    return null;
  }

  void borrow(String participantId, String resourceId) {
    final p = findParticipant(participantId);
    final r = _resources[resourceId];
    if (p == null) throw CenterException('No participant with ID "$participantId".');
    if (r == null) throw CenterException('No resource with ID "$resourceId".');

    final current = _loans[participantId]!;
    if (current.length >= p.borrowLimit) {
      throw CenterException(
          '${p.name} has reached the limit of ${p.borrowLimit} borrowed item(s).');
    }
    if (current.contains(resourceId)) {
      throw CenterException('${p.name} already borrowed "${r.name}".');
    }
    r.checkOut();
    current.add(resourceId);
    _log('${p.name} borrowed ${r.name}');
  }

  /// Returns the late fee charged (0 if on time).
  double returnResource(String participantId, String resourceId, int daysKept) {
    final p = findParticipant(participantId);
    final r = _resources[resourceId];
    if (p == null) throw CenterException('No participant with ID "$participantId".');
    if (r == null) throw CenterException('No resource with ID "$resourceId".');

    final current = _loans[participantId]!;
    if (!current.remove(resourceId)) {
      throw CenterException('${p.name} did not borrow "${r.name}".');
    }
    r.checkIn();
    final daysLate = daysKept > p.maxLoanDays ? daysKept - p.maxLoanDays : 0;
    final fee = calculateLateFee(daysLate, p.lateFeePerDay);
    _log('${p.name} returned ${r.name} after $daysKept day(s), late fee P${fee.toStringAsFixed(2)}');
    return fee;
  }

  void showResources() {
    if (_resources.isEmpty) {
      print('No resources yet.');
      return;
    }
    for (final r in _resources.values) {
      print('  ${r.describe()}');
    }
  }

  void showParticipants() {
    if (_participants.isEmpty) {
      print('No participants yet.');
      return;
    }
    for (final p in _participants) {
      final loans = _loans[p.id]!.map((id) => _resources[id]!.name).toList();
      print('  ${p.describe()}');
      print('      Borrowed: ${loans.isEmpty ? "none" : loans.join(", ")}');
    }
  }

  /// Polymorphism: resources and participants handled through CenterRecord.
  void showAllRecords() {
    final List<CenterRecord> all = [..._resources.values, ..._participants];
    if (all.isEmpty) {
      print('No records yet.');
      return;
    }
    for (var i = 0; i < all.length; i++) {
      print('  ${i + 1}. ${all[i].describe()}');
    }
    print('  Total records: ${all.length}');
  }

  void showLog() {
    if (_transactionLog.isEmpty) {
      print('No transactions yet.');
      return;
    }
    for (var i = 0; i < _transactionLog.length; i++) {
      print('  ${i + 1}. ${_transactionLog[i]}');
    }
  }

  void _log(String entry) => _transactionLog.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $entry');
}

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

/// Calculation using operators; returns the fee owed.
double calculateLateFee(int daysLate, double ratePerDay) => daysLate * ratePerDay;

/// Prompts and returns trimmed input, or null if input has ended.
String? ask(String prompt) {
  stdout.write(prompt);
  return stdin.readLineSync()?.trim();
}

/// Prompts for a positive integer; returns null if invalid or missing.
int? askPositiveInt(String prompt) {
  final text = ask(prompt);
  if (text == null || text.isEmpty) return null;
  final value = int.tryParse(text);
  if (value == null || value <= 0) return null;
  return value;
}

void printMenu(String centerName) {
  print('\n==============================================');
  print('  $centerName');
  print('==============================================');
  print('  1. Add learning resource');
  print('  2. Register participant');
  print('  3. Borrow resource');
  print('  4. Return resource');
  print('  5. View resources');
  print('  6. View participants and loans');
  print('  7. View all records');
  print('  8. View transaction log');
  print('  0. Exit');
}

// ---------------------------------------------------------------------------
// Menu actions
// ---------------------------------------------------------------------------

void handleAddResource(LearningCenter center) {
  final id = ask('Resource ID (e.g. R100): ');
  final title = ask('Title: ');
  final format = ask('Format (Book/Laptop/Kit/Video): ');
  final copies = askPositiveInt('Number of copies: ');
  if (id == null || id.isEmpty || title == null || title.isEmpty ||
      format == null || format.isEmpty) {
    print('Error: ID, title and format are required.');
    return;
  }
  if (copies == null) {
    print('Error: copies must be a whole number greater than 0.');
    return;
  }
  center.addResource(id, title, format, copies);
  print('Resource "$title" added.');
}

void handleRegisterParticipant(LearningCenter center) {
  final id = ask('Participant ID (e.g. P100): ');
  final name = ask('Full name: ');
  final type = ask('Type (1 = Student, 2 = Educator): ');
  if (id == null || id.isEmpty || name == null || name.isEmpty) {
    print('Error: ID and name are required.');
    return;
  }
  switch (type) {
    case '1':
      final grade = ask('Grade level: ');
      center.registerParticipant(
          Student(id, name, (grade == null || grade.isEmpty) ? 'N/A' : grade));
      break;
    case '2':
      final subject = ask('Subject area: ');
      center.registerParticipant(Educator(
          id, name, (subject == null || subject.isEmpty) ? 'General' : subject));
      break;
    default:
      print('Error: type must be 1 or 2.');
      return;
  }
  print('Participant "$name" registered.');
}

void handleBorrow(LearningCenter center) {
  final pid = ask('Participant ID: ');
  final rid = ask('Resource ID: ');
  if (pid == null || pid.isEmpty || rid == null || rid.isEmpty) {
    print('Error: both IDs are required.');
    return;
  }
  center.borrow(pid, rid);
  print('Borrow successful.');
}

void handleReturn(LearningCenter center) {
  final pid = ask('Participant ID: ');
  final rid = ask('Resource ID: ');
  final days = askPositiveInt('Days the item was kept: ');
  if (pid == null || pid.isEmpty || rid == null || rid.isEmpty) {
    print('Error: both IDs are required.');
    return;
  }
  if (days == null) {
    print('Error: days must be a whole number greater than 0.');
    return;
  }
  final fee = center.returnResource(pid, rid, days);
  if (fee > 0) {
    print('Returned late. Late fee: P${fee.toStringAsFixed(2)}');
  } else {
    print('Returned on time. No fee.');
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

void main() {
  final center = LearningCenter('COMMUNITY LEARNING CENTER MANAGEMENT SYSTEM');

  // Starting records, added through the same methods the menu uses.
  center.addResource('R001', 'Dart Programming Basics', 'Book', 2);
  center.addResource('R002', 'Student Laptop', 'Laptop', 1);
  center.registerParticipant(Student('P001', 'Ana Reyes', 'Grade 10'));
  center.registerParticipant(Educator('P002', 'Mr. Cruz', 'Mathematics'));

  var running = true;
  while (running) {
    printMenu(center.centerName);
    final choice = ask('Choose an option (0-8): ');
    if (choice == null) {
      print('\nNo input available. Exiting.');
      break;
    }

    try {
      switch (choice) {
        case '1':
          handleAddResource(center);
          break;
        case '2':
          handleRegisterParticipant(center);
          break;
        case '3':
          handleBorrow(center);
          break;
        case '4':
          handleReturn(center);
          break;
        case '5':
          print('\n--- Resources ---');
          center.showResources();
          break;
        case '6':
          print('\n--- Participants ---');
          center.showParticipants();
          break;
        case '7':
          print('\n--- All Records ---');
          center.showAllRecords();
          break;
        case '8':
          print('\n--- Transaction Log ---');
          center.showLog();
          break;
        case '0':
          running = false;
          print('\nThank you for using the system. Goodbye!');
          break;
        default:
          print('Invalid choice "$choice". Please enter a number from 0 to 8.');
      }
    } on CenterException catch (e) {
      print('Could not complete operation: $e');
    } catch (e) {
      print('Unexpected problem: $e');
    }
  }
}
