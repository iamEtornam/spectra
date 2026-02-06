/// Defines the different types of LLM usage in Spectra.
///
/// This allows users to configure different LLM providers for different tasks,
/// optimizing for cost, performance, or capability based on the use case.
enum LLMUsageType {
  /// Used for high-level strategic tasks:
  /// - Breaking roadmaps into task plans
  /// - Analyzing codebases and extracting architecture
  /// - Generating project documentation
  /// - Creating ROADMAP.md content
  ///
  /// Recommended models: Strong reasoning models like Claude, GPT-5
  planning,

  /// Used for tactical code generation tasks:
  /// - Implementing specific code changes
  /// - Writing actual files and functions
  /// - Refactoring existing code
  /// - Worker agent task execution
  ///
  /// Recommended models: Fast, code-focused models like Gemini-Flash,
  /// DeepSeek, or GPT-5-Mini
  coding;

  /// Returns a human-readable description of this usage type.
  String get description {
    return switch (this) {
      LLMUsageType.planning =>
        'Strategic planning, documentation, and analysis',
      LLMUsageType.coding => 'Code generation and implementation',
    };
  }

  /// Returns examples of when this usage type is used.
  List<String> get examples {
    return switch (this) {
      LLMUsageType.planning => [
        'spectra plan "Phase 1"',
        'spectra map',
        'Generating ROADMAP.md',
        'Analyzing project architecture',
      ],
      LLMUsageType.coding => [
        'spectra execute',
        'spectra start (worker agents)',
        'Implementing tasks',
        'Writing actual code files',
      ],
    };
  }

  /// Returns recommended providers for this usage type.
  List<String> get recommendedProviders {
    return switch (this) {
      LLMUsageType.planning => [
        'claude (Claude 4.5 - best reasoning)',
        'openai (GPT-5 - balanced)',
        'gemini (Gemini 3.0 Pro - fast)',
      ],
      LLMUsageType.coding => [
        'gemini (Gemini 3.0 Flash - fastest)',
        'deepseek (DeepSeek V3 - code-focused)',
        'openai (GPT-5 Mini - balanced)',
        'grok (Grok 4.1 - experimental)',
      ],
    };
  }
}
