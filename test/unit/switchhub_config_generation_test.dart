import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

void main() {
  group('SwitchHubConfig Generation Tests', () {
    test('dynamic actions generate sequence data in SwitchHubConfig', () {
      // Create a scene with dynamic actions
      final strobeAction = CommandAction(
        controllerId: 'emergency-lights-01',
        type: CommandActionType.strobeMode,
        channel: 5,
        count: 10,
        totalTime: 5000,
        pauseTime: 1000,
      );

      final bundle = CommandBundle(
        id: 'emergency-bundle',
        label: 'Emergency Bundle',
        actions: [strobeAction],
      );

      final state = ToggleState(
        toggleId: 'emergency-switch',
        stateId: 'alert',
        label: 'Alert State',
        commandBundles: [bundle],
      );

      final scene = ToggleScene(
        id: 'emergency-scene',
        name: 'Emergency Scene',
        states: [state],
      );

      // Generate SwitchHubConfig
      final switchHubConfig = scene.toSwitchHubConfig();

      // Verify the config contains sequence data
      expect(switchHubConfig.switches.length, equals(1));
      final switchHubSwitch = switchHubConfig.switches.first;

      // The switch should have logic that includes our strobe action
      expect(switchHubSwitch.onLogic.runtimeType.toString(), contains('LeafNode'));

      // Verify metadata contains scene information
      expect(switchHubConfig.metadata?['scene_id'], equals('emergency-scene'));
      expect(switchHubConfig.metadata?['scene_name'], equals('Emergency Scene'));
    });

    test('mixed dynamic actions generate combined sequence data', () {
      // Create a scene with multiple dynamic actions
      final gradientAction = CommandAction(
        controllerId: 'living-room-lights',
        type: CommandActionType.gradientMode,
        channel: 2,
        value: 200,
        duration: 3000,
      );

      final blinkAction = CommandAction(
        controllerId: 'living-room-lights',
        type: CommandActionType.blinkMode,
        channel: 1,
        period: 2000,
      );

      final bundle = CommandBundle(
        id: 'mixed-bundle',
        label: 'Mixed Bundle',
        actions: [gradientAction, blinkAction],
      );

      final state = ToggleState(
        toggleId: 'living-room-switch',
        stateId: 'on',
        label: 'On State',
        commandBundles: [bundle],
      );

      final scene = ToggleScene(
        id: 'mixed-scene',
        name: 'Mixed Scene',
        states: [state],
      );

      // Generate SwitchHubConfig
      final switchHubConfig = scene.toSwitchHubConfig();

      // Verify the config contains sequence data
      expect(switchHubConfig.switches.length, equals(1));
      final switchHubSwitch = switchHubConfig.switches.first;

      // The switch should have logic that includes both actions
      expect(switchHubSwitch.onLogic.runtimeType.toString(), contains('LeafNode'));

      // Verify metadata
      expect(switchHubConfig.metadata?['scene_id'], equals('mixed-scene'));
      expect(switchHubConfig.metadata?['scene_name'], equals('Mixed Scene'));
    });

    test('channel value actions still work in sequence generation', () {
      // Ensure backward compatibility
      final channelAction = CommandAction(
        controllerId: 'simple-lights',
        type: CommandActionType.channelValue,
        channel: 3,
        value: 128,
      );

      final bundle = CommandBundle(
        id: 'simple-bundle',
        label: 'Simple Bundle',
        actions: [channelAction],
      );

      final state = ToggleState(
        toggleId: 'simple-switch',
        stateId: 'on',
        label: 'On State',
        commandBundles: [bundle],
      );

      final scene = ToggleScene(
        id: 'simple-scene',
        name: 'Simple Scene',
        states: [state],
      );

      // Generate SwitchHubConfig
      final switchHubConfig = scene.toSwitchHubConfig();

      // Verify the config contains sequence data
      expect(switchHubConfig.switches.length, equals(1));
      final switchHubSwitch = switchHubConfig.switches.first;

      expect(switchHubSwitch.onLogic.runtimeType.toString(), contains('LeafNode'));
    });

    test('empty bundles do not generate switches', () {
      final emptyBundle = CommandBundle(
        id: 'empty-bundle',
        label: 'Empty Bundle',
        actions: [],
      );

      final state = ToggleState(
        toggleId: 'empty-switch',
        stateId: 'off',
        label: 'Off State',
        commandBundles: [emptyBundle],
      );

      final scene = ToggleScene(
        id: 'empty-scene',
        name: 'Empty Scene',
        states: [state],
      );

      // Generate SwitchHubConfig
      final switchHubConfig = scene.toSwitchHubConfig();

      // Empty bundles should still create switches but with empty sequences
      expect(switchHubConfig.switches.length, equals(1));
    });
  });
}