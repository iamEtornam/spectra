import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../workflow/workflow_config.dart';
import 'workspace.dart';
import 'workspace_failure.dart';
import 'workspace_hooks.dart';

/// Result of a workspace removal request.
class WorkspaceRemoval {
  /// Whether the workspace directory was removed.
  final bool removed;

  /// Whether the worktree itself was unregistered with git.
  final bool worktreeRemoved;

  /// Outcome of the `before_remove` hook, when configured.
  final WorkspaceHookOutcome? beforeRemoveHook;

  /// Creates a removal report.
  const WorkspaceRemoval({
    required this.removed,
    required this.worktreeRemoved,
    this.beforeRemoveHook,
  });
}

/// Pluggable command runner used to invoke `git`. Tests can swap this for a
/// stub that records arguments without spawning a subprocess.
typedef GitCommandRunner =
    Future<ProcessResult> Function(
      List<String> arguments, {
      String? workingDirectory,
    });

Future<ProcessResult> _defaultGitRunner(
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
  );
}

/// Creates and reuses per-issue workspaces backed by git worktrees.
///
/// The manager enforces the Symphony safety invariants:
///
/// * Workspace keys are sanitized to `[A-Za-z0-9._-]`.
/// * Workspace paths must remain inside the configured workspace root.
/// * Each workspace is the cwd handed to the agent runner.
class WorkspaceManager {
  /// Workspace settings derived from `WORKFLOW.md`.
  final WorkspaceWorkflowConfig workspaceConfig;

  /// Hook configuration applied when running lifecycle hooks.
  final HooksWorkflowConfig hooksConfig;

  /// Repository root used as the source for git worktrees. Defaults to the
  /// current working directory.
  final String repositoryRoot;

  /// Hook runner used for `after_create`/`before_run`/`after_run`/`before_remove`.
  final WorkspaceHookRunner hookRunner;

  /// Logger for status messages.
  final Logger logger;

  /// Branch ref (or commit) used as the base for new worktrees.
  final String baseRef;

  /// Whether to actually create git worktrees.
  ///
  /// When false, the manager will create plain directories. Used by tests and
  /// non-git project roots.
  final bool useGitWorktrees;

  /// Pluggable git runner used by tests.
  final GitCommandRunner _git;

  /// Sanitization regex.
  static final RegExp _illegalChars = RegExp(r'[^A-Za-z0-9._-]');

  /// Creates a workspace manager.
  WorkspaceManager({
    required this.workspaceConfig,
    required this.hooksConfig,
    required this.logger,
    String? repositoryRoot,
    WorkspaceHookRunner? hookRunner,
    this.baseRef = 'HEAD',
    bool? useGitWorktrees,
    GitCommandRunner? gitRunner,
  }) : repositoryRoot = repositoryRoot ?? Directory.current.path,
       hookRunner = hookRunner ?? WorkspaceHookRunner(logger: logger),
       useGitWorktrees = useGitWorktrees ?? true,
       _git = gitRunner ?? _defaultGitRunner;

  /// Sanitizes [identifier] into a workspace key.
  ///
  /// Visible for testing.
  static String sanitizeKey(String identifier) {
    final replaced = identifier.replaceAll(_illegalChars, '_');
    return replaced.replaceAll(RegExp(r'_+'), '_');
  }

  /// Resolves the workspace path for [issueIdentifier] without creating it.
  String resolvePath(String issueIdentifier) {
    final key = sanitizeKey(issueIdentifier);
    if (key.isEmpty) {
      throw const WorkspaceException(
        WorkspaceFailureCode.emptyKey,
        'Workspace key resolved to an empty string after sanitization.',
      );
    }
    final candidate = p.normalize(p.join(workspaceConfig.root, key));
    final root = p.normalize(workspaceConfig.root);
    if (!p.isWithin(root, candidate) && candidate != root) {
      throw WorkspaceException(
        WorkspaceFailureCode.pathEscape,
        'Workspace path $candidate escapes root $root.',
      );
    }
    return candidate;
  }

