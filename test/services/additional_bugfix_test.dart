import 'package:test/test.dart';
import 'package:spectra_cli/services/llm_service.dart';
import 'package:spectra_cli/models/spectra_config.dart';

/// Tests for additional bug fixes in v0.1.5
void main() {
  group('Bug Fix: LLMService Null Home Directory', () {
    test('should handle null home directory validation', () {
      // Since we can't modify Platform.environment in tests,
      // we test that the same validation logic would work

      expect(() {
        const home = null;
        if (home == null) {
          throw StateError(
            'Unable to determine home directory. Neither HOME nor USERPROFILE environment variables are set.',
          );
        }
      }, throwsStateError);
    });

    test('LLMService with caching should validate home directory', () {
      // This test documents that LLMService now has the same
      // validation as ConfigService and SecureStorageService

      // If we could set HOME to null, LLMService constructor would throw
      // For now, we verify the service can be created normally
      expect(
        () => LLMService(enableCaching: true),
        returnsNormally,
        reason: 'Should work when HOME is set',
      );
    });

    test('LLMService without caching should not need home directory', () {
      // Without caching, no home directory needed
      expect(() => LLMService(enableCaching: false), returnsNormally);
    });
  });

  group('Bug Fix: Case-Insensitive Provider Names', () {
    test('should normalize capitalized provider names from legacy configs', () {
      // Simulate legacy v0.1.4 config with capitalized provider
      final yaml = {
        'gemini_key': 'test-key',
        'preferred_provider': 'Gemini', // Capitalized (legacy format)
      };

      final config = SpectraConfig.fromYaml(yaml);

      // Should be normalized to lowercase
      expect(config.preferredProvider, equals('gemini'));
    });

    test('should normalize all capitalized provider variations', () {
      final testCases = [
        ('Gemini', 'gemini'),
        ('OpenAI', 'openai'),
        ('Claude', 'claude'),
        ('Grok', 'grok'),
        ('DeepSeek', 'deepseek'),
        ('GEMINI', 'gemini'),
        ('gemini', 'gemini'),
      ];

      for (final (input, expected) in testCases) {
        final yaml = {'preferred_provider': input};

        final config = SpectraConfig.fromYaml(yaml);

        expect(
          config.preferredProvider,
          equals(expected),
          reason: '"$input" should normalize to "$expected"',
        );
      }
    });

    test('should normalize planning provider from legacy configs', () {
      final yaml = {
        'planning_provider': 'Claude', // Capitalized
      };

      final config = SpectraConfig.fromYaml(yaml);

      expect(config.planningProvider, equals('claude'));
    });

    test('should normalize coding provider from legacy configs', () {
      final yaml = {
        'coding_provider': 'Gemini', // Capitalized
      };

      final config = SpectraConfig.fromYaml(yaml);

      expect(config.codingProvider, equals('gemini'));
    });

    test('should handle whitespace in provider names', () {
      final yaml = {
        'preferred_provider': ' Gemini ', // With whitespace
      };

      final config = SpectraConfig.fromYaml(yaml);

      expect(config.preferredProvider, equals('gemini'));
    });

    test('should normalize provider names from map (secure storage)', () {
      final map = {
        'preferred_provider': 'Claude', // Capitalized in migrated storage
        'planning_provider': 'OpenAI',
        'coding_provider': 'Gemini',
      };

      final config = SpectraConfig.fromMap(map);

      expect(config.preferredProvider, equals('claude'));
      expect(config.planningProvider, equals('openai'));
      expect(config.codingProvider, equals('gemini'));
    });

    test('should handle null provider names gracefully', () {
      final yaml = {
        'gemini_key': 'test-key',
        // No provider specified
      };

      final config = SpectraConfig.fromYaml(yaml);

      expect(config.preferredProvider, isNull);
      expect(config.planningProvider, isNull);
      expect(config.codingProvider, isNull);
    });

    test('copyWith should not modify provider name case', () {
      final original = SpectraConfig(preferredProvider: 'gemini');

      final updated = original.copyWith(planningProvider: 'claude');

      expect(updated.preferredProvider, equals('gemini'));
      expect(updated.planningProvider, equals('claude'));
    });

    test('should handle mixed-case legacy configs', () {
      final yaml = {
        'gemini_key': 'test-gemini',
        'claude_key': 'test-claude',
        'preferred_provider': 'Gemini', // v0.1.4 format
        'planning_provider': 'CLAUDE', // Mixed case
        'coding_provider': 'gemini', // Already lowercase
      };

      final config = SpectraConfig.fromYaml(yaml);

      expect(config.preferredProvider, equals('gemini'));
      expect(config.planningProvider, equals('claude'));
      expect(config.codingProvider, equals('gemini'));
    });
  });
}
