import 'dart:async';
import 'dart:io';

import 'package:xml/xml.dart';

import '../features/observability/runtime_snapshot.dart';
import '../features/orchestration/scheduler.dart';
import '../features/runner/llm_agent_runner.dart';
import '../features/runner/prompt_renderer.dart';
import '../features/tracker/issue.dart';
import '../features/tracker/tracker_factory.dart';
import '../features/workflow/workflow.dart';
import '../features/workspaces/workspace_manager.dart';
import '../models/convoy.dart';
import '../models/execution_mode.dart';
import '../models/llm_usage_type.dart';
import '../models/task.dart';
import '../services/config_service.dart';
import '../services/llm_service.dart';
import '../services/orchestrator_service.dart';
import 'base_command.dart';

class StartCommand extends SpectraCommand {
  @override
  final name = 'start';
  @override
  final description = 'Starts the multi-agent orchestrator daemon.';

  final ConfigService _configService = ConfigService();

  StartCommand({required super.logger}) {
    argParser
      ..addOption(
        'workers',
        abbr: 'w',
        help: 'Number of worker agents to spawn (legacy mode).',
        defaultsTo: '2',
      )
      ..addOption(
        'workflow',
        help: 'Path to the WORKFLOW.md file. Defaults to ./WORKFLOW.md.',
      )
      ..addFlag(
        'manual',
        abbr: 'm',
        help: 'Manual mode: Show task assignments without generating code.',
        negatable: false,
      )
      ..addFlag(
        'legacy',
        help:
            'Force the legacy convoy/PLAN.md orchestrator even when '
            'WORKFLOW.md is present.',
        negatable: false,
      );
  }

  @override
  Future<void> run() async {
    final manualFlag = argResults?['manual'] as bool? ?? false;
    final legacyFlag = argResults?['legacy'] as bool? ?? false;
    final workflowPath = argResults?['workflow'] as String? ?? 'WORKFLOW.md';

    final config = await _configService.loadConfig();
    final modeStr = config.executionMode ?? 'automatic';
    final mode = ExecutionMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ExecutionMode.automatic,
    );

    if (manualFlag || mode == ExecutionMode.manual) {
      _runManualMode();
      return;
    }

