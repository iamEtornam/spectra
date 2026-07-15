import 'dart:io';

import 'package:spectra_cli/features/tracker/linear_tracker_client.dart';
import 'package:test/test.dart';

void main() {
  final apiKey = Platform.environment['LINEAR_API_KEY'];
  final projectSlug = Platform.environment['LINEAR_PROJECT_SLUG'];

  group(
    'LinearTrackerClient real integration',
    skip: apiKey == null || apiKey.isEmpty
        ? 'LINEAR_API_KEY not set; skipping real integration profile.'
        : null,
    () {
      test('fetchCandidates returns a list without throwing', () async {
        final client = LinearTrackerClient(
          endpoint: 'https://api.linear.app/graphql',
          apiKey: apiKey ?? '',
          projectSlug: projectSlug ?? '',
          activeStates: const <String>['Todo', 'In Progress'],
        );
        addTearDown(client.close);
        final result = await client.fetchCandidates();
        result.fold((failure) => fail('Linear request failed: $failure'), (
          issues,
        ) {
          expect(issues, isA<List<dynamic>>());
        });
      });
    },
  );
}
