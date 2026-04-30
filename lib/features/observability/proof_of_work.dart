import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-run "proof of work" artifact persisted under
/// `.spectra/runs/<run_id>/proof.md`.
///
/// Captures the diff summary, changed files, retry history, and final status
/// in a stable Markdown shape that operators can review without leaving the
/// dashboard.
class ProofOfWork {
  /// Run identifier (stable across retries).
  final String runId;

  /// Issue identifier the run is for.
  final String issueIdentifier;

  /// Workspace path where the worker ran.
  final String workspacePath;

  /// 1-based attempt count (1 for first run).
  final int attempt;

  /// Wall-clock start time.
  final DateTime startedAt;

  /// Wall-clock finish time.
  final DateTime endedAt;

  /// Whether the run succeeded.
  final bool succeeded;

  /// Files changed by the run, relative to the workspace root.
  final List<String> changedFiles;

  /// Hooks that ran and their final status (`succeeded`, `failed`, ...).
  final Map<String, String> hookStatuses;

  /// Retry history (most recent first).
  final List<String> retryHistory;

  /// Optional final recommendation (next action operators should take).
  final String? recommendation;

  /// Optional concatenated diff text (already truncated by the caller).
  final String? diffSummary;

  /// Creates a proof-of-work record.
  const ProofOfWork({
    required this.runId,
    required this.issueIdentifier,
    required this.workspacePath,
    required this.attempt,
    required this.startedAt,
    required this.endedAt,
    required this.succeeded,
    required this.changedFiles,
    required this.hookStatuses,
    required this.retryHistory,
    this.recommendation,
    this.diffSummary,
  });

  /// Persists the artifact to disk and returns the absolute path.
  Future<String> persist({String runsRoot = '.spectra/runs'}) async {
    final dir = Directory(p.join(runsRoot, runId));
    dir.createSync(recursive: true);
    final file = File(p.join(dir.path, 'proof.md'));
    file.writeAsStringSync(toMarkdown());
    return file.path;
  }

  /// Renders the artifact as Markdown.
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer
      ..writeln('# Proof of Work: $issueIdentifier')
      ..writeln()
      ..writeln('- Run id: `$runId`')
      ..writeln('- Workspace: `$workspacePath`')
      ..writeln('- Attempt: $attempt')
      ..writeln('- Started at: ${startedAt.toIso8601String()}')
      ..writeln('- Ended at: ${endedAt.toIso8601String()}')
      ..writeln('- Status: ${succeeded ? 'succeeded' : 'failed'}');

    if (recommendation != null && recommendation!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Recommendation')
        ..writeln(recommendation);
    }

    if (changedFiles.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Changed Files')
        ..writeln(changedFiles.map((f) => '- `$f`').join('\n'));
    }

    if (hookStatuses.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Hooks')
        ..writeln(
          hookStatuses.entries.map((e) => '- ${e.key}: ${e.value}').join('\n'),
        );
    }

    if (retryHistory.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Retry History')
        ..writeln(retryHistory.map((r) => '- $r').join('\n'));
    }

    if (diffSummary != null && diffSummary!.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Diff Summary')
        ..writeln('```diff')
        ..writeln(diffSummary)
        ..writeln('```');
    }

    return buffer.toString();
  }
}
