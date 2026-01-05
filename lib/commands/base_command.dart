import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';

/// Base class for all Spectra CLI commands.
///
/// Provides common functionality including logger access and
/// a consistent interface for command implementation.
abstract class SpectraCommand extends Command<void> {
  /// Logger for command output.
  final Logger logger;

  /// Creates a new Spectra command.
  SpectraCommand({required this.logger});
}
