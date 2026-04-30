import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../workflow/workflow_config.dart';
import 'workspace_failure.dart';

/// Identifies which lifecycle hook is being executed.
enum WorkspaceHookKind {
  /// Runs once when a workspace is first created.
  afterCreate,

  /// Runs before each agent attempt.
  beforeRun,

  /// Runs after each agent attempt regardless of outcome.
  afterRun,

  /// Runs before workspace removal.
  beforeRemove,
}

extension WorkspaceHookKindName on WorkspaceHookKind {
  /// Human-readable name used in logs and config keys.
  String get keyName {
    switch (this) {
      case WorkspaceHookKind.afterCreate:
        return 'after_create';
      case WorkspaceHookKind.beforeRun:
        return 'before_run';
      case WorkspaceHookKind.afterRun:
        return 'after_run';
      case WorkspaceHookKind.beforeRemove:
        return 'before_remove';
    }
  }
}

/// Outcome of a hook execution.
class WorkspaceHookOutcome {
  /// Hook that ran.
  final WorkspaceHookKind kind;

  /// Whether the hook completed successfully (exit code 0, no timeout).
  final bool succeeded;

  /// True when the hook exceeded the configured timeout.
  final bool timedOut;

  /// Exit code, when known.
  final int? exitCode;

  /// Truncated combined stdout/stderr for observability.
  final String output;

  /// Creates an outcome.
  const WorkspaceHookOutcome({
    required this.kind,
    required this.succeeded,
    required this.timedOut,
    required this.exitCode,
    required this.output,
  });

  /// Whether this hook outcome should fail the current workspace operation.
  ///
  /// Spec semantics: `after_create` and `before_run` failures are fatal,
  /// `after_run` and `before_remove` failures are logged and ignored.
  bool get isFatal {
    if (succeeded) return false;
    return kind == WorkspaceHookKind.afterCreate ||
        kind == WorkspaceHookKind.beforeRun;
  }
}

/// Runs workspace lifecycle hooks via `bash -lc <script>` with a timeout.
class WorkspaceHookRunner {
  /// Logger for hook lifecycle messages.
  final Logger logger;

  /// Maximum bytes of combined stdout/stderr captured per hook (truncated).
  final int maxOutputBytes;

  /// Creates a hook runner.
  const WorkspaceHookRunner({required this.logger, this.maxOutputBytes = 4096});

  /// Runs [kind] for [workspacePath] using config in [hooks].
  ///
  /// When the hook is unset for [kind], returns a successful outcome with
  /// empty output. When the hook fails or times out and [kind] is fatal, the
  /// caller is expected to throw [WorkspaceException] with the proper code.
  Future<WorkspaceHookOutcome> run({
    required WorkspaceHookKind kind,
    required String workspacePath,
    required HooksWorkflowConfig hooks,
  }) async {
    final script = _scriptFor(kind, hooks);
    if (script == null || script.trim().isEmpty) {
      return WorkspaceHookOutcome(
        kind: kind,
        succeeded: true,
        timedOut: false,
        exitCode: 0,
        output: '',
      );
    }

    logger.detail('[hook ${kind.keyName}] starting in $workspacePath');

    final Process process;
    try {
      process = await Process.start(
        'bash',
        <String>['-lc', script],
        workingDirectory: workspacePath,
        runInShell: false,
      );
    } catch (e) {
      logger.err('[hook ${kind.keyName}] failed to spawn: $e');
      return WorkspaceHookOutcome(
        kind: kind,
        succeeded: false,
        timedOut: false,
        exitCode: null,
        output: 'failed to spawn: $e',
      );
    }

    final outputBuffer = StringBuffer();
    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .listen(outputBuffer.write);
    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .listen(outputBuffer.write);

    int? exitCode;
    var timedOut = false;
    try {
      exitCode = await process.exitCode.timeout(
        hooks.timeout,
        onTimeout: () {
          timedOut = true;
          process.kill(ProcessSignal.sigterm);
          return -1;
        },
      );
    } finally {
      await stdoutSub.cancel();
      await stderrSub.cancel();
    }

    final captured = _truncate(outputBuffer.toString());
    final succeeded = !timedOut && exitCode == 0;

    if (timedOut) {
      logger.err(
        '[hook ${kind.keyName}] timed out after ${hooks.timeout.inSeconds}s',
      );
    } else if (!succeeded) {
      logger.err('[hook ${kind.keyName}] exited with code $exitCode');
    } else {
      logger.detail('[hook ${kind.keyName}] completed successfully');
    }

    return WorkspaceHookOutcome(
      kind: kind,
      succeeded: succeeded,
      timedOut: timedOut,
      exitCode: timedOut ? null : exitCode,
      output: captured,
    );
  }

  String _truncate(String value) {
    if (value.length <= maxOutputBytes) return value;
    return '${value.substring(0, maxOutputBytes)}...[truncated]';
  }

  String? _scriptFor(WorkspaceHookKind kind, HooksWorkflowConfig hooks) {
    switch (kind) {
      case WorkspaceHookKind.afterCreate:
        return hooks.afterCreate;
      case WorkspaceHookKind.beforeRun:
        return hooks.beforeRun;
      case WorkspaceHookKind.afterRun:
        return hooks.afterRun;
      case WorkspaceHookKind.beforeRemove:
        return hooks.beforeRemove;
    }
  }
}
