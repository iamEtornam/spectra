class SpectraConfig {
  final String? geminiKey;
  final String? openaiKey;
  final String? claudeKey;
  final String? grokKey;
  final String? deepseekKey;

  final String? geminiModel;
  final String? openaiModel;
  final String? claudeModel;
  final String? grokModel;
  final String? deepseekModel;

  /// Legacy: Preferred provider when no specific usage type is specified.
  /// For backward compatibility only.
  final String? preferredProvider;

  /// Provider to use for planning, documentation, and analysis tasks.
  /// Examples: breaking roadmaps into tasks, analyzing codebases.
  /// Recommended: Claude (reasoning), GPT-5 (balanced), Gemini Pro (fast).
  final String? planningProvider;

  /// Provider to use for code generation and implementation tasks.
  /// Examples: executing tasks, writing files, worker agents.
  /// Recommended: Gemini Flash (fastest), DeepSeek (code-focused), GPT-5 Mini.
  final String? codingProvider;

  /// Execution mode: how tasks should be executed.
  /// - 'automatic': AI generates and writes code (default)
  /// - 'manual': AI plans, user implements manually
  /// - 'interactive': AI generates, user reviews and approves
  final String? executionMode;

  SpectraConfig({
    this.geminiKey,
    this.openaiKey,
    this.claudeKey,
    this.grokKey,
    this.deepseekKey,
    this.geminiModel,
    this.openaiModel,
    this.claudeModel,
    this.grokModel,
    this.deepseekModel,
    this.preferredProvider,
    this.planningProvider,
    this.codingProvider,
    this.executionMode,
  });

  factory SpectraConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    // Helper to normalize provider names to lowercase (for v0.1.4 migration)
    String? normalizeProvider(String? provider) =>
        provider?.toLowerCase().trim();

    return SpectraConfig(
      geminiKey: yaml['gemini_key'] as String?,
      openaiKey: yaml['openai_key'] as String?,
      claudeKey: yaml['claude_key'] as String?,
      grokKey: yaml['grok_key'] as String?,
      deepseekKey: yaml['deepseek_key'] as String?,
      geminiModel: yaml['gemini_model'] as String?,
      openaiModel: yaml['openai_model'] as String?,
      claudeModel: yaml['claude_model'] as String?,
      grokModel: yaml['grok_model'] as String?,
      deepseekModel: yaml['deepseek_model'] as String?,
      preferredProvider: normalizeProvider(
        yaml['preferred_provider'] as String?,
      ),
      planningProvider: normalizeProvider(yaml['planning_provider'] as String?),
      codingProvider: normalizeProvider(yaml['coding_provider'] as String?),
      executionMode: yaml['execution_mode'] as String?,
    );
  }

  Map<String, String?> toYaml() {
    return {
      'gemini_key': geminiKey,
      'openai_key': openaiKey,
      'claude_key': claudeKey,
      'grok_key': grokKey,
      'deepseek_key': deepseekKey,
      'gemini_model': geminiModel,
      'openai_model': openaiModel,
      'claude_model': claudeModel,
      'grok_model': grokModel,
      'deepseek_model': deepseekModel,
      'preferred_provider': preferredProvider,
      'planning_provider': planningProvider,
      'coding_provider': codingProvider,
      'execution_mode': executionMode,
    };
  }

  /// Creates a SpectraConfig from a map (used for secure storage).
  factory SpectraConfig.fromMap(Map<String, String> map) {
    // Helper to normalize provider names to lowercase (for v0.1.4 migration)
    String? normalizeProvider(String? provider) =>
        provider?.toLowerCase().trim();

    return SpectraConfig(
      geminiKey: map['gemini_key'],
      openaiKey: map['openai_key'],
      claudeKey: map['claude_key'],
      grokKey: map['grok_key'],
      deepseekKey: map['deepseek_key'],
      geminiModel: map['gemini_model'],
      openaiModel: map['openai_model'],
      claudeModel: map['claude_model'],
      grokModel: map['grok_model'],
      deepseekModel: map['deepseek_model'],
      preferredProvider: normalizeProvider(map['preferred_provider']),
      planningProvider: normalizeProvider(map['planning_provider']),
      codingProvider: normalizeProvider(map['coding_provider']),
      executionMode: map['execution_mode'],
    );
  }

  /// Converts to a map (used for secure storage).
  Map<String, String> toMap() {
    final map = <String, String>{};
    if (geminiKey != null) map['gemini_key'] = geminiKey!;
    if (openaiKey != null) map['openai_key'] = openaiKey!;
    if (claudeKey != null) map['claude_key'] = claudeKey!;
    if (grokKey != null) map['grok_key'] = grokKey!;
    if (deepseekKey != null) map['deepseek_key'] = deepseekKey!;
    if (geminiModel != null) map['gemini_model'] = geminiModel!;
    if (openaiModel != null) map['openai_model'] = openaiModel!;
    if (claudeModel != null) map['claude_model'] = claudeModel!;
    if (grokModel != null) map['grok_model'] = grokModel!;
    if (deepseekModel != null) map['deepseek_model'] = deepseekModel!;
    if (preferredProvider != null) {
      map['preferred_provider'] = preferredProvider!;
    }
    if (planningProvider != null) map['planning_provider'] = planningProvider!;
    if (codingProvider != null) map['coding_provider'] = codingProvider!;
    if (executionMode != null) map['execution_mode'] = executionMode!;
    return map;
  }

  SpectraConfig copyWith({
    String? geminiKey,
    String? openaiKey,
    String? claudeKey,
    String? grokKey,
    String? deepseekKey,
    String? geminiModel,
    String? openaiModel,
    String? claudeModel,
    String? grokModel,
    String? deepseekModel,
    String? preferredProvider,
    String? planningProvider,
    String? codingProvider,
    String? executionMode,
  }) {
    return SpectraConfig(
      geminiKey: geminiKey ?? this.geminiKey,
      openaiKey: openaiKey ?? this.openaiKey,
      claudeKey: claudeKey ?? this.claudeKey,
      grokKey: grokKey ?? this.grokKey,
      deepseekKey: deepseekKey ?? this.deepseekKey,
      geminiModel: geminiModel ?? this.geminiModel,
      openaiModel: openaiModel ?? this.openaiModel,
      claudeModel: claudeModel ?? this.claudeModel,
      grokModel: grokModel ?? this.grokModel,
      deepseekModel: deepseekModel ?? this.deepseekModel,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      planningProvider: planningProvider ?? this.planningProvider,
      codingProvider: codingProvider ?? this.codingProvider,
      executionMode: executionMode ?? this.executionMode,
    );
  }
}
