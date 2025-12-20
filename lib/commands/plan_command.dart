import 'dart:io';

import 'package:spectra/models/task.dart';
import 'package:spectra/services/llm_service.dart';
import 'package:xml/xml.dart';

import 'base_command.dart';

class PlanCommand extends SpectraCommand {
  @override
  final name = 'plan';
  @override
  final description = 'Break a roadmap phase into atomic tasks using XML.';

  final LLMService _llmService = LLMService();

  PlanCommand({required super.logger});

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    if (argResults == null || argResults.rest.isEmpty) {
      logger.err(
          'Please specify a phase to plan (e.g., spectra plan "Phase 1").');
      return;
    }

    final phase = argResults.rest.first;

    final projectFile = File('.spectra/PROJECT.md');
    final roadmapFile = File('.spectra/ROADMAP.md');

    if (!projectFile.existsSync() || !roadmapFile.existsSync()) {
      logger.err('Project context not found. Run `spectra new` first.');
      return;
    }

    final projectContext = projectFile.readAsStringSync();
    final roadmapContext = roadmapFile.readAsStringSync();

    final provider = await _llmService.getPreferredProvider();
    if (provider == null) {
      logger.err(
          'No LLM provider configured. Run `spectra config` to set up a provider.');
      return;
    }

    logger.info('Planning tasks for $phase using ${provider.name}...');

    final prompt = '''
You are a software architect. Break the following phase into atomic, implementable tasks.
Each task must be wrapped in a <task> XML tag following this structure:
<task id="1" type="implement">
  <n>Task Name</n>
  <files><file action="create">path/to/file.dart</file></files>
  <objective>Specific goal of this task</objective>
  <verification>How to verify this task works</verification>
  <acceptance>Git commit message for this task</acceptance>
</task>

PROJECT CONTEXT:
$projectContext

ROADMAP:
$roadmapContext

TARGET PHASE:
$phase

Return ONLY the XML tasks, one per line.
''';

    try {
      final response = await provider.generateResponse(prompt);
      final tasks = _parseTasksFromResponse(response);

      if (tasks.isEmpty) {
        logger.err('Failed to generate any valid tasks from LLM response.');
        logger.detail('Response was: $response');
        return;
      }

      final planContent = '''
# PLAN: $phase

${tasks.map((t) => t.toXml()).join('\n\n')}
''';

      final planFile = File('.spectra/PLAN.md');
      planFile.writeAsStringSync(planContent);

      logger.success('PLAN.md generated with ${tasks.length} tasks.');
    } catch (e) {
      logger.err('Error generating plan: $e');
    }
  }

  List<SpectraTask> _parseTasksFromResponse(String response) {
    try {
      final taskRegex = RegExp(r'<task.*?>.*?</task>', dotAll: true);
      final matches = taskRegex.allMatches(response);
      return matches.map((m) {
        final doc = XmlDocument.parse(m.group(0)!);
        return SpectraTask.fromXml(doc.rootElement);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
