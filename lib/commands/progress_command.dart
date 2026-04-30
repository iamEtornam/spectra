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

  ProgressCommand({required super.logger}) {
    argParser.addFlag(
      'runs',
      negatable: false,
      help: 'Show the live runtime snapshot (running, retrying, totals).',
    );
  }

  @override
  void run() {
    final showRuns = argResults?['runs'] as bool? ?? false;
    if (showRuns) {
      _showRuntimeSnapshot();
    } else {
      _showAgentStatus();
    }

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
    final percent = totalTasks == 0
        ? 0
        : (completedTasks / totalTasks * 100).toInt();

    logger.info(
      '\nOverall Completion: $percent% ($completedTasks/$totalTasks tasks)',
    );
  }

  void _showRuntimeSnapshot() {
    final file = File('.spectra/RUNTIME.json');
    if (!file.existsSync()) {
      logger.warn('RUNTIME.json not found. Is the orchestrator running?');
      return;
    }
    try {
      final raw = jsonDecode(file.readAsStringSync());
      if (raw is! Map<String, dynamic>) {
        logger.err('RUNTIME.json is malformed.');
        return;
      }
      const header = '--- LIVE RUNTIME SNAPSHOT ---';
      logger.info(lightCyan.wrap(header) ?? header);
      final counts =
          raw['counts'] as Map<String, dynamic>? ?? const <String, dynamic>{};
      logger.info(
        'Running: ${counts['running'] ?? 0}  '
        'Retrying: ${counts['retrying'] ?? 0}  '
        'Claimed: ${counts['claimed'] ?? 0}  '
        'Completed: ${counts['completed'] ?? 0}',
      );

      final running = (raw['running'] as List<dynamic>?) ?? const <dynamic>[];
      for (final entry in running.whereType<Map<String, dynamic>>()) {
        logger.info(
          '• ${entry['issue_identifier']} [${entry['state']}] '
          'turn ${entry['turn_count'] ?? 0} '
          '(${entry['workspace_path'] ?? ''})',
        );
      }

      final retrying = (raw['retrying'] as List<dynamic>?) ?? const <dynamic>[];
      for (final entry in retrying.whereType<Map<String, dynamic>>()) {
        logger.info(
          '↻ ${entry['identifier']} attempt ${entry['attempt']} '
          'due ${entry['due_at']}',
        );
      }

      final totals =
          raw['codex_totals'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
      logger.info(
        'Tokens in/out/total: '
        '${totals['input_tokens'] ?? 0} / ${totals['output_tokens'] ?? 0} / '
        '${totals['total_tokens'] ?? 0}',
      );
      logger.info('Runtime seconds: ${totals['seconds_running'] ?? 0}');

      final errors =
          (raw['validation_errors'] as List<dynamic>?) ?? const <dynamic>[];
      if (errors.isNotEmpty) {
        logger.warn('Validation errors: ${errors.join(' ')}');
      }
      logger.info('');
    } catch (e) {
      logger.err('Failed to read RUNTIME.json: $e');
    }
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

      const header = '--- LIVE AGENT STATUS ---';
      logger.info(lightCyan.wrap(header) ?? header);
      for (final agent in agents) {
        final color = _getStatusColor(agent.status);
        final statusName = agent.status.name.toUpperCase();
        final statusStr = color.wrap(statusName) ?? statusName;
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
