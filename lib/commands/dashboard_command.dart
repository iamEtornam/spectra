import 'dart:async';
import 'dart:io';

import '../services/dashboard_service.dart';
import 'base_command.dart';

/// Command to launch the web-based agent monitoring dashboard.
class DashboardCommand extends SpectraCommand {
  @override
  final name = 'dashboard';

  @override
  final description = 'Launch a web dashboard to monitor agents in real-time.';

  DashboardCommand({required super.logger}) {
    argParser.addOption(
      'port',
      abbr: 'p',
      defaultsTo: '3000',
      help: 'Port to run the dashboard on.',
    );
  }

  @override
  Future<void> run() async {
    final portArg = argResults?['port'] as String?;
    final port = int.tryParse(portArg ?? '3000') ?? 3000;

    // Check if .spectra directory exists
    if (!Directory('.spectra').existsSync()) {
      logger.warn('No .spectra directory found. Initialize a project first.');
      logger.info('Run: spectra new (for new projects)');
      logger.info('  or: spectra map (for existing projects)');
      return;
    }

    final dashboard = DashboardService(logger: logger, port: port);

    // Handle graceful shutdown
    late StreamSubscription<ProcessSignal> sigintSub;
    late StreamSubscription<ProcessSignal> sigtermSub;

    Future<void> shutdown() async {
      logger.info('\nShutting down dashboard...');
      await dashboard.stop();
      await sigintSub.cancel();
      await sigtermSub.cancel();
      exit(0);
    }

    sigintSub = ProcessSignal.sigint.watch().listen((_) => shutdown());
    sigtermSub = ProcessSignal.sigterm.watch().listen((_) => shutdown());

    await dashboard.start();

    // Keep the process running
    await Completer<void>().future;
  }
}
