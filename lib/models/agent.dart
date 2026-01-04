enum AgentRole {
  mayor,    // Coordinator: Assigns tasks to workers
  witness,  // Monitor: Watches for stuck workers or timeouts
  worker,   // Executor: Performs the actual coding tasks
}

enum AgentStatus {
  idle,
  working,
  stuck,
  completed,
  failed,
}

class AgentState {
  final String id;
  final AgentRole role;
  AgentStatus status;
  String? currentTaskId;
  DateTime lastActivity;

  AgentState({
    required this.id,
    required this.role,
    this.status = AgentStatus.idle,
    this.currentTaskId,
    DateTime? lastActivity,
  }) : lastActivity = lastActivity ?? DateTime.now();
}

