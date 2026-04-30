import 'dart:io';

import 'package:xml/xml.dart';

import '../workflow/workflow_config.dart';
import 'issue.dart';
import 'issue_tracker_client.dart';
import 'tracker_failure.dart';

/// Adapter that exposes `.spectra/PLAN.md` tasks as normalized [Issue]s.
///
/// This keeps the `spectra plan` -> `spectra start` flow working without an
/// external tracker. Task state is derived from `.spectra/ROADMAP.md` checkbox
/// markers when present, otherwise tasks default to `Todo`.
///
/// State conventions:
///
/// * `[ ] task name` -> `Todo`
/// * `[~] task name` or `[/] task name` -> `In Progress`
/// * `[x] task name` -> `Done`
class LocalPlanTrackerClient implements IssueTrackerClient {
  /// Project-relative or absolute path to `PLAN.md`.
  final String planPath;

  /// Optional path to `ROADMAP.md`.
  final String roadmapPath;

  /// Active states declared in workflow config (Symphony default
  /// `['Todo', 'In Progress']`).
  final List<String> activeStates;

  /// Terminal states declared in workflow config.
  final List<String> terminalStates;

  /// Creates a local plan tracker.
  LocalPlanTrackerClient({
    this.planPath = '.spectra/PLAN.md',
    this.roadmapPath = '.spectra/ROADMAP.md',
    this.activeStates = const <String>['Todo', 'In Progress'],
    this.terminalStates = const <String>['Done'],
  });

  /// Builds a tracker pre-wired from a [WorkflowConfig].
  factory LocalPlanTrackerClient.fromConfig(WorkflowConfig config) {
    return LocalPlanTrackerClient(
      activeStates: config.tracker.activeStates,
      terminalStates: config.tracker.terminalStates,
    );
  }

  @override
  String get kind => 'local_plan';

  @override
  Future<TrackerResult<List<Issue>>> fetchCandidates() async {
    final result = await _loadAllIssues();
    return result.fold(TrackerError<List<Issue>>.new, (issues) {
      final activeLowercased = activeStates.map((s) => s.toLowerCase()).toSet();
      final filtered = issues
          .where((i) => activeLowercased.contains(i.normalizedState))
          .toList(growable: false);
      return TrackerSuccess<List<Issue>>(filtered);
    });
  }

  @override
  Future<TrackerResult<List<Issue>>> fetchStatesByIds(
    List<String> issueIds,
  ) async {
    if (issueIds.isEmpty) {
      return const TrackerSuccess<List<Issue>>(<Issue>[]);
    }

    final result = await _loadAllIssues();
    return result.fold(TrackerError<List<Issue>>.new, (issues) {
      final wanted = issueIds.toSet();
      final filtered = issues
          .where((i) => wanted.contains(i.id))
          .toList(growable: false);
      return TrackerSuccess<List<Issue>>(filtered);
    });
  }

  @override
  Future<TrackerResult<List<Issue>>> fetchByStates(
    List<String> stateNames,
  ) async {
    if (stateNames.isEmpty) {
      return const TrackerSuccess<List<Issue>>(<Issue>[]);
    }

    final result = await _loadAllIssues();
    return result.fold(TrackerError<List<Issue>>.new, (issues) {
      final wanted = stateNames.map((s) => s.toLowerCase()).toSet();
      final filtered = issues
          .where((i) => wanted.contains(i.normalizedState))
          .toList(growable: false);
      return TrackerSuccess<List<Issue>>(filtered);
    });
  }

  @override
  Future<void> close() async {}

