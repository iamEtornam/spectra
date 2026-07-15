import 'package:spectra_cli/features/runner/prompt_renderer.dart';
import 'package:spectra_cli/features/tracker/issue.dart';
import 'package:spectra_cli/features/workflow/workflow_failure.dart';
import 'package:test/test.dart';

const _issue = Issue(
  id: 'abc',
  identifier: 'SPEC-9',
  title: 'Refactor login',
  state: 'In Progress',
  labels: <String>['bug', 'urgent'],
);

void main() {
  group('PromptRenderer', () {
    test('renders {{ issue.identifier }} and {{ attempt }}', () {
      const template =
          'Issue {{ issue.identifier }} ({{ issue.title }}). Attempt {{ attempt }}.';
      final rendered = const PromptRenderer().render(
        template,
        issue: _issue,
        attempt: 3,
      );
      expect(rendered, equals('Issue SPEC-9 (Refactor login). Attempt 3.'));
    });

    test('falls back to default prompt when template is empty', () {
      final rendered = const PromptRenderer().render('   ', issue: _issue);
      expect(rendered, equals('You are working on an issue from Spectra.'));
    });

    test('handles {% if %} / {% else %} branches', () {
      const template =
          '{% if issue.priority %}Pri {{ issue.priority }}{% else %}No priority{% endif %}';
      final rendered = const PromptRenderer().render(template, issue: _issue);
      expect(rendered, equals('No priority'));
    });

    test('handles {% for %} loops over labels', () {
      const template =
          'Labels:{% for label in issue.labels %} - {{ label }}{% endfor %}';
      final rendered = const PromptRenderer().render(template, issue: _issue);
      expect(rendered, equals('Labels: - bug - urgent'));
    });

    test('throws templateRenderError on unknown variables', () {
      expect(
        () => const PromptRenderer().render(
          'Hello {{ unknown.value }}',
          issue: _issue,
        ),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.templateRenderError,
          ),
        ),
      );
    });

    test('throws templateParseError on filters', () {
      expect(
        () => const PromptRenderer().render(
          '{{ issue.title | upcase }}',
          issue: _issue,
        ),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.templateParseError,
          ),
        ),
      );
    });

    test('throws when {% if %} is unterminated', () {
      expect(
        () => const PromptRenderer().render(
          '{% if issue.title %} hello',
          issue: _issue,
        ),
        throwsA(
          isA<WorkflowException>().having(
            (e) => e.code,
            'code',
            WorkflowFailureCode.templateParseError,
          ),
        ),
      );
    });
  });
}
