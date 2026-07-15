import 'dart:convert';

import '../orchestration/scheduler.dart';

/// Frozen snapshot of the scheduler's state at a point in time.
///
/// This is the JSON shape exposed by `/api/v1/state` and persisted to
/// `.spectra/RUNTIME.json` for cold-start observability.
class RuntimeSnapshot {
  /// Wall-clock time the snapshot was generated.
  final DateTime generatedAt;

  /// Currently running entries.
  final List<Map<String, dynamic>> running;

  /// Pending retry queue.
  final List<Map<String, dynamic>> retrying;

  /// Issue ids currently claimed by the scheduler (running or queued).
  final List<String> claimed;

  /// Issue ids that have completed at least once.
  final List<String> completed;

  /// Aggregate token + runtime totals.
  final Map<String, dynamic> codexTotals;

  /// Latest known rate-limit payload, when available.
  final Map<String, dynamic>? rateLimits;

  /// Recent orchestration events (oldest first).
  final List<Map<String, dynamic>> recentEvents;

  /// Workflow validation errors blocking dispatch, when any.
  final List<String> validationErrors;

  /// Proof-of-work artifact path per issue identifier for completed or
  /// reviewable runs.
  final Map<String, String> proofOfWork;

  /// Creates a snapshot.
  const RuntimeSnapshot({
    required this.generatedAt,
    required this.running,
    required this.retrying,
    required this.claimed,
    required this.completed,
    required this.codexTotals,
    required this.recentEvents,
    required this.validationErrors,
    this.proofOfWork = const <String, String>{},
    this.rateLimits,
  });

  /// Builds a snapshot from a [Scheduler].
  factory RuntimeSnapshot.fromScheduler(Scheduler scheduler) {
    final now = DateTime.now();
    final totalsJson = scheduler.totals.toJson();
    // Add live elapsed time for active runs to the runtime aggregate so the
    // dashboard reflects in-flight work without continuously updating timers.
    var liveSeconds = (totalsJson['seconds_running'] as num).toDouble();
    for (final entry in scheduler.running.values) {
      liveSeconds += now.difference(entry.startedAt).inMilliseconds / 1000.0;
    }
    totalsJson['seconds_running'] = liveSeconds;

    return RuntimeSnapshot(
      generatedAt: now,
      running: scheduler.running.values
          .map((e) => e.toJson())
          .toList(growable: false),
      retrying: scheduler.retryAttempts.values
          .map((r) => r.toJson())
          .toList(growable: false),
      claimed: scheduler.claimed.toList(growable: false),
      completed: scheduler.completed.toList(growable: false),
      codexTotals: totalsJson,
      recentEvents: scheduler.recentEvents
          .map((e) => e.toJson())
          .toList(growable: false),
      validationErrors: scheduler.validationErrors,
      proofOfWork: scheduler.proofPaths,
    );
  }

  /// JSON view used by the snapshot file and HTTP API.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'generated_at': generatedAt.toIso8601String(),
    'counts': <String, int>{
      'running': running.length,
      'retrying': retrying.length,
      'claimed': claimed.length,
      'completed': completed.length,
    },
    'running': running,
    'retrying': retrying,
    'claimed': claimed,
    'completed': completed,
    'codex_totals': codexTotals,
    'rate_limits': rateLimits,
    'recent_events': recentEvents,
    'validation_errors': validationErrors,
    'proof_of_work': proofOfWork,
  };

  /// Returns the snapshot encoded as pretty-printed JSON.
  String toPrettyJson() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }
}
