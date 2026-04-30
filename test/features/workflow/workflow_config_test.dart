import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spectra_cli/features/workflow/workflow.dart';
import 'package:test/test.dart';

void main() {
  group('WorkflowConfig', () {
    test('applies defaults when front matter is empty', () {
      final definition = WorkflowDefinition(
        config: const <String, dynamic>{},
        promptTemplate: 'Prompt',
        path: p.join(Directory.current.path, 'WORKFLOW.md'),
      );

      final config = WorkflowConfig.fromDefinition(
        definition,
        environment: const <String, String>{},
      );

      expect(config.tracker.kind, isNull);
      expect(config.tracker.endpoint, equals('https://api.linear.app/graphql'));
      expect(config.tracker.activeStates, equals(['Todo', 'In Progress']));
      expect(
        config.tracker.terminalStates,
        equals(['Closed', 'Cancelled', 'Canceled', 'Duplicate', 'Done']),
      );
      expect(config.polling.interval, equals(const Duration(seconds: 30)));
      expect(config.workspace.root, endsWith('.spectra/workspaces'));
      expect(config.hooks.timeout, equals(const Duration(seconds: 60)));
      expect(config.agent.maxConcurrentAgents, equals(10));
      expect(config.agent.maxTurns, equals(20));
      expect(config.codex.command, equals('codex app-server'));
    });

    test('resolves tracker api key from environment', () {
      final definition = WorkflowDefinition(
        config: const <String, dynamic>{
          'tracker': <String, dynamic>{
            'kind': 'linear',
            'api_key': r'$LINEAR_API_KEY',
            'project_slug': 'spectra',
          },
        },
        promptTemplate: 'Prompt',
        path: p.join(Directory.current.path, 'WORKFLOW.md'),
      );

      final config = WorkflowConfig.fromDefinition(
        definition,
        environment: const <String, String>{'LINEAR_API_KEY': 'linear-secret'},
      );

      expect(config.tracker.apiKey, equals('linear-secret'));
      expect(config.validateForDispatch(), isEmpty);
    });

    test('normalizes relative workspace root against workflow directory', () {
      final tempDir = Directory.systemTemp.createTempSync(
        'spectra_workflow_config_test_',
      );
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final definition = WorkflowDefinition(
        config: const <String, dynamic>{
          'workspace': <String, dynamic>{'root': 'tmp/workspaces'},
        },
        promptTemplate: 'Prompt',
        path: p.join(tempDir.path, 'WORKFLOW.md'),
      );

      final config = WorkflowConfig.fromDefinition(
        definition,
        environment: const <String, String>{},
      );

      expect(
        config.workspace.root,
        equals(p.join(tempDir.path, 'tmp/workspaces')),
      );
      expect(p.isAbsolute(config.workspace.root), isTrue);
    });

    test('parses typed nested config values', () {
      final definition = WorkflowDefinition(
        config: const <String, dynamic>{
          'tracker': <String, dynamic>{
            'kind': 'linear',
            'api_key': 'literal-token',
            'project_slug': 'spectra',
            'active_states': <String>['Ready', 'In Progress'],
          },
          'polling': <String, dynamic>{'interval_ms': 1000},
          'hooks': <String, dynamic>{
            'after_create': 'git status',
            'timeout_ms': 2000,
          },
          'agent': <String, dynamic>{
            'max_concurrent_agents': 2,
            'max_turns': 5,
            'max_retry_backoff_ms': 4000,
            'max_concurrent_agents_by_state': <String, dynamic>{
              'In Progress': 1,
              'invalid': 0,
            },
          },
          'codex': <String, dynamic>{
            'command': 'custom app-server',
            'turn_timeout_ms': 6000,
            'read_timeout_ms': 7000,
            'stall_timeout_ms': 8000,
          },
          'server': <String, dynamic>{'port': 4567},
        },
        promptTemplate: 'Prompt',
        path: p.join(Directory.current.path, 'WORKFLOW.md'),
      );

      final config = WorkflowConfig.fromDefinition(
        definition,
        environment: const <String, String>{},
      );

      expect(config.tracker.activeStates, equals(['Ready', 'In Progress']));
      expect(config.polling.interval, equals(const Duration(seconds: 1)));
      expect(config.hooks.afterCreate, equals('git status'));
      expect(config.hooks.timeout, equals(const Duration(seconds: 2)));
      expect(config.agent.maxConcurrentAgents, equals(2));
      expect(config.agent.maxTurns, equals(5));
      expect(config.agent.maxRetryBackoff, equals(const Duration(seconds: 4)));
      expect(
        config.agent.maxConcurrentAgentsByState,
        equals({'in progress': 1}),
      );
      expect(config.codex.command, equals('custom app-server'));
      expect(config.codex.turnTimeout, equals(const Duration(seconds: 6)));
      expect(config.codex.readTimeout, equals(const Duration(seconds: 7)));
      expect(config.codex.stallTimeout, equals(const Duration(seconds: 8)));
      expect(config.server.port, equals(4567));
    });

    test('reports dispatch validation errors', () {
      final definition = WorkflowDefinition(
        config: const <String, dynamic>{
          'tracker': <String, dynamic>{'kind': 'linear'},
          'agent': <String, dynamic>{'max_concurrent_agents': 0},
        },
        promptTemplate: 'Prompt',
        path: p.join(Directory.current.path, 'WORKFLOW.md'),
      );

      final config = WorkflowConfig.fromDefinition(
        definition,
        environment: const <String, String>{},
      );

      final errors = config.validateForDispatch();

      expect(
        errors,
        contains('tracker.api_key or LINEAR_API_KEY is required.'),
      );
      expect(errors, contains('tracker.project_slug is required.'));
      expect(errors, contains('agent.max_concurrent_agents must be positive.'));
      expect(
        config.requireDispatchable,
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.configValidationError,
          ),
        ),
      );
    });
  });
}
