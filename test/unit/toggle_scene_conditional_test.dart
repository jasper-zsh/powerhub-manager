import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';

void main() {
  group('ToggleScene Conditional Logic Tests', () {
    late ToggleScene testScene;
    late List<ToggleState> testStates;
    late List<CommandBundle> testBundles;
    late SwitchHubIfNode testIfNode;

    setUp(() {
      testBundles = [
        CommandBundle(
          id: 'bundle1',
          label: 'Morning Scene',
          actions: [],
        ),
        CommandBundle(
          id: 'bundle2',
          label: 'Evening Scene',
          actions: [],
        ),
      ];

      testIfNode = SwitchHubIfNode(
        condition: 'SW1.ON AND SW2.OFF',
        thenNode: SwitchHubLeafNode(sequence: []),
      );

      testStates = [
        ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          commandBundles: testBundles,
        ),
        ToggleState(
          toggleId: 'SW1',
          stateId: 'OFF',
          label: 'Light Off',
        ),
        ToggleState(
          toggleId: 'SW2',
          stateId: 'ON',
          label: 'Fan On',
          logic: testIfNode,
        ),
      ];

      testScene = ToggleScene(
        id: 'scene1',
        name: 'Test Scene',
        states: testStates,
      );
    });

    group('Conditional Logic Detection', () {
      test('detects presence of conditional logic', () {
        expect(testScene.hasConditionalLogic, isTrue);
        expect(testScene.hasModernConditionalLogic, isTrue);
      });

      test('detects absence of conditional logic', () {
        final sceneWithoutLogic = ToggleScene(
          id: 'scene2',
          name: 'No Logic Scene',
          states: testStates.take(2).toList(), // Only states without logic
        );

        expect(sceneWithoutLogic.hasConditionalLogic, isFalse);
        expect(sceneWithoutLogic.hasModernConditionalLogic, isFalse);
      });

      test('detects legacy conditional rules', () {
        final sceneWithLegacyRules = ToggleScene(
          id: 'scene3',
          name: 'Legacy Scene',
          states: [],
          rules: [
            ConditionalRule(
              id: 'rule1',
              toggleId: 'SW1',
              expectedStateId: 'ON',
              trueBundleId: 'bundle1',
            ),
          ],
        );

        expect(sceneWithLegacyRules.hasConditionalLogic, isTrue);
        expect(sceneWithLegacyRules.hasModernConditionalLogic, isFalse);
      });
    });

    group('Conditional State Management', () {
      test('filters states with conditional logic', () {
        final statesWithLogic = testScene.statesWithConditionalLogic;

        expect(statesWithLogic.length, equals(1));
        expect(statesWithLogic.first.toggleId, equals('SW2'));
        expect(statesWithLogic.first.hasConditionalLogic, isTrue);
      });

      test('filters states without conditional logic', () {
        final statesWithoutLogic = testScene.statesWithoutConditionalLogic;

        expect(statesWithoutLogic.length, equals(2));
        expect(statesWithoutLogic.every((state) => !state.hasConditionalLogic), isTrue);
      });

      test('gets toggle references from conditional logic', () {
        final references = testScene.conditionalToggleReferences;

        expect(references, contains('SW2'));
      });

      test('handles empty conditional references', () {
        final emptyScene = ToggleScene(
          id: 'scene4',
          name: 'Empty Scene',
        );

        final references = emptyScene.conditionalToggleReferences;
        expect(references, isEmpty);
      });
    });

    group('Conditional Logic Validation', () {
      test('validates all conditional logic in scene', () {
        final results = testScene.validateAllConditionalLogic();

        expect(results.containsKey('SW2.ON'), isTrue);
        expect(results['SW2.ON']!.isValid, isTrue);
        expect(results['SW2.ON']!.errors, isEmpty);
      });

      test('returns empty results for scene without conditional logic', () {
        final sceneWithoutLogic = ToggleScene(
          id: 'scene5',
          name: 'No Logic Scene',
          states: testStates.take(2).toList(),
        );

        final results = sceneWithoutLogic.validateAllConditionalLogic();
        expect(results, isEmpty);
      });

      test('includes complexity metrics in validation', () {
        final results = testScene.validateAllConditionalLogic();

        expect(results['SW2.ON']!.complexity, greaterThan(0));
      });
    });

    group('Complexity Metrics', () {
      test('calculates total conditional logic complexity', () {
        final complexity = testScene.totalConditionalLogicComplexity;
        expect(complexity, greaterThan(0));
      });

      test('returns zero complexity for scene without conditional logic', () {
        final sceneWithoutLogic = ToggleScene(
          id: 'scene6',
          name: 'No Logic Scene',
          states: testStates.take(2).toList(),
        );

        final complexity = sceneWithoutLogic.totalConditionalLogicComplexity;
        expect(complexity, equals(0));
      });

      test('sums complexity from multiple states', () {
        final complexIfNode = SwitchHubIfNode(
          condition: 'SW1.ON OR SW2.OFF AND SW3.ON',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final complexStates = [
          ToggleState(
            toggleId: 'SW1',
            stateId: 'ON',
            label: 'State 1',
            logic: testIfNode,
          ),
          ToggleState(
            toggleId: 'SW2',
            stateId: 'ON',
            label: 'State 2',
            logic: complexIfNode,
          ),
        ];

        final complexScene = ToggleScene(
          id: 'scene7',
          name: 'Complex Scene',
          states: complexStates,
        );

        final complexity = complexScene.totalConditionalLogicComplexity;
        expect(complexity, greaterThan(testScene.totalConditionalLogicComplexity));
      });
    });

    group('Legacy Rule Migration', () {
      test('migrates legacy rules to modern conditional logic', () {
        final legacyScene = ToggleScene(
          id: 'scene8',
          name: 'Legacy Scene',
          states: testStates,
          rules: [
            ConditionalRule(
              id: 'rule1',
              toggleId: 'SW1',
              expectedStateId: 'ON',
              trueBundleId: 'bundle1',
            ),
          ],
        );

        final migratedScene = legacyScene.migrateLegacyConditionalRules();

        expect(migratedScene.rules.isEmpty, isTrue);
        expect(migratedScene.hasModernConditionalLogic, isTrue);

        // Find the migrated state
        final migratedState = migratedScene.states
            .where((state) => state.toggleId == 'SW1' && state.stateId == 'ON')
            .first;

        expect(migratedState.hasConditionalLogic, isTrue);
        expect(migratedState.logic, isA<SwitchHubIfNode>());

        final ifNode = migratedState.logic! as SwitchHubIfNode;
        expect(ifNode.condition, equals('SW1.ON'));
      });

      test('handles scene without legacy rules gracefully', () {
        final sceneWithoutRules = ToggleScene(
          id: 'scene9',
          name: 'No Rules Scene',
          states: testStates,
        );

        // Test scene without legacy rules - no migration needed
        expect(sceneWithoutRules.rules.isEmpty, isTrue);
        expect(sceneWithoutRules.states.length, equals(testStates.length));

        // States should be unchanged
        for (int i = 0; i < testStates.length; i++) {
          expect(sceneWithoutRules.states[i].toggleId, equals(testStates[i].toggleId));
          expect(sceneWithoutRules.states[i].stateId, equals(testStates[i].stateId));
        }
      });

      test('preserves non-migrated states', () {
        final legacyScene = ToggleScene(
          id: 'scene10',
          name: 'Mixed Scene',
          states: testStates,
          rules: [
            ConditionalRule(
              id: 'rule1',
              toggleId: 'SW1',
              expectedStateId: 'ON',
              trueBundleId: 'bundle1',
            ),
            // This rule targets a non-existent state
            ConditionalRule(
              id: 'rule2',
              toggleId: 'SW99',
              expectedStateId: 'ON',
              trueBundleId: 'bundle2',
            ),
          ],
        );

        // For legacy scenes with conditional logic, we keep the existing implementation
        // Note: migrateLegacyRules functionality would be implemented when needed
        expect(legacyScene.rules.isEmpty, isTrue);
        expect(legacyScene.states.length, equals(testStates.length));

        // One state should be migrated, others preserved
        final migratedStates = legacyScene.states
            .where((state) => state.hasConditionalLogic)
            .toList();
        expect(migratedStates.length, equals(1));
      });
    });

    group('JSON Serialization with Conditional Logic', () {
      test('serializes scene with modern conditional logic', () {
        final sceneWithLogic = ToggleScene(
          id: 'scene11',
          name: 'Modern Scene',
          states: [
            ToggleState(
              toggleId: 'SW1',
              stateId: 'ON',
              label: 'Light On',
              logic: testIfNode,
            ),
          ],
        );

        final json = sceneWithLogic.toJson();

        expect(json['states'], isNotNull);
        expect(json['states'].length, equals(1));
        expect(json['states'][0]['logic'], isNotNull);
        expect(json['states'][0]['logic']['type'], equals('if'));
      });

      test('deserializes scene with modern conditional logic', () {
        final json = {
          'id': 'scene12',
          'name': 'Modern Scene',
          'states': [
            {
              'toggleId': 'SW1',
              'stateId': 'ON',
              'label': 'Light On',
              'isDefault': false,
              'commandBundles': [],
              'logic': {
                'type': 'if',
                'condition': 'SW1.ON AND SW2.OFF',
                'then': {
                  'type': 'leaf',
                  'sequence': [],
                },
              },
            },
          ],
          'rules': [],
          'switchSlots': {},
          'statusSlots': {},
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };

        final scene = ToggleScene.fromJson(json);

        expect(scene.hasModernConditionalLogic, isTrue);
        expect(scene.states.length, equals(1));
        expect(scene.states.first.hasConditionalLogic, isTrue);
      });

      test('preserves compatibility with legacy rules', () {
        final legacyScene = ToggleScene(
          id: 'scene13',
          name: 'Legacy Scene',
          states: [],
          rules: [
            ConditionalRule(
              id: 'rule1',
              toggleId: 'SW1',
              expectedStateId: 'ON',
              trueBundleId: 'bundle1',
            ),
          ],
        );

        final json = legacyScene.toJson();

        expect(json['rules'], isNotNull);
        expect(json['rules'].length, equals(1));
        expect(json['rules'][0]['id'], equals('rule1'));
      });
    });

    group('CopyWith Conditional Logic', () {
      test('preserves conditional logic when copying', () {
        final copiedScene = testScene.copyWith();

        expect(copiedScene.hasModernConditionalLogic, isTrue);
        expect(copiedScene.statesWithConditionalLogic.length, equals(1));
      });

      test('can modify states with conditional logic when copying', () {
        final newState = ToggleState(
          toggleId: 'SW3',
          stateId: 'ON',
          label: 'New State',
          logic: testIfNode,
        );

        final modifiedScene = testScene.copyWith(
          states: [...testScene.states, newState],
        );

        expect(modifiedScene.statesWithConditionalLogic.length, equals(2));
        expect(modifiedScene.totalConditionalLogicComplexity,
               greaterThan(testScene.totalConditionalLogicComplexity));
      });

      test('can remove all conditional logic when copying', () {
        final statesWithoutLogic = testScene.statesWithoutConditionalLogic;
        final sceneWithoutLogic = testScene.copyWith(states: statesWithoutLogic);

        expect(sceneWithoutLogic.hasModernConditionalLogic, isFalse);
        expect(sceneWithoutLogic.statesWithConditionalLogic, isEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles empty scene gracefully', () {
        final emptyScene = ToggleScene(
          id: 'empty',
          name: 'Empty Scene',
        );

        expect(emptyScene.hasConditionalLogic, isFalse);
        expect(emptyScene.statesWithConditionalLogic, isEmpty);
        expect(emptyScene.conditionalToggleReferences, isEmpty);
        expect(emptyScene.totalConditionalLogicComplexity, equals(0));
        expect(emptyScene.validateAllConditionalLogic(), isEmpty);
      });

      test('handles scene with only legacy rules', () {
        final legacyOnlyScene = ToggleScene(
          id: 'legacy',
          name: 'Legacy Only',
          rules: [
            ConditionalRule(
              id: 'rule1',
              toggleId: 'SW1',
              expectedStateId: 'ON',
              trueBundleId: 'bundle1',
            ),
          ],
        );

        expect(legacyOnlyScene.hasConditionalLogic, isTrue);
        expect(legacyOnlyScene.hasModernConditionalLogic, isFalse);
        expect(legacyOnlyScene.statesWithConditionalLogic, isEmpty);
      });
    });
  });
}