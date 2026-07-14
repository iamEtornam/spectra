import 'dart:async';
import 'dart:collection';

import 'package:mason_logger/mason_logger.dart';

import '../observability/proof_of_work.dart';
import '../runner/agent_runner.dart';
import '../runner/runner_event.dart';
import '../tracker/issue.dart';
import '../tracker/issue_tracker_client.dart';
import '../workflow/workflow_config.dart';
import '../workspaces/workspace_failure.dart';
import '../workspaces/workspace_manager.dart';
import 'codex_totals.dart';
import 'orchestration_event.dart';
import 'retry_entry.dart';
import 'run_attempt.dart';
import 'running_entry.dart';

/// Builds a rendered prompt for one attempt. The scheduler stays decoupled
/// from the prompt renderer so tests can swap in deterministic builders.
typedef PromptBuilder = String Function(Issue issue, int? attempt);

/// Single-authority scheduler that owns dispatch, reconciliation, and retries.
///
/// Implements the Symphony orchestration state machine (§7) using an
/// in-memory state model. The scheduler is the only component that mutates
/// scheduling state — runners and trackers report results back through it.
class Scheduler {
  /// Workflow config governing dispatch behavior.
  ///
  /// Mutable so [updateConfig] can apply hot-reloaded `WORKFLOW.md` settings.
  /// Every read (`config.*`) inside the scheduler happens dynamically per
  /// tick / dispatch / retry, so swapping this field takes effect on the next
  /// tick without restarting the scheduler.
  WorkflowConfig _config;

  /// Returns the currently active workflow config.
  WorkflowConfig get config => _config;

  /// Tracker adapter used to fetch candidates and refresh state.
  final IssueTrackerClient tracker;

  /// Workspace manager used to create per-issue workspaces.
  final WorkspaceManager workspaceManager;

  /// Agent runner used to actually execute work.
  final AgentRunner runner;

  /// Builds the rendered prompt for an issue.
  final PromptBuilder promptBuilder;

  /// Logger for status messages.
  final Logger logger;

  /// Maximum retained orchestration events for snapshots.
  final int eventHistorySize;

  /// Root directory for per-run proof-of-work artifacts.
  final String runsRoot;

  /// Whether proof-of-work artifacts are written when runs end.
  final bool writeProofOfWork;

  /// Internal state.
  final Map<String, RunningEntry> _running = <String, RunningEntry>{};
  final Set<String> _claimed = <String>{};
  final Map<String, RetryEntry> _retryAttempts = <String, RetryEntry>{};
  final Set<String> _completed = <String>{};
  final CodexTotals _totals = CodexTotals();
  final Queue<OrchestrationEvent> _events = Queue<OrchestrationEvent>();
  final List<String> _validationErrors = <String>[];
  final Map<String, List<String>> _changedFilesByRun = <String, List<String>>{};
  final Map<String, List<String>> _retryHistoryByIssue =
      <String, List<String>>{};
  final Map<String, String> _proofPathsByIssue = <String, String>{};

  /// Successful runs (turns) per issue. Kept separate from the retry
  /// `attempt` counter: failure retries and slot-contention requeues bump
  /// `attempt` without doing work, and must not deplete the turn budget.
  final Map<String, int> _turnsByIssue = <String, int>{};

  Timer? _pollTimer;
  bool _running_ = false;
  bool _shuttingDown = false;

  /// Number of `_dispatchIssue` invocations that have started but have not
  /// yet finished placing an entry into `_running` (or failing). Required for
  /// honoring the global concurrency cap because `_dispatchIssue` is async:
  /// the synchronous dispatch loop and other retry callbacks would otherwise
  /// observe a stale `_running.length` and over-dispatch.
  int _pendingDispatches = 0;

  /// Creates a scheduler.
  Scheduler({
    required WorkflowConfig config,
    required this.tracker,
    required this.workspaceManager,
    required this.runner,
    required this.promptBuilder,
    required this.logger,
    this.eventHistorySize = 100,
    this.runsRoot = '.spectra/runs',
    this.writeProofOfWork = true,
  }) : _config = config;

