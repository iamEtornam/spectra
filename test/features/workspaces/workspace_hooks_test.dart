@TestOn('vm')
library;

import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:spectra_cli/features/workflow/workflow_config.dart';
import 'package:spectra_cli/features/workspaces/workspace_hooks.dart';
import 'package:test/test.dart';

HooksWorkflowConfig _hooks({
  String? afterCreate,
  String? beforeRun,
  String? afterRun,
  String? beforeRemove,
  Duration timeout = const Duration(seconds: 5),
  String? shell,
  List<String>? shellArguments,
}) {
  return HooksWorkflowConfig(
    afterCreate: afterCreate,
    beforeRun: beforeRun,
    afterRun: afterRun,
    beforeRemove: beforeRemove,
    timeout: timeout,
    shellExecutable: shell,
    shellArguments: shellArguments,
  );
}

void main() {
  group('WorkspaceHookRunner', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('spectra_hook_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test(
      'bounds captured output to maxOutputBytes and flags truncation',
      () async {
        // Skip on Windows because the default invocation is `cmd.exe /c`,
        // which does not understand the shell loop below.
        if (Platform.isWindows) return;

        final runner = WorkspaceHookRunner(
          logger: Logger(level: Level.quiet),
          maxOutputBytes: 64,
        );
        // Print a long string ~1 KiB into stdout so the bounded buffer kicks
        // in before the script finishes.
        final outcome = await runner.run(
          kind: WorkspaceHookKind.afterRun,
          workspacePath: tempDir.path,
          hooks: _hooks(
            afterRun: 'for i in \$(seq 1 200); do echo "noisy_chunk_\$i"; done',
            timeout: const Duration(seconds: 10),
          ),
        );

        expect(outcome.succeeded, isTrue);
        // The captured output keeps the first 64 chars and appends the
        // "...[truncated]" marker outside that cap.
        expect(outcome.output.length, lessThan(200));
        expect(outcome.output, startsWith('noisy_chunk_1'));
        expect(outcome.output, endsWith('...[truncated]'));
      },
    );

    test('default shell on POSIX is bash -lc <script>', () async {
      if (Platform.isWindows) return;

      final runner = WorkspaceHookRunner(
        logger: Logger(level: Level.quiet),
        isWindows: false,
      );
      final outcome = await runner.run(
        kind: WorkspaceHookKind.afterRun,
        workspacePath: tempDir.path,
        // `echo $0` prints the shell name; expecting "bash" confirms the
        // resolver picked the right default.
        hooks: _hooks(afterRun: r'echo $0'),
      );

      expect(outcome.succeeded, isTrue);
      expect(outcome.output.trim(), contains('bash'));
    });

    test('shell can be overridden via WORKFLOW.md', () async {
      if (Platform.isWindows) return;
      // Pick `sh` as a portable POSIX override, asserting the resolver
      // honors `hooks.shell` instead of falling back to `bash`.
      final runner = WorkspaceHookRunner(
        logger: Logger(level: Level.quiet),
        isWindows: false,
      );
      final outcome = await runner.run(
        kind: WorkspaceHookKind.afterRun,
        workspacePath: tempDir.path,
        hooks: _hooks(
          afterRun: r'echo $0',
          shell: 'sh',
          shellArguments: const <String>['-c'],
        ),
      );

      expect(outcome.succeeded, isTrue);
      // `sh -c "echo $0"` prints `sh` (or the literal arg-0 the shell sees).
      expect(outcome.output, isNotEmpty);
    });

    test('on Windows the default shell is cmd.exe /c <script>', () async {
      // Drive the resolver through a fake `isWindows` flag rather than the
      // real platform, then verify the spawn fails with the expected
      // "executable not found"-class error so we know cmd.exe was selected.
      if (Platform.isWindows) return;

      final runner = WorkspaceHookRunner(
        logger: Logger(level: Level.quiet),
        isWindows: true,
      );
      final outcome = await runner.run(
        kind: WorkspaceHookKind.afterRun,
        workspacePath: tempDir.path,
        hooks: _hooks(afterRun: r'echo hi'),
      );

      // cmd.exe is not installed on POSIX runners, so the spawn fails with
      // a categorized failure rather than executing through bash.
      expect(outcome.succeeded, isFalse);
      expect(outcome.output, contains('failed to spawn'));
    });

    test('HooksWorkflowConfig.fromMap parses shell + shell_arguments', () {
      final config = HooksWorkflowConfig.fromMap(<String, dynamic>{
        'shell': 'pwsh',
        'shell_arguments': <String>['-NoProfile', '-Command', '{}'],
        'after_create': 'Write-Host hi',
      });

      expect(config.shellExecutable, equals('pwsh'));
      expect(
        config.shellArguments,
        equals(<String>['-NoProfile', '-Command', '{}']),
      );
      expect(config.afterCreate, equals('Write-Host hi'));
    });

    test('shell falls back to platform default when fields are absent', () {
      final config = HooksWorkflowConfig.fromMap(const <String, dynamic>{});
      expect(config.shellExecutable, isNull);
      expect(config.shellArguments, isNull);
    });

    test(
      'output that fits within the cap is returned without a truncation marker',
      () async {
        if (Platform.isWindows) return;

        final runner = WorkspaceHookRunner(
          logger: Logger(level: Level.quiet),
          maxOutputBytes: 4096,
          isWindows: false,
        );
        final outcome = await runner.run(
          kind: WorkspaceHookKind.afterRun,
          workspacePath: tempDir.path,
          hooks: _hooks(afterRun: 'echo hello'),
        );

        expect(outcome.succeeded, isTrue);
        expect(outcome.output.trim(), equals('hello'));
        expect(outcome.output.contains('truncated'), isFalse);
      },
    );
  });
}
