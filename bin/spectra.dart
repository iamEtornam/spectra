import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:spectra/commands/config_command.dart';
import 'package:spectra/commands/new_command.dart';
import 'package:spectra/commands/map_command.dart';
import 'package:spectra/commands/plan_command.dart';
import 'package:spectra/commands/execute_command.dart';
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
    await runner.run(arguments);
  } catch (e) {
    logger.err(e.toString());
    exit(64);
  }
}
