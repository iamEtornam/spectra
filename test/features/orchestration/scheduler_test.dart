import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:spectra_cli/features/orchestration/orchestration.dart';
import 'package:spectra_cli/features/runner/agent_runner.dart';
import 'package:spectra_cli/features/runner/runner_event.dart';
import 'package:spectra_cli/features/tracker/issue.dart';
import 'package:spectra_cli/features/tracker/issue_tracker_client.dart';
import 'package:spectra_cli/features/tracker/tracker_failure.dart';
import 'package:spectra_cli/features/workflow/workflow_config.dart';
import 'package:spectra_cli/features/workspaces/workspace.dart';
import 'package:spectra_cli/features/workspaces/workspace_failure.dart';
import 'package:spectra_cli/features/workspaces/workspace_manager.dart';
import 'package:test/test.dart';

class _FakeTracker implements IssueTrackerClient {
  List<Issue> candidates;
  Map<String, Issue> currentStates;
  TrackerFailure? candidateFailure;

  _FakeTracker({
    this.candidates = const <Issue>[],
    Map<String, Issue>? currentStates,
    this.candidateFailure,
  }) : currentStates = currentStates ?? <String, Issue>{};

  @override
  String get kind => 'fake';

  @override
  Future<TrackerResult<List<Issue>>> fetchCandidates() async {
    if (candidateFailure != null) {
      return TrackerError<List<Issue>>(candidateFailure!);
    }
    return TrackerSuccess<List<Issue>>(List<Issue>.unmodifiable(candidates));
  }

  @override
  Future<TrackerResult<List<Issue>>> fetchStatesByIds(
    List<String> issueIds,
  ) async {
    final out = <Issue>[];
    for (final id in issueIds) {
      final issue = currentStates[id];
      if (issue != null) out.add(issue);
    }
    return TrackerSuccess<List<Issue>>(out);
  }

  @override
  Future<TrackerResult<List<Issue>>> fetchByStates(
    List<String> stateNames,
  ) async {
    return const TrackerSuccess<List<Issue>>(<Issue>[]);
  }

  @override
  Future<void> close() async {}
}

class _FakeRunner implements AgentRunner {
  final List<RunnerEvent> events;
  AgentRunRequest? lastRequest;

  _FakeRunner(this.events);

  @override
  String get name => 'fake';

  @override
  Stream<RunnerEvent> run(AgentRunRequest request) async* {
    lastRequest = request;
    for (final event in events) {
      yield event;
    }
  }

  @override
  Future<void> close() async {}
}

class _FakeWorkspaceManager extends WorkspaceManager {
  _FakeWorkspaceManager(Directory root)
    : super(
        workspaceConfig: WorkspaceWorkflowConfig(root: root.path),
        hooksConfig: const HooksWorkflowConfig(
          afterCreate: null,
          beforeRun: null,
          afterRun: null,
          beforeRemove: null,
          timeout: Duration(seconds: 5),
        ),
        logger: Logger(level: Level.quiet),
        useGitWorktrees: false,
      );

  bool throwOnCreate = false;

  @override
  Future<Workspace> createForIssue(String issueIdentifier) {
    if (throwOnCreate) {
      throw const WorkspaceException(
        WorkspaceFailureCode.createFailed,
        'forced failure',
      );
    }
    return super.createForIssue(issueIdentifier);
  }
}

