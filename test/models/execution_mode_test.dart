import 'package:test/test.dart';
import 'package:spectra_cli/models/execution_mode.dart';

void main() {
  group('ExecutionMode', () {
    test('should have three execution modes', () {
      expect(ExecutionMode.values.length, equals(3));
      expect(ExecutionMode.values, contains(ExecutionMode.automatic));
      expect(ExecutionMode.values, contains(ExecutionMode.manual));
      expect(ExecutionMode.values, contains(ExecutionMode.interactive));
    });

    group('automatic', () {
      test('should have correct description', () {
        final description = ExecutionMode.automatic.description;

        expect(description.toLowerCase(), contains('automatic'));
        expect(description.toLowerCase(), contains('code'));
      });

      test('should generate code automatically', () {
        expect(ExecutionMode.automatic.generatesCode, isTrue);
        expect(ExecutionMode.automatic.requiresApproval, isFalse);
      });

      test('should have full automation', () {
        final level = ExecutionMode.automatic.automationLevel;
        expect(level.toLowerCase(), contains('full'));
      });

      test('should have appropriate use cases', () {
        final useCases = ExecutionMode.automatic.useCases;

        expect(useCases, isNotEmpty);
        expect(
          useCases.any(
            (uc) =>
                uc.toLowerCase().contains('prototype') ||
                uc.toLowerCase().contains('rapid') ||
                uc.toLowerCase().contains('greenfield'),
          ),
          isTrue,
        );
      });
    });

    group('manual', () {
      test('should have correct description', () {
        final description = ExecutionMode.manual.description;

        expect(description.toLowerCase(), contains('manual'));
        expect(description.toLowerCase(), contains('plan'));
      });

      test('should not generate code automatically', () {
        expect(ExecutionMode.manual.generatesCode, isFalse);
        expect(ExecutionMode.manual.requiresApproval, isTrue);
      });

      test('should be planning only', () {
        final level = ExecutionMode.manual.automationLevel;
        expect(level.toLowerCase(), contains('planning'));
      });

      test('should have appropriate use cases', () {
        final useCases = ExecutionMode.manual.useCases;

        expect(useCases, isNotEmpty);
        expect(
          useCases.any((uc) => uc.toLowerCase().contains('learn')),
          isTrue,
        );
      });
    });

    group('interactive', () {
      test('should have correct description', () {
        final description = ExecutionMode.interactive.description;

        expect(description.toLowerCase(), contains('review'));
        expect(description.toLowerCase(), contains('approve'));
      });

      test('should generate code but require approval', () {
        expect(ExecutionMode.interactive.generatesCode, isTrue);
        expect(ExecutionMode.interactive.requiresApproval, isTrue);
      });

      test('should be semi-automatic', () {
        final level = ExecutionMode.interactive.automationLevel;
        expect(level.toLowerCase(), contains('semi'));
      });

      test('should have appropriate use cases', () {
        final useCases = ExecutionMode.interactive.useCases;

        expect(useCases, isNotEmpty);
        expect(
          useCases.any((uc) => uc.toLowerCase().contains('production')),
          isTrue,
        );
      });
    });

    test('modes should have distinct automation levels', () {
      expect(
        ExecutionMode.automatic.automationLevel,
        isNot(equals(ExecutionMode.manual.automationLevel)),
      );
      expect(
        ExecutionMode.manual.automationLevel,
        isNot(equals(ExecutionMode.interactive.automationLevel)),
      );
    });

    test('code generation should be correct per mode', () {
      expect(ExecutionMode.automatic.generatesCode, isTrue);
      expect(ExecutionMode.manual.generatesCode, isFalse);
      expect(ExecutionMode.interactive.generatesCode, isTrue);
    });

    test('approval requirements should be correct per mode', () {
      expect(ExecutionMode.automatic.requiresApproval, isFalse);
      expect(ExecutionMode.manual.requiresApproval, isTrue);
      expect(ExecutionMode.interactive.requiresApproval, isTrue);
    });

    test('should work with switch expressions', () {
      final result = switch (ExecutionMode.manual) {
        ExecutionMode.automatic => 'auto',
        ExecutionMode.manual => 'manual',
        ExecutionMode.interactive => 'interactive',
      };

      expect(result, equals('manual'));
    });

    test('use cases should be unique per mode', () {
      final autoUseCases = ExecutionMode.automatic.useCases;
      final manualUseCases = ExecutionMode.manual.useCases;
      final interactiveUseCases = ExecutionMode.interactive.useCases;

      expect(autoUseCases, isNot(equals(manualUseCases)));
      expect(manualUseCases, isNot(equals(interactiveUseCases)));
    });

    test('descriptions should clearly differentiate modes', () {
      final auto = ExecutionMode.automatic.description;
      final manual = ExecutionMode.manual.description;
      final interactive = ExecutionMode.interactive.description;

      expect(auto, isNot(equals(manual)));
      expect(manual, isNot(equals(interactive)));
      expect(auto, isNot(equals(interactive)));
    });
  });
}
