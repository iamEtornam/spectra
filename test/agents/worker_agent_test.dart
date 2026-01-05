import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spectra_cli/agents/worker_agent.dart';
import 'package:spectra_cli/models/agent.dart';
import 'package:spectra_cli/models/task.dart';
import '../test_helpers.dart';

void main() {
  late MockLogger mockLogger;
  late FakeLLMProvider fakeProvider;
  late WorkerAgent worker;

  setUp(() {
    mockLogger = MockLogger();
    fakeProvider = FakeLLMProvider(
      response: '''
<file_content path="lib/test.dart">
void main() {
  print('Hello, World!');
}
</file_content>
''',
    );
    worker = WorkerAgent(
      id: 'Worker-1',
      provider: fakeProvider,
      logger: mockLogger,
    );

    // Register fallback values for mocktail
    registerFallbackValue('');
  });

  group('WorkerAgent', () {
    test('should initialize with correct values', () {
      expect(worker.id, equals('Worker-1'));
      expect(worker.role, equals(AgentRole.worker));
      expect(worker.status, equals(AgentStatus.idle));
      expect(worker.currentTaskId, isNull);
    });

    test('assignTask should update status and task', () {
      final task = SpectraTask(
        id: 'task-001',
        type: 'create',
        name: 'Test Task',
        files: ['lib/test.dart'],
        objective: 'Create test file',
        verification: 'File exists',
        acceptance: 'Test complete',
      );

      worker.assignTask(task);

      expect(worker.status, equals(AgentStatus.working));
      expect(worker.currentTaskId, equals('task-001'));
    });

    test('step should do nothing when no task assigned', () async {
      await worker.step();

      expect(worker.status, equals(AgentStatus.idle));
      verifyNever(() => mockLogger.info(any()));
    });

    test('step should do nothing when status is not working', () async {
      worker.updateStatus(AgentStatus.completed);

      await worker.step();

      verifyNever(() => mockLogger.info(any()));
    });

    test('state getter should return correct AgentState', () {
      final task = SpectraTask(
        id: 'task-002',
        type: 'create',
        name: 'Test',
        files: [],
        objective: '',
        verification: '',
        acceptance: '',
      );
      worker.assignTask(task);

      final state = worker.state;

      expect(state.id, equals('Worker-1'));
      expect(state.role, equals(AgentRole.worker));
      expect(state.status, equals(AgentStatus.working));
      expect(state.currentTaskId, equals('task-002'));
    });
  });
}
