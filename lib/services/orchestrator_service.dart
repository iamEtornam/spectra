import 'dart:async';

import 'package:mason_logger/mason_logger.dart';

import '../agents/base_agent.dart';
import '../agents/mayor_agent.dart';
import '../agents/witness_agent.dart';
import '../agents/worker_agent.dart';
import '../models/agent.dart';
import '../models/convoy.dart';
import '../models/task.dart';
import '../services/llm_service.dart';

class OrchestratorService {
  final List<SpectraAgent> _agents = [];
  final List<Convoy> _convoys = [];
  final Logger logger;
  final LLMService _llmService = LLMService();
  bool _isRunning = false;
  Timer? _loopTimer;

  OrchestratorService({required this.logger});

  Future<void> start({int workerCount = 2}) async {
    if (_isRunning) return;

    final provider = await _llmService.getPreferredProvider();
    if (provider == null) {
      logger.err('No LLM provider configured. Cannot start orchestrator.');
      return;
    }

    _isRunning = true;
    logger.info('Spectra Multi-Agent Orchestrator starting...');

    // Initialize Agents
    _agents.add(MayorAgent(
      id: 'Mayor-1',
      provider: provider,
      logger: logger,
      orchestrator: this,
    ));

    _agents.add(WitnessAgent(
      id: 'Witness-1',
      provider: provider,
      logger: logger,
      orchestrator: this,
    ));

    for (var i = 1; i <= workerCount; i++) {
      _agents.add(WorkerAgent(
        id: 'Worker-$i',
        provider: provider,
        logger: logger,
      ));
    }

    logger.success('Initialized ${_agents.length} agents.');

    // Start Execution Loop
    _loopTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!_isRunning) {
        timer.cancel();
        return;
      }

      // Execute each agent's step sequentially or in parallel
      // For now, sequential to keep logs clean
      for (final agent in _agents) {
        try {
          await agent.step();
        } catch (e) {
          logger.err('Error in agent ${agent.id}: $e');
        }
      }
    });
  }

  void stop() {
    _isRunning = false;
    _loopTimer?.cancel();
    logger.info('Orchestrator stopped.');
  }

  void addConvoy(Convoy convoy) {
    _convoys.add(convoy);
    logger.info('Added convoy: ${convoy.name} (${convoy.tasks.length} tasks)');
  }

  List<SpectraTask> getPendingTasks() {
    // Tasks that aren't completed and aren't currently assigned to a worker
    return _convoys
        .where((c) => c.status != 'completed')
        .expand((c) => c.tasks)
        .where((t) {
      // Check if any agent is currently working on this task
      return !_agents.any((a) =>
          a.currentTaskId == t.id &&
          (a.status == AgentStatus.working ||
              a.status == AgentStatus.completed));
    }).toList();
  }

  List<SpectraAgent> getAllAgents() => List.unmodifiable(_agents);

  List<SpectraAgent> getAgentsByRole(AgentRole role) {
    return _agents.where((a) => a.role == role).toList();
  }
}
