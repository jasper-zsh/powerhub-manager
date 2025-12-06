import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';

void main() {
  group('ToggleState Conditional Logic Tests', () {
    late List<CommandBundle> testBundles;
    late SwitchHubIfNode testIfNode;
    late SwitchHubLeafNode testLeafNode;

    setUp(() {
      testBundles = [
        CommandBundle(
          id: 'bundle1',
          label: 'Morning Scene',
          actions: [
            CommandAction(
              controllerId: '1',
              type: CommandActionType.channelValue,
              channel: 1,
              value: 255,
            ),
          ],
        ),
        CommandBundle(
          id: 'bundle2',
          label: 'Evening Scene',
          actions: [
            CommandAction(
              controllerId: '1',
              type: CommandActionType.channelValue,
              channel: 1,
              value: 100,
            ),
          ],
        ),
      ];

      testIfNode = SwitchHubIfNode(
        condition: 'SW1.ON AND SW2.OFF',
        thenNode: SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle1',
            commandPackets: [],
          ),
        ]),
        elseNode: SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle2',
            commandPackets: [],
          ),
        ]),
      );

      testLeafNode = SwitchHubLeafNode(sequence: [
        SwitchHubSequenceItem(
          targetMac: 'bundle:bundle1',
          commandPackets: [],
        ),
      ]);
    });

    group('Basic Conditional Logic Properties', () {
      test('detects conditional logic presence correctly', () {
        final stateWithLogic = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final stateWithoutLogic = ToggleState(
          toggleId: 'SW2',
          stateId: 'OFF',
          label: 'Light Off',
        );

        expect(stateWithLogic.hasConditionalLogic, isTrue);
        expect(stateWithoutLogic.hasConditionalLogic, isFalse);
      });

      test('returns resolved logic correctly', () {
        final stateWithLogic = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final stateWithoutLogic = ToggleState(
          toggleId: 'SW2',
          stateId: 'OFF',
          label: 'Light Off',
          commandBundles: testBundles,
        );

        expect(stateWithLogic.resolvedLogic, same(testIfNode));
        expect(stateWithoutLogic.resolvedLogic, isA<SwitchHubLeafNode>());
      });
    });

    group('Bundle Reference Management', () {
      test('extracts bundle references from conditional logic', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final bundleRefs = state.conditionalBundleReferences;
        expect(bundleRefs, contains('bundle1'));
        expect(bundleRefs, contains('bundle2'));
        expect(bundleRefs.length, equals(2));
      });

      test('returns empty bundle references for non-conditional state', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
        );

        final bundleRefs = state.conditionalBundleReferences;
        expect(bundleRefs, isEmpty);
      });

      test('handles conditional logic without bundle references', () {
        final ifNodeWithoutBundles = SwitchHubIfNode(
          condition: 'SW1.ON',
          thenNode: SwitchHubLeafNode(sequence: [
            SwitchHubSequenceItem(
              targetMac: 'AA:BB:CC:DD:EE:FF',
              commandPackets: [],
            ),
          ]),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: ifNodeWithoutBundles,
        );

        final bundleRefs = state.conditionalBundleReferences;
        expect(bundleRefs, isEmpty);
      });
    });

    group('Conditional Logic Validation', () {
      test('validates simple conditional logic correctly', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final availableToggles = ['SW1', 'SW2', 'SW3'];
        final aliases = <String, String>{};

        final result = state.validateConditionalLogic(availableToggles, aliases);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('detects invalid toggle references', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final availableToggles = ['SW1']; // Missing SW2
        final aliases = <String, String>{};

        final result = state.validateConditionalLogic(availableToggles, aliases);

        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
      });

      test('validates non-conditional state', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
        );

        final availableToggles = <String>[];
        final aliases = <String, String>{};

        final result = state.validateConditionalLogic(availableToggles, aliases);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
    });

    group('Conditional Rule Creation', () {
      test('creates conditional rule from bundle', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          commandBundles: testBundles,
        );

        final condition = 'SW1.ON';
        final conditionalState = state.withConditionalRule('bundle1', condition, testBundles);

        expect(conditionalState.hasConditionalLogic, isTrue);
        expect(conditionalState.logic, isA<SwitchHubIfNode>());

        final ifNode = conditionalState.logic! as SwitchHubIfNode;
        expect(ifNode.condition, equals(condition));
        expect(ifNode.thenNode, isA<SwitchHubLeafNode>());
      });

      test('preserves other state properties when creating conditional rule', () {
        final originalState = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          isDefault: true,
          commandBundles: testBundles,
        );

        final condition = 'SW1.ON';
        final conditionalState = originalState.withConditionalRule('bundle1', condition, testBundles);

        expect(conditionalState.toggleId, equals(originalState.toggleId));
        expect(conditionalState.stateId, equals(originalState.stateId));
        expect(conditionalState.label, equals(originalState.label));
        expect(conditionalState.isDefault, equals(originalState.isDefault));
        expect(conditionalState.commandBundles, equals(originalState.commandBundles));
      });

      test('throws error for unknown bundle when creating conditional rule', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          commandBundles: testBundles,
        );

        expect(
          () => state.withConditionalRule('unknown', 'SW1.ON', testBundles),
          throwsArgumentError,
        );
      });
    });

    group('Complexity Metrics', () {
      test('calculates complexity for simple conditional logic', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final complexity = state.conditionalLogicComplexity;
        expect(complexity, greaterThan(0));
      });

      test('returns zero complexity for non-conditional state', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
        );

        final complexity = state.conditionalLogicComplexity;
        expect(complexity, equals(0));
      });

      test('calculates higher complexity for nested conditions', () {
        final nestedNode = SwitchHubIfNode(
          condition: 'SW1.ON AND SW2.OFF OR SW3.ON',
          thenNode: SwitchHubIfNode(
            condition: 'SW4.OFF AND SW5.ON',
            thenNode: SwitchHubLeafNode(sequence: []),
          ),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: nestedNode,
        );

        final complexity = state.conditionalLogicComplexity;
        expect(complexity, greaterThan(10));
      });
    });

    group('CopyWith Conditional Logic', () {
      test('preserves conditional logic when copying', () {
        final originalState = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final copiedState = originalState.copyWith();

        expect(copiedState.hasConditionalLogic, isTrue);
        expect(copiedState.logic, same(originalState.logic));
      });

      test('can change conditional logic when copying', () {
        final originalState = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final newLogic = SwitchHubLeafNode(sequence: []);
        final copiedState = originalState.copyWith(logic: newLogic);

        expect(copiedState.hasConditionalLogic, isTrue);
        expect(copiedState.logic, same(newLogic));
      });

      test('can remove conditional logic when copying', () {
        final originalState = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final copiedState = originalState.copyWith(logic: null);

        expect(copiedState.hasConditionalLogic, isFalse);
        expect(copiedState.logic, isNull);
      });
    });

    group('JSON Serialization with Conditional Logic', () {
      test('serializes state with conditional logic', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testIfNode,
        );

        final json = state.toJson();

        expect(json['toggleId'], equals('SW1'));
        expect(json['stateId'], equals('ON'));
        expect(json['label'], equals('Light On'));
        expect(json['logic'], isNotNull);
        expect(json['logic']['type'], equals('if'));
        expect(json['logic']['condition'], equals('SW1.ON AND SW2.OFF'));
      });

      test('deserializes state with conditional logic', () {
        final json = {
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
        };

        final state = ToggleState.fromJson(json);

        expect(state.toggleId, equals('SW1'));
        expect(state.stateId, equals('ON'));
        expect(state.label, equals('Light On'));
        expect(state.hasConditionalLogic, isTrue);
        expect(state.logic, isA<SwitchHubIfNode>());

        final ifNode = state.logic! as SwitchHubIfNode;
        expect(ifNode.condition, equals('SW1.ON AND SW2.OFF'));
      });

      test('serializes and deserializes state without conditional logic', () {
        final originalState = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          commandBundles: testBundles,
        );

        final json = originalState.toJson();
        final deserializedState = ToggleState.fromJson(json);

        expect(deserializedState.toggleId, equals(originalState.toggleId));
        expect(deserializedState.stateId, equals(originalState.stateId));
        expect(deserializedState.label, equals(originalState.label));
        expect(deserializedState.hasConditionalLogic, isFalse);
        expect(deserializedState.commandBundles.length, equals(originalState.commandBundles.length));
      });
    });

    group('Fully Resolved Logic', () {
      test('returns same logic for non-bundle references', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: SwitchHubLeafNode(sequence: [
            SwitchHubSequenceItem(
              targetMac: 'AA:BB:CC:DD:EE:FF',
              commandPackets: [],
            ),
          ]),
        );

        final resolvedLogic = state.fullyResolvedLogic;
        expect(resolvedLogic, same(state.resolvedLogic));
      });

      test('resolves bundle references in logic', () {
        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Light On',
          logic: testLeafNode,
          commandBundles: testBundles,
        );

        final resolvedLogic = state.fullyResolvedLogic;
        expect(resolvedLogic, isA<SwitchHubLeafNode>());

        final resolvedLeaf = resolvedLogic as SwitchHubLeafNode;
        expect(resolvedLeaf.sequence.length, equals(1));
        expect(resolvedLeaf.sequence.first.targetMac, equals('00:00:00:00:00:00'));
        expect(resolvedLeaf.sequence.first.commandPackets.isNotEmpty, isTrue);
      });
    });
  });
}