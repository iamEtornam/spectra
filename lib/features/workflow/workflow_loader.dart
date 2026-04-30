import 'dart:io';

import 'package:yaml/yaml.dart';

import 'workflow_definition.dart';
import 'workflow_failure.dart';

/// Loads and parses repository-owned workflow policy.
class WorkflowLoader {
  /// Default workflow file name.
  static const defaultWorkflowPath = 'WORKFLOW.md';

  /// Loads a workflow from [path], defaulting to `WORKFLOW.md`.
  Future<WorkflowDefinition> load({String? path}) async {
    final workflowPath = path ?? defaultWorkflowPath;
    final file = File(workflowPath);

    if (!file.existsSync()) {
      throw WorkflowException(
        WorkflowFailureCode.missingWorkflowFile,
        'Workflow file not found: $workflowPath',
      );
    }

    final content = await file.readAsString();
    return parse(content, path: file.path);
  }

  /// Parses workflow file contents.
  WorkflowDefinition parse(
    String content, {
    String path = defaultWorkflowPath,
  }) {
    if (!content.startsWith('---')) {
      return WorkflowDefinition(
        config: const <String, dynamic>{},
        promptTemplate: content.trim(),
        path: path,
      );
    }

    final lines = content.split(RegExp(r'\r?\n'));
    var closingIndex = -1;
    for (var i = 1; i < lines.length; i++) {
      if (lines[i].trim() == '---') {
        closingIndex = i;
        break;
      }
    }

    if (closingIndex == -1) {
      throw const WorkflowException(
        WorkflowFailureCode.workflowParseError,
        'Workflow front matter is missing a closing delimiter.',
      );
    }

    final frontMatter = lines.sublist(1, closingIndex).join('\n');
    final promptBody = lines.sublist(closingIndex + 1).join('\n').trim();

    final config = _parseFrontMatter(frontMatter);
    return WorkflowDefinition(
      config: config,
      promptTemplate: promptBody,
      path: path,
    );
  }

  Map<String, dynamic> _parseFrontMatter(String frontMatter) {
    if (frontMatter.trim().isEmpty) {
      return const <String, dynamic>{};
    }

    final Object? yaml;
    try {
      yaml = loadYaml(frontMatter);
    } catch (e) {
      throw WorkflowException(
        WorkflowFailureCode.workflowParseError,
        'Unable to parse workflow YAML front matter: $e',
      );
    }

    if (yaml == null) {
      return const <String, dynamic>{};
    }
    if (yaml is! Map<dynamic, dynamic>) {
      throw const WorkflowException(
        WorkflowFailureCode.workflowFrontMatterNotMap,
        'Workflow YAML front matter must decode to a map.',
      );
    }

    return _normalizeMap(yaml);
  }

  Map<String, dynamic> _normalizeMap(Map<dynamic, dynamic> yaml) {
    final result = <String, dynamic>{};

    for (final entry in yaml.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const WorkflowException(
          WorkflowFailureCode.workflowParseError,
          'Workflow YAML front matter keys must be strings.',
        );
      }
      result[key] = _normalizeValue(entry.value);
    }

    return result;
  }

  Object? _normalizeValue(Object? value) {
    if (value is Map<dynamic, dynamic>) {
      return _normalizeMap(value);
    }
    if (value is YamlList) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    if (value is List<dynamic>) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    return value;
  }
}
