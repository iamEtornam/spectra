import 'dart:io';

import '../models/agent.dart';
import '../models/task.dart';
import 'base_agent.dart';

class WorkerAgent extends SpectraAgent {
  SpectraTask? _activeTask;

  WorkerAgent({
    required super.id,
    required super.provider,
    required super.logger,
  }) : super(role: AgentRole.worker);

  void assignTask(SpectraTask task) {
    _activeTask = task;
    currentTaskId = task.id;
    updateStatus(AgentStatus.working);
  }

  @override
  Future<void> step() async {
    if (_activeTask == null || status != AgentStatus.working) return;

    final task = _activeTask!;
    logger.info('[Agent $id] Executing Task #${task.id}: ${task.name}');

    final fileContext = _getFileContext(task.files);

    final prompt = '''
You are an expert developer. Implement the following task.
TASK: ${task.name}
OBJECTIVE: ${task.objective}

CURRENT FILE CONTEXT:
$fileContext

FILES TO MODIFY/CREATE: ${task.files.join(', ')}

Return the full content of each file wrapped in <file_content path="path/to/file"> XML tags.
Example:
<file_content path="lib/main.dart">
void main() {}
</file_content>
''';

    try {
      final response = await provider.generateResponse(prompt);
      final fileContents = _parseFileContents(response);

      if (fileContents.isEmpty) {
        logger.warn(
            '[Agent $id] No file contents generated for Task #${task.id}');
        updateStatus(AgentStatus.idle);
        _activeTask = null;
        return;
      }

      for (final path in fileContents.keys) {
        final content = fileContents[path]!;
        final file = File(path);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        file.writeAsStringSync(content);
        logger.detail('[Agent $id] Updated $path');
      }

      // In a real orchestrator, the Mayor or Service would handle Git/State updates
      // for coordination, but for now we keep it here or emit results.
      logger.success('[Agent $id] Completed Task #${task.id}');

      updateStatus(AgentStatus.completed);
      _activeTask = null;
    } catch (e) {
      logger.err('[Agent $id] Error executing Task #${task.id}: $e');
      updateStatus(AgentStatus.failed);
      _activeTask = null;
    }
  }

  String _getFileContext(List<String> paths) {
    final buffer = StringBuffer();
    for (final path in paths) {
      final file = File(path);
      if (file.existsSync()) {
        buffer.writeln('FILE: $path');
        buffer.writeln('CONTENT:');
        buffer.writeln(file.readAsStringSync());
        buffer.writeln('---');
      } else {
        buffer.writeln('FILE: $path (Does not exist yet)');
        buffer.writeln('---');
      }
    }
    return buffer.toString();
  }

  Map<String, String> _parseFileContents(String response) {
    final contents = <String, String>{};
    final fileRegex = RegExp(r'<file_content path="(.*?)">(.*?)</file_content>',
        dotAll: true);
    final matches = fileRegex.allMatches(response);

    for (final match in matches) {
      contents[match.group(1)!] = match.group(2)!.trim();
    }
    return contents;
  }
}
