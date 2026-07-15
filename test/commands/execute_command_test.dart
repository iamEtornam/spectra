import 'dart:io';

import 'package:mocktail/mocktail.dart';
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
  late MockLogger logger;

  setUp(() {
    originalCwd = Directory.current;
    tempDir = Directory.systemTemp.createTempSync('spectra_exec_test_');
    // Isolated home: run() loads config, which must never read the real
    // ~/.spectra (a configured provider would trigger a live LLM call).
    useTestHome(tempDir.path);
    Directory('${tempDir.path}/.spectra').createSync(recursive: true);
    Directory.current = tempDir;
    logger = MockLogger();
  });

  tearDown(() {
    Directory.current = originalCwd;
    resetTestHome();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  void writePlan(String tasks) =>
      File('.spectra/PLAN.md').writeAsStringSync('# PLAN\n$tasks');

  test('execute skips completed tasks and reports without erroring', () async {
    writePlan(_completedTask);

    await ExecuteCommand(logger: logger).run();

    verify(
      () => logger.success(any(that: contains('already completed'))),
    ).called(1);
    verifyNever(() => logger.err(any()));
  });

  test('resume reports completion without re-running finished plans', () async {
    writePlan(_completedTask);

    await ResumeCommand(logger: logger).run();

    verify(
      () => logger.success(any(that: contains('already completed'))),
    ).called(1);
    verifyNever(() => logger.err(any()));
  });
}
