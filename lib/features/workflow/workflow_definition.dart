/// Parsed workflow contract loaded from `WORKFLOW.md`.
class WorkflowDefinition {
  /// YAML front matter decoded as a normalized Dart map.
  final Map<String, dynamic> config;

  /// Markdown prompt body after front matter, trimmed.
  final String promptTemplate;

  /// Absolute or relative path the definition was loaded from.
  final String path;

  /// Creates a workflow definition.
  WorkflowDefinition({
    required this.config,
    required this.promptTemplate,
    required this.path,
  });
}
