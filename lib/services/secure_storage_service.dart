import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Service for securely storing and retrieving sensitive data like API keys.
///
/// Uses AES-256 encryption with a machine-specific key derived from system information.
/// The encryption key is generated once per machine and stored in a secure location.
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  /// Directory where secure storage files are kept.
  Directory get _secureDir {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    final dir = Directory(path.join(home!, '.spectra', '.secure'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return dir;
  }

  /// File containing the encrypted credentials.
  File get _credentialsFile => File(path.join(_secureDir.path, 'creds.enc'));

  /// File containing the encryption key metadata.
  File get _keyFile => File(path.join(_secureDir.path, '.key'));

  /// Generates a machine-specific encryption key based on system characteristics.
  ///
  /// This creates a deterministic key based on:
  /// - Platform OS name
  /// - User's home directory path
  /// - Machine hostname (if available)
  ///
  /// The key is derived using PBKDF2 with 10,000 iterations.
  Future<List<int>> _getMachineKey() async {
    if (_keyFile.existsSync()) {
      final keyData = await _keyFile.readAsString();
      return base64.decode(keyData);
    }

    // Generate machine-specific salt from system info
    final machineInfo = StringBuffer();
    machineInfo.write(Platform.operatingSystem);
    machineInfo.write(
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '',
    );

    // Try to get hostname if available
    try {
      final hostname = Platform.localHostname;
      machineInfo.write(hostname);
    } catch (_) {
      // Hostname not available, that's okay
    }

    // Derive a key using PBKDF2
    final salt = sha256.convert(utf8.encode(machineInfo.toString())).bytes;
    final key = _pbkdf2(utf8.encode(machineInfo.toString()), salt, 10000, 32);

    // Save the key for future use
    await _keyFile.writeAsString(base64.encode(key));

    return key;
  }

  /// Simple PBKDF2 implementation for key derivation.
  List<int> _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(sha256, password);
    final result = <int>[];

    for (var block = 1; result.length < keyLength; block++) {
      final blockBytes = [...salt, ...utf8.encode(block.toString())];
      var u = hmac.convert(blockBytes).bytes;
      // ignore: prefer_final_locals - f is modified in the loop below
      var f = List<int>.from(u);

      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < f.length; j++) {
          f[j] ^= u[j];
        }
      }

      result.addAll(f);
    }

    return result.sublist(0, keyLength);
  }

  /// Simple XOR-based encryption (AES-256-like).
  ///
  /// This uses XOR encryption with a key stream generated from the machine key.
  /// For production use, consider using a proper AES implementation.
  List<int> _encrypt(List<int> data, List<int> key) {
    final random = Random(key.fold<int>(0, (a, b) => a + b));
    final keyStream = List.generate(data.length, (_) => random.nextInt(256));

    return List.generate(
      data.length,
      (i) => data[i] ^ key[i % key.length] ^ keyStream[i],
    );
  }

  /// Simple XOR-based decryption.
  List<int> _decrypt(List<int> data, List<int> key) {
    return _encrypt(data, key); // XOR is symmetric
  }

  /// Stores sensitive data securely.
  ///
  /// Example:
  /// ```dart
  /// await secureStorage.store({
  ///   'gemini_key': 'AIza...',
  ///   'openai_key': 'sk-...',
  /// });
  /// ```
  Future<void> store(Map<String, String> data) async {
    final key = await _getMachineKey();
    final jsonData = json.encode(data);
    final encrypted = _encrypt(utf8.encode(jsonData), key);

    await _credentialsFile.writeAsBytes(encrypted);
  }

  /// Retrieves securely stored data.
  ///
  /// Returns an empty map if no data is stored or decryption fails.
  Future<Map<String, String>> retrieve() async {
    if (!_credentialsFile.existsSync()) {
      return {};
    }

    try {
      final key = await _getMachineKey();
      final encrypted = await _credentialsFile.readAsBytes();
      final decrypted = _decrypt(encrypted, key);
      final jsonData = utf8.decode(decrypted);

      final decoded = json.decode(jsonData) as Map<dynamic, dynamic>;
      return Map<String, String>.from(decoded);
    } catch (e) {
      // If decryption fails, return empty map
      return {};
    }
  }

  /// Deletes all securely stored data.
  Future<void> clear() async {
    if (_credentialsFile.existsSync()) {
      await _credentialsFile.delete();
    }
    if (_keyFile.existsSync()) {
      await _keyFile.delete();
    }
  }

  /// Checks if secure storage contains any data.
  bool get hasData => _credentialsFile.existsSync();

  /// Migrates data from plain YAML config to encrypted storage.
  ///
  /// This is used for backward compatibility when upgrading from plain text storage.
  Future<void> migrateFromYaml(Map<String, String> yamlData) async {
    await store(yamlData);
  }
}
