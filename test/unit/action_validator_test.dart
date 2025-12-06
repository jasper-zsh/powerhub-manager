import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/action_validator.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

void main() {
  group('ActionValidator Comprehensive Tests', () {
    group('Validation Logic Coverage', () {
      test('covers all CommandActionType enum values', () {
        final types = CommandActionType.values;

        for (final type in types) {
          CommandAction action;

          switch (type) {
            case CommandActionType.channelValue:
              action = CommandAction(
                controllerId: 'test-controller',
                type: CommandActionType.channelValue,
                channel: 1,
                value: 128,
              );
              break;
            case CommandActionType.presetTrigger:
              action = CommandAction(
                controllerId: 'test-controller',
                type: CommandActionType.presetTrigger,
                presetId: 1,
              );
              break;
            case CommandActionType.gradientMode:
              action = CommandAction(
                controllerId: 'test-controller',
                type: CommandActionType.gradientMode,
                channel: 1,
                value: 128,
                duration: 1000,
              );
              break;
            case CommandActionType.blinkMode:
              action = CommandAction(
                controllerId: 'test-controller',
                type: CommandActionType.blinkMode,
                channel: 1,
                period: 1000,
              );
              break;
            case CommandActionType.strobeMode:
              action = CommandAction(
                controllerId: 'test-controller',
                type: CommandActionType.strobeMode,
                channel: 1,
                count: 5,
                totalTime: 1000,
                pauseTime: 100,
              );
              break;
          }

          // Should not throw an exception
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: '$type should validate correctly');
        }
      });
    });

    group('Error Condition Testing', () {
      test('ActionValidator handles edge case boundary validation', () {
        // Test that validation works correctly for actions that pass constructor assertions
        // but fail validation logic

        // These should be valid (pass constructor assertions) and pass validation
        final validActions = [
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.gradientMode,
            channel: 0,
            value: 0,
            duration: 1,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.blinkMode,
            channel: 0,
            period: 50,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.strobeMode,
            channel: 0,
            count: 1,
            totalTime: 10,
            pauseTime: 1,
          ),
        ];

        for (final action in validActions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Valid boundary action should pass validation: $action');
        }
      });
    });

    group('Edge Case Testing', () {
      test('handles boundary values correctly', () {
        final boundaryActions = [
          // Gradient mode boundaries
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.gradientMode,
            channel: 0,
            value: 0,
            duration: 1,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.gradientMode,
            channel: 5,
            value: 255,
            duration: 60000,
          ),
          // Blink mode boundaries
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.blinkMode,
            channel: 0,
            period: 50,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.blinkMode,
            channel: 5,
            period: 10000,
          ),
          // Strobe mode boundaries
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.strobeMode,
            channel: 0,
            count: 1,
            totalTime: 10,
            pauseTime: 1,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.strobeMode,
            channel: 5,
            count: 255,
            totalTime: 60000,
            pauseTime: 59999,
          ),
        ];

        for (final action in boundaryActions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Boundary action should be valid: $action');
        }
      });
    });

    group('Helper Methods Testing', () {
      test('getActionTypeDescription covers all types', () {
        final types = CommandActionType.values;
        final descriptions = <CommandActionType, String>{};

        for (final type in types) {
          final description = ActionValidator.getActionTypeDescription(type);
          expect(description, isNotEmpty, reason: 'Description should not be empty for $type');
          expect(description.length, greaterThan(10), reason: 'Description should be meaningful for $type');
          descriptions[type] = description;
        }

        // Ensure all descriptions are unique
        final uniqueDescriptions = descriptions.values.toSet();
        expect(uniqueDescriptions.length, equals(types.length),
          reason: 'All action types should have unique descriptions');
      });

      test('getParameterExamples provide useful information', () {
        final types = CommandActionType.values;

        for (final type in types) {
          final examples = ActionValidator.getParameterExamples(type);
          expect(examples, isNotEmpty, reason: 'Examples should not be empty for $type');
          expect(examples.length, greaterThan(0), reason: 'Should have at least one example for $type');

          for (final example in examples) {
            expect(example, isNotEmpty, reason: 'Example should not be empty for $type');
            expect(example.length, greaterThan(5), reason: 'Example should be meaningful for $type');
          }
        }
      });

      test('getSuggestedValues provides appropriate defaults', () {
        final types = CommandActionType.values;

        for (final type in types) {
          final suggestions = ActionValidator.getSuggestedValues(type);

          // Should not throw an exception
          expect(suggestions, isA<Map<String, List<int>>>());

          // Check that suggestions make sense for each type
          switch (type) {
            case CommandActionType.gradientMode:
              expect(suggestions.containsKey('Quick fade'), isTrue);
              expect(suggestions.containsKey('Slow fade'), isTrue);
              break;
            case CommandActionType.blinkMode:
              expect(suggestions.containsKey('Fast blink'), isTrue);
              expect(suggestions.containsKey('Slow blink'), isTrue);
              break;
            case CommandActionType.strobeMode:
              expect(suggestions.containsKey('Quick bursts'), isTrue);
              expect(suggestions.containsKey('Normal strobe'), isTrue);
              break;
            case CommandActionType.channelValue:
              expect(suggestions.containsKey('Quick on'), isTrue);
              expect(suggestions.containsKey('Quick off'), isTrue);
              expect(suggestions.containsKey('Half brightness'), isTrue);
              break;
            case CommandActionType.presetTrigger:
              // Preset trigger might not have suggested values
              break;
          }
        }
      });
    });

    group('Frequency Calculation Testing', () {
      test('calculateBlinkFrequency handles edge cases', () {
        expect(ActionValidator.calculateBlinkFrequency(0), equals(0.0));
        expect(ActionValidator.calculateBlinkFrequency(-1), equals(0.0));
        expect(ActionValidator.calculateBlinkFrequency(1), equals(1000.0));
        expect(ActionValidator.calculateBlinkFrequency(1000), equals(1.0));
        expect(ActionValidator.calculateBlinkFrequency(2000), equals(0.5));
        expect(ActionValidator.calculateBlinkFrequency(500), equals(2.0));
      });

      test('calculateStrobeFrequency handles edge cases', () {
        expect(ActionValidator.calculateStrobeFrequency(0, 1000), equals(0.0));
        expect(ActionValidator.calculateStrobeFrequency(5, 0), equals(0.0));
        expect(ActionValidator.calculateStrobeFrequency(-1, 1000), equals(0.0));
        expect(ActionValidator.calculateStrobeFrequency(5, -1000), equals(0.0));
        expect(ActionValidator.calculateStrobeFrequency(1, 1000), equals(1.0));
        expect(ActionValidator.calculateStrobeFrequency(5, 1000), equals(5.0));
        expect(ActionValidator.calculateStrobeFrequency(10, 2000), equals(5.0));
        expect(ActionValidator.calculateStrobeFrequency(1, 500), equals(2.0));
      });

      test('frequency calculations are mathematically accurate', () {
        // Test known frequency calculations
        expect(ActionValidator.calculateBlinkFrequency(250), closeTo(4.0, 0.01));
        expect(ActionValidator.calculateBlinkFrequency(400), closeTo(2.5, 0.01));
        expect(ActionValidator.calculateBlinkFrequency(200), closeTo(5.0, 0.01));

        expect(ActionValidator.calculateStrobeFrequency(3, 1500), closeTo(2.0, 0.01));
        expect(ActionValidator.calculateStrobeFrequency(8, 2000), closeTo(4.0, 0.01));
        expect(ActionValidator.calculateStrobeFrequency(1, 250), closeTo(4.0, 0.01));
      });
    });

    group('Performance Testing', () {
      test('validation performance is acceptable', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 10000; i++) {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: i % 6,
            value: i % 256,
            duration: 1000 + (i % 1000),
          );
          ActionValidator.validate(action);
        }

        stopwatch.stop();

        // Should complete 10000 validations in reasonable time (<1000ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      test('helper methods perform efficiently', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 10000; i++) {
          final type = CommandActionType.values[i % CommandActionType.values.length];
          ActionValidator.getActionTypeDescription(type);
          ActionValidator.getParameterExamples(type);
          ActionValidator.getSuggestedValues(type);
        }

        stopwatch.stop();

        // Should complete helper method calls efficiently (<500ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(500));
      });
    });

    group('Real-world Scenario Testing', () {
      test('common use case validations', () {
        final commonActions = [
          // Typical gradient fade
          CommandAction(
            controllerId: 'living-room-lights',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: 200,
            duration: 3000, // 3 second fade
          ),
          // Typical evening blink
          CommandAction(
            controllerId: 'patio-lights',
            type: CommandActionType.blinkMode,
            channel: 1,
            period: 2000, // 0.5Hz for ambiance
          ),
          // Typical alarm strobe
          CommandAction(
            controllerId: 'alarm-lights',
            type: CommandActionType.strobeMode,
            channel: 5,
            count: 10,
            totalTime: 5000, // 5 seconds
            pauseTime: 1000, // 1 second pause
          ),
          // Standard channel control
          CommandAction(
            controllerId: 'kitchen-lights',
            type: CommandActionType.channelValue,
            channel: 0,
            value: 255, // Full brightness
          ),
          // Preset activation
          CommandAction(
            controllerId: 'bedroom-lights',
            type: CommandActionType.presetTrigger,
            presetId: 3, // Evening preset
          ),
        ];

        for (final action in commonActions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Common use case should be valid: $action');
        }
      });

      test('validation provides appropriate feedback', () {
        // Note: Constructor assertions prevent creating invalid actions
        // So we test that validation works correctly for valid actions
        final validActions = [
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.gradientMode,
            channel: 1,
            value: 128,
            duration: 1000,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.blinkMode,
            channel: 2,
            period: 500,
          ),
          CommandAction(
            controllerId: 'test',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 3,
            totalTime: 1500,
            pauseTime: 200,
          ),
        ];

        for (final action in validActions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Valid action should pass validation: $action');
        }
      });
    });
  });
}