import 'dart:io';
import 'base_command.dart';

class ProgressCommand extends SpectraCommand {
  @override
  final name = 'progress';
  @override
  final description = 'Visual dashboard of completed vs. upcoming phases.';

  ProgressCommand({required super.logger});

  @override
  void run() {
    final roadmapFile = File('.spectra/ROADMAP.md');
    if (!roadmapFile.existsSync()) {
      logger.err('ROADMAP.md not found.');
      return;
    }

    final content = roadmapFile.readAsStringSync();
    final lines = content.split('\n');

    logger.info('Spectra Progress Dashboard:');
    
    for (final line in lines) {
      if (line.startsWith('## Phase') || line.startsWith('- [ ]') || line.startsWith('- [x]')) {
        logger.info(line);
      }
    }

    final totalTasks = RegExp(r'- \[( |x)\]').allMatches(content).length;
    final completedTasks = RegExp(r'- \[x\]').allMatches(content).length;
    final percent = totalTasks == 0 ? 0 : (completedTasks / totalTasks * 100).toInt();

    logger.info('\nOverall Completion: $percent% ($completedTasks/$totalTasks tasks)');
  }
}
