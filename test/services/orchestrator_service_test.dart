import 'package:test/test.dart';
import 'package:spectra_cli/agents/worker_agent.dart';
import 'package:spectra_cli/models/agent.dart';
import 'package:spectra_cli/models/task.dart';
import 'package:spectra_cli/services/orchestrator_service.dart';

import '../test_helpers.dart';

void main() {
  group('OrchestratorService.recoverStuckAgents', () {
    late OrchestratorService orchestrator;
    late MockLogger logger;

    setUp(() {
      logger = MockLogger();
      orchestrator = OrchestratorService(logger: logger);
    });

    WorkerAgent workerWithTask() {
      final worker = WorkerAgent(
        id: 'Worker-1',
        provider: FakeLLMProvider(),
        logger: logger,
      );
      worker.assignTask(
        SpectraTask(
          id: 'task_001',
          name: 'Test task',
          type: 'create',
          files: const ['lib/foo.dart'],
          objective: 'obj',
          verification: 'verify',
          acceptance: 'accept',
        ),
      );
      return worker;
    }

    test('recovers a worker the Witness already marked stuck', () {
      final worker = workerWithTask();
      // Simulate the Witness flipping the agent to stuck this tick.
      worker.updateStatus(AgentStatus.stuck);
      orchestrator.addAgent(worker);

      orchestrator.recoverStuckAgents();

      expect(worker.status, AgentStatus.idle);
      expect(worker.currentTaskId, isNull);
    });

    test('recovers a working agent past the stuck threshold', () {
      final worker = workerWithTask();
      worker.lastActivity = DateTime.now().subtract(
        const Duration(minutes: 10),
      );
      orchestrator.addAgent(worker);

      orchestrator.recoverStuckAgents();

      expect(worker.status, AgentStatus.idle);
      expect(worker.currentTaskId, isNull);
    });

    test('leaves an active working agent alone', () {
      final worker = workerWithTask();
      orchestrator.addAgent(worker);

      orchestrator.recoverStuckAgents();

      expect(worker.status, AgentStatus.working);
      expect(worker.currentTaskId, 'task_001');
    });
  });
}
