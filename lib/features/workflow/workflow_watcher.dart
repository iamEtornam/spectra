import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:watcher/watcher.dart';

import 'workflow_config.dart';
import 'workflow_definition.dart';
import 'workflow_failure.dart';
import 'workflow_loader.dart';

/// Result delivered to the watcher subscriber.
class WorkflowReload {
  /// Latest known-good definition. Stays at the previous value when the
  /// reload failed.
  final WorkflowDefinition definition;

  /// Latest known-good config. Stays at the previous value when the reload
  /// failed.
  final WorkflowConfig config;

  /// Optional error captured during the reload.
  final WorkflowException? error;

  /// Creates a reload payload.
  const WorkflowReload({
    required this.definition,
    required this.config,
    this.error,
  });
}

/// Watches `WORKFLOW.md` for changes and re-parses the typed config when it
/// changes.
///
/// On parse/validation failure the previous known-good values are kept and an
/// error is included in the next reload payload so the scheduler can surface
/// it via observability without crashing.
class WorkflowWatcher {
  /// Path to the workflow file.
  final String workflowPath;

  /// Loader used to parse the file.
  final WorkflowLoader loader;

  /// Logger for status messages.
  final Logger logger;

  /// Optional debounce window for noisy filesystem events.
  final Duration debounce;

  Watcher? _watcher;
  StreamSubscription<WatchEvent>? _sub;
  Timer? _debounceTimer;
  WorkflowDefinition? _lastDefinition;
  WorkflowConfig? _lastConfig;
  final StreamController<WorkflowReload> _controller =
      StreamController<WorkflowReload>.broadcast();

  /// Creates a watcher.
  WorkflowWatcher({
    required this.workflowPath,
    required this.logger,
    WorkflowLoader? loader,
    this.debounce = const Duration(milliseconds: 200),
  }) : loader = loader ?? WorkflowLoader();

  /// Stream of reload events. Subscribers receive the latest known-good
  /// values along with any captured error.
  Stream<WorkflowReload> get reloads => _controller.stream;

  /// Most recent successfully loaded config, when available.
  WorkflowConfig? get lastKnownGoodConfig => _lastConfig;

  /// Loads the workflow once and starts watching for changes.
  Future<WorkflowReload> start() async {
    final initial = await _loadOnce();
    _lastDefinition = initial.definition;
    _lastConfig = initial.config;

    final file = File(workflowPath);
    if (file.existsSync()) {
      _watcher = FileWatcher(file.absolute.path);
      _sub = _watcher!.events.listen(_onEvent);
    }

    return initial;
  }

  /// Cancels the watcher and releases resources.
  Future<void> stop() async {
    _debounceTimer?.cancel();
    await _sub?.cancel();
    _sub = null;
    _watcher = null;
    await _controller.close();
  }

  void _onEvent(WatchEvent event) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () async {
      try {
        final reload = await _loadOnce();
        _lastDefinition = reload.definition;
        _lastConfig = reload.config;
        _controller.add(reload);
        logger.detail('[workflow] reloaded ${event.type}: $workflowPath');
      } on WorkflowException catch (e) {
        logger.err('[workflow] reload failed: ${e.message}');
        if (_lastDefinition != null && _lastConfig != null) {
          _controller.add(
            WorkflowReload(
              definition: _lastDefinition!,
              config: _lastConfig!,
              error: e,
            ),
          );
        }
      }
    });
  }

  Future<WorkflowReload> _loadOnce() async {
    final definition = await loader.load(path: workflowPath);
    final config = WorkflowConfig.fromDefinition(definition);
    return WorkflowReload(definition: definition, config: config);
  }
}
