import 'dart:io';

import 'package:interact/interact.dart';
import 'package:spectra_cli/core/llm_provider.dart';
import 'package:spectra_cli/models/execution_mode.dart';
import 'package:spectra_cli/models/llm_usage_type.dart';
import 'package:spectra_cli/services/config_service.dart';
import 'package:spectra_cli/services/llm_service.dart';
import 'package:spectra_cli/utils/state_manager.dart';
import 'package:xml/xml.dart';

import 'base_command.dart';

/// User decision for a single AI-suggested file in interactive mode.
/// Order matches the Select options in [_reviewSuggestion].
enum _ReviewAction { apply, edit, skip, quit }

class ExecuteCommand extends SpectraCommand {
  @override
  final name = 'execute';
  @override
  final description =
      'The execution engine: parses PLAN.md, applies changes, and commits.';

  final LLMService _llmService = LLMService();
  final ConfigService _configService = ConfigService();
  late final StateManager _stateManager;

  ExecuteCommand({required super.logger}) {
    _stateManager = StateManager(logger: logger);

    argParser.addFlag(
      'manual',
      abbr: 'm',
      help: 'Manual mode: Show tasks without generating code',
      negatable: false,
    );

    argParser.addFlag(
      'auto',
      abbr: 'a',
      help: 'Automatic mode: Generate and apply code (default)',
      negatable: false,
    );
  }

  @override
  Future<void> run() async {
    final planFile = File('.spectra/PLAN.md');
    if (!planFile.existsSync()) {
      logger.err('PLAN.md not found. Run `spectra plan` first.');
      return;
    }

    final content = planFile.readAsStringSync();
    final allTasks = _parseTasks(content);

    if (allTasks.isEmpty) {
      logger.warn('No tasks found in PLAN.md.');
      return;
    }

    // Tasks already marked completed (by a previous run) are not re-executed,
    // so `execute` is idempotent and `resume` continues where it left off.
    final taskDocs = allTasks
        .where((d) => d.rootElement.getAttribute('status') != 'completed')
        .toList();
    final alreadyDone = allTasks.length - taskDocs.length;
    if (alreadyDone > 0) {
      logger.detail('Skipping $alreadyDone already-completed task(s).');
    }
    if (taskDocs.isEmpty) {
      logger.success(
        'All ${allTasks.length} tasks in PLAN.md are already '
        'completed. Nothing to execute.',
      );
      return;
    }

    // Determine execution mode
    final config = await _configService.loadConfig();
    final manualFlag = argResults?['manual'] as bool? ?? false;
    final autoFlag = argResults?['auto'] as bool? ?? false;

    final ExecutionMode mode;
    if (manualFlag) {
      mode = ExecutionMode.manual;
    } else if (autoFlag) {
      mode = ExecutionMode.automatic;
    } else {
      // Use config or default to automatic
      final modeStr = config.executionMode ?? 'automatic';
      mode = ExecutionMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => ExecutionMode.automatic,
      );
    }

    if (mode == ExecutionMode.manual) {
      await _displayTasksForManualExecution(taskDocs);
      return;
    }

    // Use coding provider for actual code generation
    final provider = await _llmService.getProviderForUsage(LLMUsageType.coding);
    if (provider == null) {
      logger.err('No coding provider configured.');
      return;
    }

    final interactive = mode == ExecutionMode.interactive;
    logger.info(
      'Executing ${taskDocs.length} tasks using ${provider.name} '
      '(${interactive ? 'Interactive Review' : 'Code Generation'})...',
    );