  /// Hot-swaps the active workflow config.
  ///
  /// Called by `WorkflowWatcher` listeners after `WORKFLOW.md` is reloaded.
  /// Subsequent reads of `config.*` inside ticks, dispatches, and retries
  /// observe the new values immediately. If `polling.interval` changed, the
  /// pending poll timer is cancelled and rescheduled with the new value so
  /// the change takes effect without waiting for the previously scheduled
  /// tick to fire.
  ///
  /// In-flight agent sessions are not restarted; callers that need to react
  /// to changes in `tracker.kind`, `agent.runner`, or `workspace.root` should
  /// surface their own operator-visible warnings before invoking this method.
  void updateConfig(WorkflowConfig next) {
    final previous = _config;
    if (identical(previous, next)) return;

    _config = next;
    final intervalChanged = previous.polling.interval != next.polling.interval;

    _record(
      'config_reloaded',
      'Workflow config reloaded '
          '(poll=${next.polling.interval.inMilliseconds}ms, '
          'max_concurrent=${next.agent.maxConcurrentAgents}, '
          'max_turns=${next.agent.maxTurns}).',
      data: <String, dynamic>{
        'interval_changed': intervalChanged,
        'max_concurrent_agents': next.agent.maxConcurrentAgents,
        'max_turns': next.agent.maxTurns,
      },
    );

    if (intervalChanged && _running_ && !_shuttingDown) {
      _scheduleNextTick();
    }
  }

  /// Whether the scheduler poll loop is active.
  bool get isRunning => _running_;

  /// Currently running entries (read-only view).
  Map<String, RunningEntry> get running =>
      Map<String, RunningEntry>.unmodifiable(_running);

  /// Issue ids reserved by the scheduler (running or queued for retry).
  Set<String> get claimed => Set<String>.unmodifiable(_claimed);

  /// Pending retry entries (read-only view).
  Map<String, RetryEntry> get retryAttempts =>
      Map<String, RetryEntry>.unmodifiable(_retryAttempts);

  /// Issue ids that completed at least once (bookkeeping only).
  Set<String> get completed => Set<String>.unmodifiable(_completed);

  /// Proof-of-work artifact path per issue identifier, for completed or
  /// reviewable runs.
  Map<String, String> get proofPaths =>
      Map<String, String>.unmodifiable(_proofPathsByIssue);

  /// Aggregate token + runtime totals.
  CodexTotals get totals => _totals;

  /// Recent orchestration events (most recent last).
  List<OrchestrationEvent> get recentEvents =>
      List<OrchestrationEvent>.unmodifiable(_events);

  /// Latest dispatch validation errors. Empty when dispatch can proceed.
  List<String> get validationErrors =>
      List<String>.unmodifiable(_validationErrors);

  /// Number of issues for which retry history is currently retained.
  ///
  /// Exposed for tests that verify the bookkeeping maps do not leak when
  /// runs reach terminal states. Operators should not rely on this in
  /// production code.
  int get retainedRetryHistoryCount => _retryHistoryByIssue.length;

  /// Starts the poll loop. Returns immediately after kicking off the first
  /// tick; the loop runs in the background until [stop] is called.
  Future<void> start() async {
    if (_running_) {
      logger.warn('Scheduler is already running.');
      return;
    }
    _running_ = true;
    _shuttingDown = false;
    _record('scheduler_started', 'Scheduler started.');

    // Kick off first tick immediately; subsequent ticks are scheduled by tick().
    unawaited(tick());
  }

  /// Stops the scheduler and cancels all running workers/timers.
  ///
  /// Idempotent: calling stop() repeatedly (or after a scheduler that was
  /// driven via direct `tick()` invocations without `start()`) still releases
  /// in-memory bookkeeping so callers can rely on it for cleanup.
  Future<void> stop() async {
    final wasRunning = _running_;
    _shuttingDown = true;
    _running_ = false;
    _pollTimer?.cancel();
    _pollTimer = null;

    for (final entry in _retryAttempts.values) {
      entry.timer?.cancel();
    }
    _retryAttempts.clear();

    final cancellations = <Future<void>>[];
    for (final entry in _running.values.toList()) {
      cancellations.add(entry.subscription.cancel());
    }
    await Future.wait(cancellations);
    _running.clear();
    _claimed.clear();
    _changedFilesByRun.clear();
    _retryHistoryByIssue.clear();
    _proofPathsByIssue.clear();
    _turnsByIssue.clear();

    if (wasRunning) {
      _record('scheduler_stopped', 'Scheduler stopped.');
    }
  }

