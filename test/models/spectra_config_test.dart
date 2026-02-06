import 'package:test/test.dart';
import 'package:spectra_cli/models/spectra_config.dart';

void main() {
  group('SpectraConfig', () {
    test('should create with all fields', () {
      final config = SpectraConfig(
        geminiKey: 'gemini-key',
        geminiModel: 'gemini-3.0-pro',
        openaiKey: 'openai-key',
        openaiModel: 'gpt-5-turbo',
        claudeKey: 'claude-key',
        claudeModel: 'claude-4.5-sonnet',
        grokKey: 'grok-key',
        grokModel: 'grok-4.1',
        deepseekKey: 'deepseek-key',
        deepseekModel: 'deepseek-v3.2',
        preferredProvider: 'claude',
      );

      expect(config.geminiKey, equals('gemini-key'));
      expect(config.geminiModel, equals('gemini-3.0-pro'));
      expect(config.openaiKey, equals('openai-key'));
      expect(config.openaiModel, equals('gpt-5-turbo'));
      expect(config.claudeKey, equals('claude-key'));
      expect(config.claudeModel, equals('claude-4.5-sonnet'));
      expect(config.grokKey, equals('grok-key'));
      expect(config.grokModel, equals('grok-4.1'));
      expect(config.deepseekKey, equals('deepseek-key'));
      expect(config.deepseekModel, equals('deepseek-v3.2'));
      expect(config.preferredProvider, equals('claude'));
    });

    test('should create with null fields', () {
      final config = SpectraConfig();

      expect(config.geminiKey, isNull);
      expect(config.openaiKey, isNull);
      expect(config.claudeKey, isNull);
      expect(config.grokKey, isNull);
      expect(config.deepseekKey, isNull);
      expect(config.geminiModel, isNull);
      expect(config.openaiModel, isNull);
      expect(config.claudeModel, isNull);
      expect(config.grokModel, isNull);
      expect(config.deepseekModel, isNull);
      expect(config.preferredProvider, isNull);
    });

    group('fromYaml', () {
      test('should parse complete YAML', () {
        final yaml = {
          'gemini_key': 'gemini-test',
          'openai_key': 'openai-test',
          'claude_key': 'claude-test',
          'grok_key': 'grok-test',
          'deepseek_key': 'deepseek-test',
          'gemini_model': 'gemini-3.0-flash',
          'openai_model': 'gpt-5-mini',
          'claude_model': 'claude-4.5-opus',
          'grok_model': 'grok-4.1-beta',
          'deepseek_model': 'deepseek-v3.2-chat',
          'preferred_provider': 'openai',
        };

        final config = SpectraConfig.fromYaml(yaml);

        expect(config.geminiKey, equals('gemini-test'));
        expect(config.openaiKey, equals('openai-test'));
        expect(config.claudeKey, equals('claude-test'));
        expect(config.grokKey, equals('grok-test'));
        expect(config.deepseekKey, equals('deepseek-test'));
        expect(config.geminiModel, equals('gemini-3.0-flash'));
        expect(config.openaiModel, equals('gpt-5-mini'));
        expect(config.claudeModel, equals('claude-4.5-opus'));
        expect(config.grokModel, equals('grok-4.1-beta'));
        expect(config.deepseekModel, equals('deepseek-v3.2-chat'));
        expect(config.preferredProvider, equals('openai'));
      });

      test('should handle partial YAML', () {
        final yaml = {'gemini_key': 'gemini-only'};

        final config = SpectraConfig.fromYaml(yaml);

        expect(config.geminiKey, equals('gemini-only'));
        expect(config.openaiKey, isNull);
        expect(config.claudeKey, isNull);
      });

      test('should handle empty YAML', () {
        final config = SpectraConfig.fromYaml({});

        expect(config.geminiKey, isNull);
        expect(config.openaiKey, isNull);
      });
    });

    group('toYaml', () {
      test('should convert to YAML map', () {
        final config = SpectraConfig(
          geminiKey: 'gemini-key',
          openaiKey: 'openai-key',
          preferredProvider: 'gemini',
        );

        final yaml = config.toYaml();

        expect(yaml['gemini_key'], equals('gemini-key'));
        expect(yaml['openai_key'], equals('openai-key'));
        expect(yaml['preferred_provider'], equals('gemini'));
      });

      test('should include null values', () {
        final config = SpectraConfig(geminiKey: 'only-gemini');

        final yaml = config.toYaml();

        expect(yaml['gemini_key'], equals('only-gemini'));
        expect(yaml['openai_key'], isNull);
        expect(yaml['claude_key'], isNull);
      });
    });

    group('fromMap', () {
      test('should parse complete map', () {
        final map = {
          'gemini_key': 'gemini-test',
          'openai_key': 'openai-test',
          'claude_key': 'claude-test',
          'grok_key': 'grok-test',
          'deepseek_key': 'deepseek-test',
          'preferred_provider': 'claude',
        };

        final config = SpectraConfig.fromMap(map);

        expect(config.geminiKey, equals('gemini-test'));
        expect(config.openaiKey, equals('openai-test'));
        expect(config.claudeKey, equals('claude-test'));
        expect(config.grokKey, equals('grok-test'));
        expect(config.deepseekKey, equals('deepseek-test'));
        expect(config.preferredProvider, equals('claude'));
      });

      test('should handle partial map', () {
        final map = {'gemini_key': 'gemini-only'};

        final config = SpectraConfig.fromMap(map);

        expect(config.geminiKey, equals('gemini-only'));
        expect(config.openaiKey, isNull);
      });

      test('should handle empty map', () {
        final config = SpectraConfig.fromMap({});

        expect(config.geminiKey, isNull);
        expect(config.openaiKey, isNull);
      });
    });

    group('toMap', () {
      test('should convert to map without nulls', () {
        final config = SpectraConfig(
          geminiKey: 'gemini-key',
          openaiKey: 'openai-key',
          preferredProvider: 'gemini',
        );

        final map = config.toMap();

        expect(map['gemini_key'], equals('gemini-key'));
        expect(map['openai_key'], equals('openai-key'));
        expect(map['preferred_provider'], equals('gemini'));
        expect(map.containsKey('claude_key'), isFalse);
      });

      test('should handle all providers', () {
        final config = SpectraConfig(
          geminiKey: 'g-key',
          openaiKey: 'o-key',
          claudeKey: 'c-key',
          grokKey: 'x-key',
          deepseekKey: 'd-key',
        );

        final map = config.toMap();

        expect(map.length, equals(5));
        expect(map['gemini_key'], equals('g-key'));
        expect(map['openai_key'], equals('o-key'));
        expect(map['claude_key'], equals('c-key'));
        expect(map['grok_key'], equals('x-key'));
        expect(map['deepseek_key'], equals('d-key'));
      });

      test('should handle empty config', () {
        final config = SpectraConfig();

        final map = config.toMap();

        expect(map.isEmpty, isTrue);
      });
    });

    group('copyWith', () {
      test('should copy with new values', () {
        final original = SpectraConfig(
          geminiKey: 'original-gemini',
          openaiKey: 'original-openai',
        );

        final updated = original.copyWith(
          geminiKey: 'updated-gemini',
          claudeKey: 'new-claude',
        );

        expect(updated.geminiKey, equals('updated-gemini'));
        expect(updated.openaiKey, equals('original-openai'));
        expect(updated.claudeKey, equals('new-claude'));
      });

      test('should maintain unchanged values', () {
        final original = SpectraConfig(
          geminiKey: 'gemini-key',
          openaiKey: 'openai-key',
          claudeKey: 'claude-key',
        );

        final updated = original.copyWith(geminiKey: 'new-gemini-key');

        expect(updated.geminiKey, equals('new-gemini-key'));
        expect(updated.openaiKey, equals('openai-key'));
        expect(updated.claudeKey, equals('claude-key'));
      });

      test('should handle model updates', () {
        final original = SpectraConfig(
          geminiKey: 'gemini-key',
          geminiModel: 'gemini-3.0-pro',
        );

        final updated = original.copyWith(geminiModel: 'gemini-3.0-flash');

        expect(updated.geminiKey, equals('gemini-key'));
        expect(updated.geminiModel, equals('gemini-3.0-flash'));
      });
    });

    group('Integration scenarios', () {
      test('should handle full lifecycle: create, update, convert', () {
        // Create
        final config = SpectraConfig(geminiKey: 'initial-key');

        // Convert to map
        var map = config.toMap();
        expect(map['gemini_key'], equals('initial-key'));

        // Update
        final updated = config.copyWith(openaiKey: 'added-openai');

        // Convert updated to map
        map = updated.toMap();
        expect(map['gemini_key'], equals('initial-key'));
        expect(map['openai_key'], equals('added-openai'));

        // Recreate from map
        final recreated = SpectraConfig.fromMap(map);
        expect(recreated.geminiKey, equals('initial-key'));
        expect(recreated.openaiKey, equals('added-openai'));
      });

      test('should handle migration scenario', () {
        // Original YAML format
        final yamlData = {
          'gemini_key': 'yaml-gemini',
          'openai_key': 'yaml-openai',
          'preferred_provider': 'gemini',
        };

        // Parse from YAML
        final config = SpectraConfig.fromYaml(yamlData);

        // Convert to secure storage format (map)
        final secureMap = config.toMap();

        // Verify migration
        expect(secureMap['gemini_key'], equals('yaml-gemini'));
        expect(secureMap['openai_key'], equals('yaml-openai'));
        expect(secureMap['preferred_provider'], equals('gemini'));

        // Recreate from secure storage
        final recreated = SpectraConfig.fromMap(secureMap);
        expect(recreated.geminiKey, equals('yaml-gemini'));
        expect(recreated.openaiKey, equals('yaml-openai'));
        expect(recreated.preferredProvider, equals('gemini'));
      });
    });
  });
}
