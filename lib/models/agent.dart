/// Defines the role an agent fulfills in the multi-agent system.
enum AgentRole {
  /// Coordinator agent that assigns tasks to workers.
  mayor,

  /// Monitor agent that watches for stuck workers or timeouts.
  witness,

  /// Executor agent that performs the actual coding tasks.
  worker,
}

/// Represents the operational status of an agent.
enum AgentStatus {
  /// Agent is ready to accept work.
  idle,

  /// Agent is currently processing a task.
  working,

  /// Agent has been detected as unresponsive.
  stuck,

  /// Agent finished its current work successfully.
  completed,

  /// Agent encountered an unrecoverable error.
  failed,
}

/// Immutable snapshot of an agent's current state.
///
/// Used for serialization, monitoring, and inter-agent communication.
class AgentState {
  /// Unique identifier of the agent.
  final String id;

  /// The role this agent fulfills.
  final AgentRole role;

  /// Current operational status.
  AgentStatus status;

  /// ID of the task being processed, if any.
  String? currentTaskId;

  /// Timestamp of the agent's last recorded activity.
  DateTime lastActivity;

  /// Creates a new agent state snapshot.
  AgentState({
    required this.id,
    required this.role,
    this.status = AgentStatus.idle,
    this.currentTaskId,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();

  /// Serializes this state to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'status': status.name,
        'currentTaskId': currentTaskId,
        'lastActivity': lastActivity.toIso8601String(),
      };

  /// Deserializes an agent state from a JSON map.
  factory AgentState.fromJson(Map<String, dynamic> json) => AgentState(
        id: json['id'] as String,
        role: AgentRole.values.byName(json['role'] as String),
        status: AgentStatus.values.byName(json['status'] as String),
        currentTaskId: json['currentTaskId'] as String?,
        lastActivity: DateTime.parse(json['lastActivity'] as String),
      );
}
