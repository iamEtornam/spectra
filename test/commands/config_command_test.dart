import 'dart:io';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spectra_cli/commands/config_command.dart';
import 'package:spectra_cli/services/config_service.dart';
import 'package:spectra_cli/models/spectra_config.dart';
import '../test_helpers.dart';

void main() {
  late MockLogger mockLogger;
  late ConfigService configService;
  late ConfigCommand configCommand;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('spectra_config_cmd_test_');
    useTestHome(tempDir.path);

    mockLogger = MockLogger();
    configService = ConfigService();
    configCommand = ConfigCommand(logger: mockLogger);

    // Register fallback values
    registerFallbackValue('');
  });

  tearDown(() async {
    // Cleanup (must run before resetTestHome so it clears the temp home).
    await configService.clearConfig();
    resetTestHome();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ConfigCommand Integration Tests', () {
    test('should have correct name and description', () {
      expect(configCommand.name, equals('config'));
      expect(configCommand.description, contains('provider keys'));
    });

    test('should save and load config successfully', () async {
      // Create a test config
      final testConfig = SpectraConfig(
        geminiKey: 'test-gemini-key',
        openaiKey: 'test-openai-key',
        claudeKey: 'test-claude-key',
        preferredProvider: 'gemini',
      );

      // Save config
      await configService.saveConfig(testConfig);

      // Load and verify
      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('test-gemini-key'));
      expect(loaded.openaiKey, equals('test-openai-key'));
      expect(loaded.claudeKey, equals('test-claude-key'));
      expect(loaded.preferredProvider, equals('gemini'));
    });

    test('should handle missing keys gracefully', () async {
      final testConfig = SpectraConfig(geminiKey: 'only-gemini-key');

      await configService.saveConfig(testConfig);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('only-gemini-key'));
      expect(loaded.openaiKey, isNull);
      expect(loaded.claudeKey, isNull);
    });

    test('should update existing config', () async {
      // Save initial config
      final initialConfig = SpectraConfig(geminiKey: 'initial-key');
      await configService.saveConfig(initialConfig);

      // Update config
      final updatedConfig = SpectraConfig(
        geminiKey: 'updated-key',
        openaiKey: 'new-openai-key',
      );
      await configService.saveConfig(updatedConfig);

      // Verify update
      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('updated-key'));
      expect(loaded.openaiKey, equals('new-openai-key'));
    });

    test('should handle all provider keys', () async {
      final fullConfig = SpectraConfig(
        geminiKey: 'gemini-test-key',
        openaiKey: 'openai-test-key',
        claudeKey: 'claude-test-key',
        grokKey: 'grok-test-key',
        deepseekKey: 'deepseek-test-key',
        preferredProvider: 'claude',
      );

      await configService.saveConfig(fullConfig);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiKey, equals('gemini-test-key'));
      expect(loaded.openaiKey, equals('openai-test-key'));
      expect(loaded.claudeKey, equals('claude-test-key'));
      expect(loaded.grokKey, equals('grok-test-key'));
      expect(loaded.deepseekKey, equals('deepseek-test-key'));
      expect(loaded.preferredProvider, equals('claude'));
    });

    test('should clear config completely', () async {
      // Save config
      final config = SpectraConfig(geminiKey: 'test-key');
      await configService.saveConfig(config);

      expect(configService.hasConfig, isTrue);

      // Clear config
      await configService.clearConfig();

      expect(configService.hasConfig, isFalse);

      // Verify empty config
      final loaded = await configService.loadConfig();
      expect(loaded.geminiKey, isNull);
    });

    test('should handle model preferences', () async {
      final config = SpectraConfig(
        geminiKey: 'gemini-key',
        geminiModel: 'gemini-3.0-flash',
        openaiKey: 'openai-key',
        openaiModel: 'gpt-5-mini',
      );

      await configService.saveConfig(config);

      final loaded = await configService.loadConfig();

      expect(loaded.geminiModel, equals('gemini-3.0-flash'));
      expect(loaded.openaiModel, equals('gpt-5-mini'));
    });

    test('should persist config across service instances', () async {
      // Save with first instance
      final config = SpectraConfig(geminiKey: 'persistent-key');
      await configService.saveConfig(config);

      // Create new service instance and load
      final newService = ConfigService();
      final loaded = await newService.loadConfig();

      expect(loaded.geminiKey, equals('persistent-key'));
    });
  });
}
