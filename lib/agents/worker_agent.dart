import 'dart:io';

import '../models/agent.dart';
import '../models/task.dart';
import '../services/codebase_context_service.dart';
import 'base_agent.dart';

/// Callback type for when a worker completes a task.
typedef TaskCompletedCallback = void Function(String taskId);

/// Worker agent that executes assigned tasks by generating code.
///
/// Workers are assigned tasks by the [MayorAgent] and execute them by:
/// 1. Reading current file context and broader codebase context
/// 2. Generating code changes via LLM
/// 3. Writing file changes to disk
/// 4. Updating state files
class WorkerAgent extends SpectraAgent {
  SpectraTask? _activeTask;
  final CodebaseContextService _contextService;

  /// Optional callback when a task is completed successfully.
  TaskCompletedCallback? onTaskCompleted;

  /// Creates a new worker agent.
  ///
  /// [id] - Unique identifier for this worker.
  /// [provider] - The LLM provider to use for code generation.
  /// [logger] - Logger for output.
  /// [onTaskCompleted] - Optional callback when tasks are completed.
  /// [contextService] - Optional codebase context service (created if not provided).
  WorkerAgent({
    required super.id,
    required super.provider,
    required super.logger,
    this.onTaskCompleted,
    CodebaseContextService? contextService,
  })  : _contextService = contextService ?? CodebaseContextService(logger: logger),
        super(role: AgentRole.worker);

  /// The currently assigned task, if any.
  SpectraTask? get activeTask => _activeTask;

  /// Assigns a task to this worker.
  ///
  /// Changes status to [AgentStatus.working] and begins execution on next step.
  void assignTask(SpectraTask task) {
    _activeTask = task;
    currentTaskId = task.id;
    updateStatus(AgentStatus.working);
    logger.detail('[Agent $id] Assigned Task #${task.id}: ${task.name}');
  }

  @override
  Future<void> step() async {
    if (_activeTask == null || status != AgentStatus.working) return;

    final task = _activeTask!;
    logger.info('[Agent $id] Executing Task #${task.id}: ${task.name}');

    // Get comprehensive codebase context
    final codebaseContext = _contextService.getCodebaseContext(task.files);
    final fileContext = _getFileContext(task.files);

    final prompt = '''
You are an expert developer working on a real codebase. Implement the following task with full awareness of the project context.

$codebaseContext

=== TASK DETAILS ===
TASK: ${task.name}
OBJECTIVE: ${task.objective}
VERIFICATION: ${task.verification}
ACCEPTANCE CRITERIA: ${task.acceptance}

=== TARGET FILES ===
FILES TO MODIFY/CREATE: ${task.files.join(', ')}

=== CURRENT FILE CONTENT ===
$fileContext

=== INSTRUCTIONS ===
1. Analyze the codebase context above to understand project structure, patterns, and conventions
2. Review related files and dependencies to ensure consistency
3. Follow existing code patterns and naming conventions
4. Implement the task objective while maintaining code quality and consistency
5. Ensure your implementation matches the acceptance criteria

Return the full content of each file wrapped in <file_content path="path/to/file"> XML tags.
Example:
<file_content path="lib/main.dart">
void main() {}
</file_content>

IMPORTANT: Only generate code that is relevant to this codebase. Do not invent new patterns or structures that don't match the existing codebase.
''';

    try {
      final response = await provider.generateResponse(prompt);
      final fileContents = _parseFileContents(response);

      if (fileContents.isEmpty) {
        logger.warn(
            '[Agent $id] No file contents generated for Task #${task.id}');
        _completeTask(task.id, success: false);
        return;
      }

      for (final entry in fileContents.entries) {
        final file = File(entry.key);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        file.writeAsStringSync(entry.value);
        logger.detail('[Agent $id] Updated ${entry.key}');
      }

      logger.success('[Agent $id] Completed Task #${task.id}');
      _completeTask(task.id, success: true);
    } catch (e) {
      logger.err('[Agent $id] Error executing Task #${task.id}: $e');
      // Re-throw to let orchestrator handle error recovery
      rethrow;
    }
  }

  /// Completes the current task and resets worker state.
  void _completeTask(String taskId, {required bool success}) {
    if (success) {
      onTaskCompleted?.call(taskId);
    }
    updateStatus(AgentStatus.idle);
    currentTaskId = null;
    _activeTask = null;
  }

  /// Builds context string from existing files.
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

  /// Parses file content blocks from LLM response.
  Map<String, String> _parseFileContents(String response) {
    final contents = <String, String>{};
    final fileRegex = RegExp(
      r'<file_content path="(.*?)">(.*?)</file_content>',
      dotAll: true,
    );
    final matches = fileRegex.allMatches(response);

    for (final match in matches) {
      contents[match.group(1)!] = match.group(2)!.trim();
    }
    return contents;
  }
}
