import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:spectra/commands/config_command.dart';
import 'package:spectra/commands/execute_command.dart';
import 'package:spectra/commands/map_command.dart';
import 'package:spectra/commands/new_command.dart';
import 'package:spectra/commands/plan_command.dart';
import 'package:spectra/commands/progress_command.dart';
import 'package:spectra/commands/resume_command.dart';

Future<void> main(List<String> arguments) async {
  final logger = Logger();
  final runner = CommandRunner(
      'spectra', 'Spectra - A Multi-LLM Spec-Driven Development System')
    ..addCommand(ConfigCommand(logger: logger))
    ..addCommand(NewCommand(logger: logger))
    ..addCommand(MapCommand(logger: logger))
    ..addCommand(PlanCommand(logger: logger))
    ..addCommand(ExecuteCommand(logger: logger))
    ..addCommand(ProgressCommand(logger: logger))
    ..addCommand(ResumeCommand(logger: logger));

  try {
    if (arguments.isEmpty ||
        arguments.first == 'help' ||
        arguments.contains('-h') ||
        arguments.contains('--help')) {
      logger.info(lightCyan.wrap('''
  ███████╗██████╗ ███████╗ ██████╗████████╗██████╗  █████╗ 
  ██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔══██╗
  ███████╗██████╔╝█████╗  ██║        ██║   ██████╔╝███████║
  ╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██╔══██╗██╔══██║
  ███████║██║     ███████╗╚██████╗   ██║   ██║  ██║██║  ██║
  ╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝
''')!);
      logger.info('Spectra - A Multi-LLM Spec-Driven Development System\n');

      if (arguments.isEmpty) {
        logger.info('Usage: spectra <command> [arguments]\n');
        logger.info('Available Commands:');
        logger.info('  new           Initialize a new project');
        logger.info('  map           Analyze an existing repository');
        logger.info('  plan          Generate implementation tasks');
        logger.info('  execute       Run the execution engine');
        logger.info('  config        Configure API keys and models');
        logger.info('  progress      Show project status');
        logger.info('  resume        Continue from last task');
        logger.info('\nExamples:');
        logger.info('  spectra plan "Auth System"');
        logger.info('  spectra execute');
        logger.info('\nUse "spectra help <command>" for detailed information.');
        return;
      }
    }
    await runner.run(arguments);
  } catch (e) {
    logger.err(e.toString());
    exit(64);
  }
}
