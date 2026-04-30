import 'package:spectra_cli/features/tracker/issue.dart';
import 'package:test/test.dart';

void main() {
  group('Issue', () {
    test('round-trips through JSON', () {
      final issue = Issue(
        id: 'abc',
        identifier: 'SPEC-1',
        title: 'Title',
        description: 'Body',
        priority: 2,
        state: 'In Progress',
        labels: const <String>['bug', 'urgent'],
        blockedBy: const <IssueBlocker>[
          IssueBlocker(id: 'b1', identifier: 'SPEC-2', state: 'Done'),
        ],
        createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
        updatedAt: DateTime.parse('2026-02-01T00:00:00Z'),
      );

      final json = issue.toJson();
      final decoded = Issue.fromJson(Map<String, dynamic>.from(json));

      expect(decoded.id, equals('abc'));
      expect(decoded.identifier, equals('SPEC-1'));
      expect(decoded.state, equals('In Progress'));
      expect(decoded.priority, equals(2));
      expect(decoded.labels, equals(<String>['bug', 'urgent']));
      expect(decoded.blockedBy.single.identifier, equals('SPEC-2'));
      expect(decoded.createdAt, equals(DateTime.parse('2026-01-01T00:00:00Z')));
    });

    test('lowercases labels when parsed from JSON', () {
      final issue = Issue.fromJson(<String, dynamic>{
        'id': 'a',
        'identifier': 'SPEC-9',
        'title': 'X',
        'state': 'Todo',
        'labels': <String>['Bug', 'URGENT'],
      });
      expect(issue.labels, equals(<String>['bug', 'urgent']));
    });

    test('blockersAreTerminal returns false when a blocker has no state', () {
      const issue = Issue(
        id: 'a',
        identifier: 'SPEC-10',
        title: 'X',
        state: 'Todo',
        blockedBy: <IssueBlocker>[
          IssueBlocker(id: null, identifier: null, state: null),
        ],
      );
      expect(issue.blockersAreTerminal(<String>{'done'}), isFalse);
    });

    test('blockersAreTerminal returns true when every state is terminal', () {
      const issue = Issue(
        id: 'a',
        identifier: 'SPEC-11',
        title: 'X',
        state: 'Todo',
        blockedBy: <IssueBlocker>[
          IssueBlocker(state: 'Done'),
          IssueBlocker(state: 'Cancelled'),
        ],
      );
      expect(issue.blockersAreTerminal(<String>{'done', 'cancelled'}), isTrue);
    });
  });
}
