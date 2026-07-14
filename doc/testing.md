# Testing Guide

Spectra includes comprehensive test coverage across unit tests, integration tests, and end-to-end workflow tests.

## Test Structure

```
test/
├── agents/                      # Agent behavior tests
│   └── worker_agent_test.dart
├── commands/                    # Command integration tests
│   ├── config_command_test.dart
│   ├── execute_command_test.dart
│   ├── map_command_test.dart
│   └── plan_command_test.dart
├── e2e/                        # End-to-end workflow tests
│   └── workflow_test.dart
├── features/                   # Symphony-aligned feature tests
│   ├── observability/
│   │   └── runtime_snapshot_test.dart
│   ├── orchestration/
│   │   └── scheduler_test.dart
│   ├── runner/
│   │   ├── llm_agent_runner_test.dart
│   │   └── prompt_renderer_test.dart
│   ├── tracker/
│   │   ├── issue_test.dart
│   │   ├── linear_real_integration_test.dart
│   │   ├── linear_tracker_client_test.dart
│   │   ├── local_plan_tracker_client_test.dart
│   │   └── tracker_factory_test.dart
│   ├── workflow/
│   │   ├── workflow_config_test.dart
│   │   ├── workflow_loader_test.dart
│   │   └── workflow_watcher_test.dart
│   └── workspaces/
│       ├── workspace_hooks_test.dart
│       └── workspace_manager_test.dart
├── models/                     # Model and data structure tests
│   ├── agent_test.dart
│   ├── execution_mode_test.dart
│   ├── llm_usage_type_test.dart
│   ├── spectra_config_test.dart
│   └── task_test.dart
├── services/                   # Service layer tests
│   ├── additional_bugfix_test.dart
│   ├── config_service_test.dart
│   ├── llm_service_test.dart
│   ├── orchestrator_service_test.dart
│   ├── secure_storage_service_test.dart
│   └── security_bugfix_test.dart
├── utils/                      # Utility function tests
│   └── state_manager_test.dart
└── test_helpers.dart          # Shared test utilities and mocks
```

## Running Tests

### Run All Tests

```bash
dart test
```

### Run Specific Test File

```bash
dart test test/services/secure_storage_service_test.dart
```

### Run Tests with Coverage

```bash
dart test --coverage=coverage
dart pub global activate coverage
format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```

### Run Tests in Watch Mode

```bash
dart test --watch
```

## Test Categories

### Unit Tests

Test individual components in isolation:

- **Models**: Data structures, serialization, validation
- **Services**: Business logic, data access, encryption
- **Utilities**: Helper functions, transformations

**Example:**

```dart
test('should encrypt and decrypt data correctly', () async {
  final secureStorage = SecureStorageService();
  
  final testData = {'key': 'sensitive-value'};
  await secureStorage.store(testData);
  
  final retrieved = await secureStorage.retrieve();
  expect(retrieved, equals(testData));
});
```

### Integration Tests

Test how components work together:

- **Commands**: Command execution with real services
- **Workflows**: Multi-step operations
- **File System**: Reading/writing .spectra files

**Example:**

```dart
test('should save and load config successfully', () async {
  final configService = ConfigService();
  
  final config = SpectraConfig(
    geminiKey: 'test-key',
    preferredProvider: 'gemini',
  );
  
  await configService.saveConfig(config);
  final loaded = await configService.loadConfig();
  
  expect(loaded.geminiKey, equals('test-key'));
});
```

### End-to-End Tests

Test complete user workflows from start to finish:

- **New Project Workflow**: Config → Init → Plan → Execute
- **Existing Project Workflow**: Config → Map → Plan → Execute
- **Multi-Agent Orchestration**: Task distribution and coordination

**Example:**

