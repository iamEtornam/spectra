import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spectra_cli/features/tracker/local_plan_tracker_client.dart';
import 'package:spectra_cli/features/tracker/tracker_failure.dart';
import 'package:test/test.dart';

const _samplePlan = '''
# PLAN: sample

<task id="1" type="implement">
  <n>Configure linting</n>
  <files><file action="create">analysis_options.yaml</file></files>
  <objective>Establish coding standards.</objective>
  <verification>Run dart analyze.</verification>
  <acceptance>feat: add analysis_options.yaml</acceptance>
</task>

<task id="2" type="refactor">
  <n>Extract models</n>
  <files><file action="create">lib/src/models/color_model.dart</file></files>
  <objective>Move color classes.</objective>
  <verification>Tests pass.</verification>
  <acceptance>refactor: move models</acceptance>
</task>
''';

void main() {
  group('LocalPlanTrackerClient', () {
    late Directory tempDir;
    late String previousCwd;

    setUp(() {
      previousCwd = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync('spectra_local_tracker_');
      Directory(p.join(tempDir.path, '.spectra')).createSync(recursive: true);
      File(
        p.join(tempDir.path, '.spectra', 'PLAN.md'),
      ).writeAsStringSync(_samplePlan);
      Directory.current = tempDir;
    });

    tearDown(() {
      Directory.current = previousCwd;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('parses tasks into normalized issues', () async {
      final tracker = LocalPlanTrackerClient();
      final result = await tracker.fetchCandidates();
      result.fold((failure) => fail('expected success but got $failure'), (
        issues,
      ) {
        expect(issues, hasLength(2));
        expect(issues.first.identifier, equals('PLAN-1'));
        expect(issues.first.title, equals('Configure linting'));
        expect(issues.first.state, equals('Todo'));
        expect(issues.first.labels, equals(<String>['implement']));
        expect(issues[1].identifier, equals('PLAN-2'));
        expect(issues[1].labels, equals(<String>['refactor']));
      });
    });

    test('uses ROADMAP.md checkboxes to derive state', () async {
      File(p.join(tempDir.path, '.spectra', 'ROADMAP.md')).writeAsStringSync('''
# Roadmap

- [ ] #1 - Configure linting
- [x] #2 - Extract models
''');

      final tracker = LocalPlanTrackerClient();
      final candidates = await tracker.fetchCandidates();
      candidates.fold((failure) => fail('expected success but got $failure'), (
        issues,
      ) {
        expect(issues.map((i) => i.identifier), equals(<String>['PLAN-1']));
        expect(issues.single.state, equals('Todo'));
      });

      final byState = await tracker.fetchByStates(const <String>['Done']);
      byState.fold((failure) => fail('expected success but got $failure'), (
        issues,
      ) {
        expect(issues, hasLength(1));
        expect(issues.single.identifier, equals('PLAN-2'));
      });
    });

    test('fetchStatesByIds short-circuits on empty input', () async {
      final tracker = LocalPlanTrackerClient();
      final result = await tracker.fetchStatesByIds(const <String>[]);
      expect(result.isSuccess, isTrue);
      result.fold(
        (failure) => fail('expected success'),
        (issues) => expect(issues, isEmpty),
      );
    });

    test('returns localPlanMissing when PLAN.md is absent', () async {
      File(p.join(tempDir.path, '.spectra', 'PLAN.md')).deleteSync();
      final tracker = LocalPlanTrackerClient();
      final result = await tracker.fetchCandidates();
      expect(result.isFailure, isTrue);
      result.fold(
        (failure) =>
            expect(failure.code, equals(TrackerFailureCode.localPlanMissing)),
        (_) => fail('expected failure'),
      );
    });

    test('parsePlanContent recovers task description text', () {
      final issues = LocalPlanTrackerClient.parsePlanContent(_samplePlan);
      expect(issues, hasLength(2));
      final first = issues.first;
      expect(first.description, contains('Establish coding standards.'));
      expect(first.description, contains('Files'));
    });
  });
}