    for (final taskDoc in taskDocs) {
      final keepGoing = await _executeTask(
        taskDoc,
        provider,
        interactive: interactive,
      );
      if (!keepGoing) {
        logger.info('Execution stopped by user.');
        return;
      }
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

  /// Executes a single task. Returns false when the user chose to quit
  /// during an interactive review.
  Future<bool> _executeTask(
    XmlDocument taskDoc,
    LLMProvider provider, {
    bool interactive = false,
  }) async {
    final taskElement = taskDoc.rootElement;
    final id = taskElement.getAttribute('id');
    final name = taskElement.findElements('n').first.innerText;
    final files = taskElement.findElements('files').first.findElements('file');
    final objective = taskElement.findElements('objective').first.innerText;
    final acceptance = taskElement.findElements('acceptance').first.innerText;

    logger.info('Processing Task #$id: $name');

    final filePaths = files.map((f) => f.innerText).toList();
    final fileContext = _getFileContext(filePaths);

    final prompt =
        '''
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
        return true;
      }

      var appliedAny = false;
      for (final path in fileContents.keys) {
        var content = fileContents[path]!;

        if (interactive) {
          final (action, reviewed) = await _reviewInteractively(path, content);
          if (action == _ReviewAction.quit) return false;
          if (action == _ReviewAction.skip) {
            logger.detail('Skipped $path');
            continue;
          }
          content = reviewed;
        }

        final file = File(path);
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        file.writeAsStringSync(content);
        appliedAny = true;
        logger.success('✅ File written: $path');
      }

      if (!appliedAny) {
        logger.info('No files applied for Task #$id; skipping commit.');
        return true;
      }

      // Update PLAN.md state
      _updatePlanStatus(id!);

      // Update STATE.md
      _updateProjectState(name, objective);

      if (interactive) {
        return _promptCommit(acceptance);
      }

      // Real Git Commit
      logger.info('Committing changes: $acceptance');
      _commitChanges(acceptance);
    } catch (e) {
      logger.err('Error executing Task #$id: $e');
    }
    return true;
  }

  /// Runs the review menu until the user lands on a final decision.
  ///
  /// A failed editor launch re-shows the menu instead of silently applying
  /// the unedited suggestion — the user picked Edit precisely because they
  /// did not want it as-is.
  Future<(_ReviewAction, String)> _reviewInteractively(
    String path,
    String content,
  ) async {
    while (true) {
      final action = _reviewSuggestion(path, content);
      if (action != _ReviewAction.edit) return (action, content);

      final edited = await _editSuggestion(path, content);
      if (edited == null) {
        logger.warn('Edit failed — nothing was applied. Choose again.');
        continue;
      }
      return (_ReviewAction.apply, edited);
    }
  }

  /// Shows a generated file and asks the user what to do with it.
  _ReviewAction _reviewSuggestion(String path, String content) {
    logger.info('─' * 60);
    logger.info('AI suggests for $path:');
    logger.info('─' * 60);
    logger.write('$content\n');
    logger.info('─' * 60);

    final choice = Select(
      prompt: 'Apply suggestion for $path?',
      options: const [
        '[A] Apply as-is',
        '[E] Edit suggestion',
        '[S] Skip',
        '[Q] Quit',
      ],
    ).interact();

    return _ReviewAction.values[choice];
  }

  /// Opens the suggestion in $EDITOR and returns the edited content, or
  /// null if the editor failed (caller keeps the original suggestion).
  Future<String?> _editSuggestion(String path, String content) async {
    final tempDir = Directory.systemTemp.createTempSync('spectra_edit_');
    final tempFile = File(
      '${tempDir.path}/${path.split(Platform.pathSeparator).last.split('/').last}',
    );
    tempFile.writeAsStringSync(content);

    // $EDITOR may carry arguments ("code --wait", "vim -u NONE") — split
    // into executable + args or Process.start treats it as one binary name.
    final editor =
        (Platform.environment['EDITOR'] ??
                Platform.environment['VISUAL'] ??
                (Platform.isWindows ? 'notepad' : 'vi'))
            .trim();
    final editorParts = editor.split(RegExp(r'\s+'));

    try {
      final process = await Process.start(
        editorParts.first,
        [...editorParts.skip(1), tempFile.path],
        mode: ProcessStartMode.inheritStdio,
        runInShell: true,
      );
      final exitCode = await process.exitCode;
      if (exitCode != 0) {
        logger.warn('Editor exited with code $exitCode; keeping suggestion.');
        return null;
      }
      return tempFile.readAsStringSync();
    } catch (e) {
      logger.warn('Failed to launch editor "$editor": $e');
      return null;
    } finally {
      tempDir.deleteSync(recursive: true);
    }
  }

  /// Interactive commit prompt. Returns false when the user chose to quit.
  bool _promptCommit(String message) {
    final choice = Select(
      prompt: 'Commit message: "$message"',
      options: const ['[Y] Commit now', '[N] Skip commit', '[E] Edit message'],
    ).interact();

    switch (choice) {
      case 0:
        _commitChanges(message);
      case 1:
        logger.detail('Skipped commit.');
      case 2:
        final edited = Input(
          prompt: 'Commit message',
          defaultValue: message,
        ).interact();
        _commitChanges(edited.trim().isEmpty ? message : edited);
    }
    return true;
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
        '<task id="$taskId"',
        '<task id="$taskId" status="completed"',
      );
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

  /// Displays tasks for manual execution without generating code.
  ///
  /// In manual mode, Spectra shows the task breakdown but leaves
  /// implementation to the user.
  Future<void> _displayTasksForManualExecution(
    List<XmlDocument> taskDocs,
  ) async {
    logger.info(
      '📋 Manual Execution Mode - ${taskDocs.length} tasks to implement:',
    );
    logger.detail('You will implement these tasks manually.\n');

    for (var i = 0; i < taskDocs.length; i++) {
      final taskElement = taskDocs[i].rootElement;
      final id = taskElement.getAttribute('id');
      final name = taskElement.findElements('n').first.innerText;
      final files = taskElement
          .findElements('files')
          .first
          .findElements('file');
      final objective = taskElement.findElements('objective').first.innerText;
      final verification = taskElement
          .findElements('verification')
          .first
          .innerText;
      final acceptance = taskElement.findElements('acceptance').first.innerText;

      final filePaths = files.map((f) => f.innerText).toList();

      logger.info('─' * 60);
      logger.info('Task ${i + 1}/${taskDocs.length}: #$id');
      logger.success('Name: $name');
      logger.detail('Objective: $objective');
      logger.detail('Files: ${filePaths.join(', ')}');
      logger.detail('Verification: $verification');
      logger.detail('Acceptance: $acceptance');
      logger.info('');

      // Show file context if files exist
      for (final path in filePaths) {
        final file = File(path);
        if (file.existsSync()) {
          logger.detail('  Existing: $path (${file.lengthSync()} bytes)');
        } else {
          logger.detail('  Create: $path (new file)');
        }
      }

      logger.info('');
    }

    logger.info('─' * 60);
    logger.success(
      '\n✅ Task list displayed. Implement manually and commit when ready.',
    );
    logger.detail('Tip: Mark tasks complete in PLAN.md as you finish them.');
    logger.detail(
      'Tip: Run `spectra execute --auto` when ready for AI to take over.',
    );
  }
}
