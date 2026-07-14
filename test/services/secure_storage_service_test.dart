import 'dart:io';
import 'package:test/test.dart';
import 'package:spectra_cli/services/secure_storage_service.dart';
import '../test_helpers.dart';

void main() {
  late SecureStorageService secureStorage;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('spectra_secure_test_');
    useTestHome(tempDir.path);
    secureStorage = SecureStorageService();
  });

  tearDown(() async {
    // Cleanup (must run before resetTestHome so it clears the temp home).
    await secureStorage.clear();
    resetTestHome();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('SecureStorageService', () {
    test('should be a singleton', () {
      final instance1 = SecureStorageService();
      final instance2 = SecureStorageService();

      expect(instance1, same(instance2));
    });

    test('should store and retrieve data', () async {
      final testData = {
        'gemini_key': 'test-gemini-key',
        'openai_key': 'test-openai-key',
        'claude_key': 'test-claude-key',
      };

      await secureStorage.store(testData);

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, equals(testData));
    });

    test('should return empty map if no data exists', () async {
      final retrieved = await secureStorage.retrieve();

      expect(retrieved, isEmpty);
    });

    test('should overwrite existing data', () async {
      final firstData = {'gemini_key': 'first-key'};

      await secureStorage.store(firstData);

      final secondData = {
        'gemini_key': 'second-key',
        'openai_key': 'new-openai-key',
      };

      await secureStorage.store(secondData);

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, equals(secondData));
      expect(retrieved['gemini_key'], equals('second-key'));
    });

    test('should clear all data', () async {
      final testData = {'gemini_key': 'test-key'};

      await secureStorage.store(testData);
      expect(secureStorage.hasData, isTrue);

      await secureStorage.clear();

      expect(secureStorage.hasData, isFalse);
      final retrieved = await secureStorage.retrieve();
      expect(retrieved, isEmpty);
    });

    test('hasData should return true when data exists', () async {
      expect(secureStorage.hasData, isFalse);

      await secureStorage.store({'key': 'value'});

      expect(secureStorage.hasData, isTrue);
    });

    test('should handle empty data storage', () async {
      await secureStorage.store({});

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, isEmpty);
    });

    test('should handle special characters in values', () async {
      final testData = {
        'key1': 'value with spaces',
        'key2': 'value_with-special!@#\$%^&*()chars',
        'key3': 'value\nwith\nnewlines',
      };

      await secureStorage.store(testData);

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, equals(testData));
    });

    test('should handle unicode characters', () async {
      final testData = {'unicode_key': '你好世界 🌍 مرحبا العالم'};

      await secureStorage.store(testData);

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, equals(testData));
    });

    test('should handle large data sets', () async {
      final largeData = <String, String>{};
      for (var i = 0; i < 100; i++) {
        largeData['key_$i'] = 'value_$i' * 10;
      }

      await secureStorage.store(largeData);

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, equals(largeData));
      expect(retrieved.length, equals(100));
    });

    test('migrateFromYaml should store yaml data securely', () async {
      final yamlData = {
        'gemini_key': 'yaml-gemini-key',
        'openai_key': 'yaml-openai-key',
      };

      await secureStorage.migrateFromYaml(yamlData);

      final retrieved = await secureStorage.retrieve();

      expect(retrieved, equals(yamlData));
    });

    test(
      'should maintain data consistency across multiple operations',
      () async {
        // Store data
        await secureStorage.store({'key1': 'value1'});

        // Retrieve and verify
        var retrieved = await secureStorage.retrieve();
        expect(retrieved['key1'], equals('value1'));

        // Update with new key
        await secureStorage.store({'key1': 'value1', 'key2': 'value2'});

        // Retrieve and verify both keys
        retrieved = await secureStorage.retrieve();
        expect(retrieved['key1'], equals('value1'));
        expect(retrieved['key2'], equals('value2'));

        // Update existing key
        await secureStorage.store({'key1': 'updated_value1', 'key2': 'value2'});

        // Retrieve and verify update
        retrieved = await secureStorage.retrieve();
        expect(retrieved['key1'], equals('updated_value1'));
        expect(retrieved['key2'], equals('value2'));
      },
    );
  });
}
