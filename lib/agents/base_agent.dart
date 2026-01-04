import 'package:mason_logger/mason_logger.dart';
import '../models/agent.dart';
import '../core/llm_provider.dart';

abstract class SpectraAgent {
  final String id;
  final AgentRole role;
  final LLMProvider provider;
  final Logger logger;
  AgentStatus status = AgentStatus.idle;
  String? currentTaskId;
  DateTime lastActivity = DateTime.now();

  SpectraAgent({
    required this.id,
    required this.role,
    required this.provider,
    required this.logger,
  });

  /// The main execution step for the agent
  Future<void> step();

  void markActive() => lastActivity = DateTime.now();

  void updateStatus(AgentStatus newStatus) {
    status = newStatus;
    markActive();
  }
}

