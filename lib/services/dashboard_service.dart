import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jaspr/server.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../dashboard/dashboard_page.dart';
import '../features/observability/runtime_snapshot.dart';
import '../features/orchestration/scheduler.dart';
import '../models/agent.dart';

/// Service that runs a local web dashboard for monitoring runs.
///
/// Symphony refactor: the dashboard is run-first. State comes from a
/// [RuntimeSnapshot] (live when a [Scheduler] is supplied, otherwise read from
/// the persisted `.spectra/RUNTIME.json` snapshot). The legacy `AGENTS.json`
/// view stays available for one release as a compatibility shim.
class DashboardService {
  /// Logger for status messages.
  final Logger logger;

  /// HTTP port (overridable from CLI).
  final int port;

  /// Optional live scheduler reference. When set, the snapshot is generated on
  /// demand from in-memory state.
  Scheduler? _scheduler;

  /// Path to the persisted runtime snapshot, used as a fallback.
  final String runtimePath;

  /// Path to the legacy agents file kept for one release.
  final String legacyAgentsPath;

  HttpServer? _server;

  /// Creates a dashboard service.
  DashboardService({
    required this.logger,
    this.port = 3000,
    Scheduler? scheduler,
    this.runtimePath = '.spectra/RUNTIME.json',
    this.legacyAgentsPath = '.spectra/AGENTS.json',
  }) : _scheduler = scheduler;

  /// Attaches a live [Scheduler] so the dashboard can render in-memory state
  /// instead of relying on the persisted snapshot file.
  // ignore: use_setters_to_change_properties
  void attachScheduler(Scheduler scheduler) {
    _scheduler = scheduler;
  }

  /// Detaches the current live scheduler.
  void detachScheduler() {
    _scheduler = null;
  }

  /// Starts the dashboard HTTP server.
  Future<void> start() async {
    Jaspr.initializeApp();

    final router = Router()
      ..get('/api/agents', _handleAgentsApi)
      ..get('/api/project', _handleProjectApi)
      ..get('/api/v1/state', _handleV1State)
      ..get('/api/v1/issue/<identifier>', _handleV1Issue)
      ..post('/api/v1/refresh', _handleV1Refresh)
      ..get('/', _handleDashboard);

    final handler = const shelf.Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(
          shelf.logRequests(
            logger: (msg, isError) {
              if (isError) {
                logger.err(msg);
              } else {
                logger.detail(msg);
              }
            },
          ),
        )
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
    logger.success('Dashboard running at http://localhost:$port');
    logger.info('Press Ctrl+C to stop.');
  }

