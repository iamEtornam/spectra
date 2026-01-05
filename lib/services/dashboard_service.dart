import 'dart:convert';
import 'dart:io';

import 'package:jaspr/server.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../dashboard/app.dart';
import '../dashboard/document.dart' show wrapInDocument;
import '../models/agent.dart';

/// Service that runs a local web dashboard for monitoring agents.
///
/// Uses Jaspr for server-side rendering of the dashboard UI.
/// See: https://docs.jaspr.site
class DashboardService {
  final Logger logger;
  final int port;
  HttpServer? _server;

  DashboardService({
    required this.logger,
    this.port = 3000,
  });

  /// Starts the dashboard HTTP server.
  Future<void> start() async {
    // Initialize Jaspr for server-side rendering
    Jaspr.initializeApp();

    final router = Router();

    // API endpoint for agent status
    router.get('/api/agents', _handleAgentsApi);

    // API endpoint for project info
    router.get('/api/project', _handleProjectApi);

    // Serve the Jaspr-rendered dashboard
    router.get('/', _handleDashboard);

    // Add CORS and logging middleware
    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(logRequests(logger: (msg, isError) {
      if (isError) {
        logger.err(msg);
      } else {
        logger.detail(msg);
      }
    })).addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
    logger.success('Dashboard running at http://localhost:$port');
    logger.info('Built with Jaspr (https://docs.jaspr.site)');
    logger.info('Press Ctrl+C to stop.');
  }

  /// Stops the dashboard server.
  Future<void> stop() async {
    await _server?.close(force: true);
    logger.info('Dashboard stopped.');
  }

  /// CORS middleware for browser requests.
  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type',
        });
      };
    };
  }

  /// Handles the /api/agents endpoint.
  Response _handleAgentsApi(Request request) {
    final statusFile = File('.spectra/AGENTS.json');
    if (!statusFile.existsSync()) {
      return Response.ok(
        jsonEncode({'agents': <dynamic>[], 'running': false}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    try {
      final content = statusFile.readAsStringSync();
      final decoded = jsonDecode(content);
      if (decoded is! List) {
        return Response.ok(
          jsonEncode({'agents': <dynamic>[], 'running': false}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final agents = decoded
          .cast<Map<String, dynamic>>()
          .map((j) => AgentState.fromJson(j).toJson())
          .toList();

      return Response.ok(
        jsonEncode({'agents': agents, 'running': true}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.ok(
        jsonEncode(
            {'agents': <dynamic>[], 'running': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handles the /api/project endpoint.
  Response _handleProjectApi(Request request) {
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
        'percent':
            totalTasks == 0 ? 0 : (completedTasks / totalTasks * 100).round(),
      };
    }

    // Read PLAN.md for current tasks
    final planFile = File('.spectra/PLAN.md');
    if (planFile.existsSync()) {
      data['plan'] = planFile.readAsStringSync();
    }

    return Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handles the dashboard HTML page using Jaspr SSR.
  Future<Response> _handleDashboard(Request request) async {
    // Load current agent state
    final agents = _loadAgents();
    final progress = _loadProgress();

    // Render the Jaspr component to HTML
    final result = await renderComponent(
      DashboardApp(
        agents: agents,
        completedTasks: progress.$1,
        totalTasks: progress.$2,
        isRunning: agents.isNotEmpty,
      ),
      request: request,
      standalone: true, // Get just the component HTML, not full document
    );

    // Wrap in our custom HTML document with auto-refresh
    final html = wrapInDocument(result.body);

    return Response.ok(
      html,
      headers: {'Content-Type': 'text/html; charset=utf-8'},
    );
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
  (int completed, int total) _loadProgress() {
    final roadmapFile = File('.spectra/ROADMAP.md');
    if (!roadmapFile.existsSync()) return (0, 0);

    try {
      final content = roadmapFile.readAsStringSync();
      final totalTasks = RegExp(r'- \[( |x)\]').allMatches(content).length;
      final completedTasks = RegExp(r'- \[x\]').allMatches(content).length;
      return (completedTasks, totalTasks);
    } catch (e) {
      return (0, 0);
    }
  }
}