  /// Creates or reuses the workspace for [issueIdentifier].
  Future<Workspace> createForIssue(String issueIdentifier) async {
    final key = sanitizeKey(issueIdentifier);
    if (key.isEmpty) {
      throw const WorkspaceException(
        WorkspaceFailureCode.emptyKey,
        'Workspace key resolved to an empty string after sanitization.',
      );
    }

    final root = p.normalize(workspaceConfig.root);
    final path = resolvePath(issueIdentifier);
    final branchName = 'spectra/$key';

    Directory(root).createSync(recursive: true);

    final dir = Directory(path);
    final existedBefore = dir.existsSync();
    var createdNow = false;

    if (!existedBefore) {
      if (useGitWorktrees) {
        final result = await _git(<String>[
          'worktree',
          'add',
          '-B',
          branchName,
          path,
          baseRef,
        ], workingDirectory: repositoryRoot);
        if (result.exitCode != 0) {
          throw WorkspaceException(
            WorkspaceFailureCode.worktreeAddFailed,
            'git worktree add failed (exit ${result.exitCode}): ${result.stderr}',
          );
        }
      } else {
        try {
          dir.createSync(recursive: true);
        } catch (e) {
          throw WorkspaceException(
            WorkspaceFailureCode.createFailed,
            'Failed to create workspace directory $path: $e',
            cause: e,
          );
        }
      }
      createdNow = true;
    }

    final workspace = Workspace(
      workspaceKey: key,
      path: path,
      branchName: branchName,
      createdNow: createdNow,
    );

    if (createdNow) {
      final outcome = await hookRunner.run(
        kind: WorkspaceHookKind.afterCreate,
        workspacePath: path,
        hooks: hooksConfig,
      );
      if (outcome.isFatal) {
        await _bestEffortRemoveWorktree(path);
        throw WorkspaceException(
          outcome.timedOut
              ? WorkspaceFailureCode.hookTimedOut
              : WorkspaceFailureCode.hookFailed,
          'after_create hook failed: ${outcome.output}',
        );
      }
    }

    return workspace;
  }

  /// Runs the configured `before_run` hook.
  ///
  /// Throws when the hook is fatal so the scheduler can fail the attempt.
  Future<WorkspaceHookOutcome> runBeforeRun(Workspace workspace) async {
    final outcome = await hookRunner.run(
      kind: WorkspaceHookKind.beforeRun,
      workspacePath: workspace.path,
      hooks: hooksConfig,
    );
    if (outcome.isFatal) {
      throw WorkspaceException(
        outcome.timedOut
            ? WorkspaceFailureCode.hookTimedOut
            : WorkspaceFailureCode.hookFailed,
        'before_run hook failed: ${outcome.output}',
      );
    }
    return outcome;
  }

  /// Runs the configured `after_run` hook. Failures are swallowed per spec.
  Future<WorkspaceHookOutcome> runAfterRun(Workspace workspace) {
    return hookRunner.run(
      kind: WorkspaceHookKind.afterRun,
      workspacePath: workspace.path,
      hooks: hooksConfig,
    );
  }

  /// Removes the workspace directory and unregisters the worktree.
  ///
  /// `before_remove` hook failures are logged and ignored.
  Future<WorkspaceRemoval> remove(String issueIdentifier) async {
    final path = resolvePath(issueIdentifier);
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return const WorkspaceRemoval(removed: false, worktreeRemoved: false);
    }

    final beforeRemove = await hookRunner.run(
      kind: WorkspaceHookKind.beforeRemove,
      workspacePath: path,
      hooks: hooksConfig,
    );

    var worktreeRemoved = false;
    if (useGitWorktrees) {
      final result = await _git(<String>[
        'worktree',
        'remove',
        '--force',
        path,
      ], workingDirectory: repositoryRoot);
      worktreeRemoved = result.exitCode == 0;
      if (!worktreeRemoved) {
        logger.warn(
          'git worktree remove failed (exit ${result.exitCode}): ${result.stderr}',
        );
      }
    }

    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (e) {
        logger.warn('Failed to delete workspace directory $path: $e');
      }
    }

    return WorkspaceRemoval(
      removed: !dir.existsSync(),
      worktreeRemoved: worktreeRemoved,
      beforeRemoveHook: beforeRemove,
    );
  }

  Future<void> _bestEffortRemoveWorktree(String path) async {
    if (!Directory(path).existsSync()) return;
    if (useGitWorktrees) {
      try {
        await _git(<String>[
          'worktree',
          'remove',
          '--force',
          path,
        ], workingDirectory: repositoryRoot);
      } catch (_) {
        // Swallow; we still try to delete the directory below.
      }
    }
    try {
      Directory(path).deleteSync(recursive: true);
    } catch (_) {
      // Best-effort cleanup.
    }
  }
}
