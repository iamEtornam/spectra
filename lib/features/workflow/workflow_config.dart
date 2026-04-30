import 'dart:io';

import 'package:path/path.dart' as p;

import 'workflow_definition.dart';
import 'workflow_failure.dart';

/// Typed runtime view of a workflow definition.
class WorkflowConfig {
  /// Issue tracker settings.
  final TrackerWorkflowConfig tracker;

  /// Polling scheduler settings.
  final PollingWorkflowConfig polling;

  /// Workspace root and path settings.
  final WorkspaceWorkflowConfig workspace;

  /// Workspace lifecycle hook settings.
  final HooksWorkflowConfig hooks;

  /// Agent scheduling settings.
  final AgentWorkflowConfig agent;

  /// Coding-agent subprocess settings.
  final CodexWorkflowConfig codex;

  /// Optional local HTTP status/control server settings.
  final ServerWorkflowConfig server;

  /// Creates a typed workflow config.
  const WorkflowConfig({
    required this.tracker,
    required this.polling,
    required this.workspace,
    required this.hooks,
    required this.agent,
    required this.codex,
    required this.server,
  });

  /// Builds typed config from a parsed workflow definition.
  factory WorkflowConfig.fromDefinition(
    WorkflowDefinition definition, {
    Map<String, String>? environment,
  }) {
    final workflowDirectory = p.dirname(p.absolute(definition.path));
    final env = environment ?? Platform.environment;
    final config = definition.config;

    return WorkflowConfig(
      tracker: TrackerWorkflowConfig.fromMap(
        _mapValue(config, 'tracker'),
        environment: env,
      ),
      polling: PollingWorkflowConfig.fromMap(_mapValue(config, 'polling')),
      workspace: WorkspaceWorkflowConfig.fromMap(
        _mapValue(config, 'workspace'),
        workflowDirectory: workflowDirectory,
        environment: env,
      ),
      hooks: HooksWorkflowConfig.fromMap(_mapValue(config, 'hooks')),
      agent: AgentWorkflowConfig.fromMap(_mapValue(config, 'agent')),
      codex: CodexWorkflowConfig.fromMap(_mapValue(config, 'codex')),
      server: ServerWorkflowConfig.fromMap(_mapValue(config, 'server')),
    );
  }

  /// Tracker kinds supported by the built-in factory.
  static const supportedTrackerKinds = <String>{'linear', 'local_plan'};

  /// Returns dispatch-blocking validation errors.
  List<String> validateForDispatch() {
    final errors = <String>[];

    if (tracker.kind == null || tracker.kind!.isEmpty) {
      errors.add('tracker.kind is required for dispatch.');
    } else if (!supportedTrackerKinds.contains(tracker.kind)) {
      errors.add('Unsupported tracker.kind: ${tracker.kind}.');
    }

    if (tracker.kind == 'linear') {
      if (tracker.apiKey == null || tracker.apiKey!.isEmpty) {
        errors.add('tracker.api_key or LINEAR_API_KEY is required.');
      }
      if (tracker.projectSlug == null || tracker.projectSlug!.isEmpty) {
        errors.add('tracker.project_slug is required.');
      }
    }

    if (polling.interval.inMilliseconds <= 0) {
      errors.add('polling.interval_ms must be positive.');
    }
    if (hooks.timeout.inMilliseconds <= 0) {
      errors.add('hooks.timeout_ms must be positive.');
    }
    if (agent.maxConcurrentAgents <= 0) {
      errors.add('agent.max_concurrent_agents must be positive.');
    }
    if (agent.maxTurns <= 0) {
      errors.add('agent.max_turns must be positive.');
    }
    if (agent.maxRetryBackoff.inMilliseconds <= 0) {
      errors.add('agent.max_retry_backoff_ms must be positive.');
    }
    if (codex.turnTimeout.inMilliseconds <= 0) {
      errors.add('codex.turn_timeout_ms must be positive.');
    }
    if (codex.readTimeout.inMilliseconds <= 0) {
      errors.add('codex.read_timeout_ms must be positive.');
    }

    return errors;
  }

  /// Throws if dispatch-blocking validation fails.
  void requireDispatchable() {
    final errors = validateForDispatch();
    if (errors.isNotEmpty) {
      throw WorkflowException(
        WorkflowFailureCode.configValidationError,
        errors.join(' '),
      );
    }
  }
}

/// Issue tracker settings from workflow front matter.
class TrackerWorkflowConfig {
  /// Tracker kind. The first supported value is `linear`.
  final String? kind;

  /// Tracker API endpoint.
  final String endpoint;

  /// Resolved tracker API key.
  final String? apiKey;

  /// Tracker project slug used to select candidate work.
  final String? projectSlug;

  /// Tracker states eligible for dispatch.
  final List<String> activeStates;

  /// Tracker states considered terminal.
  final List<String> terminalStates;

  /// Creates tracker workflow config.
  const TrackerWorkflowConfig({
    required this.kind,
    required this.endpoint,
    required this.apiKey,
    required this.projectSlug,
    required this.activeStates,
    required this.terminalStates,
  });

