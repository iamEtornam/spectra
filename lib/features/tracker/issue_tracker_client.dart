import 'issue.dart';
import 'tracker_failure.dart';

/// Adapter contract every issue tracker integration must satisfy.
///
/// Implementations are expected to be stateless wrt the orchestrator: every
/// call returns either a fresh [TrackerResult] containing normalized [Issue]s
/// or a categorized [TrackerFailure].
abstract class IssueTrackerClient {
  /// Stable identifier for this tracker kind (`linear`, `local_plan`, ...).
  String get kind;

  /// Returns issues currently in the configured `active_states`, sorted by the
  /// adapter's natural order (the scheduler will re-sort for dispatch).
  Future<TrackerResult<List<Issue>>> fetchCandidates();

  /// Returns minimal normalized issues for the supplied [issueIds].
  ///
  /// Used by reconciliation. Implementations MAY return a subset when issues
  /// no longer exist, and SHOULD include enough state for the scheduler to
  /// classify the issue (state, identifier, blockers when relevant).
  Future<TrackerResult<List<Issue>>> fetchStatesByIds(List<String> issueIds);

  /// Returns issues currently in any of the supplied [stateNames].
  ///
  /// Used by startup terminal-workspace cleanup. An empty input list MUST
  /// short-circuit with an empty success result without making a network call.
  Future<TrackerResult<List<Issue>>> fetchByStates(List<String> stateNames);

  /// Releases adapter-managed resources (HTTP clients, timers, etc.).
  ///
  /// Called when the scheduler shuts down. Default implementation is a no-op.
  Future<void> close() async {}
}
