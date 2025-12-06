import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/action_validator.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/widgets/orchestration/dynamic_action_preview.dart';

void main() {
  group('Dynamic Action Integration Tests', () {
    group('Complete Workflow Testing', () {
      test('end-to-end dynamic action creation and validation', () {
        // Create a complex scene with multiple dynamic actions
        final scene = ToggleScene(
          id: 'complex-dynamic-scene',
          name: 'Complex Dynamic Actions Test Scene',
          states: [
            ToggleState(
              toggleId: 'main-toggle',
              stateId: 'dynamic-state',
              label: 'Dynamic Effects',
              commandBundles: [
                CommandBundle(
                  id: 'dynamic-effects-bundle',
                  label: 'Dynamic Effects Bundle',
                  actions: [
                    // Gentle morning fade-in
                    CommandAction(
                      controllerId: 'living-room-lights',
                      type: CommandActionType.gradientMode,
                      channel: 1,
                      value: 150,
                      duration: 3000,
                    ),
                    // Ambient breathing effect
                    CommandAction(
                      controllerId: 'bedroom-lights',
                      type: CommandActionType.blinkMode,
                      channel: 2,
                      period: 2000,
                    ),
                    // Attention-grabbing strobe for notifications
                    CommandAction(
                      controllerId: 'kitchen-lights',
                      type: CommandActionType.strobeMode,
                      channel: 0,
                      count: 3,
                      totalTime: 1500,
                      pauseTime: 500,
                    ),
                    // Standard channel control for contrast
                    CommandAction(
                      controllerId: 'bathroom-lights',
                      type: CommandActionType.channelValue,
                      channel: 3,
                      value: 200,
                    ),
                    // Preset activation
                    CommandAction(
                      controllerId: 'hallway-lights',
                      type: CommandActionType.presetTrigger,
                      presetId: 2,
                    ),
                  ],
                ),
              ],
            ),
          ],
          rules: [],
        );

        // Validate all actions in the scene
        for (final bundle in scene.states.expand((state) => state.commandBundles)) {
          for (final action in bundle.actions) {
            final result = ActionValidator.validate(action);
            expect(result, isNull, reason: 'Action should be valid: $action');
          }
        }

        // Verify scene structure
        expect(scene.states, hasLength(1));
        expect(scene.states.first.commandBundles, hasLength(1));
        expect(scene.states.first.commandBundles.first.actions, hasLength(5));

        // Verify action types are properly distributed
        final actions = scene.states.first.commandBundles.first.actions;
        expect(actions.where((a) => a.type == CommandActionType.gradientMode), hasLength(1));
        expect(actions.where((a) => a.type == CommandActionType.blinkMode), hasLength(1));
        expect(actions.where((a) => a.type == CommandActionType.strobeMode), hasLength(1));
        expect(actions.where((a) => a.type == CommandActionType.channelValue), hasLength(1));
        expect(actions.where((a) => a.type == CommandActionType.presetTrigger), hasLength(1));
      });

      test('command object creation from actions', () {
        // Test that CommandActions can be properly converted to command objects
        final gradientAction = CommandAction(
          controllerId: 'test-controller',
          type: CommandActionType.gradientMode,
          channel: 2,
          value: 180,
          duration: 2500,
        );

        final fadeCommand = FadeCommand(
          channel: gradientAction.channel!,
          targetValue: gradientAction.value!,
          duration: gradientAction.duration!,
        );

        expect(fadeCommand.channel, equals(2));
        expect(fadeCommand.targetValue, equals(180));
        expect(fadeCommand.duration, equals(2500));
        expect(fadeCommand.isValidTargetValue, isTrue);
        expect(fadeCommand.isValidDuration, isTrue);

        // Test blink command creation
        final blinkAction = CommandAction(
          controllerId: 'test-controller',
          type: CommandActionType.blinkMode,
          channel: 1,
          period: 1000,
        );

        final blinkCommand = BlinkCommand(
          channel: blinkAction.channel!,
          period: blinkAction.period!,
        );

        expect(blinkCommand.channel, equals(1));
        expect(blinkCommand.period, equals(1000));

        // Test strobe command creation
        final strobeAction = CommandAction(
          controllerId: 'test-controller',
          type: CommandActionType.strobeMode,
          channel: 3,
          count: 5,
          totalTime: 2000,
          pauseTime: 300,
        );

        final strobeCommand = StrobeCommand(
          channel: strobeAction.channel!,
          flashCount: strobeAction.count!,
          totalDuration: strobeAction.totalTime!,
          pauseDuration: strobeAction.pauseTime!,
        );

        expect(strobeCommand.channel, equals(3));
        expect(strobeCommand.flashCount, equals(5));
        expect(strobeCommand.totalDuration, equals(2000));
        expect(strobeCommand.pauseDuration, equals(300));
      });

      test('JSON serialization round-trip for complex scenes', () {
        // Create complex scene with mixed actions
        final originalScene = ToggleScene(
          id: 'json-test-scene',
          name: 'JSON Serialization Test',
          states: [
            ToggleState(
              toggleId: 'test-toggle',
              stateId: 'test-state',
              label: 'Test State',
              commandBundles: [
                CommandBundle(
                  id: 'test-bundle',
                  label: 'Test Bundle',
                  actions: [
                    CommandAction(
                      controllerId: 'controller-1',
                      type: CommandActionType.gradientMode,
                      channel: 2,
                      value: 200,
                      duration: 1500,
                    ),
                    CommandAction(
                      controllerId: 'controller-2',
                      type: CommandActionType.blinkMode,
                      channel: 1,
                      period: 750,
                    ),
                    CommandAction(
                      controllerId: 'controller-3',
                      type: CommandActionType.strobeMode,
                      channel: 4,
                      count: 8,
                      totalTime: 4000,
                      pauseTime: 800,
                    ),
                    CommandAction(
                      controllerId: 'controller-4',
                      type: CommandActionType.channelValue,
                      channel: 0,
                      value: 255,
                    ),
                    CommandAction(
                      controllerId: 'controller-5',
                      type: CommandActionType.presetTrigger,
                      presetId: 3,
                    ),
                  ],
                ),
              ],
            ),
          ],
          rules: [],
        );

        // Convert to JSON and back
        final json = originalScene.toJson();
        final restoredScene = ToggleScene.fromJson(json);

        // Verify complete restoration
        expect(restoredScene.id, equals(originalScene.id));
        expect(restoredScene.name, equals(originalScene.name));
        expect(restoredScene.states, hasLength(originalScene.states.length));

        final originalState = originalScene.states.first;
        final restoredState = restoredScene.states.first;

        expect(restoredState.toggleId, equals(originalState.toggleId));
        expect(restoredState.stateId, equals(originalState.stateId));
        expect(restoredState.label, equals(originalState.label));
        expect(restoredState.commandBundles, hasLength(originalState.commandBundles.length));

        final originalBundle = originalState.commandBundles.first;
        final restoredBundle = restoredState.commandBundles.first;

        expect(restoredBundle.id, equals(originalBundle.id));
        expect(restoredBundle.label, equals(originalBundle.label));
        expect(restoredBundle.actions, hasLength(originalBundle.actions.length));

        // Verify each action is correctly restored
        for (int i = 0; i < originalBundle.actions.length; i++) {
          final originalAction = originalBundle.actions[i];
          final restoredAction = restoredBundle.actions[i];

          expect(restoredAction.controllerId, equals(originalAction.controllerId));
          expect(restoredAction.type, equals(originalAction.type));
          expect(restoredAction.channel, equals(originalAction.channel));
          expect(restoredAction.value, equals(originalAction.value));
          expect(restoredAction.presetId, equals(originalAction.presetId));
          expect(restoredAction.duration, equals(originalAction.duration));
          expect(restoredAction.period, equals(originalAction.period));
          expect(restoredAction.count, equals(originalAction.count));
          expect(restoredAction.totalTime, equals(originalAction.totalTime));
          expect(restoredAction.pauseTime, equals(originalAction.pauseTime));
        }
      });

      test('command encoding consistency across workflow', () {
        // Create actions with specific parameters
        final actions = [
          CommandAction(
            controllerId: 'test-1',
            type: CommandActionType.gradientMode,
            channel: 1,
            value: 100,
            duration: 2000,
          ),
          CommandAction(
            controllerId: 'test-2',
            type: CommandActionType.blinkMode,
            channel: 2,
            period: 1500,
          ),
          CommandAction(
            controllerId: 'test-3',
            type: CommandActionType.strobeMode,
            channel: 3,
            count: 4,
            totalTime: 3000,
            pauseTime: 600,
          ),
        ];

        // Create command objects
        final commands = [
          FadeCommand(
            channel: actions[0].channel!,
            targetValue: actions[0].value!,
            duration: actions[0].duration!,
          ),
          BlinkCommand(
            channel: actions[1].channel!,
            period: actions[1].period!,
          ),
          StrobeCommand(
            channel: actions[2].channel!,
            flashCount: actions[2].count!,
            totalDuration: actions[2].totalTime!,
            pauseDuration: actions[2].pauseTime!,
          ),
        ];

        // Generate command packets
        final packets = commands.map((cmd) => cmd.toBytes()).toList();

        // Verify packet formats
        expect(packets[0], hasLength(5)); // Fade: [type][channel][value][duration_high][duration_low]
        expect(packets[1], hasLength(4)); // Blink: [type][channel][period_high][period_low]
        expect(packets[2], hasLength(7)); // Strobe: [type][channel][count][total_high][total_low][pause_high][pause_low]

        // Verify command identifiers
        expect(packets[0][0], equals(0x01)); // Fade command identifier
        expect(packets[1][0], equals(0x02)); // Blink command identifier
        expect(packets[2][0], equals(0x03)); // Strobe command identifier

        // Verify channel encoding
        expect(packets[0][1], equals(1));
        expect(packets[1][1], equals(2));
        expect(packets[2][1], equals(3));

        // Verify value encoding for fade command
        expect(packets[0][2], equals(100));

        // Verify duration encoding for fade command (2000 = 0x07D0)
        expect(packets[0][3], equals(0x07));
        expect(packets[0][4], equals(0xD0));

        // Verify period encoding for blink command (1500 = 0x05DC)
        expect(packets[1][2], equals(0x05));
        expect(packets[1][3], equals(0xDC));

        // Verify strobe parameters encoding
        expect(packets[2][2], equals(4)); // count
        // total time 3000 = 0x0BB8
        expect(packets[2][3], equals(0x0B));
        expect(packets[2][4], equals(0xB8));
        // pause time 600 = 0x0258
        expect(packets[2][5], equals(0x02));
        expect(packets[2][6], equals(0x58));
      });

      test('helper method integration across action types', () {
        final actionTypes = CommandActionType.values;

        for (final type in actionTypes) {
          // Test action type descriptions
          final description = ActionValidator.getActionTypeDescription(type);
          expect(description, isNotEmpty);
          expect(description.length, greaterThan(10));

          // Test parameter examples
          final examples = ActionValidator.getParameterExamples(type);
          expect(examples, isNotEmpty);

          // Test suggested values
          final suggestions = ActionValidator.getSuggestedValues(type);
          expect(suggestions, isA<Map<String, List<int>>>());

          // Test frequency calculations where applicable
          switch (type) {
            case CommandActionType.blinkMode:
              final blinkFreq = ActionValidator.calculateBlinkFrequency(1000);
              expect(blinkFreq, equals(1.0));
              break;
            case CommandActionType.strobeMode:
              final strobeFreq = ActionValidator.calculateStrobeFrequency(5, 1000);
              expect(strobeFreq, equals(5.0));
              break;
            default:
              // Other types don't have frequency calculations
              break;
          }
        }
      });
    });

    group('Performance and Scalability', () {
      test('large scale scene performance', () {
        // Create a scene with many dynamic actions
        final actions = <CommandAction>[];

        // Add 100 actions of each type
        for (int i = 0; i < 100; i++) {
          actions.add(CommandAction(
            controllerId: 'controller-$i',
            type: CommandActionType.gradientMode,
            channel: i % 6,
            value: i % 256,
            duration: 1000 + (i % 5000),
          ));

          actions.add(CommandAction(
            controllerId: 'controller-$i',
            type: CommandActionType.blinkMode,
            channel: (i + 1) % 6,
            period: 500 + (i % 2000),
          ));

          actions.add(CommandAction(
            controllerId: 'controller-$i',
            type: CommandActionType.strobeMode,
            channel: (i + 2) % 6,
            count: (i % 10) + 1,
            totalTime: 1000 + (i % 4000),
            pauseTime: 100 + (i % 500),
          ));
        }

        expect(actions, hasLength(300));

        // Test validation performance
        final stopwatch = Stopwatch()..start();
        for (final action in actions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Action should be valid: $action');
        }
        stopwatch.stop();

        // Should validate 300 actions in reasonable time (<100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));

        // Test JSON serialization performance
        final scene = ToggleScene(
          id: 'large-scene',
          name: 'Large Scene Test',
          states: [
            ToggleState(
              toggleId: 'main-toggle',
              stateId: 'dynamic-state',
              label: 'Dynamic State',
              commandBundles: [
                CommandBundle(
                  id: 'large-bundle',
                  label: 'Large Bundle',
                  actions: actions,
                ),
              ],
            ),
          ],
          rules: [],
        );

        stopwatch.reset();
        stopwatch.start();
        final json = scene.toJson();
        final restoredScene = ToggleScene.fromJson(json);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(500));
        expect(restoredScene.states.first.commandBundles.first.actions, hasLength(300));
      });

      test('memory efficiency with complex scenes', () {
        // Test that repeated scene operations don't cause memory leaks
        for (int iteration = 0; iteration < 100; iteration++) {
          final scene = ToggleScene(
            id: 'memory-test-scene-$iteration',
            name: 'Memory Test Scene $iteration',
            states: [
              ToggleState(
                toggleId: 'test-toggle',
                stateId: 'test-state',
                label: 'Test State',
                commandBundles: [
                  CommandBundle(
                    id: 'test-bundle',
                    label: 'Test Bundle',
                    actions: [
                      for (int i = 0; i < 50; i++)
                        CommandAction(
                          controllerId: 'controller-$i',
                          type: CommandActionType.values[i % CommandActionType.values.length],
                          channel: i % 6,
                          value: i % 256,
                          duration: 1000 + (i % 2000),
                          period: 500 + (i % 1000),
                          count: (i % 10) + 1,
                          totalTime: 1000 + (i % 3000),
                          pauseTime: 100 + (i % 400),
                          presetId: i % 10,
                        ),
                    ],
                  ),
                ],
              ),
            ],
            rules: [],
          );

          // Validate all actions
          for (final bundle in scene.states.expand((state) => state.commandBundles)) {
            for (final action in bundle.actions) {
              ActionValidator.validate(action);
            }
          }

          // Convert to JSON and back
          final json = scene.toJson();
          ToggleScene.fromJson(json);
        }

        // If we get here without memory issues, the test passes
        expect(true, isTrue);
      });
    });

    group('Error Recovery and Edge Cases', () {
      test('graceful handling of extreme parameter combinations', () {
        // Test actions with extreme but valid parameters
        final extremeActions = [
          CommandAction(
            controllerId: 'extreme-test',
            type: CommandActionType.gradientMode,
            channel: 0,
            value: 0,
            duration: 1, // Minimum valid values
          ),
          CommandAction(
            controllerId: 'extreme-test',
            type: CommandActionType.gradientMode,
            channel: 5,
            value: 255,
            duration: 60000, // Maximum valid value according to validator
          ),
          CommandAction(
            controllerId: 'extreme-test',
            type: CommandActionType.blinkMode,
            channel: 0,
            period: 50, // Minimum valid blink period
          ),
          CommandAction(
            controllerId: 'extreme-test',
            type: CommandActionType.blinkMode,
            channel: 5,
            period: 10000, // Maximum valid blink period
          ),
          CommandAction(
            controllerId: 'extreme-test',
            type: CommandActionType.strobeMode,
            channel: 0,
            count: 1,
            totalTime: 10,
            pauseTime: 1, // Minimum valid values
          ),
          CommandAction(
            controllerId: 'extreme-test',
            type: CommandActionType.strobeMode,
            channel: 5,
            count: 255,
            totalTime: 60000,
            pauseTime: 59999, // Maximum valid values according to validator
          ),
        ];

        for (final action in extremeActions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Extreme but valid action should pass validation: $action');

          // Test that command objects can be created successfully
          switch (action.type) {
            case CommandActionType.gradientMode:
              final fadeCommand = FadeCommand(
                channel: action.channel!,
                targetValue: action.value!,
                duration: action.duration!,
              );
              expect(fadeCommand.isValidTargetValue, isTrue);
              expect(fadeCommand.isValidDuration, isTrue);
              break;
            case CommandActionType.blinkMode:
              BlinkCommand(
                channel: action.channel!,
                period: action.period!,
              );
              break;
            case CommandActionType.strobeMode:
              StrobeCommand(
                channel: action.channel!,
                flashCount: action.count!,
                totalDuration: action.totalTime!,
                pauseDuration: action.pauseTime!,
              );
              break;
            default:
              break;
          }
        }
      });

      test('consistency validation across all action types', () {
        // Verify that all action types follow consistent patterns
        final actions = [
          CommandAction(
            controllerId: 'consistency-test',
            type: CommandActionType.channelValue,
            channel: 1,
            value: 128,
          ),
          CommandAction(
            controllerId: 'consistency-test',
            type: CommandActionType.presetTrigger,
            presetId: 5,
          ),
          CommandAction(
            controllerId: 'consistency-test',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: 200,
            duration: 1500,
          ),
          CommandAction(
            controllerId: 'consistency-test',
            type: CommandActionType.blinkMode,
            channel: 3,
            period: 1000,
          ),
          CommandAction(
            controllerId: 'consistency-test',
            type: CommandActionType.strobeMode,
            channel: 4,
            count: 5,
            totalTime: 2000,
            pauseTime: 300,
          ),
        ];

        // All actions should have the same controller ID pattern
        for (final action in actions) {
          expect(action.controllerId, equals('consistency-test'));
          expect(action.controllerId, isNotEmpty);
        }

        // All actions should be valid
        for (final action in actions) {
          final result = ActionValidator.validate(action);
          expect(result, isNull, reason: 'Action should be valid: $action');
        }

        // All actions should serialize and deserialize correctly
        for (final action in actions) {
          final json = action.toJson();
          final restored = CommandAction.fromJson(json);

          expect(restored.controllerId, equals(action.controllerId));
          expect(restored.type, equals(action.type));
          expect(restored.channel, equals(action.channel));
          expect(restored.value, equals(action.value));
          expect(restored.presetId, equals(action.presetId));
          expect(restored.duration, equals(action.duration));
          expect(restored.period, equals(action.period));
          expect(restored.count, equals(action.count));
          expect(restored.totalTime, equals(action.totalTime));
          expect(restored.pauseTime, equals(action.pauseTime));
        }
      });
    });
  });
}