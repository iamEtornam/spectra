import 'dart:convert';
import 'dart:io';
import 'package:mason_logger/mason_logger.dart';
import '../models/agent.dart';
import 'base_command.dart';

class ProgressCommand extends SpectraCommand {
  @override
  final name = 'progress';
  @override
  final description = 'Visual dashboard of completed vs. upcoming phases.';

  ProgressCommand({required super.logger});

  @override
  void run() {
    _showAgentStatus();

    final roadmapFile = File('.spectra/ROADMAP.md');
    if (!roadmapFile.existsSync()) {
      logger.err('ROADMAP.md not found.');
      return;
    }

    final content = roadmapFile.readAsStringSync();
    final lines = content.split('\n');

    logger.info('\nSpectra Roadmap Progress:');

    for (final line in lines) {
      if (line.startsWith('## Phase') ||
          line.startsWith('- [ ]') ||
          line.startsWith('- [x]')) {
        logger.info(line);
      }
    }

    final totalTasks = RegExp(r'- \[( |x)\]').allMatches(content).length;
    final completedTasks = RegExp(r'- \[x\]').allMatches(content).length;
    final percent =
        totalTasks == 0 ? 0 : (completedTasks / totalTasks * 100).toInt();

    logger.info(
        '\nOverall Completion: $percent% ($completedTasks/$totalTasks tasks)');
  }

  void _showAgentStatus() {
    final statusFile = File('.spectra/AGENTS.json');
    if (!statusFile.existsSync()) return;

    try {
      final content = statusFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! List) return;
      final agents = decoded
          .cast<Map<String, dynamic>>()
          .map((j) => AgentState.fromJson(j))
          .toList();

      logger.info(lightCyan.wrap('--- LIVE AGENT STATUS ---')!);
      for (final agent in agents) {
        final color = _getStatusColor(agent.status);
        final statusStr = color.wrap(agent.status.name.toUpperCase())!;
        final taskInfo = agent.currentTaskId != null
            ? ' (Task: ${agent.currentTaskId})'
            : '';

        logger.info('• ${agent.id} [${agent.role.name}]: $statusStr$taskInfo');
      }
      logger.info('');
    } catch (e) {
      // If file is being written while we read it, just skip
    }
  }

  AnsiCode _getStatusColor(AgentStatus status) {
    switch (status) {
      case AgentStatus.working:
        return yellow;
      case AgentStatus.completed:
        return green;
      case AgentStatus.failed:
      case AgentStatus.stuck:
        return red;
      default:
        return white;
    }
  }
}
