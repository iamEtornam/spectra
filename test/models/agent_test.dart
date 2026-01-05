import 'package:test/test.dart';
import 'package:spectra_cli/models/agent.dart';

void main() {
  group('AgentRole', () {
    test('should have correct values', () {
      expect(AgentRole.values.length, equals(3));
      expect(AgentRole.values, contains(AgentRole.mayor));
      expect(AgentRole.values, contains(AgentRole.witness));
      expect(AgentRole.values, contains(AgentRole.worker));
    });
  });

  group('AgentStatus', () {
    test('should have correct values', () {
      expect(AgentStatus.values.length, equals(5));
      expect(AgentStatus.values, contains(AgentStatus.idle));
      expect(AgentStatus.values, contains(AgentStatus.working));
      expect(AgentStatus.values, contains(AgentStatus.stuck));
      expect(AgentStatus.values, contains(AgentStatus.completed));
      expect(AgentStatus.values, contains(AgentStatus.failed));
    });
  });

  group('AgentState', () {
    test('should create with default values', () {
      final state = AgentState(
        id: 'test-agent',
        role: AgentRole.worker,
      );

      expect(state.id, equals('test-agent'));
      expect(state.role, equals(AgentRole.worker));
      expect(state.status, equals(AgentStatus.idle));
      expect(state.currentTaskId, isNull);
      expect(state.lastActivity, isNotNull);
    });

    test('should create with custom values', () {
      final now = DateTime.now();
      final state = AgentState(
        id: 'test-agent',
        role: AgentRole.mayor,
        status: AgentStatus.working,
        currentTaskId: 'task-123',
        lastActivity: now,
      );

      expect(state.id, equals('test-agent'));
      expect(state.role, equals(AgentRole.mayor));
      expect(state.status, equals(AgentStatus.working));
      expect(state.currentTaskId, equals('task-123'));
      expect(state.lastActivity, equals(now));
    });

    group('JSON serialization', () {
      test('toJson should produce correct output', () {
        final state = AgentState(
          id: 'test-agent',
          role: AgentRole.worker,
          status: AgentStatus.working,
          currentTaskId: 'task-001',
        );

        final json = state.toJson();

        expect(json['id'], equals('test-agent'));
        expect(json['role'], equals('worker'));
        expect(json['status'], equals('working'));
        expect(json['currentTaskId'], equals('task-001'));
        expect(json['lastActivity'], isA<String>());
      });

      test('fromJson should parse correctly', () {
        final json = {
          'id': 'test-agent',
          'role': 'mayor',
          'status': 'idle',
          'currentTaskId': null,
          'lastActivity': '2025-01-05T12:00:00.000',
        };

        final state = AgentState.fromJson(json);

        expect(state.id, equals('test-agent'));
        expect(state.role, equals(AgentRole.mayor));
        expect(state.status, equals(AgentStatus.idle));
        expect(state.currentTaskId, isNull);
      });

      test('round-trip serialization should preserve data', () {
        final original = AgentState(
          id: 'worker-1',
          role: AgentRole.worker,
          status: AgentStatus.completed,
          currentTaskId: 'task-42',
        );

        final json = original.toJson();
        final restored = AgentState.fromJson(json);

        expect(restored.id, equals(original.id));
        expect(restored.role, equals(original.role));
        expect(restored.status, equals(original.status));
        expect(restored.currentTaskId, equals(original.currentTaskId));
      });
    });
  });
}
