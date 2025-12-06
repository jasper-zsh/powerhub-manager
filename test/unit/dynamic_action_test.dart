import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/action_validator.dart';

void main() {
  group('Dynamic Action Tests', () {
    group('CommandAction Creation', () {
      test('creates gradient mode action with required parameters', () {
        final action = CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.gradientMode,
          channel: 2,
          value: 200,
          duration: 1500,
        );

        expect(action.controllerId, equals('controller-1'));
        expect(action.type, equals(CommandActionType.gradientMode));
        expect(action.channel, equals(2));
        expect(action.value, equals(200));
        expect(action.duration, equals(1500));
        expect(action.period, isNull);
        expect(action.count, isNull);
        expect(action.totalTime, isNull);
        expect(action.pauseTime, isNull);
      });

      test('creates blink mode action with required parameters', () {
        final action = CommandAction(
          controllerId: 'controller-2',
          type: CommandActionType.blinkMode,
          channel: 3,
          period: 1000,
        );

        expect(action.controllerId, equals('controller-2'));
        expect(action.type, equals(CommandActionType.blinkMode));
        expect(action.channel, equals(3));
        expect(action.period, equals(1000));
        expect(action.value, isNull);
        expect(action.duration, isNull);
        expect(action.count, isNull);
        expect(action.totalTime, isNull);
        expect(action.pauseTime, isNull);
      });

      test('creates strobe mode action with required parameters', () {
        final action = CommandAction(
          controllerId: 'controller-3',
          type: CommandActionType.strobeMode,
          channel: 1,
          count: 5,
          totalTime: 2000,
          pauseTime: 500,
        );

        expect(action.controllerId, equals('controller-3'));
        expect(action.type, equals(CommandActionType.strobeMode));
        expect(action.channel, equals(1));
        expect(action.count, equals(5));
        expect(action.totalTime, equals(2000));
        expect(action.pauseTime, equals(500));
        expect(action.value, isNull);
        expect(action.duration, isNull);
        expect(action.period, isNull);
      });

      test('copyWith preserves all parameters for dynamic actions', () {
        final original = CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.gradientMode,
          channel: 2,
          value: 150,
          duration: 3000,
        );

        final copied = original.copyWith(
          value: 200,
          duration: 1500,
        );

        expect(copied.controllerId, equals('controller-1'));
        expect(copied.type, equals(CommandActionType.gradientMode));
        expect(copied.channel, equals(2));
        expect(copied.value, equals(200));
        expect(copied.duration, equals(1500));
      });
    });

    group('JSON Serialization', () {
      test('serializes and deserializes gradient mode action', () {
        final original = CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.gradientMode,
          channel: 2,
          value: 180,
          duration: 2500,
        );

        final json = original.toJson();
        final deserialized = CommandAction.fromJson(json);

        expect(deserialized.controllerId, equals(original.controllerId));
        expect(deserialized.type, equals(original.type));
        expect(deserialized.channel, equals(original.channel));
        expect(deserialized.value, equals(original.value));
        expect(deserialized.duration, equals(original.duration));
      });

      test('serializes and deserializes blink mode action', () {
        final original = CommandAction(
          controllerId: 'controller-2',
          type: CommandActionType.blinkMode,
          channel: 0,
          period: 750,
        );

        final json = original.toJson();
        final deserialized = CommandAction.fromJson(json);

        expect(deserialized.controllerId, equals(original.controllerId));
        expect(deserialized.type, equals(original.type));
        expect(deserialized.channel, equals(original.channel));
        expect(deserialized.period, equals(original.period));
      });

      test('serializes and deserializes strobe mode action', () {
        final original = CommandAction(
          controllerId: 'controller-3',
          type: CommandActionType.strobeMode,
          channel: 4,
          count: 8,
          totalTime: 4000,
          pauseTime: 800,
        );

        final json = original.toJson();
        final deserialized = CommandAction.fromJson(json);

        expect(deserialized.controllerId, equals(original.controllerId));
        expect(deserialized.type, equals(original.type));
        expect(deserialized.channel, equals(original.channel));
        expect(deserialized.count, equals(original.count));
        expect(deserialized.totalTime, equals(original.totalTime));
        expect(deserialized.pauseTime, equals(original.pauseTime));
      });
    });

    group('ActionValidator Tests', () {
      group('Gradient Mode Validation', () {
        test('validates correct gradient mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: 200,
            duration: 1500,
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('rejects gradient mode with invalid channel', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 6, // Invalid: should be 0-5
            value: 200,
            duration: 1500,
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Channel must be between 0 and 5'));
        });

        test('rejects gradient mode with invalid target value', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: 300, // Invalid: should be 0-255
            duration: 1500,
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Target value must be between 0 and 255'));
        });

        test('rejects gradient mode with duration too short', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: 200,
            duration: 0, // Invalid: should be >= 1
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Duration must be at least 1ms'));
        });

        test('rejects gradient mode with duration too long', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: 200,
            duration: 70000, // Invalid: should be <= 60000
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Duration must not exceed 60 seconds (60000ms)'));
        });

        test('allows edge case gradient mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 0,
            value: 0,
            duration: 1, // Minimum valid values
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('allows maximum gradient mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.gradientMode,
            channel: 5,
            value: 255,
            duration: 60000, // Maximum valid values
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });
      });

      group('Blink Mode Validation', () {
        test('validates correct blink mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.blinkMode,
            channel: 1,
            period: 1000,
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('rejects blink mode with period too short', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.blinkMode,
            channel: 1,
            period: 25, // Invalid: should be >= 50
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Period must be at least 50ms for visible blinking'));
        });

        test('rejects blink mode with period too long', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.blinkMode,
            channel: 1,
            period: 15000, // Invalid: should be <= 10000
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Period must not exceed 10 seconds (10000ms)'));
        });

        test('allows long blink period without error (just warns)', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.blinkMode,
            channel: 1,
            period: 6000, // Long but valid
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull); // Should not error
        });

        test('allows edge case blink mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.blinkMode,
            channel: 0,
            period: 50, // Minimum valid values
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('allows maximum blink mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.blinkMode,
            channel: 5,
            period: 10000, // Maximum valid values
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });
      });

      group('Strobe Mode Validation', () {
        test('validates correct strobe mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 5,
            totalTime: 2000,
            pauseTime: 300,
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('rejects strobe mode with invalid count', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 0, // Invalid: should be >= 1
            totalTime: 2000,
            pauseTime: 300,
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Count must be at least 1'));
        });

        test('rejects strobe mode with count too high', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 300, // Invalid: should be <= 255
            totalTime: 2000,
            pauseTime: 300,
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Count must not exceed 255'));
        });

        test('rejects strobe mode with total time too short', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 5,
            totalTime: 5, // Invalid: should be >= 10
            pauseTime: 1,
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Total time must be at least 10ms'));
        });

        test('rejects strobe mode with pause time too long', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 5,
            totalTime: 1000,
            pauseTime: 1000, // Invalid: should be < totalTime
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Pause time must be less than total time'));
        });

        test('allows edge case strobe mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 0,
            count: 1,
            totalTime: 10,
            pauseTime: 1, // Minimum valid values
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('allows maximum strobe mode parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.strobeMode,
            channel: 5,
            count: 255,
            totalTime: 60000,
            pauseTime: 59999, // Maximum valid values
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });
      });

      group('Preset Trigger Validation', () {
        test('validates correct preset trigger parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.presetTrigger,
            presetId: 3,
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('rejects preset trigger with negative preset ID', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.presetTrigger,
            presetId: -1,
          );

          final result = ActionValidator.validate(action);
          expect(result, equals('Preset ID must be positive'));
        });

        test('allows edge case preset trigger parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.presetTrigger,
            presetId: 0, // Minimum valid value
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });

        test('allows large preset trigger parameters', () {
          final action = CommandAction(
            controllerId: 'test-controller',
            type: CommandActionType.presetTrigger,
            presetId: 999999, // Large valid value
          );

          final result = ActionValidator.validate(action);
          expect(result, isNull);
        });
      });
    });

    group('Helper Methods', () {
      test('getActionTypeDescription returns correct descriptions', () {
        expect(
          ActionValidator.getActionTypeDescription(CommandActionType.gradientMode),
          equals('Smooth transition to target value over specified duration'),
        );
        expect(
          ActionValidator.getActionTypeDescription(CommandActionType.blinkMode),
          equals('Periodic on/off blinking with specified period'),
        );
        expect(
          ActionValidator.getActionTypeDescription(CommandActionType.strobeMode),
          equals('Strobe effect with count, timing, and pause intervals'),
        );
        expect(
          ActionValidator.getActionTypeDescription(CommandActionType.presetTrigger),
          equals('Activate a preset configuration'),
        );
        expect(
          ActionValidator.getActionTypeDescription(CommandActionType.channelValue),
          equals('Set channel to static value immediately'),
        );
      });

      test('getParameterExamples returns useful examples', () {
        final gradientExamples = ActionValidator.getParameterExamples(CommandActionType.gradientMode);
        expect(gradientExamples, contains('Channel: 0-5, Target: 0-255, Duration: 100-60000ms'));
        expect(gradientExamples, contains('Example: Channel 1, Target 200, Duration 2000ms (2 seconds)'));

        final blinkExamples = ActionValidator.getParameterExamples(CommandActionType.blinkMode);
        expect(blinkExamples, contains('Channel: 0-5, Period: 50-10000ms'));
        expect(blinkExamples, contains('Example: Channel 0, Period 1000ms (1 Hz)'));

        final strobeExamples = ActionValidator.getParameterExamples(CommandActionType.strobeMode);
        expect(strobeExamples, contains('Channel: 0-5, Count: 1-255, Total Time: 10-60000ms, Pause Time: 1-TotalTime-1'));
        expect(strobeExamples, contains('Example: Channel 2, Count 5, Total Time 3000ms, Pause 500ms'));
      });

      test('getSuggestedValues returns appropriate suggestions', () {
        final gradientSuggestions = ActionValidator.getSuggestedValues(CommandActionType.gradientMode);
        expect(gradientSuggestions.containsKey('Quick fade'), isTrue);
        expect(gradientSuggestions['Quick fade'], equals([500]));

        final blinkSuggestions = ActionValidator.getSuggestedValues(CommandActionType.blinkMode);
        expect(blinkSuggestions.containsKey('Fast blink'), isTrue);
        expect(blinkSuggestions['Fast blink'], equals([250]));

        final strobeSuggestions = ActionValidator.getSuggestedValues(CommandActionType.strobeMode);
        expect(strobeSuggestions.containsKey('Quick bursts'), isTrue);
        expect(strobeSuggestions['Quick bursts'], equals([10, 1000, 200]));
      });
    });

    group('Frequency Calculations', () {
      test('calculateBlinkFrequency returns correct frequency', () {
        expect(ActionValidator.calculateBlinkFrequency(1000), equals(1.0));
        expect(ActionValidator.calculateBlinkFrequency(500), equals(2.0));
        expect(ActionValidator.calculateBlinkFrequency(250), equals(4.0));
        expect(ActionValidator.calculateBlinkFrequency(0), equals(0.0));
      });

      test('calculateStrobeFrequency returns correct frequency', () {
        expect(ActionValidator.calculateStrobeFrequency(5, 1000), equals(5.0));
        expect(ActionValidator.calculateStrobeFrequency(10, 2000), equals(5.0));
        expect(ActionValidator.calculateStrobeFrequency(1, 500), equals(2.0));
        expect(ActionValidator.calculateStrobeFrequency(0, 1000), equals(0.0));
        expect(ActionValidator.calculateStrobeFrequency(5, 0), equals(0.0));
      });
    });
  });
}