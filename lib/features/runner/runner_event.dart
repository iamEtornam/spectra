/// Categorized error reasons emitted by an [AgentRunner].
///
/// Names mirror the Symphony app-server error categories so logs and snapshots
/// stay consistent across runners.
enum RunnerErrorCategory {
  /// Coding agent executable was not found.
  codexNotFound,

  /// Working directory passed to the coding agent was invalid.
  invalidWorkspaceCwd,

  /// Synchronous request/response timeout.
  responseTimeout,

  /// Total turn timeout reached.
  turnTimeout,

  /// Agent subprocess exited.
  portExit,

  /// Agent reported an explicit response error.
  responseError,

  /// Turn failed by agent contract.
  turnFailed,

  /// Turn was cancelled by the agent.
  turnCancelled,

  /// Agent requested user input we cannot satisfy.
  turnInputRequired,

  /// Prompt rendering failed before launch.
  promptError,

  /// LLM provider returned no usable file contents.
  emptyResponse,

  /// LLM provider response exceeded the configured byte cap.
  responseTooLarge,

  /// Underlying provider raised an exception.
  providerError,
}

/// Token-usage payload reported by the runner.
class RunnerTokenUsage {
  /// Input/prompt tokens.
  final int inputTokens;

  /// Output/completion tokens.
  final int outputTokens;

  /// Total tokens (input + output).
  final int totalTokens;

  /// Creates a token usage value.
  const RunnerTokenUsage({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
  });

  /// Returns a JSON view of the payload.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'total_tokens': totalTokens,
  };
}

/// Sealed runtime event emitted by an [AgentRunner].
sealed class RunnerEvent {
  /// Stable enum-like name for logging and snapshots.
  String get name;

  /// Timestamp when the event was emitted.
  final DateTime at;

  /// Optional human-readable summary.
  final String? message;

  /// Creates a runner event.
  RunnerEvent({DateTime? at, this.message}) : at = at ?? DateTime.now();

  /// Returns a JSON view used by the snapshot/dashboard.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'event': name,
    'at': at.toIso8601String(),
    if (message != null) 'message': message,
  };
}

/// Emitted once when the runner has launched and obtained a session id.
class SessionStarted extends RunnerEvent {
  /// Composite session id.
  final String sessionId;

  /// Optional thread id when the runner exposes one.
  final String? threadId;

  /// Optional turn id when the runner exposes one.
  final String? turnId;

  /// Creates the event.
  SessionStarted({
    required this.sessionId,
    this.threadId,
    this.turnId,
    super.at,
    super.message,
  });

  @override
  String get name => 'session_started';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'session_id': sessionId,
    if (threadId != null) 'thread_id': threadId,
    if (turnId != null) 'turn_id': turnId,
  };
}

/// Emitted when a new turn begins.
class TurnStarted extends RunnerEvent {
  /// 1-based turn ordinal within the worker session.
  final int turnNumber;

  /// Creates the event.
  TurnStarted({required this.turnNumber, super.at, super.message});

  @override
  String get name => 'turn_started';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'turn_number': turnNumber,
  };
}

/// Generic notification surfaced by the runner.
class RunnerNotification extends RunnerEvent {
  /// Creates a notification event.
  RunnerNotification({required String message, super.at})
    : super(message: message);

  @override
  String get name => 'notification';
}

/// Emitted when token usage is updated for the current turn.
class TokenUsageUpdated extends RunnerEvent {
  /// Latest token usage snapshot.
  final RunnerTokenUsage usage;

  /// Creates the event.
  TokenUsageUpdated({required this.usage, super.at, super.message});

  @override
  String get name => 'token_usage';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'usage': usage.toJson(),
  };
}

/// Emitted when a turn completes successfully.
class TurnCompleted extends RunnerEvent {
  /// 1-based turn ordinal.
  final int turnNumber;

  /// Files written during the turn (paths relative to the workspace root).
  final List<String> changedFiles;

  /// Creates the event.
  TurnCompleted({
    required this.turnNumber,
    this.changedFiles = const <String>[],
    super.at,
    super.message,
  });

  @override
  String get name => 'turn_completed';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'turn_number': turnNumber,
    'changed_files': changedFiles,
  };
}

/// Emitted when a turn fails with a categorized error.
class TurnFailed extends RunnerEvent {
  /// 1-based turn ordinal.
  final int turnNumber;

  /// Categorized error.
  final RunnerErrorCategory category;

  /// Creates the event.
  TurnFailed({
    required this.turnNumber,
    required this.category,
    super.at,
    super.message,
  });

  @override
  String get name => 'turn_failed';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'turn_number': turnNumber,
    'category': category.name,
  };
}

/// Emitted at the very end of a worker run.
class RunFinished extends RunnerEvent {
  /// Whether the worker exited normally.
  final bool succeeded;

  /// Total turns executed.
  final int turns;

  /// Aggregate token usage across all turns.
  final RunnerTokenUsage totalUsage;

  /// Creates the event.
  RunFinished({
    required this.succeeded,
    required this.turns,
    this.totalUsage = const RunnerTokenUsage(),
    super.at,
    super.message,
  });

  @override
  String get name => 'finished';

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    ...super.toJson(),
    'succeeded': succeeded,
    'turns': turns,
    'usage': totalUsage.toJson(),
  };
}
