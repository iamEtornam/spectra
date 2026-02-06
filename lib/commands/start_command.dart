import 'dart:io';
import 'package:xml/xml.dart';
import 'base_command.dart';
import '../models/execution_mode.dart';
import '../services/config_service.dart';
import '../services/orchestrator_service.dart';
import '../models/convoy.dart';
import '../models/task.dart';

class StartCommand extends SpectraCommand {
  @override
  final name = 'start';
  @override
  final description = 'Starts the multi-agent orchestrator daemon.';

  final ConfigService _configService = ConfigService();

  StartCommand({required super.logger}) {
    argParser.addOption(
      'workers',
      abbr: 'w',
      help: 'Number of worker agents to spawn.',
      defaultsTo: '2',
    );

    argParser.addFlag(
      'manual',
      abbr: 'm',
      help: 'Manual mode: Show task assignments without generating code',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
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

    // Check for manual mode
    final config = await _configService.loadConfig();
    final manualFlag = argResults?['manual'] as bool? ?? false;
    final modeStr = config.executionMode ?? 'automatic';
    final mode = ExecutionMode.values.firstWhere(
      (m) => m.name == modeStr,
      orElse: () => ExecutionMode.automatic,
    );

    if (manualFlag || mode == ExecutionMode.manual) {
      _displayTasksForManualExecution(tasks);
      return;
    }

    final workersArg = argResults?['workers'] as String?;
    final workerCount = int.tryParse(workersArg ?? '2') ?? 2;

    final orchestrator = OrchestratorService(logger: logger);

    final convoy = Convoy(id: 'plan-main', name: 'Main Plan', tasks: tasks);

    orchestrator.addConvoy(convoy);

    logger.info('Starting orchestrator with $workerCount workers...');
    await orchestrator.start(workerCount: workerCount);

    logger.success('Orchestrator is running. Press Enter to stop.');

    // Keep alive until user input
    await stdin.first;
    orchestrator.stop();
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
    logger.info('📋 Manual Execution Mode - Task Breakdown:');
    logger.detail('Orchestrator will NOT generate code automatically.\n');

    logger.info('Total Tasks: ${tasks.length}');
    logger.detail(
      'Implement these tasks yourself or run without --manual flag.\n',
    );

    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];

      logger.info('─' * 60);
      logger.info('Task ${i + 1}/${tasks.length}: ${task.id}');
      logger.success(task.name);
      logger.detail('Type: ${task.type}');
      logger.detail('Objective: ${task.objective}');
      logger.detail('Files: ${task.files.join(', ')}');
      logger.detail('Verification: ${task.verification}');
      logger.detail('Acceptance: ${task.acceptance}');
      logger.info('');
    }

    logger.info('─' * 60);
    logger.success('\n✅ Review complete.');
    logger.info('Next steps:');
    logger.detail('  1. Implement tasks manually in your IDE');
    logger.detail('  2. Mark tasks complete in PLAN.md');
    logger.detail('  3. Commit changes as you go');
    logger.detail('  4. Or run `spectra start` without --manual for AI');
  }
}