    final useWorkflow = !legacyFlag && File(workflowPath).existsSync();
    if (useWorkflow) {
      await _runWorkflowMode(workflowPath);
    } else {
      if (!File('WORKFLOW.md').existsSync()) {
        logger.warn(
          'WORKFLOW.md not found. Falling back to legacy convoy mode. '
          'Run `spectra new` to scaffold a WORKFLOW.md.',
        );
      }
      await _runLegacyMode();
    }
  }

  Future<void> _runWorkflowMode(String workflowPath) async {
    final WorkflowDefinition definition;
    try {
      definition = await WorkflowLoader().load(path: workflowPath);
    } on WorkflowException catch (e) {
      logger.err('Failed to load $workflowPath: ${e.message}');
      return;
    }

    final workflowConfig = WorkflowConfig.fromDefinition(definition);
    final validationErrors = workflowConfig.validateForDispatch();
    if (validationErrors.isNotEmpty) {
      logger.err('WORKFLOW.md validation failed:');
      for (final err in validationErrors) {
        logger.err('  - $err');
      }
      return;
    }

    final trackerResult = const TrackerFactory().build(workflowConfig);
    final trackerOrError = trackerResult.fold((failure) {
      logger.err(
        'Tracker setup failed (${failure.code.name}): ${failure.message}',
      );
      return null;
    }, (client) => client);
    if (trackerOrError == null) return;
    final tracker = trackerOrError;

    final llmService = LLMService();
    final provider = await llmService.getProviderForUsage(LLMUsageType.coding);
    if (provider == null) {
      logger.err(
        'No coding provider configured. Run `spectra config` to set one.',
      );
      return;
    }

    final workspaceManager = WorkspaceManager(
      workspaceConfig: workflowConfig.workspace,
      hooksConfig: workflowConfig.hooks,
      logger: logger,
      useGitWorktrees: Directory('.git').existsSync(),
    );

    const renderer = PromptRenderer();
    final runner = LlmAgentRunner(
      provider: provider,
      llmConfig: workflowConfig.agent.llm,
      logger: logger,
    );

    final scheduler = Scheduler(
      config: workflowConfig,
      tracker: tracker,
      workspaceManager: workspaceManager,
      runner: runner,
      promptBuilder: (Issue issue, int? attempt) => renderer.render(
        definition.promptTemplate,
        issue: issue,
        attempt: attempt,
      ),
      logger: logger,
    );

    final watcher = WorkflowWatcher(workflowPath: workflowPath, logger: logger);
    final reloadSub = watcher.reloads.listen((reload) {
      if (reload.error != null) {
        logger.err('WORKFLOW.md reload failed: ${reload.error!.message}');
      } else {
        logger.info(
          'WORKFLOW.md reloaded; new config will apply on next tick.',
        );
      }
    });
    await watcher.start();

    logger.info(
      'Spectra Symphony scheduler starting (tracker=${workflowConfig.tracker.kind}, '
      'runner=${workflowConfig.agent.runner}, '
      'max_concurrent=${workflowConfig.agent.maxConcurrentAgents})',
    );
    await scheduler.start();
    logger.success('Scheduler is running. Press Enter to stop.');

    final snapshotTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _persistSnapshot(scheduler);
    });

    try {
      await stdin.first;
    } finally {
      snapshotTimer.cancel();
      await reloadSub.cancel();
      await watcher.stop();
      await scheduler.stop();
      await runner.close();
      await tracker.close();
      _deleteRuntimeFile();
    }
  }

  void _persistSnapshot(Scheduler scheduler) {
    try {
      final dir = Directory('.spectra');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final snapshot = RuntimeSnapshot.fromScheduler(scheduler);
      File('.spectra/RUNTIME.json').writeAsStringSync(snapshot.toPrettyJson());
    } catch (_) {
      // Snapshot persistence is best-effort.
    }
  }

  void _deleteRuntimeFile() {
    final file = File('.spectra/RUNTIME.json');
    if (file.existsSync()) file.deleteSync();
  }

  Future<void> _runLegacyMode() async {
    final planFile = File('.spectra/PLAN.md');
    if (!planFile.existsSync()) {
      logger.err('PLAN.md not found. Run `spectra plan` first.');
      return;
    }

    final content = planFile.readAsStringSync();
    final tasks = _parseTasks(content);

    if (tasks.isEmpty) {
      logger.warn('No tasks found in PLAN.md.');
      return;
    }

    final workersArg = argResults?['workers'] as String?;
    final workerCount = int.tryParse(workersArg ?? '2') ?? 2;

    final orchestrator = OrchestratorService(logger: logger);
    final convoy = Convoy(id: 'plan-main', name: 'Main Plan', tasks: tasks);
    orchestrator.addConvoy(convoy);

    logger.info('Starting legacy orchestrator with $workerCount workers...');
    await orchestrator.start(workerCount: workerCount);

    logger.success('Orchestrator is running. Press Enter to stop.');

    await stdin.first;
    orchestrator.stop();
  }

  void _runManualMode() {
    final planFile = File('.spectra/PLAN.md');
    if (!planFile.existsSync()) {
      logger.err('PLAN.md not found. Run `spectra plan` first.');
      return;
    }

    final tasks = _parseTasks(planFile.readAsStringSync());
    if (tasks.isEmpty) {
      logger.warn('No tasks found in PLAN.md.');
      return;
    }
    _displayTasksForManualExecution(tasks);
  }

  List<SpectraTask> _parseTasks(String content) {
    final taskRegex = RegExp(r'<task.*?>.*?</task>', dotAll: true);
    final matches = taskRegex.allMatches(content);
    return matches.map((m) {
      final doc = XmlDocument.parse(m.group(0)!);
      return SpectraTask.fromXml(doc.rootElement);
    }).toList();
  }

  /// Displays tasks for manual execution without starting the orchestrator.
  void _displayTasksForManualExecution(List<SpectraTask> tasks) {
    logger.info('Manual Execution Mode - Task Breakdown:');
    logger.detail('Orchestrator will NOT generate code automatically.\n');

    logger.info('Total Tasks: ${tasks.length}');
    logger.detail(
      'Implement these tasks yourself or run without --manual flag.\n',
    );

    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];

      logger.info('-' * 60);
      logger.info('Task ${i + 1}/${tasks.length}: ${task.id}');
      logger.success(task.name);
      logger.detail('Type: ${task.type}');
      logger.detail('Objective: ${task.objective}');
      logger.detail('Files: ${task.files.join(', ')}');
      logger.detail('Verification: ${task.verification}');
      logger.detail('Acceptance: ${task.acceptance}');
      logger.info('');
    }

    logger.info('-' * 60);
    logger.success('\nReview complete.');
    logger.info('Next steps:');
    logger.detail('  1. Implement tasks manually in your IDE');
    logger.detail('  2. Mark tasks complete in PLAN.md');
    logger.detail('  3. Commit changes as you go');
    logger.detail('  4. Or run `spectra start` without --manual for AI');
  }
}
