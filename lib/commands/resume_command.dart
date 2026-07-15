import 'dart:io';
import 'base_command.dart';
import 'execute_command.dart';

class ResumeCommand extends SpectraCommand {
  @override
  final name = 'resume';
  @override
  final description =
      'Detects interrupted states and picks up the last uncompleted task.';

  ResumeCommand({required super.logger});

  @override
  Future<void> run() async {
    final planFile = File('.spectra/PLAN.md');

    if (!planFile.existsSync()) {
      logger.err('No PLAN.md found to resume.');
      return;
    }

    logger.info('Analyzing session state...');

    // Task status lives in PLAN.md: execute stamps status="completed" on each
    // finished task, so the first task without it is where we pick up.
    final content = planFile.readAsStringSync();
    final taskRegex = RegExp(r'<task\b[^>]*>', dotAll: true);
    final tasks = taskRegex.allMatches(content).toList();

    if (tasks.isEmpty) {
      logger.warn('No tasks found in current plan.');
      return;
    }

    final completed = tasks
        .where((m) => m.group(0)!.contains('status="completed"'))
        .length;
    final remaining = tasks.length - completed;

    if (remaining == 0) {
      logger.success(
        'All ${tasks.length} tasks in PLAN.md are already completed.',
      );
      return;
    }

    logger.info(
      'Found ${tasks.length} tasks: $completed completed, $remaining remaining.',
    );
    logger.info('Resuming with the first uncompleted task...');

    // Delegate to ExecuteCommand, which skips completed tasks.
    await ExecuteCommand(logger: logger).run();
  }
}