  /// Builds tracker config from a map.
  factory TrackerWorkflowConfig.fromMap(
    Map<String, dynamic> map, {
    required Map<String, String> environment,
  }) {
    final kind = _stringValue(map, 'kind');
    return TrackerWorkflowConfig(
      kind: kind,
      endpoint:
          _stringValue(map, 'endpoint') ?? 'https://api.linear.app/graphql',
      apiKey: _resolveEnvValue(
        _stringValue(map, 'api_key') ?? r'$LINEAR_API_KEY',
        environment,
      ),
      projectSlug: _stringValue(map, 'project_slug'),
      activeStates: _stringListValue(map, 'active_states', const [
        'Todo',
        'In Progress',
      ]),
      terminalStates: _stringListValue(map, 'terminal_states', const [
        'Closed',
        'Cancelled',
        'Canceled',
        'Duplicate',
        'Done',
      ]),
    );
  }
}

/// Polling scheduler config.
class PollingWorkflowConfig {
  /// Scheduler poll interval.
  final Duration interval;

  /// Creates polling config.
  const PollingWorkflowConfig({required this.interval});

  /// Builds polling config from a map.
  factory PollingWorkflowConfig.fromMap(Map<String, dynamic> map) {
    return PollingWorkflowConfig(
      interval: Duration(milliseconds: _intValue(map, 'interval_ms') ?? 30000),
    );
  }
}

/// Per-issue workspace config.
class WorkspaceWorkflowConfig {
  /// Normalized absolute workspace root.
  final String root;

  /// Creates workspace config.
  const WorkspaceWorkflowConfig({required this.root});

  /// Builds workspace config from a map.
  factory WorkspaceWorkflowConfig.fromMap(
    Map<String, dynamic> map, {
    required String workflowDirectory,
    required Map<String, String> environment,
  }) {
    final rawRoot =
        _resolveEnvValue(
          _stringValue(map, 'root') ?? '.spectra/workspaces',
          environment,
        ) ??
        '.spectra/workspaces';
    final expandedRoot = _expandHome(rawRoot);
    final root = p.isAbsolute(expandedRoot)
        ? p.normalize(expandedRoot)
        : p.normalize(p.join(workflowDirectory, expandedRoot));

    return WorkspaceWorkflowConfig(root: root);
  }
}

/// Workspace lifecycle hook config.
class HooksWorkflowConfig {
  /// Script run after a workspace is first created.
  final String? afterCreate;

  /// Script run before each agent attempt.
  final String? beforeRun;

  /// Script run after each agent attempt.
  final String? afterRun;

  /// Script run before workspace removal.
  final String? beforeRemove;

  /// Timeout applied to hook execution.
  final Duration timeout;

  /// Creates hook config.
  const HooksWorkflowConfig({
    required this.afterCreate,
    required this.beforeRun,
    required this.afterRun,
    required this.beforeRemove,
    required this.timeout,
  });

  /// Builds hook config from a map.
  factory HooksWorkflowConfig.fromMap(Map<String, dynamic> map) {
    return HooksWorkflowConfig(
      afterCreate: _stringValue(map, 'after_create'),
      beforeRun: _stringValue(map, 'before_run'),
      afterRun: _stringValue(map, 'after_run'),
      beforeRemove: _stringValue(map, 'before_remove'),
      timeout: Duration(milliseconds: _intValue(map, 'timeout_ms') ?? 60000),
    );
  }
}

/// Agent scheduling config.
class AgentWorkflowConfig {
  /// Maximum number of concurrent agent runs.
  final int maxConcurrentAgents;

  /// Maximum turns per worker session.
  final int maxTurns;

  /// Maximum retry backoff duration.
  final Duration maxRetryBackoff;

  /// Optional per-tracker-state concurrency overrides.
  final Map<String, int> maxConcurrentAgentsByState;

  /// Identifier for the agent runner implementation.
  ///
  /// Defaults to `llm`, which uses Spectra's existing LLM providers via
  /// `LlmAgentRunner`. `codex` is reserved for a future Codex app-server
  /// runner.
  final String runner;

  /// LLM-runner-specific overrides.
  final LlmRunnerWorkflowConfig llm;

  /// Creates agent workflow config.
  const AgentWorkflowConfig({
    required this.maxConcurrentAgents,
    required this.maxTurns,
    required this.maxRetryBackoff,
    required this.maxConcurrentAgentsByState,
    required this.runner,
    required this.llm,
  });

  /// Builds agent config from a map.
  factory AgentWorkflowConfig.fromMap(Map<String, dynamic> map) {
    return AgentWorkflowConfig(
      maxConcurrentAgents: _intValue(map, 'max_concurrent_agents') ?? 10,
      maxTurns: _intValue(map, 'max_turns') ?? 20,
      maxRetryBackoff: Duration(
        milliseconds: _intValue(map, 'max_retry_backoff_ms') ?? 300000,
      ),
      maxConcurrentAgentsByState: _intMapValue(
        map,
        'max_concurrent_agents_by_state',
      ),
      runner: _stringValue(map, 'runner') ?? 'llm',
      llm: LlmRunnerWorkflowConfig.fromMap(_mapValue(map, 'llm')),
    );
  }
}

