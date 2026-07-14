import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Service for securely storing and retrieving sensitive data like API keys.
///
/// Uses an XOR stream cipher with a SHA-256-derived keystream and a
/// machine-specific key derived from system information via PBKDF2.
/// The encryption key is generated once per machine and stored in a secure location.
class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  /// Overrides the base directory used for storage (normally `$HOME`).
  /// Intended for tests so they don't touch the real `~/.spectra`.
  static String? homeOverride;

  /// Directory where secure storage files are kept.
  Directory get _secureDir {
    final home =
        homeOverride ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'];
    if (home == null) {
      throw StateError(
        'Unable to determine home directory. Neither HOME nor USERPROFILE environment variables are set.',
      );
    }
    final dir = Directory(path.join(home, '.spectra', '.secure'));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      _restrictPermissions(dir.path, '700');
    }
    return dir;
  }

  /// Best-effort permission tightening on POSIX systems (no-op on Windows,
  /// where ACLs already scope the profile directory to the user).
  void _restrictPermissions(String targetPath, String mode) {
    if (Platform.isWindows) return;
    try {
      Process.runSync('chmod', [mode, targetPath]);
    } catch (_) {
      // chmod unavailable; the OS default umask still applies.
    }
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
    _restrictPermissions(_keyFile.path, '600');

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

  /// XOR stream cipher with a SHA-256-derived keystream and random IV.
  ///
  /// The keystream is produced in counter mode: block N is
  /// `SHA-256(key || IV || N)`, so the full 256-bit machine key feeds every
  /// keystream byte and the random IV makes encryption non-deterministic.
  /// The IV is prepended to the ciphertext.
  ///
  /// Format: [IV (16 bytes)][Encrypted Data]
  List<int> _encrypt(List<int> data, List<int> key) {
    // Generate random IV (16 bytes)
    final random = Random.secure();
    final iv = List.generate(16, (_) => random.nextInt(256));

    final keyStream = _keyStream(key, iv, data.length);
    final encrypted = List.generate(data.length, (i) => data[i] ^ keyStream[i]);

    // Prepend IV to ciphertext
    return [...iv, ...encrypted];
  }

  /// Decrypts data produced by [_encrypt].
  ///
  /// Extracts the IV from the first 16 bytes, then decrypts the remaining data.
  List<int> _decrypt(List<int> data, List<int> key) {
    if (data.length < 16) {
      throw ArgumentError('Invalid encrypted data: too short');
    }

    final iv = data.sublist(0, 16);
    final encrypted = data.sublist(16);

    final keyStream = _keyStream(key, iv, encrypted.length);
    return List.generate(encrypted.length, (i) => encrypted[i] ^ keyStream[i]);
  }

  /// SHA-256 counter-mode keystream: block N is SHA-256(key || iv || N).
  List<int> _keyStream(List<int> key, List<int> iv, int length) {
    final stream = <int>[];
    for (var counter = 0; stream.length < length; counter++) {
      final block = sha256.convert([
        ...key,
        ...iv,
        ...utf8.encode(counter.toString()),
      ]).bytes;
      stream.addAll(block);
    }
    return stream.sublist(0, length);
  }

  /// Decrypts data written by versions <= 0.2.0, whose keystream came from
  /// Dart's `Random` seeded with the byte-sum of key and IV.
  List<int> _decryptLegacy(List<int> data, List<int> key) {
    if (data.length < 16) {
      throw ArgumentError('Invalid encrypted data: too short');
    }

    final iv = data.sublist(0, 16);
    final encrypted = data.sublist(16);

    final keySeed =
        key.fold<int>(0, (a, b) => a + b) + iv.fold<int>(0, (a, b) => a + b);
    final streamRandom = Random(keySeed);
    final keyStream = List.generate(
      encrypted.length,
      (_) => streamRandom.nextInt(256),
    );

    return List.generate(
      encrypted.length,
      (i) => encrypted[i] ^ key[i % key.length] ^ keyStream[i],
    );
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
    _restrictPermissions(_credentialsFile.path, '600');
  }

  /// Retrieves securely stored data.
  ///
  /// Falls back to the pre-0.2.1 cipher for existing files and transparently
  /// re-encrypts them with the current scheme.
  /// Returns an empty map if no data is stored or decryption fails.
  Future<Map<String, String>> retrieve() async {
    if (!_credentialsFile.existsSync()) {
      return {};
    }

    final key = await _getMachineKey();
    final encrypted = await _credentialsFile.readAsBytes();

    final current = _tryDecode(() => _decrypt(encrypted, key));
    if (current != null) return current;

    final legacy = _tryDecode(() => _decryptLegacy(encrypted, key));
    if (legacy != null) {
      // Upgrade the on-disk format to the current cipher.
      await store(legacy);
      return legacy;
    }

    return {};
  }

  /// Runs [decrypt] and decodes the result as a JSON string map.
  /// Returns null when decryption yields garbage (wrong cipher/key).
  Map<String, String>? _tryDecode(List<int> Function() decrypt) {
    try {
      final decoded =
          json.decode(utf8.decode(decrypt())) as Map<dynamic, dynamic>;
      return Map<String, String>.from(decoded);
    } catch (_) {
      return null;
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
