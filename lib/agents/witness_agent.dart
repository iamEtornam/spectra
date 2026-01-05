import '../models/agent.dart';
import '../services/orchestrator_service.dart';
import 'base_agent.dart';

class WitnessAgent extends SpectraAgent {
  final OrchestratorService orchestrator;
  final Duration timeoutThreshold;

  WitnessAgent({
    required super.id,
    required super.provider,
    required super.logger,
    required this.orchestrator,
    this.timeoutThreshold = const Duration(minutes: 5),
  }) : super(role: AgentRole.witness);

  @override
  Future<void> step() async {
    updateStatus(AgentStatus.working);

    final allAgents = orchestrator.getAllAgents();
    final now = DateTime.now();

    for (final agent in allAgents) {
      if (agent.id == id) continue; // Don't witness yourself

      if (agent.status == AgentStatus.working) {
        final inactiveDuration = now.difference(agent.lastActivity);
        if (inactiveDuration > timeoutThreshold) {
          logger.warn(
              '[Witness $id] Agent ${agent.id} seems stuck (inactive for ${inactiveDuration.inMinutes}m).');
          agent.updateStatus(AgentStatus.stuck);
        }
      }
    }

    updateStatus(AgentStatus.idle);
  }
}