/// LLM runner overrides set under `agent.llm`.
class LlmRunnerWorkflowConfig {
  /// Optional planning provider override.
  final String? planningProvider;

  /// Optional coding provider override.
  final String? codingProvider;

  /// Per-turn timeout for LLM calls.
  final Duration timeout;

  /// Maximum response size before the runner aborts the turn.
  final int maxResponseBytes;

  /// Creates an LLM runner config view.
  const LlmRunnerWorkflowConfig({
    required this.planningProvider,
    required this.codingProvider,
    required this.timeout,
    required this.maxResponseBytes,
  });

  /// Builds an LLM runner config from a map.
  factory LlmRunnerWorkflowConfig.fromMap(Map<String, dynamic> map) {
    return LlmRunnerWorkflowConfig(
      planningProvider: _stringValue(map, 'planning_provider'),
      codingProvider: _stringValue(map, 'coding_provider'),
      timeout: Duration(milliseconds: _intValue(map, 'timeout_ms') ?? 120000),
      maxResponseBytes: _intValue(map, 'max_response_bytes') ?? 4 * 1024 * 1024,
    );
  }
}

/// Coding-agent subprocess config.
class CodexWorkflowConfig {
  /// Shell command used to launch the app-server.
  final String command;

  /// Approval policy passed through to the runner.
  final String? approvalPolicy;

  /// Thread sandbox setting passed through to the runner.
  final String? threadSandbox;

  /// Turn sandbox setting passed through to the runner.
  final String? turnSandboxPolicy;

  /// Total timeout for a turn.
  final Duration turnTimeout;

  /// Timeout for app-server sync reads.
  final Duration readTimeout;

  /// Stall timeout based on event inactivity.
  final Duration stallTimeout;

  /// Creates Codex workflow config.
  const CodexWorkflowConfig({
    required this.command,
    required this.approvalPolicy,
    required this.threadSandbox,
    required this.turnSandboxPolicy,
    required this.turnTimeout,
    required this.readTimeout,
    required this.stallTimeout,
  });

  /// Builds Codex config from a map.
  factory CodexWorkflowConfig.fromMap(Map<String, dynamic> map) {
    return CodexWorkflowConfig(
      command: _stringValue(map, 'command') ?? 'codex app-server',
      approvalPolicy: _stringValue(map, 'approval_policy'),
      threadSandbox: _stringValue(map, 'thread_sandbox'),
      turnSandboxPolicy: _stringValue(map, 'turn_sandbox_policy'),
      turnTimeout: Duration(
        milliseconds: _intValue(map, 'turn_timeout_ms') ?? 3600000,
      ),
      readTimeout: Duration(
        milliseconds: _intValue(map, 'read_timeout_ms') ?? 5000,
      ),
      stallTimeout: Duration(
        milliseconds: _intValue(map, 'stall_timeout_ms') ?? 300000,
      ),
    );
  }
}

/// Optional local server extension config.
class ServerWorkflowConfig {
  /// Optional local server port.
  final int? port;

  /// Creates server workflow config.
  const ServerWorkflowConfig({required this.port});

  /// Builds server config from a map.
  factory ServerWorkflowConfig.fromMap(Map<String, dynamic> map) {
    return ServerWorkflowConfig(port: _intValue(map, 'port'));
  }
}

Map<String, dynamic> _mapValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Map<String, dynamic>) {
    return value;
  }
  return <String, dynamic>{};
}

String? _stringValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value : null;
}

int? _intValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is int ? value : null;
}

List<String> _stringListValue(
  Map<String, dynamic> map,
  String key,
  List<String> defaults,
) {
  final value = map[key];
  if (value is! List<dynamic>) {
    return List<String>.unmodifiable(defaults);
  }

  return List<String>.unmodifiable(value.whereType<String>());
}

Map<String, int> _intMapValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! Map<String, dynamic>) {
    return const <String, int>{};
  }

  final result = <String, int>{};
  for (final entry in value.entries) {
    if (entry.value is int && (entry.value as int) > 0) {
      result[entry.key.toLowerCase()] = entry.value as int;
    }
  }
  return Map<String, int>.unmodifiable(result);
}

String? _resolveEnvValue(String? value, Map<String, String> environment) {
  if (value == null) {
    return null;
  }
  if (!value.startsWith(r'$') || value.length == 1) {
    return value;
  }

  final resolved = environment[value.substring(1)];
  if (resolved == null || resolved.isEmpty) {
    return null;
  }
  return resolved;
}

String _expandHome(String path) {
  if (path == '~' || path.startsWith('~/')) {
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.isNotEmpty) {
      return path == '~' ? home : p.join(home, path.substring(2));
    }
  }
  return path;
}
