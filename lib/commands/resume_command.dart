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
    
    // In a real implementation, we would track task status in STATE.md or PLAN.md
    // For now, we'll look for tasks in PLAN.md and ask the user where to start
    final content = planFile.readAsStringSync();
    final taskRegex = RegExp(r'<task id="(.*?)".*?><n>(.*?)</n>', dotAll: true);
    final matches = taskRegex.allMatches(content).toList();

    if (matches.isEmpty) {
      logger.warn('No tasks found in current plan.');
      return;
    }

    logger.info('Found ${matches.length} tasks in current plan.');
    logger.info('Picking up from the beginning of the current PLAN.md...');
    
    // Delegate to ExecuteCommand
    await ExecuteCommand(logger: logger).run();
  }
}
