import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

abstract class SpectraCommand extends Command {
  final Logger logger;

  SpectraCommand({required this.logger});
}
