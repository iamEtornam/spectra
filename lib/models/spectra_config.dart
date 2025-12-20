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

  final String? preferredProvider;

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
  });

  factory SpectraConfig.fromYaml(Map<dynamic, dynamic> yaml) {
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
      preferredProvider: yaml['preferred_provider'] as String?,
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
    };
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
    );
  }
}
