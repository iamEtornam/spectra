import 'dart:io';
import 'package:xml/xml.dart';
import 'base_command.dart';
import '../services/orchestrator_service.dart';
import '../models/convoy.dart';
import '../models/task.dart';

class StartCommand extends SpectraCommand {
  @override
  final name = 'start';
  @override
  final description = 'Starts the multi-agent orchestrator daemon.';

  StartCommand({required super.logger}) {
    argParser.addOption(
      'workers',
      abbr: 'w',
      help: 'Number of worker agents to spawn.',
      defaultsTo: '2',
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

    final workerCount = int.tryParse(argResults?['workers'] ?? '2') ?? 2;
    
    final orchestrator = OrchestratorService(logger: logger);
    
    final convoy = Convoy(
      id: 'plan-main',
      name: 'Main Plan',
      tasks: tasks,
    );
    
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
}

