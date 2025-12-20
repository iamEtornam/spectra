import 'dart:io';
import 'package:yaml/yaml.dart';
import '../models/spectra_config.dart';

class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  File get _configFile {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final configDir = Directory('$home/.spectra');
    if (!configDir.existsSync()) {
      configDir.createSync(recursive: true);
    }
    return File('${configDir.path}/config.yaml');
  }

  Future<SpectraConfig> loadConfig() async {
    final file = _configFile;
    if (!file.existsSync()) {
      return SpectraConfig();
    }

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content);
      if (yaml is Map) {
        return SpectraConfig.fromYaml(yaml);
      }
    } catch (e) {
      // Return empty config if loading fails
    }
    return SpectraConfig();
  }

  Future<void> saveConfig(SpectraConfig config) async {
    final file = _configFile;
    final yamlMap = config.toYaml();

    final buffer = StringBuffer();
    yamlMap.forEach((key, value) {
      if (value != null) {
        buffer.writeln('$key: "$value"');
      }
    });

    await file.writeAsString(buffer.toString());
  }
}