  /// Runs one full tick: reconcile -> validate -> fetch -> dispatch.
  ///
  /// Public for tests; the poll loop calls this in the background.
  Future<void> tick() async {
    if (_shuttingDown) return;

    try {
      await _reconcileRunningIssues();

      final errors = config.validateForDispatch();
      _validationErrors
        ..clear()
        ..addAll(errors);
      if (errors.isNotEmpty) {
        _record(
          'dispatch_validation_failed',
          'Dispatch skipped: ${errors.join(' ')}',
        );
        _scheduleNextTick();
        return;
      }

      final candidatesResult = await tracker.fetchCandidates();
      candidatesResult.fold((failure) {
        _record(
          'tracker_fetch_failed',
          'Tracker fetch failed: ${failure.message}',
          data: <String, dynamic>{'code': failure.code.name},
        );
      }, _dispatchCandidates);
    } catch (e, stack) {
      logger.err('Scheduler tick failed: $e\n$stack');
      _record('tick_error', 'Scheduler tick failed: $e');
    } finally {
      _scheduleNextTick();
    }
  }

  /// Runs an immediate tick. Used by the HTTP refresh endpoint.
  Future<void> requestImmediateTick() => tick();

  void _scheduleNextTick() {
    if (_shuttingDown || !_running_) return;
    _pollTimer?.cancel();
    _pollTimer = Timer(config.polling.interval, () {
      unawaited(tick());
    });
  }

  void _dispatchCandidates(List<Issue> candidates) {
    final sorted = sortForDispatch(candidates);
    final terminalLowercased = config.tracker.terminalStates
        .map((s) => s.toLowerCase())
        .toSet();
    final activeLowercased = config.tracker.activeStates
        .map((s) => s.toLowerCase())
        .toSet();

    final byStateCounts = <String, int>{};
    for (final entry in _running.values) {
      final key = entry.issue.normalizedState;
      byStateCounts[key] = (byStateCounts[key] ?? 0) + 1;
    }

    // `_dispatchIssue` is async and only adds to `_running` after its first
    // `await` (workspace creation), so this synchronous loop never observes
    // `_running` grow. The `_pendingDispatches` counter (incremented at the
    // top of `_dispatchIssue` before any await) closes that race. Without
    // this guard, candidates spanning multiple tracker states would each be
    // capped only by the per-state limit — which, when
    // `agent.max_concurrent_agents_by_state` is empty, defaults to the
    // global limit and lets every state spawn up to that limit independently.
    for (final issue in sorted) {
      if (_running.length + _pendingDispatches >=
          config.agent.maxConcurrentAgents) {
        break;
      }
      if (_running.containsKey(issue.id) || _claimed.contains(issue.id)) {
        continue;
      }
      if (!activeLowercased.contains(issue.normalizedState)) {
        continue;
      }
      if (issue.normalizedState == 'todo' &&
          !issue.blockersAreTerminal(terminalLowercased)) {
        continue;
      }

      final perStateCap =
          config.agent.maxConcurrentAgentsByState[issue.normalizedState] ??
          config.agent.maxConcurrentAgents;
      final inUseForState = byStateCounts[issue.normalizedState] ?? 0;
      if (inUseForState >= perStateCap) {
        continue;
      }

      _dispatchIssue(issue, attempt: null);
      byStateCounts[issue.normalizedState] = inUseForState + 1;
    }
  }

  /// Sorts [issues] in dispatch order: priority asc, oldest createdAt, then
  /// identifier as a stable tie-breaker.
  ///
  /// Visible for testing.
  static List<Issue> sortForDispatch(List<Issue> issues) {
    final copy = List<Issue>.from(issues);
    copy.sort((a, b) {
      final pa = a.priority ?? 1 << 30;
      final pb = b.priority ?? 1 << 30;
      if (pa != pb) return pa.compareTo(pb);
      final ca = a.createdAt;
      final cb = b.createdAt;
      if (ca != null && cb != null) {
        final cmp = ca.compareTo(cb);
        if (cmp != 0) return cmp;
      } else if (ca != null) {
        return -1;
      } else if (cb != null) {
        return 1;
      }
      return a.identifier.compareTo(b.identifier);
    });
    return copy;
  }

