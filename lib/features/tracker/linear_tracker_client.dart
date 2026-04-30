import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../workflow/workflow_config.dart';
import 'issue.dart';
import 'issue_tracker_client.dart';
import 'tracker_failure.dart';

/// Symphony-spec compatible Linear tracker adapter.
///
/// Uses Linear's GraphQL API at the configured endpoint and filters by
/// `project.slugId == config.tracker.project_slug`.
class LinearTrackerClient implements IssueTrackerClient {
  /// HTTP client used for requests. Injectable for tests.
  final http.Client httpClient;

  /// GraphQL endpoint URL.
  final String endpoint;

  /// Linear API key sent in the `Authorization` header.
  final String apiKey;

  /// Linear project slug used as `project.slugId`.
  final String projectSlug;

  /// Active tracker states for candidate fetching.
  final List<String> activeStates;

  /// Pagination size; the spec recommends 50.
  final int pageSize;

  /// Per-request timeout (Symphony recommends 30 seconds).
  final Duration timeout;

  /// Whether the underlying http client is owned by this adapter.
  final bool _ownsClient;

  /// Creates a Linear tracker client.
  LinearTrackerClient({
    required this.endpoint,
    required this.apiKey,
    required this.projectSlug,
    required this.activeStates,
    http.Client? httpClient,
    this.pageSize = 50,
    this.timeout = const Duration(seconds: 30),
  }) : httpClient = httpClient ?? http.Client(),
       _ownsClient = httpClient == null;

  /// Builds a Linear client pre-wired from a [WorkflowConfig].
  ///
  /// Throws a [TrackerFailure]-equivalent error when the config is missing the
  /// required fields. Callers SHOULD prefer the tracker factory which surfaces
  /// the error as a [TrackerResult].
  factory LinearTrackerClient.fromConfig(
    WorkflowConfig config, {
    http.Client? httpClient,
  }) {
    final apiKey = config.tracker.apiKey;
    final slug = config.tracker.projectSlug;
    if (apiKey == null || apiKey.isEmpty) {
      throw const TrackerFailure(
        TrackerFailureCode.missingTrackerApiKey,
        'Linear tracker requires tracker.api_key (LINEAR_API_KEY).',
      );
    }
    if (slug == null || slug.isEmpty) {
      throw const TrackerFailure(
        TrackerFailureCode.missingTrackerProjectSlug,
        'Linear tracker requires tracker.project_slug.',
      );
    }
    return LinearTrackerClient(
      endpoint: config.tracker.endpoint,
      apiKey: apiKey,
      projectSlug: slug,
      activeStates: config.tracker.activeStates,
      httpClient: httpClient,
    );
  }

  @override
  String get kind => 'linear';

  static const _candidateQuery = r'''
query SpectraCandidates($projectSlug: String!, $stateNames: [String!]!, $first: Int!, $after: String) {
  issues(
    first: $first
    after: $after
    filter: {
      project: { slugId: { eq: $projectSlug } }
      state: { name: { in: $stateNames } }
    }
  ) {
    pageInfo { hasNextPage endCursor }
    nodes {
      id identifier title description priority branchName url
      createdAt updatedAt
      state { name }
      labels(first: 50) { nodes { name } }
      inverseRelations(first: 50) {
        nodes {
          type
          issue { id identifier state { name } }
        }
      }
    }
  }
}
''';

  static const _stateRefreshQuery = r'''
query SpectraIssueStates($ids: [ID!]!) {
  issues(filter: { id: { in: $ids } }) {
    nodes {
      id identifier title state { name }
    }
  }
}
''';

  static const _issuesByStateQuery = r'''
query SpectraIssuesByState($projectSlug: String!, $stateNames: [String!]!, $first: Int!, $after: String) {
  issues(
    first: $first
    after: $after
    filter: {
      project: { slugId: { eq: $projectSlug } }
      state: { name: { in: $stateNames } }
    }
  ) {
    pageInfo { hasNextPage endCursor }
    nodes {
      id identifier title state { name }
    }
  }
}
''';

  @override
  Future<TrackerResult<List<Issue>>> fetchCandidates() async {
    return _paginatedQuery(
      query: _candidateQuery,
      stateNames: activeStates,
      mapper: _mapCandidateNode,
    );
  }

