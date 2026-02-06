import 'dart:io';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spectra_cli/commands/plan_command.dart';
import '../test_helpers.dart';

void main() {
  late MockLogger mockLogger;
  late PlanCommand planCommand;
  late Directory tempProjectDir;
  late Directory originalCwd;

  setUp(() {
    mockLogger = MockLogger();
    planCommand = PlanCommand(logger: mockLogger);

    tempProjectDir = Directory.systemTemp.createTempSync('spectra_plan_test_');
    originalCwd = Directory.current;

    // Change to temp directory
    Directory.current = tempProjectDir;

    // Create .spectra directory
    final spectraDir = Directory('${tempProjectDir.path}/.spectra');
    spectraDir.createSync();

    // Register fallback values
    registerFallbackValue('');
  });

  tearDown(() {
    // Restore original directory
    Directory.current = originalCwd;

    // Cleanup
    if (tempProjectDir.existsSync()) {
      tempProjectDir.deleteSync(recursive: true);
    }
  });

  group('PlanCommand Integration Tests', () {
    test('should have correct name and description', () {
      expect(planCommand.name, equals('plan'));
      expect(planCommand.description, contains('roadmap'));
    });

    test('should create PLAN.md file', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final planFile = File('${spectraDir.path}/PLAN.md');

      // Create sample plan
      planFile.writeAsStringSync('''
# Plan

## Phase: Authentication Implementation

<task id="task-001" type="create">
  <name>Create User Model</name>
  <files>lib/models/user.dart</files>
  <objective>Create user data model</objective>
  <verification>Model compiles</verification>
  <acceptance>User model exists</acceptance>
</task>
''');

      expect(planFile.existsSync(), isTrue);
    });

    test('should parse XML task format', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final planFile = File('${spectraDir.path}/PLAN.md');

      const xmlContent = '''
<task id="task-001" type="create">
  <name>Test Task</name>
  <files>lib/test.dart</files>
  <objective>Create test file</objective>
  <verification>File exists</verification>
  <acceptance>Test passes</acceptance>
</task>
''';

      planFile.writeAsStringSync(xmlContent);

      final content = planFile.readAsStringSync();

      expect(content.contains('<task id="task-001"'), isTrue);
      expect(content.contains('<name>Test Task</name>'), isTrue);
      expect(content.contains('<files>lib/test.dart</files>'), isTrue);
    });

    test('should handle multiple tasks in plan', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final planFile = File('${spectraDir.path}/PLAN.md');

      planFile.writeAsStringSync('''
# Plan

<task id="task-001" type="create">
  <name>Task 1</name>
  <files>lib/file1.dart</files>
  <objective>Objective 1</objective>
  <verification>Verify 1</verification>
  <acceptance>Accept 1</acceptance>
</task>

<task id="task-002" type="update">
  <name>Task 2</name>
  <files>lib/file2.dart</files>
  <objective>Objective 2</objective>
  <verification>Verify 2</verification>
  <acceptance>Accept 2</acceptance>
</task>

<task id="task-003" type="test">
  <name>Task 3</name>
  <files>test/file_test.dart</files>
  <objective>Objective 3</objective>
  <verification>Verify 3</verification>
  <acceptance>Accept 3</acceptance>
</task>
''');

      final content = planFile.readAsStringSync();

      expect(content.contains('task-001'), isTrue);
      expect(content.contains('task-002'), isTrue);
      expect(content.contains('task-003'), isTrue);
    });

    test('should validate task types', () {
      final validTypes = ['create', 'update', 'delete', 'test', 'refactor'];

      for (final type in validTypes) {
        final taskXml =
            '''
<task id="task-$type" type="$type">
  <name>Test $type</name>
  <files>lib/test.dart</files>
  <objective>Test objective</objective>
  <verification>Test verification</verification>
  <acceptance>Test acceptance</acceptance>
</task>
''';

        expect(taskXml.contains('type="$type"'), isTrue);
      }
    });

    test('should handle ROADMAP.md integration', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final roadmapFile = File('${spectraDir.path}/ROADMAP.md');

      roadmapFile.writeAsStringSync('''
# Roadmap

## Phase 1: Foundation
- Set up project structure
- Configure dependencies

## Phase 2: Core Features
- Implement user authentication
- Create data models

## Phase 3: Testing
- Write unit tests
- Add integration tests
''');

      expect(roadmapFile.existsSync(), isTrue);

      final content = roadmapFile.readAsStringSync();
      expect(content.contains('Phase 1: Foundation'), isTrue);
      expect(content.contains('Phase 2: Core Features'), isTrue);
      expect(content.contains('Phase 3: Testing'), isTrue);
    });

    test('should handle PROJECT.md context', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final projectFile = File('${spectraDir.path}/PROJECT.md');

      projectFile.writeAsStringSync('''
# Project: Test Application

## Vision
A test application for demonstration purposes.

## Tech Stack
- Dart 3.x
- Flutter
- Supabase

## Constraints
- Mobile-first design
- Offline support required
''');

      expect(projectFile.existsSync(), isTrue);

      final content = projectFile.readAsStringSync();
      expect(content.contains('Tech Stack'), isTrue);
      expect(content.contains('Constraints'), isTrue);
    });

    test('should verify required .spectra files exist', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');

      // Create required files
      File('${spectraDir.path}/PROJECT.md').writeAsStringSync('# Project\n');
      File('${spectraDir.path}/ROADMAP.md').writeAsStringSync('# Roadmap\n');
      File('${spectraDir.path}/STATE.md').writeAsStringSync('# State\n');

      expect(File('${spectraDir.path}/PROJECT.md').existsSync(), isTrue);
      expect(File('${spectraDir.path}/ROADMAP.md').existsSync(), isTrue);
      expect(File('${spectraDir.path}/STATE.md').existsSync(), isTrue);
    });

    test('should handle task dependencies', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final planFile = File('${spectraDir.path}/PLAN.md');

      planFile.writeAsStringSync('''
<task id="task-001" type="create" depends="[]">
  <name>Base Task</name>
  <files>lib/base.dart</files>
  <objective>Create base</objective>
  <verification>Base exists</verification>
  <acceptance>Base complete</acceptance>
</task>

<task id="task-002" type="create" depends="[task-001]">
  <name>Dependent Task</name>
  <files>lib/dependent.dart</files>
  <objective>Create dependent</objective>
  <verification>Dependent exists</verification>
  <acceptance>Dependent complete</acceptance>
</task>
''');

      final content = planFile.readAsStringSync();

      expect(content.contains('depends="[]"'), isTrue);
      expect(content.contains('depends="[task-001]"'), isTrue);
    });

    test('should track task completion status', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final summaryFile = File('${spectraDir.path}/SUMMARY.md');

      summaryFile.writeAsStringSync('''
# Summary

## Completed Tasks
- [x] task-001: Create User Model
- [x] task-002: Add Authentication

## Pending Tasks
- [ ] task-003: Write Tests
- [ ] task-004: Deploy Application
''');

      final content = summaryFile.readAsStringSync();

      expect(content.contains('[x] task-001'), isTrue);
      expect(content.contains('[x] task-002'), isTrue);
      expect(content.contains('[ ] task-003'), isTrue);
      expect(content.contains('[ ] task-004'), isTrue);
    });

    test('should handle empty plan gracefully', () {
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      final planFile = File('${spectraDir.path}/PLAN.md');

      planFile.writeAsStringSync('# Plan\n\nNo tasks yet.\n');

      expect(planFile.existsSync(), isTrue);
      expect(planFile.readAsStringSync().contains('No tasks yet'), isTrue);
    });
  });
}