  /// Stops the dashboard server.
  Future<void> stop() async {
    await _server?.close(force: true);
    logger.info('Dashboard stopped.');
  }

  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final response = await innerHandler(request);
        return response.change(
          headers: <String, Object>{
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          },
        );
      };
    };
  }

  /// Builds the current snapshot, preferring live scheduler state.
  Map<String, dynamic>? _readSnapshot() {
    final scheduler = _scheduler;
    if (scheduler != null) {
      return RuntimeSnapshot.fromScheduler(scheduler).toJson();
    }
    final file = File(runtimePath);
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fall through; return null.
    }
    return null;
  }

  shelf.Response _handleV1State(shelf.Request request) {
    final snapshot = _readSnapshot();
    if (snapshot == null) {
      return shelf.Response.ok(
        jsonEncode(<String, dynamic>{
          'generated_at': DateTime.now().toIso8601String(),
          'counts': <String, int>{
            'running': 0,
            'retrying': 0,
            'claimed': 0,
            'completed': 0,
          },
          'running': <dynamic>[],
          'retrying': <dynamic>[],
          'claimed': <dynamic>[],
          'completed': <dynamic>[],
          'codex_totals': <String, dynamic>{
            'input_tokens': 0,
            'output_tokens': 0,
            'total_tokens': 0,
            'seconds_running': 0,
          },
          'rate_limits': null,
          'recent_events': <dynamic>[],
          'validation_errors': <dynamic>[],
        }),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }
    return shelf.Response.ok(
      jsonEncode(snapshot),
      headers: <String, String>{'Content-Type': 'application/json'},
    );
  }

  shelf.Response _handleV1Issue(shelf.Request request, String identifier) {
    final snapshot = _readSnapshot();
    if (snapshot == null) {
      return shelf.Response.notFound(
        jsonEncode(<String, dynamic>{
          'error': <String, String>{
            'code': 'snapshot_unavailable',
            'message': 'Runtime snapshot is not available.',
          },
        }),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }
    final running =
        (snapshot['running'] as List<dynamic>?) ?? const <dynamic>[];
    final match = running
        .whereType<Map<String, dynamic>>()
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (e) => e?['issue_identifier'] == identifier,
          orElse: () => null,
        );
    if (match == null) {
      return shelf.Response.notFound(
        jsonEncode(<String, dynamic>{
          'error': <String, String>{
            'code': 'issue_not_found',
            'message': 'Issue $identifier is not currently tracked.',
          },
        }),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }
    return shelf.Response.ok(
      jsonEncode(match),
      headers: <String, String>{'Content-Type': 'application/json'},
    );
  }

  Future<shelf.Response> _handleV1Refresh(shelf.Request request) async {
    final scheduler = _scheduler;
    if (scheduler == null) {
      return shelf.Response(
        503,
        body: jsonEncode(<String, dynamic>{
          'error': <String, String>{
            'code': 'scheduler_not_attached',
            'message': 'Refresh requires a live scheduler.',
          },
        }),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }
    unawaited(scheduler.requestImmediateTick());
    return shelf.Response(
      202,
      body: jsonEncode(<String, dynamic>{
        'queued': true,
        'coalesced': false,
        'requested_at': DateTime.now().toIso8601String(),
        'operations': <String>['poll', 'reconcile'],
      }),
      headers: <String, String>{'Content-Type': 'application/json'},
    );
  }

  shelf.Response _handleAgentsApi(shelf.Request request) {
    final statusFile = File(legacyAgentsPath);
    if (!statusFile.existsSync()) {
      return shelf.Response.ok(
        jsonEncode(<String, dynamic>{
          'agents': <dynamic>[],
          'running': false,
          'deprecation':
              'AGENTS.json is deprecated. Read /api/v1/state instead.',
        }),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }

    try {
      final content = statusFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return shelf.Response.ok(
          jsonEncode(<String, dynamic>{
            'agents': <dynamic>[],
            'running': false,
          }),
          headers: <String, String>{'Content-Type': 'application/json'},
        );
      }

      final agents = decoded
          .cast<Map<String, dynamic>>()
          .map((j) => AgentState.fromJson(j).toJson())
          .toList();

      return shelf.Response.ok(
        jsonEncode(<String, dynamic>{'agents': agents, 'running': true}),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.ok(
        jsonEncode(<String, dynamic>{
          'agents': <dynamic>[],
          'running': false,
          'error': e.toString(),
        }),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }
  }

  shelf.Response _handleProjectApi(shelf.Request request) {
    final data = <String, dynamic>{};

    final projectFile = File('.spectra/PROJECT.md');
    if (projectFile.existsSync()) {
      data['project'] = projectFile.readAsStringSync();
    }

    final roadmapFile = File('.spectra/ROADMAP.md');
    if (roadmapFile.existsSync()) {
      final content = roadmapFile.readAsStringSync();
      data['roadmap'] = content;

      final totalTasks = RegExp(r'- \[( |x)\]').allMatches(content).length;
      final completedTasks = RegExp(r'- \[x\]').allMatches(content).length;
      data['progress'] = <String, num>{
        'total': totalTasks,
        'completed': completedTasks,
        'percent': totalTasks == 0
            ? 0
            : (completedTasks / totalTasks * 100).round(),
      };
    }

    final planFile = File('.spectra/PLAN.md');
    if (planFile.existsSync()) {
      data['plan'] = planFile.readAsStringSync();
    }

    return shelf.Response.ok(
      jsonEncode(data),
      headers: <String, String>{'Content-Type': 'application/json'},
    );
  }

  Future<shelf.Response> _handleDashboard(shelf.Request request) async {
    final agents = _loadAgents();
    final progress = _loadProgress();

    final dashboardComponent = DashboardPage(
      agents: agents,
      projectProgress: progress.percent,
      totalTasks: progress.total,
      completedTasks: progress.completed,
    );

    final rendered = await renderComponent(
      dashboardComponent,
      standalone: true,
    );

    final bodyHtml = utf8.decode(rendered.body);
    final fullHtml = _wrapInDocument(bodyHtml, isRunning: agents.isNotEmpty);

    return shelf.Response.ok(
      fullHtml,
      headers: <String, String>{'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  String _wrapInDocument(String bodyHtml, {required bool isRunning}) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Spectra Dashboard</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    @keyframes pulse {
      0%, 100% { opacity: 1; }
      50% { opacity: 0.5; }
    }
    .status-working span:first-child {
      animation: pulse 2s infinite;
    }
  </style>
</head>
<body>
$bodyHtml
<script>
  setTimeout(function() { window.location.reload(); }, 2000);
</script>
</body>
</html>
''';
  }

  List<AgentState> _loadAgents() {
    final statusFile = File(legacyAgentsPath);
    if (!statusFile.existsSync()) return <AgentState>[];

    try {
      final content = statusFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! List) return <AgentState>[];

      return decoded
          .cast<Map<String, dynamic>>()
          .map((j) => AgentState.fromJson(j))
          .toList();
    } catch (e) {
      return <AgentState>[];
    }
  }

  ({int completed, int total, int percent}) _loadProgress() {
    final roadmapFile = File('.spectra/ROADMAP.md');
    if (!roadmapFile.existsSync()) {
      return (completed: 0, total: 0, percent: 0);
    }

    try {
      final content = roadmapFile.readAsStringSync();
      final totalTasks = RegExp(r'- \[( |x)\]').allMatches(content).length;
      final completedTasks = RegExp(r'- \[x\]').allMatches(content).length;
      final percent = totalTasks == 0
          ? 0
          : (completedTasks / totalTasks * 100).round();
      return (completed: completedTasks, total: totalTasks, percent: percent);
    } catch (e) {
      return (completed: 0, total: 0, percent: 0);
    }
  }
}