```dart
test('complete greenfield project setup workflow', () async {
  // Step 1: Configure API keys
  final config = SpectraConfig(geminiKey: 'test-key');
  await configService.saveConfig(config);
  
  // Step 2: Initialize project
  _createSpectraProjectStructure(projectDir);
  
  // Step 3: Create PROJECT.md
  final projectFile = File('${projectDir}/.spectra/PROJECT.md');
  projectFile.writeAsStringSync('# Project...');
  
  // Verify complete workflow
  expect(configService.hasConfig, isTrue);
  expect(projectFile.existsSync(), isTrue);
});
```

## Test Helpers and Mocks

### Available Mocks

```dart
// Logger mock for testing output
class MockLogger extends Mock implements Logger {}

// LLM provider mock for testing AI interactions
class MockLLMProvider extends Mock implements LLMProvider {}

// Service mocks
class MockLLMService extends Mock implements LLMService {}
class MockConfigService extends Mock implements ConfigService {}

// Fake LLM provider with predictable responses
class FakeLLMProvider implements LLMProvider {
  final String _name;
  final String _response;

  FakeLLMProvider({
    String name = 'FakeProvider',
    String response = 'Fake response',
  }) : _name = name,
       _response = response;

  @override
  String get name => _name;

  @override
  String get model => 'fake-model-1';

  @override
  Future<String> generateResponse(
    String prompt, {
    List<String>? context,
  }) async => _response;
}
```

### Test Utilities

```dart
// Create test configuration
final config = createTestConfig(
  geminiKey: 'test-key',
  preferredProvider: 'gemini',
);

// Register fallback values for mocktail
registerFallbackValue('');
```

Tests call `useTestHome(dir)` in `setUp` (and `resetTestHome()` in `tearDown`) to point every home-directory-based service at an isolated temp directory, so the suite never touches your real `~/.spectra`.

Suites run one at a time (`dart_test.yaml` sets `concurrency: 1`): several command and e2e suites change the process-global working directory, which races when suite isolates run in parallel.

## Test Coverage Targets

| Category | Target |
|----------|--------|
| Models | 90%+ |
| Services | 85%+ |
| Commands | 75%+ |
| Agents | 80%+ |
| Overall | 80%+ |

Actual coverage is reported per run via Codecov (see Continuous Integration below).

## Testing Best Practices

### 1. Test Isolation

Each test should be independent:

```dart
setUp(() {
  // Create fresh instances for each test
  configService = ConfigService();
  tempDir = Directory.systemTemp.createTempSync();
});

tearDown(() {
  // Clean up after each test
  tempDir.deleteSync(recursive: true);
});
```

### 2. Use Descriptive Test Names

```dart
// Good
test('should migrate from YAML to encrypted storage', () {});

// Bad
test('test migration', () {});
```

### 3. Arrange-Act-Assert Pattern

```dart
test('should store and retrieve data', () async {
  // Arrange
  final storage = SecureStorageService();
  final testData = {'key': 'value'};
  
  // Act
  await storage.store(testData);
  final retrieved = await storage.retrieve();
  
  // Assert
  expect(retrieved, equals(testData));
});
```

### 4. Test Edge Cases

```dart
test('should handle empty data storage', () async {
  await secureStorage.store({});
  final retrieved = await secureStorage.retrieve();
  expect(retrieved, isEmpty);
});

test('should handle unicode characters', () async {
  final testData = {'key': '你好世界 🌍'};
  await secureStorage.store(testData);
  final retrieved = await secureStorage.retrieve();
  expect(retrieved, equals(testData));
});
```

### 5. Mock External Dependencies

```dart
test('worker agent should process task', () async {
  final mockProvider = FakeLLMProvider(
    response: '<file_content>...</file_content>',
  );
  
  final worker = WorkerAgent(
    id: 'Worker-1',
    provider: mockProvider,
    logger: mockLogger,
  );
  
  // Test worker behavior
});
```

## Security Testing

### Encrypted Storage Tests

Verify that sensitive data is properly encrypted:

