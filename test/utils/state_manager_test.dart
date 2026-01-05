import 'dart:io';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spectra_cli/utils/state_manager.dart';
import '../test_helpers.dart';

void main() {
  late MockLogger mockLogger;
  late StateManager stateManager;
  late Directory tempDir;

  setUp(() {
    mockLogger = MockLogger();
    stateManager = StateManager(logger: mockLogger);
    tempDir = Directory.systemTemp.createTempSync('spectra_test_');

    // Create .spectra directory in temp
    Directory('${tempDir.path}/.spectra').createSync();

    // Change to temp directory for tests
    Directory.current = tempDir;

    // Register fallback values
    registerFallbackValue('');
  });

  tearDown(() {
    // Cleanup
    Directory.current = Directory.systemTemp;
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StateManager', () {
    test('pruneState should do nothing if STATE.md does not exist', () {
      stateManager.pruneState();

      verifyNever(() => mockLogger.info(any()));
    });

    test('pruneState should do nothing if STATE.md has less than 200 lines',
        () {
      final stateFile = File('${tempDir.path}/.spectra/STATE.md');
      final lines = List.generate(100, (i) => 'Line $i');
      stateFile.writeAsStringSync(lines.join('\n'));

      stateManager.pruneState();

      verifyNever(() => mockLogger.info(any()));
    });

    test('pruneState should prune STATE.md if it exceeds 200 lines', () {
      final stateFile = File('${tempDir.path}/.spectra/STATE.md');
      final lines = List.generate(250, (i) => 'Line $i');
      stateFile.writeAsStringSync(lines.join('\n'));

      when(() => mockLogger.info(any())).thenReturn(null);
      when(() => mockLogger.success(any())).thenReturn(null);

      stateManager.pruneState();

      verify(() => mockLogger.info(any())).called(1);
      verify(() => mockLogger.success(any())).called(1);

      // Check that file was pruned
      final prunedContent = stateFile.readAsStringSync();
      expect(prunedContent, contains('# STATE (Pruned)'));
    });

    test('pruneState should archive old state to history', () {
      final stateFile = File('${tempDir.path}/.spectra/STATE.md');
      final lines = List.generate(250, (i) => 'Line $i');
      stateFile.writeAsStringSync(lines.join('\n'));

      when(() => mockLogger.info(any())).thenReturn(null);
      when(() => mockLogger.success(any())).thenReturn(null);

      stateManager.pruneState();

      // Check history directory was created
      final historyDir = Directory('${tempDir.path}/.spectra/history');
      expect(historyDir.existsSync(), isTrue);

      // Check archive file exists
      final archiveFiles = historyDir.listSync();
      expect(archiveFiles.length, equals(1));
    });
  });
}
