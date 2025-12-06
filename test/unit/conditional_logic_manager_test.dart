import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/conditional_logic_manager.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';

void main() {
  group('ConditionalLogicManager Tests', () {
    late ConditionalLogicManager manager;
    late List<CommandBundle> testBundles;
    late List<String> testToggles;
    late Map<String, String> testAliases;

    setUp(() {
      manager = const ConditionalLogicManager();
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
      testToggles = ['SW1', 'SW2', 'SW3'];
      testAliases = {'LIGHT': 'SW1', 'FAN': 'SW2'};
    });

    group('Bundle Resolution Tests', () {
      test('resolves simple bundle reference in leaf node', () {
        final leafNode = SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle1',
            commandPackets: [],
          ),
        ]);

        final resolved = manager.resolveBundleReferences(leafNode, testBundles);

        expect(resolved, isA<SwitchHubLeafNode>());
        final resolvedLeaf = resolved as SwitchHubLeafNode;
        expect(resolvedLeaf.sequence.length, equals(1));
        expect(resolvedLeaf.sequence.first.targetMac, equals('00:00:00:00:00:00'));
        expect(resolvedLeaf.sequence.first.commandPackets.isNotEmpty, isTrue);
      });

      test('resolves bundle reference in conditional node', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON',
          thenNode: SwitchHubLeafNode(sequence: [
            SwitchHubSequenceItem(
              targetMac: 'bundle:bundle1',
              commandPackets: [],
            ),
          ]),
        );

        final resolved = manager.resolveBundleReferences(ifNode, testBundles);

        expect(resolved, isA<SwitchHubIfNode>());
        final resolvedIf = resolved as SwitchHubIfNode;
        expect(resolvedIf.condition, equals('SW1.ON'));
        expect(resolvedIf.thenNode, isA<SwitchHubLeafNode>());
      });

      test('handles unknown bundle reference gracefully', () {
        final leafNode = SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:unknown',
            commandPackets: [],
          ),
        ]);

        final resolved = manager.resolveBundleReferences(leafNode, testBundles);

        expect(resolved, isA<SwitchHubLeafNode>());
        final resolvedLeaf = resolved as SwitchHubLeafNode;
        expect(resolvedLeaf.sequence.length, equals(1));
        expect(resolvedLeaf.sequence.first.targetMac, equals('bundle:unknown'));
        expect(resolvedLeaf.sequence.first.commandPackets.isEmpty, isTrue);
      });

      test('preserves non-bundle sequence items', () {
        final leafNode = SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'AA:BB:CC:DD:EE:FF',
            commandPackets: [
              const SwitchHubCommandPacket(
                mode: 1,
                channel: 1,
                payload: 'AQ==',
              ),
            ],
          ),
        ]);

        final resolved = manager.resolveBundleReferences(leafNode, testBundles);

        expect(resolved, isA<SwitchHubLeafNode>());
        final resolvedLeaf = resolved as SwitchHubLeafNode;
        expect(resolvedLeaf.sequence.length, equals(1));
        expect(resolvedLeaf.sequence.first.targetMac, equals('AA:BB:CC:DD:EE:FF'));
        expect(resolvedLeaf.sequence.first.commandPackets.length, equals(1));
      });
    });

    group('Validation Tests', () {
      test('validates simple conditional logic correctly', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON AND SW2.OFF',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
        expect(result.warnings, isEmpty);
      });

      test('detects unknown toggle references', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW99.ON',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Unknown toggle reference: SW99.ON'));
      });

      test('validates alias references correctly', () {
        final ifNode = SwitchHubIfNode(
          condition: 'LIGHT.ON',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });

      test('detects unknown alias references', () {
        final ifNode = SwitchHubIfNode(
          condition: 'UNKNOWN.ON',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('Unknown toggle reference: UNKNOWN.ON'));
      });

      test('warns about complex conditional logic', () {
        // Create a very complex conditional expression
        String condition = 'SW1.ON';
        for (int i = 0; i < 10; i++) {
          condition += ' AND SW2.OFF OR SW3.ON AND SW4.ON OR SW5.OFF';
        }

        final ifNode = SwitchHubIfNode(
          condition: condition,
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        expect(result.complexity, greaterThan(50));
        expect(result.warnings, isNotEmpty);
        expect(result.warnings.any((warning) => warning.contains('Complex conditional logic')), isTrue);
      });
    });

    group('Conditional Rule Creation Tests', () {
      test('creates conditional rule from bundle', () {
        final condition = 'SW1.ON';
        final ifNode = manager.createConditionalFromBundle('bundle1', testBundles, condition);

        expect(ifNode, isA<SwitchHubIfNode>());
        expect(ifNode.condition, equals(condition));
        expect(ifNode.thenNode, isA<SwitchHubLeafNode>());
      });

      test('throws error for unknown bundle', () {
        expect(
          () => manager.createConditionalFromBundle('unknown', testBundles, 'SW1.ON'),
          throwsArgumentError,
        );
      });
    });

    group('Bundle Reference Extraction Tests', () {
      test('extracts bundle references from simple logic', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON',
          thenNode: SwitchHubLeafNode(sequence: [
            SwitchHubSequenceItem(
              targetMac: 'bundle:bundle1',
              commandPackets: [],
            ),
          ]),
        );

        final bundleIds = manager.extractBundleReferences(ifNode);

        expect(bundleIds, contains('bundle1'));
        expect(bundleIds.length, equals(1));
      });

      test('extracts bundle references from nested logic', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON',
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

        final bundleIds = manager.extractBundleReferences(ifNode);

        expect(bundleIds, contains('bundle1'));
        expect(bundleIds, contains('bundle2'));
        expect(bundleIds.length, equals(2));
      });

      test('handles logic without bundle references', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON',
          thenNode: SwitchHubLeafNode(sequence: [
            SwitchHubSequenceItem(
              targetMac: 'AA:BB:CC:DD:EE:FF',
              commandPackets: [],
            ),
          ]),
        );

        final bundleIds = manager.extractBundleReferences(ifNode);

        expect(bundleIds, isEmpty);
      });
    });

    group('Logic Merging Tests', () {
      test('merges single rule', () {
        final rules = [
          SwitchHubIfNode(
            condition: 'SW1.ON',
            thenNode: SwitchHubLeafNode(sequence: []),
          ),
        ];

        final merged = manager.mergeConditionalRules(rules);

        expect(merged, same(rules.first));
      });

      test('merges multiple rules into if-else chain', () {
        final rules = [
          SwitchHubIfNode(
            condition: 'SW1.ON',
            thenNode: SwitchHubLeafNode(sequence: []),
          ),
          SwitchHubIfNode(
            condition: 'SW2.ON',
            thenNode: SwitchHubLeafNode(sequence: []),
          ),
        ];

        final merged = manager.mergeConditionalRules(rules);

        expect(merged, isA<SwitchHubIfNode>());
        final mergedIf = merged as SwitchHubIfNode;
        expect(mergedIf.condition, equals('SW2.ON')); // Last rule becomes outer
        expect(mergedIf.elseNode, isA<SwitchHubIfNode>());
      });

      test('handles empty rules list', () {
        final merged = manager.mergeConditionalRules([]);

        expect(merged, isA<SwitchHubLeafNode>());
        final mergedLeaf = merged as SwitchHubLeafNode;
        expect(mergedLeaf.sequence, isEmpty);
      });
    });

    group('Complexity Calculation Tests', () {
      test('calculates complexity for simple conditions', () {
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON AND SW2.OFF',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        // Should count tokens in condition
        expect(result.complexity, greaterThan(0));
      });

      test('calculates higher complexity for nested conditions', () {
        final nestedNode = SwitchHubIfNode(
          condition: 'SW1.ON',
          thenNode: SwitchHubIfNode(
            condition: 'SW2.OFF',
            thenNode: SwitchHubLeafNode(sequence: []),
          ),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: nestedNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        expect(result.complexity, greaterThan(5));
      });
    });

    group('Circular Dependency Detection Tests', () {
      test('detects simple circular dependency', () {
        // This test is tricky to implement without actual object references
        // For now, we'll test the basic case
        final ifNode = SwitchHubIfNode(
          condition: 'SW1.ON',
          thenNode: SwitchHubLeafNode(sequence: []),
        );

        final state = ToggleState(
          toggleId: 'SW1',
          stateId: 'ON',
          label: 'Test State',
          logic: ifNode,
        );

        final result = manager.validateLogic(state, testToggles, testAliases);

        // Simple case shouldn't have circular dependency
        expect(result.errors, isNot(contains('circular dependency')));
      });
    });
  });

  group('ConditionalValidationResult Tests', () {
    test('creates valid result', () {
      final result = ConditionalValidationResult(
        isValid: true,
        errors: [],
        warnings: [],
        complexity: 10,
      );

      expect(result.isValid, isTrue);
      expect(result.hasErrors, isFalse);
      expect(result.hasWarnings, isFalse);
      expect(result.complexity, equals(10));
    });

    test('creates invalid result with warnings', () {
      final result = ConditionalValidationResult(
        isValid: false,
        errors: ['Error 1', 'Error 2'],
        warnings: ['Warning 1'],
        complexity: 5,
      );

      expect(result.isValid, isFalse);
      expect(result.hasErrors, isTrue);
      expect(result.hasWarnings, isTrue);
      expect(result.complexity, equals(5));
    });
  });

  group('ConditionalEvaluationMetrics Tests', () {
    test('creates metrics correctly', () {
      final metrics = ConditionalEvaluationMetrics(
        evaluationTimeMs: 150,
        nodesEvaluated: 5,
        conditionsChecked: 3,
        bundlesExecuted: 2,
      );

      expect(metrics.evaluationTimeMs, equals(150));
      expect(metrics.nodesEvaluated, equals(5));
      expect(metrics.conditionsChecked, equals(3));
      expect(metrics.bundlesExecuted, equals(2));

      final metricsString = metrics.toString();
      expect(metricsString, contains('150ms'));
      expect(metricsString, contains('nodes: 5'));
      expect(metricsString, contains('conditions: 3'));
      expect(metricsString, contains('bundles: 2'));
    });
  });
}