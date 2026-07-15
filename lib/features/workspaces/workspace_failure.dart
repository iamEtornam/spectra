/// Failure codes for workspace operations.
enum WorkspaceFailureCode {
  /// Workspace path resolved outside the configured root.
  pathEscape,

  /// Workspace key was empty after sanitization.
  emptyKey,

  /// Workspace directory could not be created.
  createFailed,

  /// `git worktree add` failed.
  worktreeAddFailed,

  /// `git worktree remove` failed.
  worktreeRemoveFailed,

  /// A workspace lifecycle hook reported a non-zero exit.
  hookFailed,

  /// A workspace lifecycle hook timed out before completing.
  hookTimedOut,
}

/// Exception thrown by the workspace manager.
class WorkspaceException implements Exception {
  /// Categorized failure code.
  final WorkspaceFailureCode code;

  /// Human-readable message for logs and dashboards.
  final String message;

  /// Underlying error, if any.
  final Object? cause;

  /// Creates a workspace exception.
  const WorkspaceException(this.code, this.message, {this.cause});

  @override
  String toString() => 'WorkspaceException(${code.name}): $message';
}
