import '../models/agent.dart';
import '../services/orchestrator_service.dart';
import 'base_agent.dart';
import 'worker_agent.dart';

class MayorAgent extends SpectraAgent {
  final OrchestratorService orchestrator;

  MayorAgent({
    required super.id,
    required super.provider,
    required super.logger,
    required this.orchestrator,
  }) : super(role: AgentRole.mayor);

  @override
  Future<void> step() async {
    updateStatus(AgentStatus.working);

    final pendingTasks = orchestrator.getPendingTasks();
    if (pendingTasks.isEmpty) {
      logger.detail('[Mayor $id] No pending tasks.');
      updateStatus(AgentStatus.idle);
      return;
    }

    final idleWorkers = orchestrator
        .getAgentsByRole(AgentRole.worker)
        .where((a) => a.status == AgentStatus.idle)
        .cast<WorkerAgent>()
        .toList();

    if (idleWorkers.isEmpty) {
      logger.detail('[Mayor $id] No idle workers available.');
      updateStatus(AgentStatus.idle);
      return;
    }

    for (var i = 0; i < pendingTasks.length && i < idleWorkers.length; i++) {
      final task = pendingTasks[i];
      final worker = idleWorkers[i];

      logger.info(
          '[Mayor $id] Assigning Task #${task.id} to Worker ${worker.id}');
      worker.assignTask(task);
    }

    updateStatus(AgentStatus.idle);
  }
}
