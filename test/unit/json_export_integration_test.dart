import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

void main() {
  group('JSON Export Integration Tests', () {
    test('Complete scene with strobe mode exports with all parameters', () {
      // Create a complete scene with strobe mode action
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
        label: 'Emergency Alert Bundle',
        actions: [strobeAction],
      );

      final state = ToggleState(
        toggleId: 'emergency-system',
        stateId: 'alert',
        label: 'Emergency Alert Active',
        commandBundles: [bundle],
      );

      final scene = ToggleScene(
        id: 'emergency-scene',
        name: 'Emergency Lighting Scene',
        description: 'Scene with strobe mode for emergency alerts',
        states: [state],
      );

      // Export to JSON (this is what gets saved to storage)
      final sceneJson = scene.toJson();
      final jsonString = jsonEncode(sceneJson);

      // Verify the JSON contains all expected strobe mode parameters
      expect(jsonString, contains('strobeMode'));
      expect(jsonString, contains('emergency-lights-01'));
      expect(jsonString, contains('count'));
      expect(jsonString, contains('totalTime'));
      expect(jsonString, contains('pauseTime'));
      expect(jsonString, contains('10')); // count value
      expect(jsonString, contains('5000')); // totalTime value
      expect(jsonString, contains('1000')); // pauseTime value

      // Print for verification
      print('JSON Export Result:');
      print('=' * 40);
      print(jsonString);
      print('=' * 40);

      // Verify the structure
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final states = decoded['states'] as List;
      final firstState = states.first as Map<String, dynamic>;
      final bundles = firstState['commandBundles'] as List;
      final firstBundle = bundles.first as Map<String, dynamic>;
      final actions = firstBundle['actions'] as List;
      final firstAction = actions.first as Map<String, dynamic>;

      // Verify strobe mode action structure
      expect(firstAction['controllerId'], equals('emergency-lights-01'));
      expect(firstAction['type'], equals('strobeMode'));
      expect(firstAction['channel'], equals(5));
      expect(firstAction['count'], equals(10));
      expect(firstAction['totalTime'], equals(5000));
      expect(firstAction['pauseTime'], equals(1000));
    });

    test('Multiple dynamic actions in one scene export correctly', () {
      final gradientAction = CommandAction(
        controllerId: 'living-room-lights',
        type: CommandActionType.gradientMode,
        channel: 2,
        value: 200,
        duration: 3000,
      );

      final blinkAction = CommandAction(
        controllerId: 'patio-lights',
        type: CommandActionType.blinkMode,
        channel: 1,
        period: 2000,
      );

      final strobeAction = CommandAction(
        controllerId: 'alarm-lights',
        type: CommandActionType.strobeMode,
        channel: 5,
        count: 15,
        totalTime: 8000,
        pauseTime: 2000,
      );

      final bundle = CommandBundle(
        id: 'multi-dynamic-bundle',
        label: 'Multi Dynamic Action Bundle',
        actions: [gradientAction, blinkAction, strobeAction],
      );

      final scene = ToggleScene(
        id: 'multi-dynamic-scene',
        name: 'Complex Dynamic Actions Scene',
        states: [
          ToggleState(
            toggleId: 'complex-lighting',
            stateId: 'active',
            label: 'Complex Lighting Active',
            commandBundles: [bundle],
          ),
        ],
      );

      // Export to JSON
      final jsonString = jsonEncode(scene.toJson());

      // Verify all dynamic action types are present
      expect(jsonString, contains('gradientMode'));
      expect(jsonString, contains('blinkMode'));
      expect(jsonString, contains('strobeMode'));
      expect(jsonString, contains('duration'));
      expect(jsonString, contains('period'));
      expect(jsonString, contains('count'));
      expect(jsonString, contains('totalTime'));
      expect(jsonString, contains('pauseTime'));

      print('Multi-Action JSON Export:');
      print('=' * 40);
      print(jsonString);
      print('=' * 40);

      // Verify round-trip
      final roundTripScene = ToggleScene.fromJson(jsonDecode(jsonString));
      expect(roundTripScene.states.length, equals(1));
      expect(roundTripScene.states.first.commandBundles.length, equals(1));
      expect(roundTripScene.states.first.commandBundles.first.actions.length, equals(3));

      final actions = roundTripScene.states.first.commandBundles.first.actions;
      expect(actions[0].type, equals(CommandActionType.gradientMode));
      expect(actions[1].type, equals(CommandActionType.blinkMode));
      expect(actions[2].type, equals(CommandActionType.strobeMode));
    });
  });
}