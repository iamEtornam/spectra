import 'dart:convert';
import 'dart:io';

import 'package:jaspr/server.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../dashboard/dashboard_page.dart';
import '../models/agent.dart';

/// Service that runs a local web dashboard for monitoring agents.
///
/// Uses Jaspr for server-side component rendering with shelf for HTTP handling.
/// See: https://docs.jaspr.site/going_further/backend
class DashboardService {
  final Logger logger;
  final int port;
  HttpServer? _server;

  DashboardService({required this.logger, this.port = 3000});

  /// Starts the dashboard HTTP server.
  Future<void> start() async {
    // Initialize Jaspr before using renderComponent
    Jaspr.initializeApp();

    final router = Router();

    // API endpoints
    router.get('/api/agents', _handleAgentsApi);
    router.get('/api/project', _handleProjectApi);

    // Serve the Jaspr-rendered dashboard
    router.get('/', _handleDashboard);

    // Add CORS and logging middleware
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

  /// CORS middleware for browser requests.
  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler innerHandler) {
      return (shelf.Request request) async {
        final response = await innerHandler(request);
        return response.change(
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
          },
        );
      };
    };
  }

  /// Handles the /api/agents endpoint.
  shelf.Response _handleAgentsApi(shelf.Request request) {
    final statusFile = File('.spectra/AGENTS.json');
    if (!statusFile.existsSync()) {
      return shelf.Response.ok(
        jsonEncode({'agents': <dynamic>[], 'running': false}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final content = statusFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return shelf.Response.ok(
          jsonEncode({'agents': <dynamic>[], 'running': false}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final agents = decoded
          .cast<Map<String, dynamic>>()
          .map((j) => AgentState.fromJson(j).toJson())
          .toList();

      return shelf.Response.ok(
        jsonEncode({'agents': agents, 'running': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.ok(
        jsonEncode({
          'agents': <dynamic>[],
          'running': false,
          'error': e.toString(),
        }),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handles the /api/project endpoint.
  shelf.Response _handleProjectApi(shelf.Request request) {
    final data = <String, dynamic>{};

    // Read PROJECT.md for project info
    final projectFile = File('.spectra/PROJECT.md');
    if (projectFile.existsSync()) {
      data['project'] = projectFile.readAsStringSync();
    }

    // Read ROADMAP.md for progress
    final roadmapFile = File('.spectra/ROADMAP.md');
    if (roadmapFile.existsSync()) {
      final content = roadmapFile.readAsStringSync();
      data['roadmap'] = content;

      final totalTasks = RegExp(r'- \[( |x)\]').allMatches(content).length;
      final completedTasks = RegExp(r'- \[x\]').allMatches(content).length;
      data['progress'] = {
        'total': totalTasks,
        'completed': completedTasks,
        'percent': totalTasks == 0
            ? 0
            : (completedTasks / totalTasks * 100).round(),
      };
    }

    // Read PLAN.md for current tasks
    final planFile = File('.spectra/PLAN.md');
    if (planFile.existsSync()) {
      data['plan'] = planFile.readAsStringSync();
    }

    return shelf.Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handles the dashboard HTML page using Jaspr components.
  Future<shelf.Response> _handleDashboard(shelf.Request request) async {
    // Load current data
    final agents = _loadAgents();
    final progress = _loadProgress();

    // Create the Jaspr component
    final dashboardComponent = DashboardPage(
      agents: agents,
      projectProgress: progress.percent,
      totalTasks: progress.total,
      completedTasks: progress.completed,
    );

    // Render the component to HTML using Jaspr's renderComponent
    // renderComponent returns ResponseLike = ({int statusCode, Uint8List body, Map<String, List<String>> headers})
    final rendered = await renderComponent(
      dashboardComponent,
      standalone: true,
    );

    // Convert the body bytes to string
    final bodyHtml = utf8.decode(rendered.body);

    // Wrap in a full HTML document with our custom styles and auto-refresh
    final fullHtml = _wrapInDocument(bodyHtml, isRunning: agents.isNotEmpty);

    return shelf.Response.ok(
      fullHtml,
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
  }

  /// Wraps the Jaspr-rendered body in a complete HTML document.
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
  // Auto-refresh every 2 seconds
  setTimeout(function() { window.location.reload(); }, 2000);
</script>
</body>
</html>
''';
  }

  /// Loads agent states from the status file.
  List<AgentState> _loadAgents() {
    final statusFile = File('.spectra/AGENTS.json');
    if (!statusFile.existsSync()) return [];

    try {
      final content = statusFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! List) return [];

      return decoded
          .cast<Map<String, dynamic>>()
          .map((j) => AgentState.fromJson(j))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Loads project progress from ROADMAP.md.
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
