import 'dart:io';
import 'package:test/test.dart';
import 'package:spectra_cli/services/config_service.dart';
import 'package:spectra_cli/services/secure_storage_service.dart';
import 'package:spectra_cli/models/spectra_config.dart';
import '../test_helpers.dart';

void main() {
  late ConfigService configService;
  late SecureStorageService secureStorage;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('spectra_config_test_');
    useTestHome(tempDir.path);
    configService = ConfigService();
    secureStorage = SecureStorageService();
  });

  tearDown(() async {
    // Cleanup (must run before resetTestHome so it clears the temp home).
    await configService.clearConfig();
    resetTestHome();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ConfigService', () {
    test('should be a singleton', () {
      final instance1 = ConfigService();
      final instance2 = ConfigService();

      expect(instance1, same(instance2));
    });

    test(
      'loadConfig should return empty config when no config exists',
      () async {
        final config = await configService.loadConfig();

        expect(config.geminiKey, isNull);
        expect(config.openaiKey, isNull);
        expect(config.claudeKey, isNull);
      },
    );

    test('saveConfig should store config securely', () async {
      final config = SpectraConfig(
        geminiKey: 'test-gemini-key',
        openaiKey: 'test-openai-key',
        claudeKey: 'test-claude-key',
        preferredProvider: 'gemini',
      );

      await configService.saveConfig(config);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('test-gemini-key'));
      expect(loaded.openaiKey, equals('test-openai-key'));
      expect(loaded.claudeKey, equals('test-claude-key'));
      expect(loaded.preferredProvider, equals('gemini'));
    });

    test('saveConfig should update existing config', () async {
      final firstConfig = SpectraConfig(geminiKey: 'first-key');

      await configService.saveConfig(firstConfig);

      final secondConfig = SpectraConfig(
        geminiKey: 'second-key',
        openaiKey: 'new-openai-key',
      );

      await configService.saveConfig(secondConfig);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('second-key'));
      expect(loaded.openaiKey, equals('new-openai-key'));
    });

    test('clearConfig should remove all configuration', () async {
      final config = SpectraConfig(geminiKey: 'test-key');

      await configService.saveConfig(config);
      expect(configService.hasConfig, isTrue);

      await configService.clearConfig();

      expect(configService.hasConfig, isFalse);
      final loaded = await configService.loadConfig();
      expect(loaded.geminiKey, isNull);
    });

    test('hasConfig should return true when config exists', () async {
      expect(configService.hasConfig, isFalse);

      final config = SpectraConfig(geminiKey: 'test-key');
      await configService.saveConfig(config);

      expect(configService.hasConfig, isTrue);
    });

    test('should migrate from legacy YAML config', () async {
      // Create a legacy YAML config file
      final configDir = Directory('${tempDir.path}/.spectra');
      configDir.createSync(recursive: true);

      final yamlFile = File('${configDir.path}/config.yaml');
      await yamlFile.writeAsString('''
gemini_key: "legacy-gemini-key"
openai_key: "legacy-openai-key"
preferred_provider: "gemini"
''');

      // Load config (should trigger migration)
      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('legacy-gemini-key'));
      expect(loaded.openaiKey, equals('legacy-openai-key'));
      expect(loaded.preferredProvider, equals('gemini'));

      // Legacy file should be deleted
      expect(yamlFile.existsSync(), isFalse);

      // Data should be in secure storage
      expect(secureStorage.hasData, isTrue);
    });

    test('should handle all LLM providers', () async {
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

      await configService.saveConfig(config);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('gemini-key'));
      expect(loaded.geminiModel, equals('gemini-3.0-pro'));
      expect(loaded.openaiKey, equals('openai-key'));
      expect(loaded.openaiModel, equals('gpt-5-turbo'));
      expect(loaded.claudeKey, equals('claude-key'));
      expect(loaded.claudeModel, equals('claude-4.5-sonnet'));
      expect(loaded.grokKey, equals('grok-key'));
      expect(loaded.grokModel, equals('grok-4.1'));
      expect(loaded.deepseekKey, equals('deepseek-key'));
      expect(loaded.deepseekModel, equals('deepseek-v3.2'));
      expect(loaded.preferredProvider, equals('claude'));
    });

    test('should handle partial config updates', () async {
      // Save initial config
      final initialConfig = SpectraConfig(
        geminiKey: 'gemini-key',
        openaiKey: 'openai-key',
      );

      await configService.saveConfig(initialConfig);

      // Update with additional keys
      final updatedConfig = SpectraConfig(
        geminiKey: 'gemini-key',
        openaiKey: 'openai-key',
        claudeKey: 'new-claude-key',
      );

      await configService.saveConfig(updatedConfig);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('gemini-key'));
      expect(loaded.openaiKey, equals('openai-key'));
      expect(loaded.claudeKey, equals('new-claude-key'));
    });

    test('should handle config with only models', () async {
      final config = SpectraConfig(
        geminiModel: 'gemini-3.0-pro',
        openaiModel: 'gpt-5-turbo',
      );

      await configService.saveConfig(config);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiModel, equals('gemini-3.0-pro'));
      expect(loaded.openaiModel, equals('gpt-5-turbo'));
      expect(loaded.geminiKey, isNull);
      expect(loaded.openaiKey, isNull);
    });

    test('should preserve null values correctly', () async {
      final config = SpectraConfig(
        geminiKey: 'gemini-key',
        // All other fields are null
      );

      await configService.saveConfig(config);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('gemini-key'));
      expect(loaded.openaiKey, isNull);
      expect(loaded.claudeKey, isNull);
      expect(loaded.grokKey, isNull);
      expect(loaded.deepseekKey, isNull);
    });
  });
}
