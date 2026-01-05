import 'package:mason_logger/mason_logger.dart';

import '../core/llm_provider.dart';
import '../models/agent.dart';

/// Abstract base class for all Spectra agents.
///
/// Agents are autonomous units that perform specific roles in the
/// multi-agent orchestration system. Each agent has:
/// - A unique [id] for identification
/// - A [role] defining its responsibilities
/// - An [LLMProvider] for AI-powered decision making
/// - Status tracking for coordination
///
/// Subclasses must implement [step] to define the agent's behavior.
abstract class SpectraAgent {
  /// Unique identifier for this agent.
  final String id;

  /// The role this agent fulfills (mayor, worker, witness).
  final AgentRole role;

  /// The LLM provider used for AI-powered operations.
  final LLMProvider provider;

  /// Logger for agent output.
  final Logger logger;

  /// Current operational status of the agent.
  AgentStatus status = AgentStatus.idle;

  /// ID of the task currently being processed, if any.
  String? currentTaskId;

  /// Timestamp of the agent's last activity.
  DateTime lastActivity = DateTime.now();

  /// Creates a new agent with the specified configuration.
  SpectraAgent({
    required this.id,
    required this.role,
    required this.provider,
    required this.logger,
  });

  /// Executes a single step of the agent's main logic.
  ///
  /// This method is called repeatedly by the orchestrator and should:
  /// - Check for work to do
  /// - Perform any necessary actions
  /// - Update status appropriately
  ///
  /// Implementations should be idempotent and handle their own errors.
  Future<void> step();

  /// Marks the agent as active (updates [lastActivity]).
  void markActive() => lastActivity = DateTime.now();

  /// Updates the agent's status and marks it as active.
  void updateStatus(AgentStatus newStatus) {
    status = newStatus;
    markActive();
  }

  /// Returns the current state of this agent as an immutable snapshot.
  AgentState get state => AgentState(
        id: id,
        role: role,
        status: status,
        currentTaskId: currentTaskId,
        lastActivity: lastActivity,
      );
}
