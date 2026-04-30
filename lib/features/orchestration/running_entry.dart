import 'dart:async';

import '../runner/runner_event.dart';
import '../tracker/issue.dart';
import '../workspaces/workspace.dart';
import 'run_attempt.dart';

/// State the scheduler tracks for a currently running worker.
class RunningEntry {
  /// Issue snapshot at dispatch time. Updated by reconciliation.
  Issue issue;

  /// Workspace assigned to the worker.
  final Workspace workspace;

  /// Current attempt status.
  RunAttemptStatus status;

  /// Subscription to the runner event stream. Cancelled by reconciliation
  /// or shutdown. Mutable so the scheduler can attach the real subscription
  /// after constructing the entry.
  StreamSubscription<RunnerEvent> subscription;

  /// Wall-clock time when the worker started.
  final DateTime startedAt;

  /// Most recent runner event.
  RunnerEvent? lastEvent;

  /// Time the most recent event was observed.
  DateTime? lastEventAt;

  /// Aggregate token usage seen so far for this run.
  RunnerTokenUsage usage;

  /// Number of completed turns inside the worker.
  int turnCount;

  /// Creates a running entry.
  RunningEntry({
    required this.issue,
    required this.workspace,
    required this.status,
    required this.subscription,
    required this.startedAt,
    this.lastEvent,
    this.lastEventAt,
    this.usage = const RunnerTokenUsage(),
    this.turnCount = 0,
  });

  /// JSON view used by snapshots and `/api/v1/state`.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'issue_id': issue.id,
    'issue_identifier': issue.identifier,
    'state': issue.state,
    'workspace_path': workspace.path,
    'started_at': startedAt.toIso8601String(),
    'turn_count': turnCount,
    'last_event': lastEvent?.name,
    'last_event_at': lastEventAt?.toIso8601String(),
    'tokens': usage.toJson(),
    'attempt': status.toJson(),
  };
}
