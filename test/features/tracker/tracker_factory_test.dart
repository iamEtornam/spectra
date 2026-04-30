import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spectra_cli/features/tracker/linear_tracker_client.dart';
import 'package:spectra_cli/features/tracker/local_plan_tracker_client.dart';
import 'package:spectra_cli/features/tracker/tracker_factory.dart';
import 'package:spectra_cli/features/tracker/tracker_failure.dart';
import 'package:spectra_cli/features/workflow/workflow.dart';
import 'package:test/test.dart';

WorkflowConfig _config(Map<String, dynamic> raw, {Map<String, String>? env}) {
  final definition = WorkflowDefinition(
    config: raw,
    promptTemplate: 'Prompt',
    path: p.join(Directory.current.path, 'WORKFLOW.md'),
  );
  return WorkflowConfig.fromDefinition(
    definition,
    environment: env ?? const <String, String>{},
  );
}

void main() {
  group('TrackerFactory', () {
    test('builds a LocalPlanTrackerClient when kind is local_plan', () {
      final config = _config(<String, dynamic>{
        'tracker': <String, dynamic>{'kind': 'local_plan'},
      });
      final result = const TrackerFactory().build(config);
      result.fold(
        (failure) => fail('expected success but got $failure'),
        (client) => expect(client, isA<LocalPlanTrackerClient>()),
      );
    });

    test('builds a LinearTrackerClient when kind is linear', () {
      final config = _config(<String, dynamic>{
        'tracker': <String, dynamic>{
          'kind': 'linear',
          'api_key': 'literal-token',
          'project_slug': 'spectra',
        },
      });
      final result = const TrackerFactory().build(config);
      result.fold(
        (failure) => fail('expected success but got $failure'),
        (client) => expect(client, isA<LinearTrackerClient>()),
      );
    });

    test('returns missingTrackerApiKey when Linear key is unresolved', () {
      final config = _config(<String, dynamic>{
        'tracker': <String, dynamic>{
          'kind': 'linear',
          'api_key': r'$LINEAR_API_KEY',
          'project_slug': 'spectra',
        },
      });
      final result = const TrackerFactory().build(config);
      result.fold(
        (failure) => expect(
          failure.code,
          equals(TrackerFailureCode.missingTrackerApiKey),
        ),
        (_) => fail('expected failure'),
      );
    });

    test('returns unsupportedTrackerKind for unknown kinds', () {
      final config = _config(<String, dynamic>{
        'tracker': <String, dynamic>{'kind': 'mystery'},
      });
      final result = const TrackerFactory().build(config);
      result.fold(
        (failure) => expect(
          failure.code,
          equals(TrackerFailureCode.unsupportedTrackerKind),
        ),
        (_) => fail('expected failure'),
      );
    });
  });
}
