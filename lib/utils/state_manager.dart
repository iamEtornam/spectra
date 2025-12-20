import 'dart:io';
import 'package:mason_logger/mason_logger.dart';

class StateManager {
  final Logger logger;

  StateManager({required this.logger});

  void pruneState() {
    final stateFile = File('.spectra/STATE.md');
    if (!stateFile.existsSync()) return;

    final lines = stateFile.readAsLinesSync();
    if (lines.length > 200) {
      logger.info('STATE.md exceeds 200 lines. Pruning...');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final historyDir = Directory('.spectra/history');
      if (!historyDir.existsSync()) {
        historyDir.createSync(recursive: true);
      }

      final archiveFile = File('.spectra/history/state-$timestamp.md');
      archiveFile.writeAsStringSync(lines.join('\n'));

      // Keep only the last 50 lines as context
      final prunedLines = lines.sublist(lines.length - 50);
      stateFile
          .writeAsStringSync('# STATE (Pruned)\n\n${prunedLines.join('\n')}');

      logger.success(
          'State pruned successfully. archived to ${archiveFile.path}');
    }
  }
}
