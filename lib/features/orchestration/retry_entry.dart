import 'dart:async';

/// Distinguishes continuation retries (after a successful exit) from
/// failure-driven retries.
enum RetryKind {
  /// Short delay re-check after a clean worker exit.
  continuation,

  /// Exponential backoff after a worker failure.
  failure,
}

/// Snapshot of a queued retry.
class RetryEntry {
  /// Issue id the retry is for.
  final String issueId;

  /// Best-effort human identifier.
  final String identifier;

  /// 1-based retry attempt number.
  final int attempt;

  /// Whether this is a continuation or failure retry.
  final RetryKind kind;

  /// Wall-clock time when the retry should fire.
  final DateTime dueAt;

  /// Optional error message captured when the retry was scheduled.
  final String? error;

  /// Active timer handle. May be null in unit tests.
  final Timer? timer;

  /// Creates a retry entry.
  const RetryEntry({
    required this.issueId,
    required this.identifier,
    required this.attempt,
    required this.kind,
    required this.dueAt,
    this.error,
    this.timer,
  });

  /// JSON view used by snapshots.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'issue_id': issueId,
    'identifier': identifier,
    'attempt': attempt,
    'kind': kind.name,
    'due_at': dueAt.toIso8601String(),
    if (error != null) 'error': error,
  };
}
