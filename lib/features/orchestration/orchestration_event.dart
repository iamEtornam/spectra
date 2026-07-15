/// Generic high-level scheduler event for observability.
class OrchestrationEvent {
  /// Stable event name (`tick`, `dispatch`, `retry_scheduled`, ...).
  final String name;

  /// Wall-clock time of the event.
  final DateTime at;

  /// Human-readable summary.
  final String message;

  /// Optional structured payload.
  final Map<String, dynamic> data;

  /// Creates an orchestration event.
  OrchestrationEvent({
    required this.name,
    required this.message,
    this.data = const <String, dynamic>{},
    DateTime? at,
  }) : at = at ?? DateTime.now();

  /// JSON view used by snapshots and dashboards.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'event': name,
    'at': at.toIso8601String(),
    'message': message,
    if (data.isNotEmpty) 'data': data,
  };
}
