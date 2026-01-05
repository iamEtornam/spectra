import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

import '../agents/base_agent.dart';
import '../agents/mayor_agent.dart';
import '../agents/witness_agent.dart';
import '../agents/worker_agent.dart';
import '../models/agent.dart';
import '../models/convoy.dart';
import '../models/task.dart';
import 'llm_service.dart';

/// Configuration for the orchestrator.
class OrchestratorConfig {
  /// Delay between orchestrator loop iterations.
  final Duration loopDelay;

  /// Timeout for individual agent steps.
  final Duration agentStepTimeout;

  /// Maximum consecutive failures before an agent is marked as failed.
  final int maxConsecutiveFailures;

  /// Duration after which an idle agent working on a task is considered stuck.
  final Duration stuckThreshold;

  /// Whether to enable automatic stuck agent recovery.
  final bool enableStuckRecovery;

  const OrchestratorConfig({
    this.loopDelay = const Duration(seconds: 2),
    this.agentStepTimeout = const Duration(minutes: 2),
    this.maxConsecutiveFailures = 3,
    this.stuckThreshold = const Duration(minutes: 5),
    this.enableStuckRecovery = true,
  });
}

/// Multi-agent orchestrator service for coordinating Spectra agents.
///
/// Manages the lifecycle of agents, distributes tasks, and handles error
/// recovery for stuck or failed agents.
class OrchestratorService {
  final List<SpectraAgent> _agents = [];
  final List<Convoy> _convoys = [];
  final Logger logger;
  final LLMService _llmService;
  final OrchestratorConfig config;

  bool _isRunning = false;
  final Map<String, int> _agentFailureCounts = {};
  final Map<String, List<String>> _taskHistory = {};

  /// Creates a new orchestrator service.
  ///
  /// [logger] - Logger for output.
  /// [config] - Optional configuration overrides.
  /// [llmService] - Optional custom LLM service (for testing).
  OrchestratorService({
    required this.logger,
    this.config = const OrchestratorConfig(),
    LLMService? llmService,
  }) : _llmService = llmService ?? LLMService();

  /// Whether the orchestrator is currently running.
  bool get isRunning => _isRunning;

  /// Starts the orchestrator with the specified number of workers.
  Future<void> start({int workerCount = 2}) async {
    if (_isRunning) {
      logger.warn('Orchestrator is already running.');
      return;
    }

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
      final worker = WorkerAgent(
        id: 'Worker-$i',
        provider: provider,
        logger: logger,
        onTaskCompleted: markTaskCompleted,
      );
      _agents.add(worker);
    }

    logger.success('Initialized ${_agents.length} agents.');

