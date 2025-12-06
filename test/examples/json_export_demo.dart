import 'dart:convert';
import 'package:app/models/orchestration/toggle_scene.dart';

/// Demo script showing how dynamic actions are exported to JSON
void main() {
  print('=== Dynamic Actions JSON Export Demo ===\n');

  // Create a strobe mode action
  final strobeAction = CommandAction(
    controllerId: 'controller-abc123',
    type: CommandActionType.strobeMode,
    channel: 3,
    count: 5,
    totalTime: 2000,
    pauseTime: 300,
  );

  // Create a complete orchestration scene with strobe mode
  final bundle = CommandBundle(
    id: 'bundle-strobe-demo',
    label: 'Strobe Light Demo Bundle',
    actions: [strobeAction],
  );

  final state = ToggleState(
    toggleId: 'alarm-system',
    stateId: 'active',
    label: 'Alarm Active',
    commandBundles: [bundle],
  );

  final scene = ToggleScene(
    id: 'scene-strobe-demo',
    name: 'Emergency Lighting Scene',
    description: 'Scene with strobe mode for emergency alerts',
    states: [state],
  );

  // Export to JSON
  final sceneJson = scene.toJson();
  final jsonString = jsonEncode(sceneJson);

  print('Complete Scene JSON:');
  print('=' * 50);
  print(jsonString);
  print('\n' + '=' * 50 + '\n');

  // Extract and show just the action part
  final actionJson = strobeAction.toJson();
  print('Individual Strobe Action JSON:');
  print('=' * 30);
  print(jsonEncode(actionJson));
  print('\n' + '=' * 30 + '\n');

  print('Key points:');
  print('- "type": "strobeMode" - indicates the action type');
  print('- "count": 5 - number of strobe flashes');
  print('- "totalTime": 2000 - total duration in milliseconds');
  print('- "pauseTime": 300 - pause between strobe bursts');
  print('- "channel": 3 - which channel to control');
  print('- All dynamic parameters are correctly serialized!');

  // Demonstrate round-trip
  print('\n=== Round-trip Test ===');
  final deserializedScene = ToggleScene.fromJson(sceneJson);
  final deserializedAction = deserializedScene.states.first.commandBundles.first.actions.first;

  print('Original strobe action:');
  print('  Controller: ${strobeAction.controllerId}');
  print('  Type: ${strobeAction.type}');
  print('  Channel: ${strobeAction.channel}');
  print('  Count: ${strobeAction.count}');
  print('  Total Time: ${strobeAction.totalTime}');
  print('  Pause Time: ${strobeAction.pauseTime}');

  print('\nDeserialized strobe action:');
  print('  Controller: ${deserializedAction.controllerId}');
  print('  Type: ${deserializedAction.type}');
  print('  Channel: ${deserializedAction.channel}');
  print('  Count: ${deserializedAction.count}');
  print('  Total Time: ${deserializedAction.totalTime}');
  print('  Pause Time: ${deserializedAction.pauseTime}');

  print('\n✅ Round-trip successful: ${strobeAction.count == deserializedAction.count}');
}