# Community Learning Center Management System

**Name:** John Aldrin C. Saet
**Section:** BSIT 3.8
**Course:** Mobile Development – Midterm Laboratory Examination

## Description
A console-based Dart application that registers learning resources and participants, processes borrow/return transactions, and displays organized records.

## Implemented Features
- Menu-driven console app (add resource, register participant, borrow, return, view records, view log, exit)
- Menu loop runs until the user chooses Exit; invalid choices and input are handled without crashing
- Classes with private fields (`_name`, `_availableCopies`, ...) and getters/setters (encapsulation)
- Abstract class `CenterRecord`, with subclasses `LearningResource` and `Participant` (`Student`, `Educator`), each implementing `describe()`
- Polymorphism: "View all records" handles resources and participants through `CenterRecord`
- Mixin `Timestamped` provides creation timestamps for all records
- `List` (participants, transaction log) and `Map` (resources by ID, loans by participant ID)
- Functions with parameters and return values: `calculateLateFee`, `askPositiveInt`, `ask`
- Error handling with `try`/`catch` and a custom `CenterException`

## Sample Test Scenarios
1. **Valid borrow/return:** Option 3 → `P001`, `R001`; then option 4 → `P001`, `R001`, `5` days → "Returned on time."
2. **Late fee:** Borrow `P001` / `R002`, return with `10` days → Student limit is 7 days, so 3 days late × P5.00 = P15.00.
3. **Invalid input:** Enter `9` or `abc` in the menu → "Invalid choice". Enter `0` as copies when adding a resource → error message. Borrow with ID `P999` → "No participant with ID".

## How to Run
1. Install the [Dart SDK](https://dart.dev/get-dart).
2. In the project folder, run:
   ```
   dart run main.dart
   ```
Note: the app reads keyboard input, so run it in a terminal (DartPad's console may not support input).
