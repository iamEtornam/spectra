import 'dart:io';
import 'package:test/test.dart';
import 'package:spectra_cli/services/llm_service.dart';
import 'package:spectra_cli/services/config_service.dart';
import 'package:spectra_cli/models/spectra_config.dart';
import 'package:spectra_cli/models/llm_usage_type.dart';
import '../test_helpers.dart';

void main() {
  late LLMService llmService;
  late ConfigService configService;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('spectra_llm_service_test_');
    useTestHome(tempDir.path);
    llmService = LLMService(enableCaching: false);
    configService = ConfigService();
  });

  tearDown(() async {
    // clearConfig must run before resetTestHome so it clears the temp home.
    await configService.clearConfig();
    resetTestHome();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('LLMService with Usage Types', () {
    test('should get planning provider when configured', () async {
      final config = SpectraConfig(
        claudeKey: 'test-claude-key',
        planningProvider: 'claude',
      );
      await configService.saveConfig(config);

      final provider = await llmService.getProviderForUsage(
        LLMUsageType.planning,
      );

      expect(provider, isNotNull);
      expect(provider!.name, equals('Claude'));
    });

    test('should get coding provider when configured', () async {
      final config = SpectraConfig(
        geminiKey: 'test-gemini-key',
        codingProvider: 'gemini',
      );
      await configService.saveConfig(config);

      final provider = await llmService.getProviderForUsage(
        LLMUsageType.coding,
      );

      expect(provider, isNotNull);
      expect(provider!.name, equals('Gemini'));
    });

    test(
      'should fallback to preferredProvider if usage-specific provider not set',
      () async {
        final config = SpectraConfig(
          openaiKey: 'test-openai-key',
          preferredProvider: 'openai',
          // No planningProvider or codingProvider set
        );
        await configService.saveConfig(config);

        final planningProvider = await llmService.getProviderForUsage(
          LLMUsageType.planning,
        );
        final codingProvider = await llmService.getProviderForUsage(
          LLMUsageType.coding,
        );

        expect(planningProvider, isNotNull);
        expect(codingProvider, isNotNull);
        expect(planningProvider!.name, equals('OpenAI'));
        expect(codingProvider!.name, equals('OpenAI'));
      },
    );

    test('should use different providers for planning vs coding', () async {
      final config = SpectraConfig(
        claudeKey: 'test-claude-key',
        geminiKey: 'test-gemini-key',
        planningProvider: 'claude',
        codingProvider: 'gemini',
      );
      await configService.saveConfig(config);

      final planningProvider = await llmService.getProviderForUsage(
        LLMUsageType.planning,
      );
      final codingProvider = await llmService.getProviderForUsage(
        LLMUsageType.coding,
      );

      expect(planningProvider, isNotNull);
      expect(codingProvider, isNotNull);
      expect(planningProvider!.name, equals('Claude'));
      expect(codingProvider!.name, equals('Gemini'));
      expect(planningProvider.name, isNot(equals(codingProvider.name)));
    });

    test('should return null if provider key not configured', () async {
      final config = SpectraConfig(
        planningProvider: 'claude',
        // No claudeKey provided
      );
      await configService.saveConfig(config);

      final provider = await llmService.getProviderForUsage(
        LLMUsageType.planning,
      );

      expect(provider, isNull);
    });

    test('should support all five LLM providers', () async {
      // Test each provider
      final providers = [
        ('gemini', 'test-gemini-key', 'Gemini'),
        ('openai', 'test-openai-key', 'OpenAI'),
        ('claude', 'test-claude-key', 'Claude'),
        ('grok', 'test-grok-key', 'Grok'),
        ('deepseek', 'test-deepseek-key', 'DeepSeek'),
      ];

      for (final (providerName, key, expectedName) in providers) {
        final config = SpectraConfig.fromMap({
          '${providerName}_key': key,
          'planning_provider': providerName,
        });
        await configService.saveConfig(config);

        final provider = await llmService.getProviderForUsage(
          LLMUsageType.planning,
        );

        expect(provider, isNotNull, reason: '$providerName should work');
        expect(provider!.name, equals(expectedName));

        // Cleanup for next iteration
        await configService.clearConfig();
      }
    });

    test('should use gemini as default fallback', () async {
      final config = SpectraConfig(
        geminiKey: 'test-gemini-key',
        // No planningProvider, codingProvider, or preferredProvider set
      );
      await configService.saveConfig(config);

      final provider = await llmService.getProviderForUsage(
        LLMUsageType.planning,
      );

      expect(provider, isNotNull);
      expect(provider!.name, equals('Gemini'));
    });

    test(
      'planning provider should be independent of coding provider config',
      () async {
        final config = SpectraConfig(
          claudeKey: 'test-claude-key',
          geminiKey: 'test-gemini-key',
          planningProvider: 'claude',
          codingProvider: 'gemini',
        );
        await configService.saveConfig(config);

        // Getting planning provider should not be affected by coding provider
        final planningProvider = await llmService.getProviderForUsage(
          LLMUsageType.planning,
        );

        expect(planningProvider, isNotNull);
        expect(planningProvider!.name, equals('Claude'));
      },
    );

    test(
      'coding provider should be independent of planning provider config',
      () async {
        final config = SpectraConfig(
          claudeKey: 'test-claude-key',
          deepseekKey: 'test-deepseek-key',
          planningProvider: 'claude',
          codingProvider: 'deepseek',
        );
        await configService.saveConfig(config);

        // Getting coding provider should not be affected by planning provider
        final codingProvider = await llmService.getProviderForUsage(
          LLMUsageType.coding,
        );

        expect(codingProvider, isNotNull);
        expect(codingProvider!.name, equals('DeepSeek'));
      },
    );

    test('should handle missing API key gracefully', () async {
      final config = SpectraConfig(
        planningProvider: 'claude',
        codingProvider: 'gemini',
        // Keys not provided
      );
      await configService.saveConfig(config);

      final planningProvider = await llmService.getProviderForUsage(
        LLMUsageType.planning,
      );
      final codingProvider = await llmService.getProviderForUsage(
        LLMUsageType.coding,
      );

      expect(planningProvider, isNull);
      expect(codingProvider, isNull);
    });

    test('should support mixed configuration scenarios', () async {
      final config = SpectraConfig(
        geminiKey: 'test-gemini-key',
        claudeKey: 'test-claude-key',
        planningProvider: 'claude',
        // codingProvider not set, should fallback to preferredProvider
        preferredProvider: 'gemini',
      );
      await configService.saveConfig(config);

      final planningProvider = await llmService.getProviderForUsage(
        LLMUsageType.planning,
      );
      final codingProvider = await llmService.getProviderForUsage(
        LLMUsageType.coding,
      );

      expect(planningProvider!.name, equals('Claude'));
      expect(codingProvider!.name, equals('Gemini'));
    });
  });

  group('Legacy getPreferredProvider', () {
    test('should still work for backward compatibility', () async {
      final config = SpectraConfig(
        geminiKey: 'test-key',
        preferredProvider: 'gemini',
      );
      await configService.saveConfig(config);

      // ignore: deprecated_member_use_from_same_package
      final provider = await llmService.getPreferredProvider();

      expect(provider, isNotNull);
      expect(provider!.name, equals('Gemini'));
    });
  });

  group('getProvider', () {
    test('should get provider by name', () async {
      final config = SpectraConfig(claudeKey: 'test-claude-key');
      await configService.saveConfig(config);

      final provider = await llmService.getProvider('claude');

      expect(provider, isNotNull);
      expect(provider!.name, equals('Claude'));
    });

    test('should return null for unconfigured provider', () async {
      final config = SpectraConfig(geminiKey: 'test-gemini-key');
      await configService.saveConfig(config);

      final provider = await llmService.getProvider('claude');

      expect(provider, isNull);
    });

    test('should be case insensitive', () async {
      final config = SpectraConfig(geminiKey: 'test-key');
      await configService.saveConfig(config);

      final provider1 = await llmService.getProvider('gemini');
      final provider2 = await llmService.getProvider('GEMINI');
      final provider3 = await llmService.getProvider('Gemini');

      expect(provider1, isNotNull);
      expect(provider2, isNotNull);
      expect(provider3, isNotNull);
    });
  });
}