  Future<void> _dispatchIssue(Issue issue, {required int? attempt}) async {
    // Reserve a slot synchronously so concurrent callers (the dispatch loop
    // and any retry callbacks) see this dispatch in their global-cap math
    // before the first `await` lands the entry in `_running`.
    _pendingDispatches += 1;
    final attemptNumber = attempt ?? 1;
    final runId = '${issue.id}-$attemptNumber';
    _claimed.add(issue.id);
    _retryAttempts.remove(issue.id);

    final startedAt = DateTime.now();
    var status = RunAttemptStatus(
      runId: runId,
      issueId: issue.id,
      issueIdentifier: issue.identifier,
      attempt: attemptNumber,
      phase: RunAttemptPhase.preparingWorkspace,
      workspacePath: '',
      startedAt: startedAt,
    );

    try {
      final workspace = await workspaceManager.createForIssue(issue.identifier);
      status = status.copyWith(phase: RunAttemptPhase.buildingPrompt);

      final prompt = promptBuilder(issue, attempt);
      await workspaceManager.runBeforeRun(workspace);

      status = RunAttemptStatus(
        runId: runId,
        issueId: issue.id,
        issueIdentifier: issue.identifier,
        attempt: attemptNumber,
        phase: RunAttemptPhase.launchingAgentProcess,
        workspacePath: workspace.path,
        startedAt: startedAt,
      );

      final request = AgentRunRequest(
        issue: issue,
        workspace: workspace,
        renderedPrompt: prompt,
        attempt: attempt,
        maxTurns: config.agent.maxTurns,
      );

      final stream = runner.run(request);
      final entry = RunningEntry(
        issue: issue,
        workspace: workspace,
        status: status.copyWith(phase: RunAttemptPhase.initializingSession),
        startedAt: startedAt,
        subscription: const Stream<RunnerEvent>.empty().listen((_) {}),
      );

      // Replace placeholder subscription with the real one.
      await entry.subscription.cancel();
      entry.subscription = stream.listen(
        (event) => _onRunnerEvent(issue.id, event),
        onError: (Object error, StackTrace stack) {
          _onRunnerError(issue.id, error);
        },
        onDone: () {
          _onRunnerDone(issue.id);
        },
        cancelOnError: false,
      );

      _running[issue.id] = entry;
      _record(
        'dispatched',
        'Dispatched ${issue.identifier} (attempt $attemptNumber).',
        data: <String, dynamic>{'issue_id': issue.id, 'attempt': attemptNumber},
      );
    } on WorkspaceException catch (e) {
      _claimed.remove(issue.id);
      _scheduleFailureRetry(
        issue: issue,
        attempt: attemptNumber,
        error: 'workspace error: ${e.message}',
      );
    } catch (e) {
      _claimed.remove(issue.id);
      _scheduleFailureRetry(
        issue: issue,
        attempt: attemptNumber,
        error: 'dispatch error: $e',
      );
    } finally {
      _pendingDispatches -= 1;
    }
  }

  void _onRunnerEvent(String issueId, RunnerEvent event) {
    final entry = _running[issueId];
    if (entry == null) return;
    entry.lastEvent = event;
    entry.lastEventAt = event.at;
    switch (event) {
      case TurnStarted(:final turnNumber):
        entry.turnCount = turnNumber;
        entry.status = entry.status.copyWith(
          phase: RunAttemptPhase.streamingTurn,
        );
      case TokenUsageUpdated(:final usage):
        final delta = RunnerTokenUsage(
          inputTokens: usage.inputTokens - entry.usage.inputTokens,
          outputTokens: usage.outputTokens - entry.usage.outputTokens,
          totalTokens: usage.totalTokens - entry.usage.totalTokens,
        );
        entry.usage = usage;
        if (delta.inputTokens != 0 ||
            delta.outputTokens != 0 ||
            delta.totalTokens != 0) {
          _totals.addUsage(
            inputTokens: delta.inputTokens,
            outputTokens: delta.outputTokens,
            totalTokens: delta.totalTokens,
          );
        }
      case TurnFailed(:final category, :final message):
        entry.status = entry.status.copyWith(
          phase: RunAttemptPhase.failed,
          error: '$category: ${message ?? ''}',
        );
      case TurnCompleted(:final changedFiles):
        entry.status = entry.status.copyWith(phase: RunAttemptPhase.finishing);
        final list = _changedFilesByRun.putIfAbsent(
          entry.status.runId,
          () => <String>[],
        );
        list.addAll(changedFiles);
      case RunFinished(:final succeeded):
        entry.status = entry.status.copyWith(
          phase: succeeded ? RunAttemptPhase.succeeded : RunAttemptPhase.failed,
        );
      case SessionStarted():
      case RunnerNotification():
        // Already captured via lastEvent/lastEventAt.
        break;
    }
  }

