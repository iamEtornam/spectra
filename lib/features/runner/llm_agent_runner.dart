import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

import '../../core/llm_provider.dart';
import '../../services/codebase_context_service.dart';
import '../workflow/workflow_config.dart';
import 'agent_runner.dart';
import 'runner_event.dart';

/// Default agent runner backed by an [LLMProvider].
///
/// Wraps the same prompt assembly + `<file_content>` parsing previously baked
/// into [WorkerAgent] (`lib/agents/worker_agent.dart`) and constrains all file
/// writes to the per-issue workspace.
class LlmAgentRunner implements AgentRunner {
  /// Provider used for code generation. Pre-resolved by the caller so the
  /// runner does not need to know about config files.
  final LLMProvider provider;

  /// Per-attempt configuration.
  final LlmRunnerWorkflowConfig llmConfig;

  /// Optional codebase context service used to assemble the prompt context.
  ///
  /// Tests can pass `null` to skip context generation.
  final CodebaseContextService? contextService;

  /// Logger for diagnostic messages.
  final Logger logger;

  /// Composes a session id from a generator. Defaults to a UTC timestamp.
  final String Function() sessionIdFactory;

  /// Creates an LLM agent runner.
  LlmAgentRunner({
    required this.provider,
    required this.llmConfig,
    required this.logger,
    this.contextService,
    String Function()? sessionIdFactory,
  }) : sessionIdFactory = sessionIdFactory ?? _defaultSessionIdFactory;

  static String _defaultSessionIdFactory() {
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch.toRadixString(
      36,
    );
    return 'llm-$stamp';
  }

  @override
  String get name => 'llm';

  @override
  Stream<RunnerEvent> run(AgentRunRequest request) async* {
    final sessionId = sessionIdFactory();
    final aggregate = _UsageAccumulator();
    yield SessionStarted(
      sessionId: sessionId,
      message: 'LLM session started for ${request.issue.identifier}',
    );

    // The LLM runner currently performs a single turn per attempt. The
    // scheduler decides whether to schedule a continuation retry based on
    // tracker state. `request.maxTurns` is forwarded into the runner state so
    // future implementations can loop without changing the public contract.
    const turn = 1;
    const turnsRun = turn;

    yield TurnStarted(turnNumber: turn, message: 'Turn $turn');

    final outcome = await _runTurn(
      request: request,
      turn: turn,
      aggregate: aggregate,
    );

    for (final event in outcome.events) {
      yield event;
    }

    yield RunFinished(
      succeeded: outcome.succeeded,
      turns: turnsRun,
      totalUsage: aggregate.snapshot(),
      message: outcome.succeeded ? 'Run completed' : 'Run failed',
    );
  }

  Future<_TurnOutcome> _runTurn({
    required AgentRunRequest request,
    required int turn,
    required _UsageAccumulator aggregate,
  }) async {
    final events = <RunnerEvent>[];

    String fullPrompt;
    try {
      fullPrompt = buildPrompt(
        request: request,
        turn: turn,
        context: contextService?.getCodebaseContext(<String>[]),
      );
    } catch (e) {
      events.add(
        TurnFailed(
          turnNumber: turn,
          category: RunnerErrorCategory.promptError,
          message: 'Prompt assembly failed: $e',
        ),
      );
      return _TurnOutcome(events: events, succeeded: false);
    }

    String response;
    try {
      response = await provider
          .generateResponse(fullPrompt)
          .timeout(llmConfig.timeout);
    } on TimeoutException catch (e) {
      events.add(
        TurnFailed(
          turnNumber: turn,
          category: RunnerErrorCategory.responseTimeout,
          message: 'LLM call timed out: $e',
        ),
      );
      return _TurnOutcome(events: events, succeeded: false);
    } catch (e) {
      events.add(
        TurnFailed(
          turnNumber: turn,
          category: RunnerErrorCategory.providerError,
          message: 'LLM call failed: $e',
        ),
      );
      return _TurnOutcome(events: events, succeeded: false);
    }

    // `String.length` returns UTF-16 code units, not bytes. The cap is named
    // `maxResponseBytes` and is meant to bound network/payload size, so we
    // measure the actual UTF-8 byte count. For plain ASCII responses these
    // numbers match; for multi-byte content (emojis, CJK, accented Latin)
    // the UTF-16 count can be 2-4x smaller than the real byte size.
    final responseBytes = utf8.encode(response).length;
    if (responseBytes > llmConfig.maxResponseBytes) {
      events.add(
        TurnFailed(
          turnNumber: turn,
          category: RunnerErrorCategory.responseTooLarge,
          message:
              'LLM response of $responseBytes bytes exceeded '
              '${llmConfig.maxResponseBytes} bytes.',
        ),
      );
      return _TurnOutcome(events: events, succeeded: false);
    }

    final usage = _estimateUsage(prompt: fullPrompt, response: response);
    aggregate.accumulate(usage);
    events.add(TokenUsageUpdated(usage: usage));

    final fileContents = parseFileContents(response);
    if (fileContents.isEmpty) {
      events.add(
        TurnFailed(
          turnNumber: turn,
          category: RunnerErrorCategory.emptyResponse,
          message: 'No <file_content> blocks found in LLM response.',
        ),
      );
      return _TurnOutcome(events: events, succeeded: false);
    }

    final changed = <String>[];
    for (final entry in fileContents.entries) {
      final relative = _safeRelativePath(entry.key);
      final absolute = p.normalize(p.join(request.workspace.path, relative));
      if (!_isWithin(request.workspace.path, absolute)) {
        events.add(
          TurnFailed(
            turnNumber: turn,
            category: RunnerErrorCategory.invalidWorkspaceCwd,
            message: 'Refused write outside workspace: $relative',
          ),
        );
        return _TurnOutcome(events: events, succeeded: false);
      }
      try {
        final file = File(absolute);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
        changed.add(relative);
      } catch (e) {
        events.add(
          TurnFailed(
            turnNumber: turn,
            category: RunnerErrorCategory.providerError,
            message: 'Failed to write $relative: $e',
          ),
        );
        return _TurnOutcome(events: events, succeeded: false);
      }
    }

    events.add(
      TurnCompleted(
        turnNumber: turn,
        changedFiles: changed,
        message: 'Wrote ${changed.length} files.',
      ),
    );
    return _TurnOutcome(events: events, succeeded: true);
  }

