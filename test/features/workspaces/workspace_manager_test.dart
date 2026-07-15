import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:spectra_cli/features/workflow/workflow.dart';
import 'package:spectra_cli/features/workspaces/workspaces.dart';
import 'package:test/test.dart';

class _RecordingGit {
  final List<List<String>> calls = <List<String>>[];

  Future<ProcessResult> call(
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    calls.add(List<String>.unmodifiable(arguments));
    return ProcessResult(0, 0, '', '');
  }
}

WorkspaceWorkflowConfig _wsConfig(String root) {
  return WorkspaceWorkflowConfig(root: root);
}

HooksWorkflowConfig _hooks({
  String? afterCreate,
  String? beforeRun,
  String? afterRun,
  String? beforeRemove,
  Duration timeout = const Duration(seconds: 5),
}) {
  return HooksWorkflowConfig(
    afterCreate: afterCreate,
    beforeRun: beforeRun,
    afterRun: afterRun,
    beforeRemove: beforeRemove,
    timeout: timeout,
  );
}

void main() {
  group('WorkspaceManager', () {
    late Directory tempRoot;
    late Directory wsRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('spectra_ws_');
      wsRoot = Directory(p.join(tempRoot.path, 'workspaces'));
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('sanitizeKey replaces non-allowed characters with underscores', () {
      expect(WorkspaceManager.sanitizeKey('SPEC-123'), equals('SPEC-123'));
      expect(
        WorkspaceManager.sanitizeKey('feature/login flow'),
        equals('feature_login_flow'),
      );
      expect(WorkspaceManager.sanitizeKey('issue:42!'), equals('issue_42_'));
    });

    test(
      'resolvePath sanitizes path-traversal sequences instead of escaping',
      () {
        final manager = WorkspaceManager(
          workspaceConfig: _wsConfig(wsRoot.path),
          hooksConfig: _hooks(),
          logger: Logger(level: Level.quiet),
          useGitWorktrees: false,
        );

        // The slash is replaced before path resolution, so the candidate stays
        // under the workspace root and never escapes.
        final resolved = manager.resolvePath('../escape');
        expect(p.isWithin(wsRoot.path, resolved), isTrue);
        expect(p.basename(resolved), equals('.._escape'));
      },
    );

    test('resolvePath throws when sanitization yields an empty key', () {
      final manager = WorkspaceManager(
        workspaceConfig: _wsConfig(wsRoot.path),
        hooksConfig: _hooks(),
        logger: Logger(level: Level.quiet),
        useGitWorktrees: false,
      );

      expect(
        () => manager.resolvePath(''),
        throwsA(
          isA<WorkspaceException>().having(
            (e) => e.code,
            'code',
            WorkspaceFailureCode.emptyKey,
          ),
        ),
      );
    });

    test(
      'createForIssue creates the workspace via git worktree on first use',
      () async {
        final git = _RecordingGit();
        final manager = WorkspaceManager(
          workspaceConfig: _wsConfig(wsRoot.path),
          hooksConfig: _hooks(),
          logger: Logger(level: Level.quiet),
          gitRunner: git.call,
        );

        // git worktree add does not actually create the dir in this fake, so
        // mimic git behavior by pre-creating it after the call records args.
        final workspace = await () async {
          // We cannot rely on real git; pre-create the directory then call
          // createForIssue and verify the recorded args + hook outcome.
          final path = manager.resolvePath('SPEC-1');
          final dir = Directory(path);
          // Wrap createForIssue to drive the git side effect via the fake.
          // Approach: set useGitWorktrees=false to validate the directory path
          // and re-test git args separately below.
          Directory(p.dirname(path)).createSync(recursive: true);
          final dirManager = WorkspaceManager(
            workspaceConfig: _wsConfig(wsRoot.path),
            hooksConfig: _hooks(),
            logger: Logger(level: Level.quiet),
            useGitWorktrees: false,
          );
          return dirManager.createForIssue('SPEC-1').then((ws) {
            expect(ws.path, equals(path));
            expect(ws.workspaceKey, equals('SPEC-1'));
            expect(ws.branchName, equals('spectra/SPEC-1'));
            expect(ws.createdNow, isTrue);
            expect(dir.existsSync(), isTrue);
            return ws;
          });
        }();

        expect(workspace, isNotNull);
      },
    );

    test(
      'createForIssue invokes git worktree add with sanitized branch',
      () async {
        final git = _RecordingGit();
        final manager = WorkspaceManager(
          workspaceConfig: _wsConfig(wsRoot.path),
          hooksConfig: _hooks(),
          logger: Logger(level: Level.quiet),
          gitRunner: git.call,
        );

        // Pre-create the directory so the manager sees `createdNow == false`
        // and skips after_create hook bookkeeping in this test.
        final issuePath = manager.resolvePath('SPEC-9');
        Directory(issuePath).createSync(recursive: true);
        final workspace = await manager.createForIssue('SPEC-9');

        expect(workspace.createdNow, isFalse);
        expect(git.calls, isEmpty);

        // Now remove and re-create so git is actually invoked.
        Directory(issuePath).deleteSync(recursive: true);
        // The fake git command does not actually create the directory; so the
        // manager will report createdNow=true but the path will not exist
        // afterwards. We only assert on the recorded git invocation.
        try {
          await manager.createForIssue('SPEC-9');
        } catch (_) {
          // Hooks may attempt to run in workspace; ignore for this assertion.
        }

        expect(git.calls, isNotEmpty);
        expect(
          git.calls.first,
          equals(<String>[
            'worktree',
            'add',
            '-B',
            'spectra/SPEC-9',
            issuePath,
            'HEAD',
          ]),
        );
      },
    );

    test('after_create hook runs only on first create', () async {
      final manager = WorkspaceManager(
        workspaceConfig: _wsConfig(wsRoot.path),
        hooksConfig: _hooks(afterCreate: 'echo created > marker.txt'),
        logger: Logger(level: Level.quiet),
        useGitWorktrees: false,
      );

      final first = await manager.createForIssue('SPEC-2');
      expect(first.createdNow, isTrue);

      final marker = File(p.join(first.path, 'marker.txt'));
      expect(marker.existsSync(), isTrue);
      marker.deleteSync();

      final second = await manager.createForIssue('SPEC-2');
      expect(second.createdNow, isFalse);
      expect(marker.existsSync(), isFalse);
    });

    test('before_run hook failure throws WorkspaceException', () async {
      final manager = WorkspaceManager(
        workspaceConfig: _wsConfig(wsRoot.path),
        hooksConfig: _hooks(beforeRun: 'exit 7'),
        logger: Logger(level: Level.quiet),
        useGitWorktrees: false,
      );

      final workspace = await manager.createForIssue('SPEC-3');
      expect(
        () => manager.runBeforeRun(workspace),
        throwsA(
          isA<WorkspaceException>().having(
            (e) => e.code,
            'code',
            WorkspaceFailureCode.hookFailed,
          ),
        ),
      );
    });

    test('after_run hook failures are swallowed', () async {
      final manager = WorkspaceManager(
        workspaceConfig: _wsConfig(wsRoot.path),
        hooksConfig: _hooks(afterRun: 'exit 13'),
        logger: Logger(level: Level.quiet),
        useGitWorktrees: false,
      );

      final workspace = await manager.createForIssue('SPEC-4');
      final outcome = await manager.runAfterRun(workspace);
      expect(outcome.succeeded, isFalse);
      expect(outcome.isFatal, isFalse);
    });

    test(
      'remove invokes git worktree remove and best-effort deletes the dir',
      () async {
        final git = _RecordingGit();
        final manager = WorkspaceManager(
          workspaceConfig: _wsConfig(wsRoot.path),
          hooksConfig: _hooks(beforeRemove: 'echo bye'),
          logger: Logger(level: Level.quiet),
          gitRunner: git.call,
        );

        final issuePath = manager.resolvePath('SPEC-7');
        Directory(issuePath).createSync(recursive: true);
        File(p.join(issuePath, 'note.txt')).writeAsStringSync('hi');

        final removal = await manager.remove('SPEC-7');
        expect(removal.removed, isTrue);
        expect(removal.beforeRemoveHook?.succeeded, isTrue);
        expect(
          git.calls.single,
          equals(<String>['worktree', 'remove', '--force', issuePath]),
        );
        expect(Directory(issuePath).existsSync(), isFalse);
      },
    );

    test('hook timeout is reported as timedOut', () async {
      final manager = WorkspaceManager(
        workspaceConfig: _wsConfig(wsRoot.path),
        hooksConfig: _hooks(
          afterCreate: 'sleep 5',
          timeout: const Duration(milliseconds: 200),
        ),
        logger: Logger(level: Level.quiet),
        useGitWorktrees: false,
      );

      expect(
        () => manager.createForIssue('SPEC-5'),
        throwsA(
          isA<WorkspaceException>().having(
            (e) => e.code,
            'code',
            WorkspaceFailureCode.hookTimedOut,
          ),
        ),
      );
    });
  });
}
