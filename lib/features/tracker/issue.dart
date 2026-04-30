/// Reference to an issue that blocks another issue.
class IssueBlocker {
  /// Tracker-internal id, when known.
  final String? id;

  /// Human-readable identifier, when known.
  final String? identifier;

  /// Current state of the blocker, when known.
  final String? state;

  /// Creates a blocker reference.
  const IssueBlocker({this.id, this.identifier, this.state});

  /// Builds a blocker from a JSON-style map.
  factory IssueBlocker.fromJson(Map<String, dynamic> json) => IssueBlocker(
    id: json['id'] as String?,
    identifier: json['identifier'] as String?,
    state: json['state'] as String?,
  );

  /// Serializes the blocker.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'identifier': identifier,
    'state': state,
  };
}

/// Normalized issue record used by orchestration, prompt rendering, and
/// observability output.
///
/// This shape matches the Symphony spec's `Issue` entity (Section 4.1.1) and is
/// the only issue representation seen by the scheduler, runner, and dashboard.
class Issue {
  /// Stable tracker-internal identifier.
  final String id;

  /// Human-readable ticket key (for example `SPEC-123`).
  final String identifier;

  /// Issue title.
  final String title;

  /// Optional descriptive body.
  final String? description;

  /// Optional priority. Lower numbers are higher priority for sorting.
  final int? priority;

  /// Current tracker state name.
  final String state;

  /// Optional tracker-provided branch name.
  final String? branchName;

  /// Optional URL to view the issue.
  final String? url;

  /// Lowercased label list.
  final List<String> labels;

  /// Issues that block this one.
  final List<IssueBlocker> blockedBy;

  /// Optional creation timestamp.
  final DateTime? createdAt;

  /// Optional last-update timestamp.
  final DateTime? updatedAt;

  /// Creates a normalized issue.
  const Issue({
    required this.id,
    required this.identifier,
    required this.title,
    required this.state,
    this.description,
    this.priority,
    this.branchName,
    this.url,
    this.labels = const <String>[],
    this.blockedBy = const <IssueBlocker>[],
    this.createdAt,
    this.updatedAt,
  });

  /// Returns a copy of this issue with the provided overrides.
  Issue copyWith({
    String? state,
    String? title,
    String? description,
    int? priority,
    List<String>? labels,
    List<IssueBlocker>? blockedBy,
    DateTime? updatedAt,
  }) {
    return Issue(
      id: id,
      identifier: identifier,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      state: state ?? this.state,
      branchName: branchName,
      url: url,
      labels: labels ?? this.labels,
      blockedBy: blockedBy ?? this.blockedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Builds an issue from a JSON-style map (used by the local plan adapter).
  factory Issue.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    final rawBlockers = json['blocked_by'];
    return Issue(
      id: json['id'] as String,
      identifier: json['identifier'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: json['priority'] is int ? json['priority'] as int : null,
      state: json['state'] as String,
      branchName: json['branch_name'] as String?,
      url: json['url'] as String?,
      labels: rawLabels is List
          ? rawLabels
                .whereType<String>()
                .map((s) => s.toLowerCase())
                .toList(growable: false)
          : const <String>[],
      blockedBy: rawBlockers is List
          ? rawBlockers
                .whereType<Map<String, dynamic>>()
                .map(IssueBlocker.fromJson)
                .toList(growable: false)
          : const <IssueBlocker>[],
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  /// Serializes the issue. Used by prompt rendering and observability.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'identifier': identifier,
    'title': title,
    'description': description,
    'priority': priority,
    'state': state,
    'branch_name': branchName,
    'url': url,
    'labels': labels,
    'blocked_by': blockedBy.map((b) => b.toJson()).toList(growable: false),
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
  };

  /// Returns the lowercased state for case-insensitive comparison.
  String get normalizedState => state.toLowerCase();

  /// Returns true when every blocker is in a recognized terminal state.
  ///
  /// Blockers without a known state are treated as still blocking, matching the
  /// Symphony Todo blocker rule.
  bool blockersAreTerminal(Set<String> terminalLowercased) {
    for (final blocker in blockedBy) {
      final state = blocker.state;
      if (state == null) {
        return false;
      }
      if (!terminalLowercased.contains(state.toLowerCase())) {
        return false;
      }
    }
    return true;
  }
}

DateTime? _parseDate(Object? raw) {
  if (raw is DateTime) {
    return raw;
  }
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw);
  }
  return null;
}
