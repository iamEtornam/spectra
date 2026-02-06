import 'package:test/test.dart';
import 'package:spectra_cli/models/llm_usage_type.dart';

void main() {
  group('LLMUsageType', () {
    test('should have two usage types', () {
      expect(LLMUsageType.values.length, equals(2));
      expect(LLMUsageType.values, contains(LLMUsageType.planning));
      expect(LLMUsageType.values, contains(LLMUsageType.coding));
    });

    group('planning', () {
      test('should have correct description', () {
        final description = LLMUsageType.planning.description;

        expect(description.toLowerCase(), contains('planning'));
        expect(
          description.toLowerCase(),
          anyOf(contains('strategic'), contains('documentation')),
        );
      });

      test('should have examples', () {
        final examples = LLMUsageType.planning.examples;

        expect(examples, isNotEmpty);
        expect(examples.length, greaterThanOrEqualTo(2));
        expect(
          examples.any((e) => e.contains('plan') || e.contains('map')),
          isTrue,
        );
      });

      test('should have recommended providers', () {
        final providers = LLMUsageType.planning.recommendedProviders;

        expect(providers, isNotEmpty);
        expect(providers.length, greaterThanOrEqualTo(2));
        expect(
          providers.any((p) => p.toLowerCase().contains('claude')),
          isTrue,
        );
      });
    });

    group('coding', () {
      test('should have correct description', () {
        final description = LLMUsageType.coding.description;

        expect(description.toLowerCase(), contains('code'));
        expect(
          description.toLowerCase(),
          anyOf(contains('generation'), contains('implementation')),
        );
      });

      test('should have examples', () {
        final examples = LLMUsageType.coding.examples;

        expect(examples, isNotEmpty);
        expect(examples.length, greaterThanOrEqualTo(2));
        expect(
          examples.any((e) => e.contains('execute') || e.contains('start')),
          isTrue,
        );
      });

      test('should have recommended providers', () {
        final providers = LLMUsageType.coding.recommendedProviders;

        expect(providers, isNotEmpty);
        expect(providers.length, greaterThanOrEqualTo(2));
        expect(
          providers.any(
            (p) =>
                p.toLowerCase().contains('gemini') ||
                p.toLowerCase().contains('deepseek'),
          ),
          isTrue,
        );
      });
    });

    test('examples should be unique between types', () {
      final planningExamples = LLMUsageType.planning.examples;
      final codingExamples = LLMUsageType.coding.examples;

      // Some examples might overlap, but they should be mostly distinct
      final overlap = planningExamples
          .where((e) => codingExamples.contains(e))
          .toList();

      expect(overlap.length, lessThan(planningExamples.length));
    });

    test('should provide clear differentiation between types', () {
      const planning = LLMUsageType.planning;
      const coding = LLMUsageType.coding;

      expect(planning.description, isNot(equals(coding.description)));
      expect(planning.examples, isNot(equals(coding.examples)));
    });

    test('switch expression should work with enum', () {
      final testResult = switch (LLMUsageType.planning) {
        LLMUsageType.planning => 'plan',
        LLMUsageType.coding => 'code',
      };

      expect(testResult, equals('plan'));
    });
  });
}
