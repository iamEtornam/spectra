import 'package:interact/interact.dart';
import '../services/config_service.dart';
import '../core/openai_provider.dart';
import '../core/claude_provider.dart';
import '../core/gemini_provider.dart';
import '../core/grok_provider.dart';
import '../core/deepseek_provider.dart';
import 'base_command.dart';

class ConfigCommand extends SpectraCommand {
  @override
  final name = 'config';
  @override
  final description = 'Set or update provider keys and model preferences.';

  final ConfigService _configService = ConfigService();

  ConfigCommand({required super.logger});

  @override
  Future<void> run() async {
    logger.info('Configuring Spectra...');

    final currentConfig = await _configService.loadConfig();

    // API Keys
    logger.info('\nEnter API Keys (leave blank to skip or keep existing):');
    final geminiKey = Input(
      prompt: 'Google Gemini API Key',
      defaultValue: currentConfig.geminiKey ?? '',
    ).interact();

    final openaiKey = Input(
      prompt: 'OpenAI API Key',
      defaultValue: currentConfig.openaiKey ?? '',
    ).interact();

    final claudeKey = Input(
      prompt: 'Anthropic Claude API Key',
      defaultValue: currentConfig.claudeKey ?? '',
    ).interact();

    final grokKey = Input(
      prompt: 'xAI Grok API Key',
      defaultValue: currentConfig.grokKey ?? '',
    ).interact();

    final deepseekKey = Input(
      prompt: 'DeepSeek API Key',
      defaultValue: currentConfig.deepseekKey ?? '',
    ).interact();

    // Model Selection
    logger.info('\nSelecting Models (default is latest)...');

    // OpenAI Model
    final openaiModels = OpenAIProvider(apiKey: '').availableModels;
    final openaiDefaultIndex = currentConfig.openaiModel != null
        ? openaiModels.indexOf(currentConfig.openaiModel!)
        : 0;
    final openaiModelIndex = Select(
      prompt: 'Select OpenAI Model',
      options: openaiModels,
      initialIndex: openaiDefaultIndex != -1 ? openaiDefaultIndex : 0,
    ).interact();

    // Claude Model
    final claudeModels = ClaudeProvider(apiKey: '').availableModels;
    final claudeDefaultIndex = currentConfig.claudeModel != null
        ? claudeModels.indexOf(currentConfig.claudeModel!)
        : 0;
    final claudeModelIndex = Select(
      prompt: 'Select Anthropic Claude Model',
      options: claudeModels,
      initialIndex: claudeDefaultIndex != -1 ? claudeDefaultIndex : 0,
    ).interact();

    // Gemini Model
    final geminiModels = GeminiProvider(apiKey: '').availableModels;
    final geminiDefaultIndex = currentConfig.geminiModel != null
        ? geminiModels.indexOf(currentConfig.geminiModel!)
        : 0;
    final geminiModelIndex = Select(
      prompt: 'Select Google Gemini Model',
      options: geminiModels,
      initialIndex: geminiDefaultIndex != -1 ? geminiDefaultIndex : 0,
    ).interact();

    // Grok Model
    final grokModels = GrokProvider(apiKey: '').availableModels;
    final grokDefaultIndex = currentConfig.grokModel != null
        ? grokModels.indexOf(currentConfig.grokModel!)
        : 0;
    final grokModelIndex = Select(
      prompt: 'Select xAI Grok Model',
      options: grokModels,
      initialIndex: grokDefaultIndex != -1 ? grokDefaultIndex : 0,
    ).interact();

    // DeepSeek Model
    final deepseekModels = DeepSeekProvider(apiKey: '').availableModels;
    final deepseekDefaultIndex = currentConfig.deepseekModel != null
        ? deepseekModels.indexOf(currentConfig.deepseekModel!)
        : 0;
    final deepseekModelIndex = Select(
      prompt: 'Select DeepSeek Model',
      options: deepseekModels,
      initialIndex: deepseekDefaultIndex != -1 ? deepseekDefaultIndex : 0,
    ).interact();

    // Provider Selection Strategy
    logger.info('\n--- Provider Strategy ---');
    logger.info(
      'Separate providers for different tasks (recommended for cost optimization):',
    );
    logger.detail(
      '  • Planning: Strategic analysis, task breakdown, documentation',
    );
    logger.detail('  • Coding: Actual code generation, file implementation');

    final providers = ['gemini', 'openai', 'claude', 'grok', 'deepseek'];
    final providerLabels = ['Gemini', 'OpenAI', 'Claude', 'Grok', 'DeepSeek'];

    // Helper function for case-insensitive provider lookup
    int findProviderIndex(String? providerName) {
      if (providerName == null) return 0;
      final index = providers.indexOf(providerName.toLowerCase());
      return index != -1 ? index : 0;
    }

    // Planning Provider
    final planningProviderIndex = Select(
      prompt:
          'Planning Provider (roadmap analysis, task breakdown) [Recommended: Claude]',
      options: providerLabels,
      initialIndex: currentConfig.planningProvider != null
          ? findProviderIndex(currentConfig.planningProvider)
          : findProviderIndex(currentConfig.preferredProvider),
    ).interact();

    // Coding Provider
    final codingProviderIndex = Select(
      prompt:
          'Coding Provider (code generation, implementation) [Recommended: Gemini Flash]',
      options: providerLabels,
      initialIndex: currentConfig.codingProvider != null
          ? findProviderIndex(currentConfig.codingProvider)
          : findProviderIndex(currentConfig.preferredProvider),
    ).interact();

    // Legacy Preferred Provider (for backward compatibility)
    final preferredProviderIndex = Select(
      prompt: 'Default Provider (legacy fallback)',
      options: providerLabels,
      initialIndex: findProviderIndex(currentConfig.preferredProvider),
    ).interact();

    // Execution Mode
    logger.info('\n--- Execution Mode ---');
    logger.info('How should Spectra execute tasks?');
    final executionModes = ['automatic', 'manual', 'interactive'];
    final executionModeLabels = [
      'Automatic (AI generates code)',
      'Manual (AI plans, you code)',
      'Interactive (AI suggests, you review)',
    ];
    final executionModeIndex = Select(
      prompt: 'Execution Mode',
      options: executionModeLabels,
      initialIndex: currentConfig.executionMode != null
          ? executionModes.indexOf(currentConfig.executionMode!)
          : 0,
    ).interact();

    final newConfig = currentConfig.copyWith(
      geminiKey: geminiKey.isEmpty ? null : geminiKey,
      openaiKey: openaiKey.isEmpty ? null : openaiKey,
      claudeKey: claudeKey.isEmpty ? null : claudeKey,
      grokKey: grokKey.isEmpty ? null : grokKey,
      deepseekKey: deepseekKey.isEmpty ? null : deepseekKey,
      openaiModel: openaiModels[openaiModelIndex],
      claudeModel: claudeModels[claudeModelIndex],
      geminiModel: geminiModels[geminiModelIndex],
      grokModel: grokModels[grokModelIndex],
      deepseekModel: deepseekModels[deepseekModelIndex],
      planningProvider: providers[planningProviderIndex],
      codingProvider: providers[codingProviderIndex],
      preferredProvider: providers[preferredProviderIndex],
      executionMode: executionModes[executionModeIndex],
    );

    await _configService.saveConfig(newConfig);
    logger.success('\nConfiguration updated successfully!');
    logger.info('Planning provider: ${providerLabels[planningProviderIndex]}');
    logger.info('Coding provider: ${providerLabels[codingProviderIndex]}');
    logger.info('Execution mode: ${executionModeLabels[executionModeIndex]}');
    logger.info('Config saved securely (encrypted)');
  }
}