WorkflowConfig _buildConfig({
  int maxConcurrent = 2,
  int maxTurns = 1,
  Duration interval = const Duration(seconds: 30),
  Duration retryCap = const Duration(seconds: 30),
  Duration stallTimeout = const Duration(milliseconds: 50),
  Map<String, int> perStateCaps = const <String, int>{},
}) {
  return WorkflowConfig(
    tracker: const TrackerWorkflowConfig(
      kind: 'local_plan',
      endpoint: '',
      apiKey: 'token',
      projectSlug: 'spectra',
      activeStates: <String>['Todo', 'In Progress'],
      terminalStates: <String>['Done'],
    ),
    polling: PollingWorkflowConfig(interval: interval),
    workspace: const WorkspaceWorkflowConfig(root: '.spectra/workspaces'),
    hooks: const HooksWorkflowConfig(
      afterCreate: null,
      beforeRun: null,
      afterRun: null,
      beforeRemove: null,
      timeout: Duration(seconds: 5),
    ),
    agent: AgentWorkflowConfig(
      maxConcurrentAgents: maxConcurrent,
      maxTurns: maxTurns,
      maxRetryBackoff: retryCap,
      maxConcurrentAgentsByState: Map<String, int>.unmodifiable(perStateCaps),
      runner: 'llm',
      llm: const LlmRunnerWorkflowConfig(
        planningProvider: null,
        codingProvider: null,
        timeout: Duration(seconds: 10),
        maxResponseBytes: 65536,
      ),
    ),
    codex: CodexWorkflowConfig(
      command: 'codex app-server',
      approvalPolicy: null,
      threadSandbox: null,
      turnSandboxPolicy: null,
      turnTimeout: const Duration(minutes: 5),
      readTimeout: const Duration(seconds: 5),
      stallTimeout: stallTimeout,
    ),
    server: const ServerWorkflowConfig(port: null),
  );
}

Issue _issue(String id, {String? state, int? priority, DateTime? createdAt}) =>
    Issue(
      id: id,
      identifier: 'SPEC-$id',
      title: 'Issue $id',
      state: state ?? 'Todo',
      priority: priority,
      createdAt: createdAt,
    );