  void _onRunnerError(String issueId, Object error) {
    final entry = _running[issueId];
    if (entry == null) return;
    entry.status = entry.status.copyWith(
      phase: RunAttemptPhase.failed,
      error: 'runner stream error: $error',
    );
  }

  Future<void> _onRunnerDone(String issueId) async {
    final entry = _running.remove(issueId);
    if (entry == null) return;

    final endedAt = DateTime.now();
    final elapsed = endedAt.difference(entry.startedAt);
    _totals.addEndedSession(elapsed);

    // Best-effort after_run hook; failures swallowed per spec.
    String afterRunStatus = 'skipped';
    try {
      final outcome = await workspaceManager.runAfterRun(entry.workspace);
      afterRunStatus = outcome.succeeded ? 'succeeded' : 'failed';
    } catch (e) {
      afterRunStatus = 'failed: $e';
    }

    final attempt = entry.status.attempt;
    final succeeded =
        entry.status.phase == RunAttemptPhase.succeeded ||
        entry.status.phase == RunAttemptPhase.finishing;

    await _persistProofOfWork(
      entry: entry,
      endedAt: endedAt,
      succeeded: succeeded,
      afterRunStatus: afterRunStatus,
    );

    if (succeeded) {
      _turnsByIssue[issueId] = (_turnsByIssue[issueId] ?? 0) + 1;
      _completed.add(issueId);
      // The proof-of-work artifact for this success has already captured the
      // accumulated retry history above; release it so a long-running scheduler
      // does not retain per-issue history forever.
      _retryHistoryByIssue.remove(issueId);
      _scheduleContinuationRetry(
        issueId: issueId,
        identifier: entry.issue.identifier,
        attempt: attempt + 1,
      );
    } else {
      final history = _retryHistoryByIssue.putIfAbsent(
        issueId,
        () => <String>[],
      );
      history.add(
        'attempt $attempt failed at ${endedAt.toIso8601String()}: '
        '${entry.status.error ?? 'unknown error'}',
      );
      _scheduleFailureRetry(
        issue: entry.issue,
        attempt: attempt + 1,
        error: entry.status.error ?? 'worker exited with failure',
      );
    }
  }

  Future<void> _persistProofOfWork({
    required RunningEntry entry,
    required DateTime endedAt,
    required bool succeeded,
    required String afterRunStatus,
  }) async {
    if (!writeProofOfWork) return;
    final runId = entry.status.runId;
    final changed = _changedFilesByRun.remove(runId) ?? const <String>[];
    final retries = _retryHistoryByIssue[entry.issue.id] ?? const <String>[];
    final proof = ProofOfWork(
      runId: runId,
      issueIdentifier: entry.issue.identifier,
      workspacePath: entry.workspace.path,
      attempt: entry.status.attempt,
      startedAt: entry.startedAt,
      endedAt: endedAt,
      succeeded: succeeded,
      changedFiles: changed,
      hookStatuses: <String, String>{'after_run': afterRunStatus},
      retryHistory: retries,
      recommendation: succeeded
          ? 'Review the diff in ${entry.workspace.branchName}.'
          : 'Inspect failure and resolve before retrying.',
    );
    try {
      final path = await proof.persist(runsRoot: runsRoot);
      _proofPathsByIssue[entry.issue.identifier] = path;
      _record(
        'proof_written',
        'Proof of work written for ${entry.issue.identifier}: $path',
        data: <String, dynamic>{'issue_id': entry.issue.id, 'path': path},
      );
    } catch (e) {
      logger.warn('Failed to persist proof-of-work for $runId: $e');
    }
  }

