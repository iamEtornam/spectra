/// Per-issue workspace returned by [WorkspaceManager].
class Workspace {
  /// Sanitized workspace key derived from the issue identifier.
  final String workspaceKey;

  /// Absolute filesystem path where the agent will run.
  final String path;

  /// Branch name backing the worktree (also stable across reuse).
  final String branchName;

  /// True when this workspace was created during the current call.
  ///
  /// Used to gate `after_create` hook execution.
  final bool createdNow;

  /// Creates a workspace value object.
  const Workspace({
    required this.workspaceKey,
    required this.path,
    required this.branchName,
    required this.createdNow,
  });

  @override
  String toString() =>
      'Workspace(key: $workspaceKey, path: $path, branch: $branchName, '
      'createdNow: $createdNow)';
}
