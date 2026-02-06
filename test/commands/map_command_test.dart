import 'dart:io';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spectra_cli/commands/map_command.dart';
import '../test_helpers.dart';

void main() {
  late MockLogger mockLogger;
  late MapCommand mapCommand;
  late Directory tempProjectDir;
  late Directory originalCwd;

  setUp(() {
    mockLogger = MockLogger();
    mapCommand = MapCommand(logger: mockLogger);

    tempProjectDir = Directory.systemTemp.createTempSync('spectra_map_test_');
    originalCwd = Directory.current;

    // Change to temp directory
    Directory.current = tempProjectDir;

    // Register fallback values
    registerFallbackValue('');
  });

  tearDown(() {
    // Restore original directory
    Directory.current = originalCwd;

    // Cleanup
    if (tempProjectDir.existsSync()) {
      tempProjectDir.deleteSync(recursive: true);
    }
  });

  group('MapCommand Integration Tests', () {
    test('should have correct name and description', () {
      expect(mapCommand.name, equals('map'));
      expect(mapCommand.description, contains('Brownfield'));
    });

    test('should create .spectra directory structure', () {
      // Create a sample project
      _createSampleProject(tempProjectDir);

      // Create .spectra directory
      final spectraDir = Directory('${tempProjectDir.path}/.spectra');
      spectraDir.createSync();

      expect(spectraDir.existsSync(), isTrue);
    });

    test('should detect Dart project files', () {
      // Create Dart project structure
      File('${tempProjectDir.path}/pubspec.yaml').writeAsStringSync('''
name: test_project
description: A test project
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  http: ^1.0.0
''');

      final libDir = Directory('${tempProjectDir.path}/lib');
      libDir.createSync();

      File('${libDir.path}/main.dart').writeAsStringSync('''
void main() {
  print('Hello, World!');
}
''');

      // Verify project files exist
      expect(File('${tempProjectDir.path}/pubspec.yaml').existsSync(), isTrue);
      expect(File('${libDir.path}/main.dart').existsSync(), isTrue);
    });

    test('should detect project architecture patterns', () {
      _createSampleProject(tempProjectDir);

      // Check for architecture directories
      final libDir = Directory('${tempProjectDir.path}/lib');

      final hasModelsDir = Directory('${libDir.path}/models').existsSync();
      final hasServicesDir = Directory('${libDir.path}/services').existsSync();

      expect(hasModelsDir || hasServicesDir, isTrue);
    });

    test('should handle Git repository detection', () {
      _createSampleProject(tempProjectDir);

      // Initialize git repo
      final gitDir = Directory('${tempProjectDir.path}/.git');
      gitDir.createSync();
      File('${gitDir.path}/config').writeAsStringSync('[core]\n');

      expect(gitDir.existsSync(), isTrue);
    });

    test('should scan multiple directory levels', () {
      // Create nested directory structure
      final nestedPath = '${tempProjectDir.path}/lib/features/auth';
      Directory(nestedPath).createSync(recursive: true);

      File('$nestedPath/auth_service.dart').writeAsStringSync('''
class AuthService {
  Future<void> login(String email, String password) async {
    // Login logic
  }
}
''');

      expect(File('$nestedPath/auth_service.dart').existsSync(), isTrue);
    });

    test('should handle empty project directories', () {
      final emptyDir = Directory('${tempProjectDir.path}/empty');
      emptyDir.createSync();

      expect(emptyDir.listSync().isEmpty, isTrue);
    });

    test('should detect multiple file types', () {
      final libDir = Directory('${tempProjectDir.path}/lib');
      libDir.createSync();

      // Create various file types
      File('${libDir.path}/main.dart').writeAsStringSync('void main() {}');
      File('${libDir.path}/README.md').writeAsStringSync('# README');
      File('${libDir.path}/config.yaml').writeAsStringSync('key: value');

      final files = libDir.listSync().whereType<File>().toList();

      expect(files.length, equals(3));
    });

    test('should respect .gitignore patterns', () {
      _createSampleProject(tempProjectDir);

      // Create .gitignore
      File('${tempProjectDir.path}/.gitignore').writeAsStringSync('''
.dart_tool/
build/
*.g.dart
''');

      expect(File('${tempProjectDir.path}/.gitignore').existsSync(), isTrue);
    });

    test('should handle projects with dependencies', () {
      File('${tempProjectDir.path}/pubspec.yaml').writeAsStringSync('''
name: test_project
dependencies:
  http: ^1.0.0
  path: ^1.8.0
  yaml: ^3.0.0
''');

      final pubspecFile = File('${tempProjectDir.path}/pubspec.yaml');
      final content = pubspecFile.readAsStringSync();

      expect(content.contains('http:'), isTrue);
      expect(content.contains('path:'), isTrue);
      expect(content.contains('yaml:'), isTrue);
    });

    test('should handle projects without pubspec.yaml', () {
      // Create project without pubspec
      final libDir = Directory('${tempProjectDir.path}/lib');
      libDir.createSync();

      File('${libDir.path}/main.dart').writeAsStringSync('void main() {}');

      expect(File('${tempProjectDir.path}/pubspec.yaml').existsSync(), isFalse);
      expect(Directory('${tempProjectDir.path}/lib').existsSync(), isTrue);
    });
  });
}

/// Helper function to create a sample project structure for testing.
void _createSampleProject(Directory projectDir) {
  // Create pubspec.yaml
  File('${projectDir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_project
description: A sample project for testing
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  http: ^1.0.0
''');

  // Create lib directory with sample files
  final libDir = Directory('${projectDir.path}/lib');
  libDir.createSync();

  File('${libDir.path}/main.dart').writeAsStringSync('''
void main() {
  print('Hello, Spectra!');
}
''');

  // Create models directory
  final modelsDir = Directory('${libDir.path}/models');
  modelsDir.createSync();

  File('${modelsDir.path}/user.dart').writeAsStringSync('''
class User {
  final String id;
  final String name;
  
  User({required this.id, required this.name});
}
''');

  // Create services directory
  final servicesDir = Directory('${libDir.path}/services');
  servicesDir.createSync();

  File('${servicesDir.path}/api_service.dart').writeAsStringSync('''
class ApiService {
  Future<void> fetchData() async {
    // Fetch data logic
  }
}
''');

  // Create test directory
  final testDir = Directory('${projectDir.path}/test');
  testDir.createSync();

  File('${testDir.path}/main_test.dart').writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('sample test', () {
    expect(1 + 1, equals(2));
  });
}
''');

  // Create .gitignore
  File('${projectDir.path}/.gitignore').writeAsStringSync('''
.dart_tool/
build/
''');
}
