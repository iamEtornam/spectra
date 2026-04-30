import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:spectra_cli/features/observability/runtime_snapshot.dart';
import 'package:spectra_cli/features/orchestration/orchestration.dart';
import 'package:spectra_cli/features/runner/agent_runner.dart';
import 'package:spectra_cli/features/runner/runner_event.dart';
import 'package:spectra_cli/features/tracker/issue.dart';
import 'package:spectra_cli/features/tracker/issue_tracker_client.dart';
import 'package:spectra_cli/features/tracker/tracker_failure.dart';
import 'package:spectra_cli/features/workflow/workflow_config.dart';
import 'package:spectra_cli/features/workspaces/workspace_manager.dart';
import 'package:test/test.dart';

class _EmptyTracker implements IssueTrackerClient {
  @override
  String get kind => 'empty';

  @override
  Future<TrackerResult<List<Issue>>> fetchCandidates() async =>
      const TrackerSuccess<List<Issue>>(<Issue>[]);

  @override
  Future<TrackerResult<List<Issue>>> fetchStatesByIds(List<String> ids) async =>
      const TrackerSuccess<List<Issue>>(<Issue>[]);

  @override
  Future<TrackerResult<List<Issue>>> fetchByStates(List<String> names) async =>
      const TrackerSuccess<List<Issue>>(<Issue>[]);

  @override
  Future<void> close() async {}
}

class _NoopRunner implements AgentRunner {
  @override
  String get name => 'noop';

  @override
  Stream<RunnerEvent> run(AgentRunRequest request) async* {
    yield RunFinished(succeeded: true, turns: 0);
  }

  @override
  Future<void> close() async {}
}

WorkflowConfig _config() {
  return const WorkflowConfig(
    tracker: TrackerWorkflowConfig(
      kind: 'local_plan',
      endpoint: '',
      apiKey: 'token',
      projectSlug: 'spectra',
      activeStates: <String>['Todo'],
      terminalStates: <String>['Done'],
    ),
    polling: PollingWorkflowConfig(interval: Duration(seconds: 30)),
    workspace: WorkspaceWorkflowConfig(root: '.spectra/workspaces'),
    hooks: HooksWorkflowConfig(
      afterCreate: null,
      beforeRun: null,
      afterRun: null,
      beforeRemove: null,
      timeout: Duration(seconds: 5),
    ),
    agent: AgentWorkflowConfig(
      maxConcurrentAgents: 2,
      maxTurns: 1,
      maxRetryBackoff: Duration(seconds: 30),
      maxConcurrentAgentsByState: <String, int>{},
      runner: 'llm',
      llm: LlmRunnerWorkflowConfig(
        planningProvider: null,
        codingProvider: null,
        timeout: Duration(seconds: 5),
        maxResponseBytes: 1024,
      ),
    ),
    codex: CodexWorkflowConfig(
      command: 'codex app-server',
      approvalPolicy: null,
      threadSandbox: null,
      turnSandboxPolicy: null,
      turnTimeout: Duration(seconds: 30),
      readTimeout: Duration(seconds: 5),
      stallTimeout: Duration(seconds: 30),
    ),
    server: ServerWorkflowConfig(port: null),
  );
}

void main() {
  group('RuntimeSnapshot', () {
    test('captures scheduler state into stable JSON keys', () async {
      final tempDir = Directory.systemTemp.createTempSync('spectra_snap_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final scheduler = Scheduler(
        config: _config(),
        tracker: _EmptyTracker(),
        workspaceManager: WorkspaceManager(
          workspaceConfig: WorkspaceWorkflowConfig(root: tempDir.path),
          hooksConfig: const HooksWorkflowConfig(
            afterCreate: null,
            beforeRun: null,
            afterRun: null,
            beforeRemove: null,
            timeout: Duration(seconds: 5),
          ),
          logger: Logger(level: Level.quiet),
          useGitWorktrees: false,
        ),
        runner: _NoopRunner(),
        promptBuilder: (issue, _) => issue.identifier,
        logger: Logger(level: Level.quiet),
      );

      await scheduler.tick();
      final snapshot = RuntimeSnapshot.fromScheduler(scheduler);
      final json = snapshot.toJson();

      expect(
        json['counts'],
        equals(<String, int>{
          'running': 0,
          'retrying': 0,
          'claimed': 0,
          'completed': 0,
        }),
      );
      expect(json['validation_errors'], isEmpty);
      expect(json['codex_totals'], isA<Map<String, dynamic>>());
      expect(json['recent_events'], isA<List<dynamic>>());
      expect(json['running'], isEmpty);
      expect(json['rate_limits'], isNull);
      await scheduler.stop();
    });
  });
}
