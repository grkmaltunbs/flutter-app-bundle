---
name: dart-add-unit-test
description: Write and organize unit tests for functions, methods, and classes using `package:test`. Use when creating new logic or fixing bugs to ensure code remains correct and regression-free.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:07:58 GMT
---
# Testing Dart and Flutter Applications

## Contents
- [Structuring Test Files](#structuring-test-files)
- [Writing Tests](#writing-tests)
- [Executing Tests](#executing-tests)
- [Test Implementation Workflow](#test-implementation-workflow)
- [Examples](#examples)

## Structuring Test Files
Organize test files to mirror the `lib` directory structure to maintain predictability.

* Place all test code within the `test` directory at the root of the package.
* Append `_test.dart` to the end of all test file names (e.g., `lib/src/utils.dart` should be tested in `test/src/utils_test.dart`).
* If writing integration tests, place them in an `integration_test` directory at the root of the package.

## Writing Tests
Utilize `package:test` as the standard testing library for Dart applications.

* Import `package:test/test.dart` (or `package:flutter_test/flutter_test.dart` for Flutter).
* Group related tests using the `group()` function to provide shared context.
* Define individual test cases using the `test()` function.
* Validate outcomes using `package:checks` — e.g. `check(actual).equals(expected)`, `check(actual).isNotNull()`, `await check(future).throws<Exception>()` — rather than `expect`/matchers, per `docs/flutter-rules.md`. Import `package:checks/checks.dart`. The `dart-migrate-to-checks-package` skill covers the full API.
* Write asynchronous tests using standard `async`/`await` syntax. The test runner automatically waits for the `Future` to complete.
* Manage test setup and teardown using `setUp()` and `tearDown()` callbacks.
* If testing code that relies on dependency injection, use `package:mocktail` alongside `package:test` to define mock objects (no code generation), configure fixed scenarios, and verify interactions. See the `dart-define-test-mocks` skill.

## Executing Tests
Select the appropriate test runner based on the project type and test location.

* If working on a pure Dart project, execute tests using the `dart test` command.
* If working on a Flutter project, execute tests using the `flutter test` command.
* If running integration tests, explicitly specify the directory path, as the default runner ignores it: `dart test integration_test` or `flutter test integration_test`.

## Test Implementation Workflow

Follow this sequential workflow when implementing new test suites. Copy the checklist to track your progress.

### Task Progress
- [ ] 1. Create the test file in the `test/` directory, ensuring the `_test.dart` suffix.
- [ ] 2. Import `package:test/test.dart` and the target library.
- [ ] 3. Define a `main()` function.
- [ ] 4. Initialize shared resources or mocks using `setUp()`.
- [ ] 5. Write `test()` cases grouped by functionality using `group()`.
- [ ] 6. Execute the test suite using the appropriate CLI command.
- [ ] 7. **Feedback Loop**: Run test -> Review stack trace for failures -> Fix implementation or assertions -> Re-run until passing.

## Examples

### Standard Unit Test Suite
Demonstrates grouping, setup, synchronous, and asynchronous testing.

```dart
import 'package:test/test.dart';
import 'package:checks/checks.dart';
import 'package:my_package/calculator.dart';

void main() {
  group('Calculator', () {
    late Calculator calc;

    setUp(() {
      calc = Calculator();
    });

    test('adds two numbers correctly', () {
      check(calc.add(2, 3)).equals(5);
    });

    test('handles asynchronous operations', () async {
      final result = await calc.fetchRemoteValue();
      check(result).isNotNull();
      check(result).isGreaterThan(0);
    });
  });
}
```

### Mocking with Mocktail
Demonstrates configuring a mock object for dependency injection testing. No code
generation is required — the mock is a hand-written class.

```dart
import 'package:test/test.dart';
import 'package:checks/checks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:my_package/api_client.dart';
import 'package:my_package/data_service.dart';

// Declare the mock by hand — no codegen.
class MockApiClient extends Mock implements ApiClient {}

void main() {
  group('DataService', () {
    late MockApiClient mockApiClient;
    late DataService dataService;

    setUp(() {
      mockApiClient = MockApiClient();
      dataService = DataService(apiClient: mockApiClient);
    });

    test('returns parsed data on successful API call', () async {
      // Configure the mock (note the closure: `when(() => ...)`).
      when(() => mockApiClient.get('/data')).thenAnswer((_) async => '{"id": 1}');

      // Execute the system under test
      final result = await dataService.fetchData();

      // Verify outcomes and interactions
      check(result.id).equals(1);
      verify(() => mockApiClient.get('/data')).called(1);
    });
  });
}
```