  void _scheduleContinuationRetry({
    required String issueId,
    required String identifier,
    required int attempt,
  }) {
    // Continuations only run while the issue stays active in the tracker,
    // and never past the configured turn limit. Gate on completed turns —
    // not the retry attempt counter, which failure retries also bump.
    final turnsDone = _turnsByIssue[issueId] ?? 0;
    if (turnsDone >= config.agent.maxTurns) {
      _record(
        'turn_limit_reached',
        'Not continuing $identifier: agent.max_turns '
            '(${config.agent.maxTurns}) reached.',
        data: <String, dynamic>{
          'issue_id': issueId,
          'attempt': attempt,
          'turns': turnsDone,
        },
      );
      return;
    }
    _retryAttempts[issueId]?.timer?.cancel();
    final dueAt = DateTime.now().add(const Duration(seconds: 1));
    final timer = Timer(const Duration(seconds: 1), () {
      _onRetryFired(issueId);
    });
    _retryAttempts[issueId] = RetryEntry(
      issueId: issueId,
      identifier: identifier,
      attempt: attempt,
      kind: RetryKind.continuation,
      dueAt: dueAt,
      timer: timer,
    );
    _record(
      'continuation_scheduled',
      'Scheduled continuation retry for $identifier in 1s.',
      data: <String, dynamic>{'issue_id': issueId, 'attempt': attempt},
    );
  }

  void _scheduleFailureRetry({
    required Issue issue,
    required int attempt,
    String? error,
  }) {
    _retryAttempts[issue.id]?.timer?.cancel();
    final delay = computeFailureBackoff(
      attempt: attempt,
      cap: config.agent.maxRetryBackoff,
    );
    final dueAt = DateTime.now().add(delay);
    final timer = Timer(delay, () {
      _onRetryFired(issue.id);
    });
    _retryAttempts[issue.id] = RetryEntry(
      issueId: issue.id,
      identifier: issue.identifier,
      attempt: attempt,
      kind: RetryKind.failure,
      dueAt: dueAt,
      error: error,
      timer: timer,
    );
    _record(
      'failure_retry_scheduled',
      'Retry ${issue.identifier} in ${delay.inSeconds}s '
          '(attempt $attempt). $error',
      data: <String, dynamic>{
        'issue_id': issue.id,
        'attempt': attempt,
        'delay_ms': delay.inMilliseconds,
      },
    );
  }

  /// Computes the exponential backoff delay capped at [cap].
  ///
  /// Uses Symphony's failure-driven formula: `min(10s * 2^(attempt-1), cap)`.
  /// Visible for testing.
  static Duration computeFailureBackoff({
    required int attempt,
    required Duration cap,
  }) {
    final clampedAttempt = attempt.clamp(1, 30);
    final base = 10000 << (clampedAttempt - 1);
    return Duration(
      milliseconds: base > cap.inMilliseconds ? cap.inMilliseconds : base,
    );
  }

  Future<void> _onRetryFired(String issueId) async {
    final entry = _retryAttempts.remove(issueId);
    if (entry == null) return;

    final candidatesResult = await tracker.fetchCandidates();
    candidatesResult.fold(
      (failure) {
        _scheduleFailureRetry(
          issue: Issue(
            id: issueId,
            identifier: entry.identifier,
            title: entry.identifier,
            state: 'Todo',
          ),
          attempt: entry.attempt + 1,
          error: 'retry poll failed: ${failure.message}',
        );
      },
      (candidates) {
        final match = candidates.cast<Issue?>().firstWhere(
          (i) => i?.id == issueId,
          orElse: () => null,
        );
        if (match == null) {
          _claimed.remove(issueId);
          // Issue is gone from the tracker (closed, deleted, moved out of
          // active states); drop any per-issue history we held for the proof
          // artifact so the map does not grow unbounded.
          _retryHistoryByIssue.remove(issueId);
          _record(
            'retry_released',
            '${entry.identifier} no longer eligible; releasing claim.',
            data: <String, dynamic>{'issue_id': issueId},
          );
          return;
        }
        // Same staleness rule as `_dispatchCandidates`: count in-flight
        // dispatches so concurrent retry callbacks do not collectively blow
        // past the global cap.
        if (_running.length + _pendingDispatches >=
            config.agent.maxConcurrentAgents) {
          _scheduleFailureRetry(
            issue: match,
            attempt: entry.attempt + 1,
            error: 'no available orchestrator slots',
          );
          return;
        }
        unawaited(_dispatchIssue(match, attempt: entry.attempt));
      },
    );
  }

