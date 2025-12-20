import 'dart:io';
import 'package:interact/interact.dart';
import 'package:spectra/services/llm_service.dart';
import 'base_command.dart';

class MapCommand extends SpectraCommand {
  @override
  final name = 'map';
  @override
  final description =
      'Brownfield Analysis: Scans an existing repo to extract architecture and tech stack.';

  final LLMService _llmService = LLMService();

  MapCommand({required super.logger});

  @override
  Future<void> run() async {
    logger.info('Mapping existing repository...');

    final currentDir = Directory.current;
    final allFiles = currentDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => !f.path.contains('.git/') && !f.path.contains('.spectra/'));

    final fileStructure = allFiles.map((f) => f.path.replaceFirst(currentDir.path, '')).toList();

    final provider = await _llmService.getPreferredProvider();
    if (provider == null) {
      logger.err('No LLM provider configured.');
      return;
    }

    logger.info('Analyzing architecture using ${provider.name}...');

    final prompt = '''
Analyze the following file structure and summarize the project's tech stack, architecture, and core modules.
FILE STRUCTURE:
${fileStructure.join('\n')}

Return a markdown summary with sections: ## Tech Stack, ## Architecture, ## Core Modules.
''';

    try {
      final analysis = await provider.generateResponse(prompt);
      
      logger.info('\n--- Analysis Results ---\n');
      logger.info(analysis);

      final confirm =
          Confirm(prompt: 'Generate .spectra context based on this analysis?')
              .interact();

      if (confirm) {
        _generateSpectraFromMap(analysis);
        logger.success('Spectra context generated from repository map!');
      }
    } catch (e) {
      logger.err('Error mapping repository: $e');
    }
  }

  void _generateSpectraFromMap(String analysis) {
    final spectraDir = Directory('.spectra');
    if (!spectraDir.existsSync()) {
      spectraDir.createSync();
    }

    final projectFile = File('.spectra/PROJECT.md');
    projectFile.writeAsStringSync('''
# PROJECT: Mapped Project

## Analysis
$analysis

## Constraints
- Extracted from existing repository
''');

    File('.spectra/ROADMAP.md').writeAsStringSync('# ROADMAP\n\n- [ ] Reverse engineering complete.');
    File('.spectra/STATE.md').writeAsStringSync('# STATE\n\n- Mapped from existing repo.');
    File('.spectra/PLAN.md').writeAsStringSync('# PLAN\n\n<!-- No tasks yet -->');
    File('.spectra/SUMMARY.md').writeAsStringSync('# SUMMARY\n\nProject mapped.');
    File('.spectra/ISSUES.md').writeAsStringSync('# ISSUES\n\nNo issues yet.');
  }
}
