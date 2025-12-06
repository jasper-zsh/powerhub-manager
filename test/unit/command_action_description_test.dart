import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

void main() {
  group('CommandAction Description Tests', () {
    test('strobe mode action has correct descriptions', () {
      final strobeAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.strobeMode,
        channel: 5,
        count: 10,
        totalTime: 5000,
        pauseTime: 1000,
      );

      expect(strobeAction.description, equals('Strobe: Channel 5 (10 flashes, 5000ms, 1000ms pause)'));
      expect(strobeAction.chineseDescription, equals('频闪: 通道5 (10次闪, 5000ms, 1000ms暂停)'));
    });

    test('gradient mode action has correct descriptions', () {
      final gradientAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.gradientMode,
        channel: 2,
        value: 200,
        duration: 3000,
      );

      expect(gradientAction.description, equals('Gradient: Channel 2 → 200 (3000ms)'));
      expect(gradientAction.chineseDescription, equals('渐变: 通道2 → 200 (3000ms)'));
    });

    test('blink mode action has correct descriptions', () {
      final blinkAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.blinkMode,
        channel: 1,
        period: 2000,
      );

      expect(blinkAction.description, equals('Blink: Channel 1 (2000ms period)'));
      expect(blinkAction.chineseDescription, equals('闪烁: 通道1 (2000ms周期)'));
    });

    test('channel value action has correct descriptions', () {
      final channelAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.channelValue,
        channel: 3,
        value: 128,
      );

      expect(channelAction.description, equals('Channel 3 → 128'));
      expect(channelAction.chineseDescription, equals('通道 3 → 128'));
    });

    test('preset trigger action has correct descriptions', () {
      final presetAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.presetTrigger,
        presetId: 5,
      );

      expect(presetAction.description, equals('Trigger preset 5'));
      expect(presetAction.chineseDescription, equals('触发预设 5'));
    });

    test('descriptions work correctly in complex scenarios', () {
      final complexStrobe = CommandAction(
        controllerId: 'emergency-system',
        type: CommandActionType.strobeMode,
        channel: 0,
        count: 255,
        totalTime: 60000,
        pauseTime: 59999,
      );

      expect(complexStrobe.description, contains('Channel 0 (255 flashes, 60000ms, 59999ms pause)'));
      expect(complexStrobe.chineseDescription, contains('通道0 (255次闪, 60000ms, 59999ms暂停)'));
    });

    test('descriptions are consistent with UI expectations', () {
      // Test that descriptions match what users expect to see
      final testActions = [
        CommandAction(
          controllerId: 'test-1',
          type: CommandActionType.channelValue,
          channel: 1,
          value: 100,
        ),
        CommandAction(
          controllerId: 'test-2',
          type: CommandActionType.gradientMode,
          channel: 2,
          value: 150,
          duration: 2000,
        ),
        CommandAction(
          controllerId: 'test-3',
          type: CommandActionType.blinkMode,
          channel: 3,
          period: 1000,
        ),
        CommandAction(
          controllerId: 'test-4',
          type: CommandActionType.strobeMode,
          channel: 4,
          count: 5,
          totalTime: 3000,
          pauseTime: 500,
        ),
        CommandAction(
          controllerId: 'test-5',
          type: CommandActionType.presetTrigger,
          presetId: 2,
        ),
      ];

      // All descriptions should be non-empty and meaningful
      for (final action in testActions) {
        expect(action.description.isNotEmpty, isTrue, reason: 'English description should not be empty for ${action.type}');
        expect(action.chineseDescription.isNotEmpty, isTrue, reason: 'Chinese description should not be empty for ${action.type}');

        // All descriptions should contain channel or preset info
        if (action.channel != null) {
          expect(action.description, contains('Channel'));
          expect(action.chineseDescription, contains('通道'));
        }

        if (action.presetId != null) {
          expect(action.description, contains('Trigger preset'));
          expect(action.chineseDescription, contains('触发预设'));
        }
      }
    });
  });
}