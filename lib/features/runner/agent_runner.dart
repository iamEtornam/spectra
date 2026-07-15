import '../tracker/issue.dart';
import '../workspaces/workspace.dart';
import 'runner_event.dart';

/// Inputs handed to an [AgentRunner] for a single attempt.
class AgentRunRequest {
  /// Issue being worked on.
  final Issue issue;

  /// Workspace prepared by [WorkspaceManager].
  final Workspace workspace;

  /// Rendered prompt template (Markdown body of `WORKFLOW.md`).
  final String renderedPrompt;

  /// Attempt number (`null` on first run, `>=1` for retry/continuation).
  final int? attempt;

  /// Maximum number of turns the runner is allowed to take.
  final int maxTurns;

  /// Creates a request.
  const AgentRunRequest({
    required this.issue,
    required this.workspace,
    required this.renderedPrompt,
    required this.maxTurns,
    this.attempt,
  });
}

/// Pluggable execution engine that turns a prepared prompt into file changes.
///
/// Implementations are expected to:
///
/// * Stream [RunnerEvent]s in chronological order.
/// * Emit exactly one [RunFinished] event before closing the stream.
/// * Constrain all writes to the workspace path (`request.workspace.path`).
/// * Surface failures as [TurnFailed] / [RunFinished(succeeded: false)] events
///   instead of throwing, so the scheduler can record them deterministically.
abstract class AgentRunner {
  /// Stable name (`llm`, `codex`, ...).
  String get name;

  /// Runs one attempt and returns a stream of events.
  Stream<RunnerEvent> run(AgentRunRequest request);

  /// Releases adapter-managed resources.
  Future<void> close() async {}
}
