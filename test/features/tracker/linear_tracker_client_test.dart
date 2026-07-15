import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spectra_cli/features/tracker/linear_tracker_client.dart';
import 'package:spectra_cli/features/tracker/tracker_failure.dart';
import 'package:test/test.dart';

LinearTrackerClient _client(MockClient inner) => LinearTrackerClient(
  endpoint: 'https://api.linear.app/graphql',
  apiKey: 'test-token',
  projectSlug: 'spectra',
  activeStates: const <String>['Todo', 'In Progress'],
  httpClient: inner,
);

void main() {
  group('LinearTrackerClient', () {
    test('paginates candidate issues across two pages', () async {
      var calls = 0;
      final client = _client(
        MockClient((request) async {
          calls += 1;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final variables = body['variables'] as Map<String, dynamic>;
          expect(variables['projectSlug'], equals('spectra'));
          expect(
            variables['stateNames'],
            equals(<String>['Todo', 'In Progress']),
          );
          if (calls == 1) {
            expect(variables.containsKey('after'), isFalse);
            return http.Response(
              jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'issues': <String, dynamic>{
                    'pageInfo': <String, dynamic>{
                      'hasNextPage': true,
                      'endCursor': 'cursor-1',
                    },
                    'nodes': <Map<String, dynamic>>[
                      <String, dynamic>{
                        'id': '1',
                        'identifier': 'SPEC-1',
                        'title': 'A',
                        'description': null,
                        'priority': 2,
                        'state': <String, dynamic>{'name': 'Todo'},
                        'labels': <String, dynamic>{
                          'nodes': <Map<String, dynamic>>[
                            <String, dynamic>{'name': 'Bug'},
                          ],
                        },
                        'inverseRelations': <String, dynamic>{
                          'nodes': <Map<String, dynamic>>[
                            <String, dynamic>{
                              'type': 'blocks',
                              'issue': <String, dynamic>{
                                'id': '99',
                                'identifier': 'SPEC-99',
                                'state': <String, dynamic>{'name': 'Todo'},
                              },
                            },
                          ],
                        },
                      },
                    ],
                  },
                },
              }),
              200,
              headers: <String, String>{'Content-Type': 'application/json'},
            );
          }
          expect(variables['after'], equals('cursor-1'));
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'issues': <String, dynamic>{
                  'pageInfo': <String, dynamic>{
                    'hasNextPage': false,
                    'endCursor': null,
                  },
                  'nodes': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': '2',
                      'identifier': 'SPEC-2',
                      'title': 'B',
                      'state': <String, dynamic>{'name': 'In Progress'},
                    },
                  ],
                },
              },
            }),
            200,
            headers: <String, String>{'Content-Type': 'application/json'},
          );
        }),
      );

      final result = await client.fetchCandidates();
      result.fold((failure) => fail('expected success but got $failure'), (
        issues,
      ) {
        expect(calls, equals(2));
        expect(issues, hasLength(2));
        expect(issues.first.identifier, equals('SPEC-1'));
        expect(issues.first.labels, equals(<String>['bug']));
        expect(issues.first.blockedBy.single.identifier, equals('SPEC-99'));
        expect(issues[1].identifier, equals('SPEC-2'));
      });
    });

    test('fetchStatesByIds returns empty result without HTTP call', () async {
      final client = _client(
        MockClient((_) async {
          fail('HTTP should not be called');
        }),
      );

      final result = await client.fetchStatesByIds(const <String>[]);
      expect(result.isSuccess, isTrue);
    });

    test('fetchStatesByIds maps state nodes', () async {
      final client = _client(
        MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(
            body['variables'],
            equals(<String, dynamic>{
              'ids': <String>['1'],
            }),
          );
          return http.Response(
            jsonEncode(<String, dynamic>{
              'data': <String, dynamic>{
                'issues': <String, dynamic>{
                  'nodes': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': '1',
                      'identifier': 'SPEC-1',
                      'title': 'A',
                      'state': <String, dynamic>{'name': 'Done'},
                    },
                  ],
                },
              },
            }),
            200,
            headers: <String, String>{'Content-Type': 'application/json'},
          );
        }),
      );

      final result = await client.fetchStatesByIds(const <String>['1']);
      result.fold((failure) => fail('expected success'), (issues) {
        expect(issues, hasLength(1));
        expect(issues.single.state, equals('Done'));
      });
    });

    test('reports apiStatus on non-2xx HTTP', () async {
      final client = _client(
        MockClient((_) async => http.Response('oops', 500)),
      );
      final result = await client.fetchCandidates();
      expect(result.isFailure, isTrue);
      result.fold(
        (failure) => expect(failure.code, equals(TrackerFailureCode.apiStatus)),
        (_) => fail('expected failure'),
      );
    });

    test('reports graphqlErrors when payload contains errors', () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{
              'errors': <Map<String, dynamic>>[
                <String, dynamic>{'message': 'no'},
              ],
            }),
            200,
            headers: <String, String>{'Content-Type': 'application/json'},
          ),
        ),
      );
      final result = await client.fetchCandidates();
      expect(result.isFailure, isTrue);
      result.fold(
        (failure) =>
            expect(failure.code, equals(TrackerFailureCode.graphqlErrors)),
        (_) => fail('expected failure'),
      );
    });

    test('reports unknownPayload when JSON shape is wrong', () async {
      final client = _client(
        MockClient(
          (_) async => http.Response(
            jsonEncode(<String, dynamic>{'data': 'not-an-object'}),
            200,
            headers: <String, String>{'Content-Type': 'application/json'},
          ),
        ),
      );
      final result = await client.fetchCandidates();
      result.fold(
        (failure) =>
            expect(failure.code, equals(TrackerFailureCode.unknownPayload)),
        (_) => fail('expected failure'),
      );
    });

    test(
      'reports missingEndCursor when hasNextPage but cursor is null',
      () async {
        final client = _client(
          MockClient(
            (_) async => http.Response(
              jsonEncode(<String, dynamic>{
                'data': <String, dynamic>{
                  'issues': <String, dynamic>{
                    'pageInfo': <String, dynamic>{
                      'hasNextPage': true,
                      'endCursor': null,
                    },
                    'nodes': <Map<String, dynamic>>[],
                  },
                },
              }),
              200,
              headers: <String, String>{'Content-Type': 'application/json'},
            ),
          ),
        );
        final result = await client.fetchCandidates();
        result.fold(
          (failure) =>
              expect(failure.code, equals(TrackerFailureCode.missingEndCursor)),
          (_) => fail('expected failure'),
        );
      },
    );
  });
}
