import 'dart:async';
import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;
import 'package:spectra_cli/features/workflow/workflow.dart';
import 'package:test/test.dart';

const _initial = '''
---
tracker:
  kind: local_plan
polling:
  interval_ms: 1000
---
First version
''';

const _updated = '''
---
tracker:
  kind: local_plan
polling:
  interval_ms: 5000
---
Second version
''';

void main() {
  group('WorkflowWatcher', () {
    late Directory tempDir;
    late File workflowFile;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('spectra_watcher_');
      workflowFile = File(p.join(tempDir.path, 'WORKFLOW.md'));
      workflowFile.writeAsStringSync(_initial);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('start() returns the parsed workflow definition and config', () async {
      final watcher = WorkflowWatcher(
        workflowPath: workflowFile.path,
        logger: Logger(level: Level.quiet),
      );
      final reload = await watcher.start();
      addTearDown(watcher.stop);

      expect(reload.error, isNull);
      expect(
        reload.config.polling.interval,
        equals(const Duration(seconds: 1)),
      );
      expect(reload.definition.promptTemplate, equals('First version'));
    });

    test(
      'keeps last known good config when the next reload is invalid',
      () async {
        final watcher = WorkflowWatcher(
          workflowPath: workflowFile.path,
          logger: Logger(level: Level.quiet),
          debounce: const Duration(milliseconds: 50),
        );
        final initial = await watcher.start();
        addTearDown(watcher.stop);

        final updates = <WorkflowReload>[];
        final sub = watcher.reloads.listen(updates.add);
        addTearDown(sub.cancel);

        // Write a syntactically invalid front matter (no closing ---).
        workflowFile.writeAsStringSync('---\nbroken\n');
        await Future<void>.delayed(const Duration(milliseconds: 500));

        // Expectation: either we received an error reload that preserved the
        // previous config, or the reload silently failed and the watcher kept
        // the last known good values.
        expect(
          watcher.lastKnownGoodConfig?.polling.interval,
          equals(initial.config.polling.interval),
        );
      },
    );

    test('emits a reload payload when the workflow changes', () async {
      final watcher = WorkflowWatcher(
        workflowPath: workflowFile.path,
        logger: Logger(level: Level.quiet),
        debounce: const Duration(milliseconds: 50),
      );
      await watcher.start();
      addTearDown(watcher.stop);

      final completer = Completer<WorkflowReload>();
      final sub = watcher.reloads.listen((reload) {
        if (!completer.isCompleted) completer.complete(reload);
      });
      addTearDown(sub.cancel);

      // Wait briefly so the watcher is fully attached.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      workflowFile.writeAsStringSync(_updated);

      final reload = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('watcher did not emit a reload'),
      );
      expect(reload.error, isNull);
      expect(
        reload.config.polling.interval,
        equals(const Duration(seconds: 5)),
      );
      expect(reload.definition.promptTemplate, equals('Second version'));
    });
  });
}