  Future<TrackerResult<List<Issue>>> _loadAllIssues() async {
    final planFile = File(planPath);
    if (!planFile.existsSync()) {
      return TrackerError<List<Issue>>(
        TrackerFailure(
          TrackerFailureCode.localPlanMissing,
          'PLAN.md not found at $planPath. Run `spectra plan` first.',
        ),
      );
    }

    final String content;
    try {
      content = await planFile.readAsString();
    } catch (e) {
      return TrackerError<List<Issue>>(
        TrackerFailure(
          TrackerFailureCode.localPlanParse,
          'Unable to read $planPath: $e',
          cause: e,
        ),
      );
    }

    final roadmapStates = await _readRoadmapStates();

    final List<Issue> issues;
    try {
      issues = parsePlanContent(content, statesById: roadmapStates);
    } catch (e) {
      return TrackerError<List<Issue>>(
        TrackerFailure(
          TrackerFailureCode.localPlanParse,
          'Unable to parse $planPath: $e',
          cause: e,
        ),
      );
    }

    return TrackerSuccess<List<Issue>>(issues);
  }

  Future<Map<String, String>> _readRoadmapStates() async {
    final roadmapFile = File(roadmapPath);
    if (!roadmapFile.existsSync()) {
      return const <String, String>{};
    }

    final lines = await roadmapFile.readAsLines();
    final states = <String, String>{};
    final regex = RegExp(
      r'^\s*-\s*\[([ xX~/])\]\s*(?:#?(\d+)\s*[-:]?\s*)?(.+)$',
    );
    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match == null) continue;

      final marker = match.group(1)!;
      final id = match.group(2);
      if (id == null) continue;

      final state = switch (marker) {
        'x' || 'X' => 'Done',
        '~' || '/' => 'In Progress',
        _ => 'Todo',
      };
      states[id] = state;
    }
    return states;
  }

  /// Parses `<task>` XML blocks from PLAN.md content into normalized issues.
  ///
  /// Visible for testing.
  static List<Issue> parsePlanContent(
    String content, {
    Map<String, String> statesById = const <String, String>{},
  }) {
    final taskRegex = RegExp(r'<task[^>]*>.*?</task>', dotAll: true);
    final matches = taskRegex.allMatches(content);
    final issues = <Issue>[];
    for (final match in matches) {
      final block = match.group(0)!;
      final XmlElement element;
      try {
        element = XmlDocument.parse(block).rootElement;
      } catch (_) {
        continue;
      }

      final id = element.getAttribute('id') ?? '';
      if (id.isEmpty) continue;

      final type = element.getAttribute('type') ?? 'implement';

      final nameElements = element.findElements('n');
      final title = nameElements.isNotEmpty
          ? nameElements.first.innerText.trim()
          : 'Task $id';

      final files = element
          .findElements('files')
          .expand((f) => f.findElements('file'))
          .map((f) => f.innerText.trim())
          .toList();

      final objective = _firstChildText(element, 'objective');
      final verification = _firstChildText(element, 'verification');
      final acceptance = _firstChildText(element, 'acceptance');

      final descriptionBuffer = StringBuffer();
      if (objective != null) {
        descriptionBuffer
          ..writeln('## Objective')
          ..writeln(objective);
      }
      if (verification != null) {
        descriptionBuffer
          ..writeln()
          ..writeln('## Verification')
          ..writeln(verification);
      }
      if (acceptance != null) {
        descriptionBuffer
          ..writeln()
          ..writeln('## Acceptance')
          ..writeln(acceptance);
      }
      if (files.isNotEmpty) {
        descriptionBuffer
          ..writeln()
          ..writeln('## Files')
          ..writeln(files.map((f) => '- $f').join('\n'));
      }

      final state = statesById[id] ?? 'Todo';

      issues.add(
        Issue(
          id: id,
          identifier: 'PLAN-$id',
          title: title,
          description: descriptionBuffer.isEmpty
              ? null
              : descriptionBuffer.toString().trimRight(),
          priority: _safeParseInt(id),
          state: state,
          labels: <String>[type.toLowerCase()],
        ),
      );
    }
    return issues;
  }
}

String? _firstChildText(XmlElement element, String tag) {
  final children = element.findElements(tag);
  if (children.isEmpty) return null;
  final text = children.first.innerText.trim();
  return text.isEmpty ? null : text;
}

int? _safeParseInt(String value) {
  return int.tryParse(value);
}
