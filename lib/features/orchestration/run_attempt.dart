/// Phases a single agent attempt transitions through.
///
/// Mirrors Symphony §7.2 lifecycle phases.
enum RunAttemptPhase {
  /// Workspace is being created or reused.
  preparingWorkspace,

  /// Prompt is being rendered from the workflow template.
  buildingPrompt,

  /// Agent runner subprocess/HTTP call is launching.
  launchingAgentProcess,

  /// Runner session has started and is initializing turn state.
  initializingSession,

  /// Runner is streaming a turn.
  streamingTurn,

  /// Runner has emitted final events; waiting on cleanup.
  finishing,

  /// Attempt completed successfully.
  succeeded,

  /// Attempt failed with a runner-side error.
  failed,

  /// Attempt failed because of a turn timeout.
  timedOut,

  /// Attempt killed by the scheduler because no events arrived in time.
  stalled,

  /// Attempt cancelled because reconciliation determined it was no longer
  /// eligible (terminal or non-active tracker state).
  canceledByReconciliation,
}

/// Snapshot of one attempt at a point in time.
class RunAttemptStatus {
  /// Stable run identifier (`<issue_id>-<attempt>`).
  final String runId;

  /// Issue id this attempt belongs to.
  final String issueId;

  /// Human-readable issue identifier.
  final String issueIdentifier;

  /// 1-based attempt number (1 for first run).
  final int attempt;

  /// Current phase.
  final RunAttemptPhase phase;

  /// Workspace path used by the attempt.
  final String workspacePath;

  /// Wall-clock start time.
  final DateTime startedAt;

  /// Optional human-readable error.
  final String? error;

  /// Creates a snapshot.
  const RunAttemptStatus({
    required this.runId,
    required this.issueId,
    required this.issueIdentifier,
    required this.attempt,
    required this.phase,
    required this.workspacePath,
    required this.startedAt,
    this.error,
  });

  /// Returns a copy with a new phase or error.
  RunAttemptStatus copyWith({RunAttemptPhase? phase, String? error}) {
    return RunAttemptStatus(
      runId: runId,
      issueId: issueId,
      issueIdentifier: issueIdentifier,
      attempt: attempt,
      phase: phase ?? this.phase,
      workspacePath: workspacePath,
      startedAt: startedAt,
      error: error ?? this.error,
    );
  }

  /// JSON view used by snapshots and logs.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'run_id': runId,
    'issue_id': issueId,
    'issue_identifier': issueIdentifier,
    'attempt': attempt,
    'phase': phase.name,
    'workspace_path': workspacePath,
    'started_at': startedAt.toIso8601String(),
    if (error != null) 'error': error,
  };
}
