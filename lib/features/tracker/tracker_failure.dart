/// Categorized failure codes for tracker adapters.
///
/// These names mirror the Symphony spec (Section 11.4) so observability fields
/// stay consistent across adapters.
enum TrackerFailureCode {
  /// Tracker kind in `WORKFLOW.md` is not supported.
  unsupportedTrackerKind,

  /// Tracker API key was missing after env resolution.
  missingTrackerApiKey,

  /// Tracker project slug was missing or empty.
  missingTrackerProjectSlug,

  /// HTTP transport failure while talking to the tracker API.
  apiRequest,

  /// Tracker API returned a non-2xx HTTP status.
  apiStatus,

  /// Tracker GraphQL response surfaced top-level `errors`.
  graphqlErrors,

  /// Tracker payload could not be decoded into the expected shape.
  unknownPayload,

  /// Pagination response was missing the `endCursor` for `hasNextPage`.
  missingEndCursor,

  /// The local plan tracker could not parse `.spectra/PLAN.md`.
  localPlanParse,

  /// The local plan tracker could not find `.spectra/PLAN.md`.
  localPlanMissing,
}

/// Failure value returned by tracker adapters.
class TrackerFailure {
  /// Categorized failure code.
  final TrackerFailureCode code;

  /// Human-readable failure message for logs and dashboards.
  final String message;

  /// Underlying error, if any.
  final Object? cause;

  /// Creates a tracker failure.
  const TrackerFailure(this.code, this.message, {this.cause});

  @override
  String toString() => 'TrackerFailure(${code.name}): $message';
}

/// Result wrapper used by tracker operations.
///
/// This is intentionally a small, explicit `Either` rather than pulling in the
/// `dartz` package. Use [fold] to handle both arms.
sealed class TrackerResult<T> {
  const TrackerResult();

  /// Folds the result into a single value.
  R fold<R>(
    R Function(TrackerFailure failure) onFailure,
    R Function(T value) onSuccess,
  );

  /// Returns true when the result is a [TrackerSuccess].
  bool get isSuccess => this is TrackerSuccess<T>;

  /// Returns true when the result is a [TrackerError].
  bool get isFailure => this is TrackerError<T>;
}

/// Successful tracker result.
class TrackerSuccess<T> extends TrackerResult<T> {
  /// Successful value.
  final T value;

  /// Creates a successful result.
  const TrackerSuccess(this.value);

  @override
  R fold<R>(
    R Function(TrackerFailure failure) onFailure,
    R Function(T value) onSuccess,
  ) => onSuccess(value);
}

/// Failed tracker result.
class TrackerError<T> extends TrackerResult<T> {
  /// Underlying failure.
  final TrackerFailure failure;

  /// Creates a failed result.
  const TrackerError(this.failure);

  @override
  R fold<R>(
    R Function(TrackerFailure failure) onFailure,
    R Function(T value) onSuccess,
  ) => onFailure(failure);
}
