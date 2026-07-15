/// Failure codes for loading and validating a Spectra workflow.
enum WorkflowFailureCode {
  /// The workflow file could not be found.
  missingWorkflowFile,

  /// The workflow file could not be parsed.
  workflowParseError,

  /// YAML front matter was present but did not decode to a map.
  workflowFrontMatterNotMap,

  /// A workflow template could not be parsed.
  templateParseError,

  /// A workflow template could not be rendered.
  templateRenderError,

  /// The workflow config is missing required dispatch settings.
  configValidationError,
}

/// Exception thrown when workflow loading or validation fails.
class WorkflowException implements Exception {
  /// Machine-readable failure code.
  final WorkflowFailureCode code;

  /// Human-readable failure message.
  final String message;

  /// Creates a workflow exception.
  const WorkflowException(this.code, this.message);

  @override
  String toString() => 'WorkflowException(${code.name}): $message';
}