void main() {
  group('Scheduler', () {
    test(
      'sortForDispatch orders by priority, then createdAt, then identifier',
      () {
        final issues = <Issue>[
          _issue('1', priority: 3, createdAt: DateTime.utc(2026, 1, 1)),
          _issue('2', priority: 1, createdAt: DateTime.utc(2026, 1, 2)),
          _issue('3', priority: 1, createdAt: DateTime.utc(2026, 1, 1)),
        ];
        final sorted = Scheduler.sortForDispatch(issues);
        expect(
          sorted.map((i) => i.identifier),
          equals(<String>['SPEC-3', 'SPEC-2', 'SPEC-1']),
        );
      },
    );

    test('computeFailureBackoff caps at the configured maximum', () {
      const cap = Duration(seconds: 30);
      expect(
        Scheduler.computeFailureBackoff(attempt: 1, cap: cap),
        equals(const Duration(seconds: 10)),
      );
      expect(
        Scheduler.computeFailureBackoff(attempt: 2, cap: cap),
        equals(const Duration(seconds: 20)),
      );
      expect(
        Scheduler.computeFailureBackoff(attempt: 5, cap: cap),
        equals(cap),
      );
    });

    test('dispatches eligible candidates and runs the runner', () async {
      final tempDir = Directory.systemTemp.createTempSync('spectra_sched_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final tracker = _FakeTracker(
        candidates: <Issue>[_issue('1', state: 'In Progress')],
      );
      final runner = _FakeRunner(<RunnerEvent>[
        SessionStarted(sessionId: 's-1'),
        TurnStarted(turnNumber: 1),
        TurnCompleted(turnNumber: 1, changedFiles: const <String>[]),
        RunFinished(succeeded: true, turns: 1),
      ]);
      final workspace = _FakeWorkspaceManager(tempDir);
      final scheduler = Scheduler(
        config: _buildConfig(),
        tracker: tracker,
        workspaceManager: workspace,
        runner: runner,
        promptBuilder: (issue, attempt) => 'prompt for ${issue.identifier}',
        logger: Logger(level: Level.quiet),
        runsRoot: p.join(tempDir.path, 'runs'),
      );

      await scheduler.tick();
      // Allow async events to drain.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(runner.lastRequest, isNotNull);
      expect(runner.lastRequest!.issue.identifier, equals('SPEC-1'));
      expect(scheduler.completed, contains('1'));
      expect(scheduler.recentEvents.map((e) => e.name), contains('dispatched'));
      await scheduler.stop();
    });

    test('respects max_concurrent_agents', () async {
      final tempDir = Directory.systemTemp.createTempSync('spectra_sched_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final tracker = _FakeTracker(
        candidates: <Issue>[
          _issue('1', state: 'In Progress'),
          _issue('2', state: 'In Progress'),
          _issue('3', state: 'In Progress'),
        ],
      );
      // Runner that never completes during the test.
      final completer = Completer<void>();
      final runner = _SlowRunner(completer.future);
      final workspace = _FakeWorkspaceManager(tempDir);
      final scheduler = Scheduler(
        config: _buildConfig(maxConcurrent: 2),
        tracker: tracker,
        workspaceManager: workspace,
        runner: runner,
        promptBuilder: (issue, attempt) => 'prompt',
        logger: Logger(level: Level.quiet),
        runsRoot: p.join(tempDir.path, 'runs'),
        writeProofOfWork: false,
      );

      await scheduler.tick();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(scheduler.running.length, equals(2));
      expect(scheduler.claimed.length, equals(2));

      completer.complete();
      await scheduler.stop();
    });

    test(
      'updateConfig swaps the active config and is honored on the next tick',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('spectra_sched_');
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });

        final tracker = _FakeTracker(
          candidates: <Issue>[
            _issue('1', state: 'In Progress'),
            _issue('2', state: 'In Progress'),
            _issue('3', state: 'In Progress'),
          ],
        );
        final completer = Completer<void>();
        final runner = _SlowRunner(completer.future);
        final workspace = _FakeWorkspaceManager(tempDir);
        final scheduler = Scheduler(
          config: _buildConfig(maxConcurrent: 1),
          tracker: tracker,
          workspaceManager: workspace,
          runner: runner,
          promptBuilder: (issue, attempt) => 'prompt',
          logger: Logger(level: Level.quiet),
          runsRoot: p.join(tempDir.path, 'runs'),
          writeProofOfWork: false,
        );
        addTearDown(scheduler.stop);

        await scheduler.tick();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // The initial cap of 1 limits dispatch to a single concurrent run.
        expect(scheduler.running.length, equals(1));
        expect(scheduler.config.agent.maxConcurrentAgents, equals(1));

        scheduler.updateConfig(_buildConfig(maxConcurrent: 3));

        // The new cap is reflected on the live config and recorded as an event.
        expect(scheduler.config.agent.maxConcurrentAgents, equals(3));
        expect(
          scheduler.recentEvents.map((e) => e.name),
          contains('config_reloaded'),
        );

        // The next tick should dispatch up to the new cap without restarting.
        await scheduler.tick();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(scheduler.running.length, equals(3));
        completer.complete();
      },
    );

    test('reports tracker fetch failures via recentEvents', () async {
      final tempDir = Directory.systemTemp.createTempSync('spectra_sched_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final tracker = _FakeTracker(
        candidateFailure: const TrackerFailure(
          TrackerFailureCode.apiRequest,
          'down',
        ),
      );
      final runner = _FakeRunner(<RunnerEvent>[]);
      final workspace = _FakeWorkspaceManager(tempDir);
      final scheduler = Scheduler(
        config: _buildConfig(),
        tracker: tracker,
        workspaceManager: workspace,
        runner: runner,
        promptBuilder: (issue, attempt) => 'prompt',
        logger: Logger(level: Level.quiet),
        runsRoot: p.join(tempDir.path, 'runs'),
        writeProofOfWork: false,
      );

      await scheduler.tick();

      expect(
        scheduler.recentEvents.map((e) => e.name),
        contains('tracker_fetch_failed'),
      );
      await scheduler.stop();
    });
  });
}

class _SlowRunner implements AgentRunner {
  final Future<void> done;
  _SlowRunner(this.done);

  @override
  String get name => 'slow';

  @override
  Stream<RunnerEvent> run(AgentRunRequest request) async* {
    yield SessionStarted(sessionId: 's');
    await done;
    yield RunFinished(succeeded: true, turns: 1);
  }

  @override
  Future<void> close() async {}
}