  @override
  Future<TrackerResult<List<Issue>>> fetchStatesByIds(
    List<String> issueIds,
  ) async {
    if (issueIds.isEmpty) {
      return const TrackerSuccess<List<Issue>>(<Issue>[]);
    }

    final result = await _executeRequest(
      query: _stateRefreshQuery,
      variables: <String, Object?>{'ids': issueIds},
    );

    return result.fold(TrackerError<List<Issue>>.new, (data) {
      final issuesNode =
          (data['issues'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      final nodes =
          (issuesNode['nodes'] as List<dynamic>?) ?? const <dynamic>[];
      final issues = nodes
          .whereType<Map<String, dynamic>>()
          .map(_mapStateRefreshNode)
          .whereType<Issue>()
          .toList(growable: false);
      return TrackerSuccess<List<Issue>>(issues);
    });
  }

  @override
  Future<TrackerResult<List<Issue>>> fetchByStates(
    List<String> stateNames,
  ) async {
    if (stateNames.isEmpty) {
      return const TrackerSuccess<List<Issue>>(<Issue>[]);
    }

    return _paginatedQuery(
      query: _issuesByStateQuery,
      stateNames: stateNames,
      mapper: _mapStateRefreshNode,
    );
  }

  Future<TrackerResult<List<Issue>>> _paginatedQuery({
    required String query,
    required List<String> stateNames,
    required Issue? Function(Map<String, dynamic> node) mapper,
  }) async {
    final issues = <Issue>[];
    String? cursor;

    while (true) {
      final variables = <String, Object?>{
        'projectSlug': projectSlug,
        'stateNames': stateNames,
        'first': pageSize,
        'after': ?cursor,
      };

      final response = await _executeRequest(
        query: query,
        variables: variables,
      );

      final TrackerResult<List<Issue>>?
      early = response.fold<TrackerResult<List<Issue>>?>(
        TrackerError<List<Issue>>.new,
        (data) {
          final issuesNode =
              (data['issues'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};
          final nodes =
              (issuesNode['nodes'] as List<dynamic>?) ?? const <dynamic>[];
          for (final node in nodes.whereType<Map<String, dynamic>>()) {
            final issue = mapper(node);
            if (issue != null) {
              issues.add(issue);
            }
          }
          final pageInfo =
              (issuesNode['pageInfo'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};
          final hasNext = pageInfo['hasNextPage'] == true;
          final endCursor = pageInfo['endCursor'] as String?;
          if (!hasNext) {
            return TrackerSuccess<List<Issue>>(issues);
          }
          if (endCursor == null || endCursor.isEmpty) {
            return const TrackerError<List<Issue>>(
              TrackerFailure(
                TrackerFailureCode.missingEndCursor,
                'Linear pagination reported hasNextPage but omitted endCursor.',
              ),
            );
          }
          cursor = endCursor;
          return null;
        },
      );

      if (early != null) {
        return early;
      }
    }
  }

  Future<TrackerResult<Map<String, dynamic>>> _executeRequest({
    required String query,
    required Map<String, Object?> variables,
  }) async {
    final body = jsonEncode(<String, Object?>{
      'query': query,
      'variables': variables,
    });

    final http.Response response;
    try {
      response = await httpClient
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': apiKey,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      return TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.apiRequest,
          'Linear request timed out after ${timeout.inSeconds}s.',
          cause: e,
        ),
      );
    } catch (e) {
      return TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.apiRequest,
          'Linear request failed: $e',
          cause: e,
        ),
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.apiStatus,
          'Linear request returned HTTP ${response.statusCode}.',
        ),
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      return TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.unknownPayload,
          'Linear response was not valid JSON.',
          cause: e,
        ),
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.unknownPayload,
          'Linear response root was not a JSON object.',
        ),
      );
    }

    final errors = decoded['errors'];
    if (errors is List && errors.isNotEmpty) {
      final messages = errors
          .whereType<Map<String, dynamic>>()
          .map((e) => e['message']?.toString() ?? 'unknown error')
          .join('; ');
      return TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.graphqlErrors,
          'Linear GraphQL errors: $messages',
        ),
      );
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      return const TrackerError<Map<String, dynamic>>(
        TrackerFailure(
          TrackerFailureCode.unknownPayload,
          'Linear response was missing the data object.',
        ),
      );
    }

    return TrackerSuccess<Map<String, dynamic>>(data);
  }

  Issue? _mapCandidateNode(Map<String, dynamic> node) {
    final id = node['id'] as String?;
    final identifier = node['identifier'] as String?;
    final title = node['title'] as String?;
    final stateNode = node['state'] as Map<String, dynamic>?;
    final stateName = stateNode?['name'] as String?;
    if (id == null ||
        identifier == null ||
        title == null ||
        stateName == null) {
      return null;
    }

    final labelsNode = node['labels'] as Map<String, dynamic>?;
    final labelNodes =
        (labelsNode?['nodes'] as List<dynamic>?) ?? const <dynamic>[];
    final labels = labelNodes
        .whereType<Map<String, dynamic>>()
        .map((n) => (n['name'] as String?)?.toLowerCase())
        .whereType<String>()
        .toList(growable: false);

    final inverseNode = node['inverseRelations'] as Map<String, dynamic>?;
    final relationNodes =
        (inverseNode?['nodes'] as List<dynamic>?) ?? const <dynamic>[];
    final blockers = <IssueBlocker>[];
    for (final rel in relationNodes.whereType<Map<String, dynamic>>()) {
      if ((rel['type'] as String?) != 'blocks') continue;
      final relIssue = rel['issue'];
      if (relIssue is! Map<String, dynamic>) continue;
      final relState = relIssue['state'];
      blockers.add(
        IssueBlocker(
          id: relIssue['id'] as String?,
          identifier: relIssue['identifier'] as String?,
          state: relState is Map<String, dynamic>
              ? relState['name'] as String?
              : null,
        ),
      );
    }

    return Issue(
      id: id,
      identifier: identifier,
      title: title,
      description: node['description'] as String?,
      priority: node['priority'] is num
          ? (node['priority'] as num).toInt()
          : null,
      state: stateName,
      branchName: node['branchName'] as String?,
      url: node['url'] as String?,
      labels: labels,
      blockedBy: blockers,
      createdAt: _parseDate(node['createdAt']),
      updatedAt: _parseDate(node['updatedAt']),
    );
  }

  Issue? _mapStateRefreshNode(Map<String, dynamic> node) {
    final id = node['id'] as String?;
    final identifier = node['identifier'] as String?;
    final title = node['title'] as String? ?? '';
    final stateNode = node['state'] as Map<String, dynamic>?;
    final stateName = stateNode?['name'] as String?;
    if (id == null || identifier == null || stateName == null) {
      return null;
    }
    return Issue(
      id: id,
      identifier: identifier,
      title: title,
      state: stateName,
    );
  }

  @override
  Future<void> close() async {
    if (_ownsClient) {
      httpClient.close();
    }
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
