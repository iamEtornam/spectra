import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:spectra_cli/core/llm_provider.dart';
import 'package:spectra_cli/features/runner/agent_runner.dart';
import 'package:spectra_cli/features/runner/llm_agent_runner.dart';
import 'package:spectra_cli/features/runner/runner_event.dart';
import 'package:spectra_cli/features/tracker/issue.dart';
import 'package:spectra_cli/features/workflow/workflow_config.dart';
import 'package:spectra_cli/features/workspaces/workspace.dart';
import 'package:test/test.dart';

class _StubProvider implements LLMProvider {
  final String response;
  final Object? error;
  String? receivedPrompt;

  _StubProvider({this.response = '', this.error});

  @override
  String get name => 'Stub';

  @override
  List<String> get availableModels => const <String>['stub'];

  @override
  String get defaultModel => 'stub';

  @override
  Future<String> generateResponse(
    String prompt, {
    List<String>? context,
  }) async {
    receivedPrompt = prompt;
    if (error != null) throw error!;
    return response;
  }
}

const _llmConfig = LlmRunnerWorkflowConfig(
  planningProvider: null,
  codingProvider: null,
  timeout: Duration(seconds: 5),
  maxResponseBytes: 64 * 1024,
);

const _issue = Issue(
  id: '1',
  identifier: 'SPEC-1',
  title: 'Add greeting',
  state: 'In Progress',
);

Workspace _makeWorkspace(Directory dir) => Workspace(
  workspaceKey: 'SPEC-1',
  path: dir.path,
  branchName: 'spectra/SPEC-1',
  createdNow: false,
);

void main() {
  group('LlmAgentRunner', () {
    late Directory workspaceDir;

    setUp(() {
      workspaceDir = Directory.systemTemp.createTempSync('spectra_runner_');
    });

    tearDown(() {
      if (workspaceDir.existsSync()) {
        workspaceDir.deleteSync(recursive: true);
      }
    });

    test('parseFileContents extracts <file_content> blocks', () {
      final parsed = LlmAgentRunner.parseFileContents('''
prefix
<file_content path="lib/a.dart">
class A {}
</file_content>
between
<file_content path="lib/b.dart">class B {}</file_content>
''');
      expect(parsed.keys, equals(<String>['lib/a.dart', 'lib/b.dart']));
      expect(parsed['lib/a.dart'], equals('class A {}'));
      expect(parsed['lib/b.dart'], equals('class B {}'));
    });

    test('writes parsed files into the workspace', () async {
      final provider = _StubProvider(
        response: '''
<file_content path="lib/main.dart">
void main() => print('hi');
</file_content>
''',
      );
      final runner = LlmAgentRunner(
        provider: provider,
        llmConfig: _llmConfig,
        logger: Logger(level: Level.quiet),
      );

      final events = await runner
          .run(
            AgentRunRequest(
              issue: _issue,
              workspace: _makeWorkspace(workspaceDir),
              renderedPrompt: 'Implement the greeting.',
              attempt: null,
              maxTurns: 1,
            ),
          )
          .toList();

      final completed = events.whereType<TurnCompleted>().single;
      expect(completed.changedFiles, equals(<String>['lib/main.dart']));

      final finished = events.whereType<RunFinished>().single;
      expect(finished.succeeded, isTrue);

      final file = File(p.join(workspaceDir.path, 'lib', 'main.dart'));
      expect(file.existsSync(), isTrue);
      expect(file.readAsStringSync(), contains("print('hi')"));
    });

    test(
      'emits emptyResponse when no <file_content> blocks are present',
      () async {
        final runner = LlmAgentRunner(
          provider: _StubProvider(response: 'no blocks here'),
          llmConfig: _llmConfig,
          logger: Logger(level: Level.quiet),
        );

        final events = await runner
            .run(
              AgentRunRequest(
                issue: _issue,
                workspace: _makeWorkspace(workspaceDir),
                renderedPrompt: 'Prompt',
                attempt: null,
                maxTurns: 1,
              ),
            )
            .toList();

        final failed = events.whereType<TurnFailed>().single;
        expect(failed.category, equals(RunnerErrorCategory.emptyResponse));
        expect(events.whereType<RunFinished>().single.succeeded, isFalse);
      },
    );

    test('emits providerError when the LLM provider throws', () async {
      final runner = LlmAgentRunner(
        provider: _StubProvider(error: Exception('boom')),
        llmConfig: _llmConfig,
        logger: Logger(level: Level.quiet),
      );

      final events = await runner
          .run(
            AgentRunRequest(
              issue: _issue,
              workspace: _makeWorkspace(workspaceDir),
              renderedPrompt: 'Prompt',
              attempt: 1,
              maxTurns: 1,
            ),
          )
          .toList();

      expect(
        events.whereType<TurnFailed>().single.category,
        equals(RunnerErrorCategory.providerError),
      );
    });

    test('rewrites absolute or escaping paths to safe filenames', () async {
      final provider = _StubProvider(
        response: '''
<file_content path="../escaped.dart">
void main() {}
</file_content>
''',
      );
      final runner = LlmAgentRunner(
        provider: provider,
        llmConfig: _llmConfig,
        logger: Logger(level: Level.quiet),
      );

      final events = await runner
          .run(
            AgentRunRequest(
              issue: _issue,
              workspace: _makeWorkspace(workspaceDir),
              renderedPrompt: 'Prompt',
              attempt: null,
              maxTurns: 1,
            ),
          )
          .toList();

      final completed = events.whereType<TurnCompleted>().single;
      expect(completed.changedFiles.single, equals('escaped.dart'));
      expect(
        File(p.join(workspaceDir.path, 'escaped.dart')).existsSync(),
        isTrue,
      );
    });
  });
}
