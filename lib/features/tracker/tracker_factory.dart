import 'package:http/http.dart' as http;

import '../workflow/workflow_config.dart';
import 'issue_tracker_client.dart';
import 'linear_tracker_client.dart';
import 'local_plan_tracker_client.dart';
import 'tracker_failure.dart';

/// Builds an [IssueTrackerClient] from a parsed [WorkflowConfig].
///
/// Returns a [TrackerResult] so callers can surface configuration mistakes
/// (missing API key, unsupported kind) as operator-visible scheduler errors
/// instead of throwing.
class TrackerFactory {
  /// Optional shared HTTP client for adapters that perform network calls.
  final http.Client? httpClient;

  /// Creates a tracker factory.
  const TrackerFactory({this.httpClient});

  /// Resolves the tracker adapter for [config].
  TrackerResult<IssueTrackerClient> build(WorkflowConfig config) {
    final kind = config.tracker.kind;
    if (kind == null || kind.isEmpty) {
      return const TrackerError<IssueTrackerClient>(
        TrackerFailure(
          TrackerFailureCode.unsupportedTrackerKind,
          'tracker.kind is required.',
        ),
      );
    }

    switch (kind) {
      case 'linear':
        try {
          return TrackerSuccess<IssueTrackerClient>(
            LinearTrackerClient.fromConfig(config, httpClient: httpClient),
          );
        } on TrackerFailure catch (failure) {
          return TrackerError<IssueTrackerClient>(failure);
        }
      case 'local_plan':
        return TrackerSuccess<IssueTrackerClient>(
          LocalPlanTrackerClient.fromConfig(config),
        );
      default:
        return TrackerError<IssueTrackerClient>(
          TrackerFailure(
            TrackerFailureCode.unsupportedTrackerKind,
            'Unsupported tracker.kind: $kind.',
          ),
        );
    }
  }
}
