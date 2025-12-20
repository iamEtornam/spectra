import 'dart:io';

import 'package:spectra_cli/services/llm_service.dart';
import 'package:spectra_cli/utils/state_manager.dart';
import 'package:xml/xml.dart';

import 'base_command.dart';

class ExecuteCommand extends SpectraCommand {
  @override
  final name = 'execute';
  @override
  final description =
      'The execution engine: parses PLAN.md, applies changes, and commits.';

  final LLMService _llmService = LLMService();
  late final StateManager _stateManager;

  ExecuteCommand({required super.logger}) {
    _stateManager = StateManager(logger: logger);
  }

  @override
  Future<void> run() async {
    final planFile = File('.spectra/PLAN.md');
    if (!planFile.existsSync()) {
      logger.err('PLAN.md not found. Run `spectra plan` first.');
      return;
    }

    final content = planFile.readAsStringSync();
    final taskDocs = _parseTasks(content);

    if (taskDocs.isEmpty) {
      logger.warn('No tasks found in PLAN.md.');
      return;
    }

    final provider = await _llmService.getPreferredProvider();
    if (provider == null) {
      logger.err('No LLM provider configured.');
      return;
    }

    logger.info('Executing ${taskDocs.length} tasks using ${provider.name}...');

    for (final taskDoc in taskDocs) {
      await _executeTask(taskDoc, provider);
    }

    // Prune state if it gets too large
    _stateManager.pruneState();

    logger.success('All tasks executed successfully!');
  }

  List<XmlDocument> _parseTasks(String content) {
    final taskRegex = RegExp(r'<task.*?>.*?</task>', dotAll: true);
    final matches = taskRegex.allMatches(content);
    return matches.map((m) => XmlDocument.parse(m.group(0)!)).toList();
  }

  Future<void> _executeTask(XmlDocument taskDoc, dynamic provider) async {
    final taskElement = taskDoc.rootElement;
    final id = taskElement.getAttribute('id');
    final name = taskElement.findElements('n').first.innerText;
    final files = taskElement.findElements('files').first.findElements('file');
    final objective = taskElement.findElements('objective').first.innerText;
    final acceptance = taskElement.findElements('acceptance').first.innerText;

    logger.info('Processing Task #$id: $name');

    final filePaths = files.map((f) => f.innerText).toList();
    final fileContext = _getFileContext(filePaths);

    final prompt = '''
You are an expert developer. Implement the following task.
TASK: $name
OBJECTIVE: $objective

CURRENT FILE CONTEXT:
$fileContext

FILES TO MODIFY/CREATE: ${filePaths.join(', ')}

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
        logger.warn('No file contents generated for Task #$id');
        return;
      }

      for (final path in fileContents.keys) {
        final content = fileContents[path]!;
        final file = File(path);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        file.writeAsStringSync(content);
        logger.detail('Updated $path');
      }

      // Update PLAN.md state
      _updatePlanStatus(id!);

      // Update STATE.md
      _updateProjectState(name, objective);

      // Real Git Commit
      logger.info('Committing changes: $acceptance');
      _commitChanges(acceptance);
    } catch (e) {
      logger.err('Error executing Task #$id: $e');
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

  void _updatePlanStatus(String taskId) {
    final planFile = File('.spectra/PLAN.md');
    if (!planFile.existsSync()) return;

    var content = planFile.readAsStringSync();
    // Simple regex to find the task and mark it complete
    final taskRegex = RegExp('<task id="$taskId".*?>', dotAll: true);
    final match = taskRegex.firstMatch(content);

    if (match != null) {
      // Find the roadmap reference above it if it exists and mark it too?
      // Actually, let's just mark the XML task as completed in a way the parser can see if we want,
      // but usually the user wants to see the checkbox marked.
      // Since our XML is in the markdown, let's just ensure we can track it.
      // For now, let's just log it. A better way would be a STATUS attribute.
      content = content.replaceFirst(
          '<task id="$taskId"', '<task id="$taskId" status="completed"');
      planFile.writeAsStringSync(content);
    }
  }

  void _updateProjectState(String taskName, String objective) {
    final stateFile = File('.spectra/STATE.md');
    final now = DateTime.now().toIso8601String();
    final entry = '\n- [$now] COMPLETED: $taskName - $objective';

    if (stateFile.existsSync()) {
      stateFile.writeAsStringSync(entry, mode: FileMode.append);
    } else {
      stateFile.writeAsStringSync('# STATE\n$entry');
    }
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

  void _commitChanges(String message) {
    try {
      final gitDir = Directory('.git');
      if (gitDir.existsSync()) {
        Process.runSync('git', ['add', '.']);
        final result = Process.runSync('git', ['commit', '-m', message]);
        if (result.exitCode == 0) {
          logger.detail('Git: Changes committed successfully.');
        } else {
          logger.warn('Git commit failed: ${result.stderr}');
        }
      } else {
        logger.detail('No .git directory found. Skipping commit.');
      }
    } catch (e) {
      logger.warn('Failed to perform git operations: $e');
    }
  }
}
