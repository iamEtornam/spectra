import 'dart:io';

import 'package:test/test.dart';
import 'package:spectra_cli/commands/execute_command.dart';
import 'package:spectra_cli/commands/resume_command.dart';

import '../test_helpers.dart';

const _completedTask = '''
<task id="task_001" type="create" status="completed">
  <n>Done task</n>
  <files><file>lib/a.dart</file></files>
  <objective>obj</objective>
  <verification>verify</verification>
  <acceptance>accept</acceptance>
</task>
''';

void main() {
  late Directory tempDir;
  late Directory originalCwd;

  setUp(() {
    originalCwd = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('spectra_exec_test_');
    Directory('${tempDir.path}/.spectra').createSync(recursive: true);
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalCwd;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void writePlan(String tasks) =>
      File('.spectra/PLAN.md').writeAsStringSync('# PLAN\n$tasks');

  test('execute returns early when every task is already completed', () async {
    writePlan(_completedTask);

    // Must finish without requiring any provider configuration.
    await ExecuteCommand(logger: MockLogger()).run();
  });

  test('resume reports completion without re-running finished plans', () async {
    writePlan(_completedTask);

    await ResumeCommand(logger: MockLogger()).run();
  });
}
