/// Aggregate token + runtime totals tracked by the scheduler across all runs.
class CodexTotals {
  /// Total input tokens consumed.
  int inputTokens;

  /// Total output tokens consumed.
  int outputTokens;

  /// Total tokens consumed.
  int totalTokens;

  /// Cumulative seconds across ended sessions (running sessions are added live
  /// when producing snapshots).
  double secondsRunning;

  /// Creates a totals counter.
  CodexTotals({
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.totalTokens = 0,
    this.secondsRunning = 0,
  });

  /// JSON view used by snapshots.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'total_tokens': totalTokens,
    'seconds_running': secondsRunning,
  };

  /// Adds an isolated delta to the totals.
  void addUsage({
    int inputTokens = 0,
    int outputTokens = 0,
    int totalTokens = 0,
  }) {
    this.inputTokens += inputTokens;
    this.outputTokens += outputTokens;
    this.totalTokens += totalTokens;
  }

  /// Adds elapsed seconds for an ended session.
  void addEndedSession(Duration elapsed) {
    secondsRunning += elapsed.inMilliseconds / 1000.0;
  }
}