  Future<void> _reconcileRunningIssues() async {
    if (_running.isEmpty) return;

    // Stall detection.
    final now = DateTime.now();
    final stallTimeout = config.codex.stallTimeout;
    if (stallTimeout.inMilliseconds > 0) {
      for (final issueId in _running.keys.toList()) {
        final entry = _running[issueId]!;
        final last = entry.lastEventAt ?? entry.startedAt;
        if (now.difference(last) > stallTimeout) {
          _record(
            'stalled',
            '${entry.issue.identifier} stalled (no events for '
                '${now.difference(last).inSeconds}s).',
            data: <String, dynamic>{'issue_id': issueId},
          );
          await _cancelRun(
            issueId: issueId,
            phase: RunAttemptPhase.stalled,
            cleanWorkspace: false,
          );
          _scheduleFailureRetry(
            issue: entry.issue,
            attempt: entry.status.attempt + 1,
            error: 'stalled',
          );
        }
      }
    }

    if (_running.isEmpty) return;

    final ids = _running.keys.toList();
    final result = await tracker.fetchStatesByIds(ids);
    await result.fold<Future<void>>(
      (failure) async {
        _record(
          'reconcile_failed',
          'State refresh failed: ${failure.message}',
          data: <String, dynamic>{'code': failure.code.name},
        );
      },
      (issues) async {
        final terminalLowercased = config.tracker.terminalStates
            .map((s) => s.toLowerCase())
            .toSet();
        final activeLowercased = config.tracker.activeStates
            .map((s) => s.toLowerCase())
            .toSet();
        final byId = <String, Issue>{for (final i in issues) i.id: i};

        for (final id in ids) {
          final entry = _running[id];
          if (entry == null) continue;
          final refreshed = byId[id];
          if (refreshed == null) continue;
          final state = refreshed.normalizedState;
          if (terminalLowercased.contains(state)) {
            await _cancelRun(
              issueId: id,
              phase: RunAttemptPhase.canceledByReconciliation,
              cleanWorkspace: true,
            );
          } else if (activeLowercased.contains(state)) {
            entry.issue = refreshed;
          } else {
            await _cancelRun(
              issueId: id,
              phase: RunAttemptPhase.canceledByReconciliation,
              cleanWorkspace: false,
            );
          }
        }
      },
    );
  }

  Future<void> _cancelRun({
    required String issueId,
    required RunAttemptPhase phase,
    required bool cleanWorkspace,
  }) async {
    final entry = _running.remove(issueId);
    if (entry == null) return;
    entry.status = entry.status.copyWith(phase: phase);
    await entry.subscription.cancel();
    _totals.addEndedSession(DateTime.now().difference(entry.startedAt));

    if (cleanWorkspace) {
      try {
        await workspaceManager.remove(entry.issue.identifier);
      } catch (e) {
        logger.warn('Workspace cleanup failed for $issueId: $e');
      }
    }

    // Reconciliation cancellation means the issue moved to a terminal or
    // non-active tracker state; per-issue retry history is no longer useful.
    _retryHistoryByIssue.remove(issueId);
    if (phase == RunAttemptPhase.canceledByReconciliation) {
      _claimed.remove(issueId);
    }
    _record(
      'run_canceled',
      'Cancelled ${entry.issue.identifier} (${phase.name}).',
      data: <String, dynamic>{'issue_id': issueId, 'phase': phase.name},
    );
  }

  void _record(
    String name,
    String message, {
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    final event = OrchestrationEvent(name: name, message: message, data: data);
    _events.addLast(event);
    while (_events.length > eventHistorySize) {
      _events.removeFirst();
    }
    logger.detail('[scheduler] $name: $message');
  }
}
