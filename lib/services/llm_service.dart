import '../core/llm_provider.dart';
import '../core/openai_provider.dart';
import '../core/claude_provider.dart';
import '../core/gemini_provider.dart';
import 'config_service.dart';

class LLMService {
  final ConfigService _configService = ConfigService();

  Future<LLMProvider?> getPreferredProvider() async {
    final config = await _configService.loadConfig();
    final providerName = config.preferredProvider ?? 'Gemini';
    return getProvider(providerName);
  }

  Future<LLMProvider?> getProvider(String providerName) async {
    final config = await _configService.loadConfig();
    
    switch (providerName.toLowerCase()) {
      case 'openai':
        if (config.openaiKey == null) return null;
        return OpenAIProvider(
          apiKey: config.openaiKey!,
          modelName: config.openaiModel ?? OpenAIProvider(apiKey: '').defaultModel,
        );
      case 'claude':
        if (config.claudeKey == null) return null;
        return ClaudeProvider(
          apiKey: config.claudeKey!,
          modelName: config.claudeModel ?? ClaudeProvider(apiKey: '').defaultModel,
        );
      case 'gemini':
        if (config.geminiKey == null) return null;
        return GeminiProvider(
          apiKey: config.geminiKey!,
          modelName: config.geminiModel ?? GeminiProvider(apiKey: '').defaultModel,
        );
      default:
        return null;
    }
  }
}