  /// Builds the prompt for [request] and [turn].
  ///
  /// Visible for testing.
  String buildPrompt({
    required AgentRunRequest request,
    required int turn,
    String? context,
  }) {
    final attempt = request.attempt;
    final attemptLine = attempt == null
        ? 'First attempt (turn $turn of ${request.maxTurns}).'
        : 'Attempt #$attempt, turn $turn of ${request.maxTurns}.';

    final buffer = StringBuffer();
    if (context != null && context.trim().isNotEmpty) {
      buffer
        ..writeln(context)
        ..writeln();
    }
    buffer
      ..writeln('=== ATTEMPT METADATA ===')
      ..writeln(attemptLine)
      ..writeln('Workspace: ${request.workspace.path}')
      ..writeln('Branch: ${request.workspace.branchName}')
      ..writeln()
      ..writeln('=== ISSUE ===')
      ..writeln('Identifier: ${request.issue.identifier}')
      ..writeln('Title: ${request.issue.title}')
      ..writeln('State: ${request.issue.state}')
      ..writeln('Labels: ${request.issue.labels.join(', ')}')
      ..writeln()
      ..writeln('=== PROMPT TEMPLATE ===')
      ..writeln(request.renderedPrompt)
      ..writeln()
      ..writeln('=== INSTRUCTIONS ===')
      ..writeln(
        'Return the full content of each file you change wrapped in '
        '<file_content path="path/to/file"> XML tags. Paths must be relative '
        'to the workspace root. Do not include any prose outside of those '
        'tags.',
      );
    return buffer.toString();
  }

  @override
  Future<void> close() async {}

  /// Parses `<file_content path="...">...</file_content>` blocks from
  /// [response].
  ///
  /// Visible for testing.
  static Map<String, String> parseFileContents(String response) {
    final regex = RegExp(
      r'<file_content path="(.*?)">(.*?)</file_content>',
      dotAll: true,
    );
    final out = <String, String>{};
    for (final match in regex.allMatches(response)) {
      out[match.group(1)!] = match.group(2)!.trim();
    }
    return out;
  }

  RunnerTokenUsage _estimateUsage({
    required String prompt,
    required String response,
  }) {
    // Rough heuristic: 4 chars per token. Used until providers expose real
    // usage counts.
    final inputTokens = (prompt.length / 4).ceil();
    final outputTokens = (response.length / 4).ceil();
    return RunnerTokenUsage(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      totalTokens: inputTokens + outputTokens,
    );
  }

  String _safeRelativePath(String input) {
    final normalized = p.normalize(input);
    if (p.isAbsolute(normalized) || normalized.startsWith('..')) {
      return p.basename(normalized);
    }
    return normalized;
  }

  bool _isWithin(String root, String candidate) {
    final normalizedRoot = p.normalize(root);
    final normalizedCandidate = p.normalize(candidate);
    if (normalizedRoot == normalizedCandidate) return true;
    return p.isWithin(normalizedRoot, normalizedCandidate);
  }
}

class _TurnOutcome {
  final List<RunnerEvent> events;
  final bool succeeded;
  const _TurnOutcome({required this.events, required this.succeeded});
}

class _UsageAccumulator {
  int _input = 0;
  int _output = 0;
  int _total = 0;

  void accumulate(RunnerTokenUsage usage) {
    _input += usage.inputTokens;
    _output += usage.outputTokens;
    _total += usage.totalTokens;
  }

  RunnerTokenUsage snapshot() => RunnerTokenUsage(
    inputTokens: _input,
    outputTokens: _output,
    totalTokens: _total,
  );
}
