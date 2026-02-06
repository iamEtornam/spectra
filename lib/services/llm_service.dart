import 'dart:io';

import '../core/cached_llm_provider.dart';
import '../core/claude_provider.dart';
import '../core/gemini_provider.dart';
import '../core/llm_provider.dart';
import '../core/openai_provider.dart';
import '../core/grok_provider.dart';
import '../core/deepseek_provider.dart';
import '../models/llm_usage_type.dart';
import 'config_service.dart';
import 'llm_cache.dart';

/// Service for managing LLM providers with optional caching.
///
/// Supports separate provider configuration for planning and coding tasks,
/// allowing users to optimize for cost, performance, or capability.
class LLMService {
  final ConfigService _configService = ConfigService();
  LLMCache? _cache;
  final bool _cachingEnabled;

  /// Creates a new LLM service.
  ///
  /// [enableCaching] - Whether to enable response caching (default: true).
  LLMService({bool enableCaching = true}) : _cachingEnabled = enableCaching {
    if (_cachingEnabled) {
      final home =
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      _cache = LLMCache(
        maxEntries: 100,
        ttl: const Duration(hours: 24),
        persistPath: '$home/.spectra/cache.json',
      );
    }
  }

  /// Gets the appropriate LLM provider based on usage type.
  ///
  /// [usageType] - The type of task (planning or coding).
  ///
  /// For [LLMUsageType.planning]: Uses planningProvider from config,
  /// falls back to preferredProvider or Gemini.
  ///
  /// For [LLMUsageType.coding]: Uses codingProvider from config,
  /// falls back to preferredProvider or Gemini.
  ///
  /// Returns null if no provider is configured with valid API keys.
  Future<LLMProvider?> getProviderForUsage(LLMUsageType usageType) async {
    final config = await _configService.loadConfig();

    String? providerName;

    switch (usageType) {
      case LLMUsageType.planning:
        providerName =
            config.planningProvider ?? config.preferredProvider ?? 'gemini';
        break;
      case LLMUsageType.coding:
        providerName =
            config.codingProvider ?? config.preferredProvider ?? 'gemini';
        break;
    }

    return getProvider(providerName);
  }

  /// Gets the user's preferred LLM provider (legacy method).
  ///
  /// For new code, prefer using [getProviderForUsage] with explicit usage type.
  @Deprecated('Use getProviderForUsage(LLMUsageType) instead')
  Future<LLMProvider?> getPreferredProvider() async {
    final config = await _configService.loadConfig();
    final providerName = config.preferredProvider ?? 'gemini';
    return getProvider(providerName);
  }

  /// Gets a specific LLM provider by name.
  Future<LLMProvider?> getProvider(String providerName) async {
    final config = await _configService.loadConfig();
    LLMProvider? provider;

    switch (providerName.toLowerCase()) {
      case 'openai':
        if (config.openaiKey == null) return null;
        provider = OpenAIProvider(
          apiKey: config.openaiKey!,
          modelName:
              config.openaiModel ?? OpenAIProvider(apiKey: '').defaultModel,
        );
        break;
      case 'claude':
        if (config.claudeKey == null) return null;
        provider = ClaudeProvider(
          apiKey: config.claudeKey!,
          modelName:
              config.claudeModel ?? ClaudeProvider(apiKey: '').defaultModel,
        );
        break;
      case 'gemini':
        if (config.geminiKey == null) return null;
        provider = GeminiProvider(
          apiKey: config.geminiKey!,
          modelName:
              config.geminiModel ?? GeminiProvider(apiKey: '').defaultModel,
        );
        break;
      case 'grok':
        if (config.grokKey == null) return null;
        provider = GrokProvider(
          apiKey: config.grokKey!,
          modelName: config.grokModel ?? GrokProvider(apiKey: '').defaultModel,
        );
        break;
      case 'deepseek':
        if (config.deepseekKey == null) return null;
        provider = DeepSeekProvider(
          apiKey: config.deepseekKey!,
          modelName:
              config.deepseekModel ?? DeepSeekProvider(apiKey: '').defaultModel,
        );
        break;
      default:
        return null;
    }

    // Wrap with caching if enabled
    if (_cachingEnabled && _cache != null) {
      return CachedLLMProvider(delegate: provider, cache: _cache!);
    }

    return provider;
  }

  /// Returns cache statistics if caching is enabled.
  Map<String, dynamic>? get cacheStats => _cache?.stats;

  /// Clears the response cache.
  void clearCache() => _cache?.clear();
}
