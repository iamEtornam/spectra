import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/spectra_config.dart';
import 'secure_storage_service.dart';

/// Service for managing Spectra configuration.
///
/// Uses encrypted storage for API keys and preferences.
/// Automatically migrates from legacy YAML format if detected.
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  final _secureStorage = SecureStorageService();

  File get _configFile {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final configDir = Directory('$home/.spectra');
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }
    return File('${configDir.path}/config.yaml');
  }

  File get _legacyConfigFile => _configFile;

  /// Loads configuration from secure storage.
  ///
  /// Automatically migrates from legacy YAML format if found.
  Future<SpectraConfig> loadConfig() async {
    // Check if secure storage has data
    if (_secureStorage.hasData) {
      final secureData = await _secureStorage.retrieve();
      return SpectraConfig.fromMap(secureData);
    }

    // Try to load from legacy YAML file
    final file = _legacyConfigFile;
    if (file.existsSync()) {
      try {
        final content = await file.readAsString();
        final yaml = loadYaml(content);
        if (yaml is Map) {
          final config = SpectraConfig.fromYaml(yaml);

          // Migrate to secure storage
          await _migrateToSecureStorage(config);

          // Delete legacy file
          await file.delete();

          return config;
        }
      } catch (e) {
        // If loading fails, return empty config
      }
    }

    return SpectraConfig();
  }

  /// Saves configuration to secure storage.
  Future<void> saveConfig(SpectraConfig config) async {
    final configMap = config.toMap();
    await _secureStorage.store(configMap);
  }

  /// Migrates configuration from YAML to secure storage.
  Future<void> _migrateToSecureStorage(SpectraConfig config) async {
    final configMap = config.toMap();
    await _secureStorage.store(configMap);
  }

  /// Clears all configuration data.
  Future<void> clearConfig() async {
    await _secureStorage.clear();
    if (_legacyConfigFile.existsSync()) {
      await _legacyConfigFile.delete();
    }
  }

  /// Checks if configuration exists.
  bool get hasConfig =>
      _secureStorage.hasData || _legacyConfigFile.existsSync();
}
