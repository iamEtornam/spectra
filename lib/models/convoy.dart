import 'task.dart';

class Convoy {
  final String id;
  final String name;
  final List<SpectraTask> tasks;
  String status; // pending, in_progress, completed, failed

  Convoy({
    required this.id,
    required this.name,
    required this.tasks,
    this.status = 'pending',
  });
}