```dart
test('should encrypt API keys', () async {
  final storage = SecureStorageService();
  final apiKeys = {'gemini_key': 'AIza...'};
  
  await storage.store(apiKeys);
  
  // Read raw encrypted file
  final encryptedFile = File('~/.spectra/.secure/creds.enc');
  final encryptedData = await encryptedFile.readAsString();
  
  // Verify data is not plain text
  expect(encryptedData.contains('AIza'), isFalse);
});
```

### Migration Tests

Test automatic migration from legacy formats:

```dart
test('should migrate from YAML to encrypted storage', () async {
  // Create legacy YAML config
  final yamlFile = File('~/.spectra/config.yaml');
  await yamlFile.writeAsString('gemini_key: "legacy-key"');
  
  // Load config (triggers migration)
  final config = await configService.loadConfig();
  
  // Verify migration
  expect(config.geminiKey, equals('legacy-key'));
  expect(yamlFile.existsSync(), isFalse); // Legacy file deleted
});
```

## Performance Testing

For performance-critical paths:

```dart
test('should load config in under 100ms', () async {
  final stopwatch = Stopwatch()..start();
  
  await configService.loadConfig();
  
  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(100));
});
```

## Continuous Integration

### GitHub Actions Workflow

CI (`.github/workflows/test.yml`) runs on pushes and pull requests to `main` and `develop`, in two jobs:

**Test job:**

- `actions/checkout@v4` + `dart-lang/setup-dart@v1` (stable SDK), then `dart pub get`
- `dart format --output=none --set-exit-if-changed .` (formatting check)
- `dart analyze --fatal-infos`
- Test suites run **per-suite** (models, services, agents, utils, commands, e2e, features) rather than as one `dart test` invocation — several suites share `ConfigService`/`SecureStorageService` singletons, and running them in one VM causes state-bleed races that don't occur in production
- Coverage is generated per suite the same way, merged with `format_coverage` into `coverage/lcov.info`, and uploaded to Codecov

**Security-audit job:**

- `dart pub outdated` (non-failing) to surface stale dependencies
- A regex scan of `lib/` for real-looking API key shapes (OpenAI `sk-...` and Google `AIza...` patterns), failing the build if any are found

## Contributing Tests

When contributing to Spectra:

1. **Write tests for new features** - All new code should have test coverage
2. **Update existing tests** - When modifying behavior, update relevant tests
3. **Run tests locally** - Ensure all tests pass before submitting PR
4. **Check coverage** - Aim to maintain or improve overall coverage

### Test Checklist

- [ ] Unit tests for new functions/classes
- [ ] Integration tests for new commands
- [ ] Edge cases covered
- [ ] Error handling tested
- [ ] All tests pass locally
- [ ] No flaky tests
- [ ] Test names are descriptive
- [ ] Code coverage maintained/improved

## Debugging Tests

### Enable Verbose Output

```bash
dart test --verbose
```

### Run Single Test

```dart
test('should do something', () async {
  // ...
}, skip: false); // Remove skip to run only this test
```

### Print Debug Information

```dart
test('debugging test', () async {
  final result = await someFunction();
  print('Result: $result'); // Will show in test output
  
  expect(result, isNotNull);
});
```

## Test Maintenance

### Regular Tasks

1. **Review Coverage**: Check coverage reports monthly
2. **Update Mocks**: Keep mocks in sync with interfaces
3. **Refactor Tests**: Improve test readability and maintainability
4. **Remove Flaky Tests**: Fix or remove unreliable tests
5. **Update Documentation**: Keep this guide current

### Known Testing Limitations

- **File System Tests**: May behave differently on Windows vs Unix
- **Timing Tests**: May fail on slow CI runners
- **Encryption Tests**: Machine-specific encryption means tests create temporary keys

---

**Testing is crucial for Spectra's reliability.** Comprehensive test coverage ensures that new features don't break existing functionality and that Spectra remains trustworthy for production use.