    // Start the execution loop (proper async loop, not Timer.periodic)
    unawaited(_runLoop());
  }

  /// Main execution loop - runs until stopped.
  Future<void> _runLoop() async {
    while (_isRunning) {
      try {
        await _executeAgentSteps();

        if (config.enableStuckRecovery) {
          _recoverStuckAgents();
        }

        _persistAgentStatus();
        _checkConvoyCompletion();
      } catch (e, stackTrace) {
        logger.err('Error in orchestrator loop: $e');
        logger.detail(stackTrace.toString());
      }

      if (_isRunning) {
        await Future<void>.delayed(config.loopDelay);
      }
    }
  }

  /// Executes each agent's step with timeout and error handling.
  Future<void> _executeAgentSteps() async {
    for (final agent in _agents) {
      if (!_isRunning) break;
      if (agent.status == AgentStatus.failed) continue;

      try {
        await agent.step().timeout(
          config.agentStepTimeout,
          onTimeout: () {
            throw TimeoutException(
              'Agent ${agent.id} step timed out',
              config.agentStepTimeout,
            );
          },
        );

        // Reset failure count on success
        _agentFailureCounts[agent.id] = 0;
      } catch (e) {
        _handleAgentError(agent, e);
      }
    }
  }

  /// Handles errors from agent execution.
  void _handleAgentError(SpectraAgent agent, Object error) {
    final failureCount = (_agentFailureCounts[agent.id] ?? 0) + 1;
    _agentFailureCounts[agent.id] = failureCount;

    logger.err('[${agent.id}] Error (failure $failureCount): $error');

    if (failureCount >= config.maxConsecutiveFailures) {
      logger.err(
          '[${agent.id}] Exceeded max failures ($failureCount). Marking as FAILED.');
      agent.updateStatus(AgentStatus.failed);

      // If it's a worker, release the task
      if (agent is WorkerAgent && agent.currentTaskId != null) {
        logger.warn(
            '[${agent.id}] Releasing task ${agent.currentTaskId} back to pool.');
        agent.currentTaskId = null;
      }
    }
  }

  /// Recovers agents that have been stuck for too long.
  void _recoverStuckAgents() {
    final now = DateTime.now();

    for (final agent in _agents) {
      if (agent.status == AgentStatus.failed) continue;

      final inactivityDuration = now.difference(agent.lastActivity);

      if (agent.status == AgentStatus.working &&
          inactivityDuration > config.stuckThreshold) {
        logger.warn(
            '[${agent.id}] Detected as stuck (inactive for ${inactivityDuration.inMinutes}min). Recovering...');
        agent.updateStatus(AgentStatus.stuck);

        // If it's a worker, release the task
        if (agent is WorkerAgent && agent.currentTaskId != null) {
          logger.warn(
              '[${agent.id}] Releasing task ${agent.currentTaskId} for reassignment.');
          agent.currentTaskId = null;
        }

        // Reset to idle so it can pick up new work
        agent.updateStatus(AgentStatus.idle);
        _agentFailureCounts[agent.id] = 0;
      }
    }
  }

  /// Checks if any convoys have been completed.
  void _checkConvoyCompletion() {
    for (final convoy in _convoys) {
      if (convoy.status == 'completed') continue;

      final completedTasks = _taskHistory[convoy.id] ?? [];
      final allCompleted = convoy.tasks.every(
        (t) => completedTasks.contains(t.id),
      );

      if (allCompleted) {
        convoy.status = 'completed';
        logger.success('Convoy "${convoy.name}" completed!');
      }
    }
  }

  /// Marks a task as completed.
  void markTaskCompleted(String taskId) {
    for (final convoy in _convoys) {
      if (convoy.tasks.any((t) => t.id == taskId)) {
        _taskHistory.putIfAbsent(convoy.id, () => []);
        if (!_taskHistory[convoy.id]!.contains(taskId)) {
          _taskHistory[convoy.id]!.add(taskId);
        }
        break;
      }
    }
  }

  /// Persists current agent status to disk for monitoring.
  void _persistAgentStatus() {
    try {
      final statusFile = File('.spectra/AGENTS.json');
      final data = _agents.map((a) {
        final state = a.state.toJson();
        state['consecutiveFailures'] = _agentFailureCounts[a.id] ?? 0;
        return state;
      }).toList();
      statusFile.writeAsStringSync(jsonEncode(data));
    } catch (e) {
      // Ignore persistence errors
    }
  }

  /// Stops the orchestrator.
  void stop() {
    _isRunning = false;

    final statusFile = File('.spectra/AGENTS.json');
    if (statusFile.existsSync()) {
      statusFile.deleteSync();
    }

    logger.info('Orchestrator stopped.');
  }

  /// Restarts a failed agent.
  bool restartAgent(String agentId) {
    final agent = _agents.where((a) => a.id == agentId).firstOrNull;
    if (agent == null) {
      logger.err('Agent $agentId not found.');
      return false;
    }

    if (agent.status != AgentStatus.failed) {
      logger.warn('Agent $agentId is not in failed state.');
      return false;
    }

    logger.info('Restarting agent $agentId...');
    agent.updateStatus(AgentStatus.idle);
    _agentFailureCounts[agentId] = 0;
    return true;
  }

  /// Adds a convoy to be processed.
  void addConvoy(Convoy convoy) {
    _convoys.add(convoy);
    _taskHistory[convoy.id] = [];
    logger.info('Added convoy: ${convoy.name} (${convoy.tasks.length} tasks)');
  }

  /// Gets all pending tasks that can be assigned.
  List<SpectraTask> getPendingTasks() {
    final assignedTaskIds = _agents
        .where(
            (a) => a.currentTaskId != null && a.status == AgentStatus.working)
        .map((a) => a.currentTaskId!)
        .toSet();

    return _convoys
        .where((c) => c.status != 'completed')
        .expand((c) => c.tasks)
        .where((t) {
      // Not assigned and not completed
      final completed = _taskHistory.values.any((list) => list.contains(t.id));
      return !assignedTaskIds.contains(t.id) && !completed;
    }).toList();
  }

  /// Gets all registered agents.
  List<SpectraAgent> getAllAgents() => List.unmodifiable(_agents);

  /// Gets agents filtered by role.
  List<SpectraAgent> getAgentsByRole(AgentRole role) {
    return _agents.where((a) => a.role == role).toList();
  }

  /// Gets orchestrator statistics.
  Map<String, dynamic> get stats => {
        'isRunning': _isRunning,
        'agentCount': _agents.length,
        'convoyCount': _convoys.length,
        'pendingTaskCount': getPendingTasks().length,
        'completedConvoyCount':
            _convoys.where((c) => c.status == 'completed').length,
        'failedAgentCount':
            _agents.where((a) => a.status == AgentStatus.failed).length,
      };
}
