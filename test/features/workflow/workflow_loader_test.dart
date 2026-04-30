import 'dart:io';

import 'package:spectra_cli/features/workflow/workflow.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowLoader', () {
    test('parses prompt-only workflow files', () {
      final loader = WorkflowLoader();

      final definition = loader.parse('Run the selected issue.');

      expect(definition.config, isEmpty);
      expect(definition.promptTemplate, equals('Run the selected issue.'));
      expect(definition.path, equals(WorkflowLoader.defaultWorkflowPath));
    });

    test('parses YAML front matter and prompt body', () {
      final loader = WorkflowLoader();

      final definition = loader.parse('''
---
tracker:
  kind: linear
  project_slug: spectra
polling:
  interval_ms: 15000
agent:
  max_concurrent_agents: 4
---

Implement {{ issue.identifier }}.
''', path: 'custom/WORKFLOW.md');

      expect(
        definition.promptTemplate,
        equals('Implement {{ issue.identifier }}.'),
      );
      expect(definition.config['tracker'], isA<Map<String, dynamic>>());
      expect(
        (definition.config['tracker'] as Map<String, dynamic>)['kind'],
        equals('linear'),
      );
      expect(
        (definition.config['polling'] as Map<String, dynamic>)['interval_ms'],
        equals(15000),
      );
    });

    test('throws when workflow file is missing', () async {
      final loader = WorkflowLoader();

      expect(
        () => loader.load(path: 'missing-WORKFLOW.md'),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.missingWorkflowFile,
          ),
        ),
      );
    });

    test('throws when front matter is not closed', () {
      final loader = WorkflowLoader();

      expect(
        () => loader.parse('---\ntracker:\n  kind: linear\n'),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.workflowParseError,
          ),
        ),
      );
    });

    test('throws when front matter is not a map', () {
      final loader = WorkflowLoader();

      expect(
        () => loader.parse('---\n- one\n- two\n---\nPrompt'),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.workflowFrontMatterNotMap,
          ),
        ),
      );
    });

    test('loads a workflow file from disk', () async {
      final tempDir = Directory.systemTemp.createTempSync(
        'spectra_workflow_loader_test_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final file = File('${tempDir.path}/WORKFLOW.md');
      file.writeAsStringSync('Prompt from disk.');

      final definition = await WorkflowLoader().load(path: file.path);

      expect(definition.promptTemplate, equals('Prompt from disk.'));
      expect(definition.path, equals(file.path));
    });
  });
}
