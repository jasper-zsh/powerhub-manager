import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/conditional_logic_manager.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';

void main() {
  group('Conditional Logic Bundle Resolution Tests', () {
    late ConditionalLogicManager manager;
    late List<CommandBundle> testBundles;

    setUp(() {
      manager = const ConditionalLogicManager();

      // Create test bundles with multiple controllers
      testBundles = [
        CommandBundle(
          id: 'bundle-test-1',
          label: 'Test Bundle 1',
          isEnabled: true,
          actions: [
            // Controller 1 actions
            CommandAction(
              controllerId: 'controller-001',
              channel: 1,
              type: CommandActionType.channelValue,
              value: 255,
            ),
            CommandAction(
              controllerId: 'controller-001',
              channel: 2,
              type: CommandActionType.channelValue,
              value: 128,
            ),
            // Controller 2 actions
            CommandAction(
              controllerId: 'controller-002',
              channel: 1,
              type: CommandActionType.blinkMode,
              period: 500,
            ),
          ],
        ),
        CommandBundle(
          id: 'bundle-test-2',
          label: 'Test Bundle 2',
          isEnabled: true,
          actions: [
            CommandAction(
              controllerId: 'controller-003',
              channel: 1,
              type: CommandActionType.gradientMode,
              duration: 2000,
              value: 200,
            ),
          ],
        ),
      ];
    });

    test('should resolve bundle references to multiple controller sequences', () {
      // Create a leaf node with bundle references
      final leafNode = SwitchHubLeafNode(
        sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle-test-1',
            commandPackets: [], // Empty packets - should be resolved
            delayMs: 0,
          ),
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle-test-2',
            commandPackets: [], // Empty packets - should be resolved
            delayMs: 100,
          ),
        ],
      );

      // Resolve bundle references
      final resolvedNode = manager.resolveBundleReferences(leafNode, testBundles);

      // Verify resolution results
      expect(resolvedNode, isA<SwitchHubLeafNode>());
      final resolvedLeaf = resolvedNode as SwitchHubLeafNode;

      // Should have sequence items for all controllers
      // bundle-test-1 has 2 controllers, bundle-test-2 has 1 controller
      expect(resolvedLeaf.sequence.length, equals(3)); // 2 + 1 controllers

      // Verify controller IDs are correctly set as targetMac
      final targetMacs = resolvedLeaf.sequence.map((item) => item.targetMac).toSet();
      expect(targetMacs, contains('controller-001'));
      expect(targetMacs, contains('controller-002'));
      expect(targetMacs, contains('controller-003'));

      // Verify command packets are generated correctly
      for (final sequenceItem in resolvedLeaf.sequence) {
        expect(sequenceItem.commandPackets.isNotEmpty, isTrue);

        // Verify packet structure
        for (final packet in sequenceItem.commandPackets) {
          expect(packet.mode, isIn([0x00, 0x01, 0x02, 0x03])); // Valid modes
          expect(packet.channel, greaterThanOrEqualTo(0));
          expect(packet.payload, isNotEmpty);

          // Verify payload is valid base64
          expect(() => base64Decode(packet.payload), returnsNormally);
        }
      }
    });

    test('should handle empty bundles correctly', () {
      final leafNode = SwitchHubLeafNode(
        sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:non-existent-bundle',
            commandPackets: [
              SwitchHubCommandPacket(
                mode: 0x00,
                channel: 0,
                payload: base64Encode([0]),
              ),
            ],
            delayMs: 0,
          ),
        ],
      );

      final resolvedNode = manager.resolveBundleReferences(leafNode, testBundles);

      expect(resolvedNode, isA<SwitchHubLeafNode>());
      final resolvedLeaf = resolvedNode as SwitchHubLeafNode;

      // Should keep original item for non-existent bundle
      expect(resolvedLeaf.sequence.length, equals(1));
      expect(resolvedLeaf.sequence.first.targetMac, equals('bundle:non-existent-bundle'));
    });

    test('should handle mixed bundle and non-bundle references', () {
      final leafNode = SwitchHubLeafNode(
        sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle-test-1',
            commandPackets: [],
            delayMs: 0,
          ),
          SwitchHubSequenceItem(
            targetMac: 'controller-direct',
            commandPackets: [
              SwitchHubCommandPacket(
                mode: 0x00,
                channel: 1,
                payload: base64Encode([255]),
              ),
            ],
            delayMs: 50,
          ),
        ],
      );

      final resolvedNode = manager.resolveBundleReferences(leafNode, testBundles);

      expect(resolvedNode, isA<SwitchHubLeafNode>());
      final resolvedLeaf = resolvedNode as SwitchHubLeafNode;

      // Should have bundle-resolved items + direct item
      // bundle-test-1 has 2 controllers + 1 direct item = 3 total
      expect(resolvedLeaf.sequence.length, equals(3));

      // Verify direct item is preserved
      final directItem = resolvedLeaf.sequence.firstWhere(
        (item) => item.targetMac == 'controller-direct',
        orElse: () => throw Exception('Direct item not found'),
      );
      expect(directItem.commandPackets.length, equals(1));
      expect(directItem.delayMs, equals(50));
    });

    test('should handle complex conditional logic tree', () {
      // Create a conditional tree with bundle references
      final ifNode = SwitchHubIfNode(
        condition: 'SW1.ON',
        thenNode: SwitchHubLeafNode(
          sequence: [
            SwitchHubSequenceItem(
              targetMac: 'bundle:bundle-test-1',
              commandPackets: [],
              delayMs: 0,
            ),
          ],
        ),
        elseNode: SwitchHubLeafNode(
          sequence: [
            SwitchHubSequenceItem(
              targetMac: 'bundle:bundle-test-2',
              commandPackets: [],
              delayMs: 0,
            ),
          ],
        ),
      );

      final resolvedNode = manager.resolveBundleReferences(ifNode, testBundles);

      expect(resolvedNode, isA<SwitchHubIfNode>());
      final resolvedIf = resolvedNode as SwitchHubIfNode;

      // Verify condition is preserved
      expect(resolvedIf.condition, equals('SW1.ON'));

      // Verify then branch (bundle-test-1 has 2 controllers)
      expect(resolvedIf.thenNode, isA<SwitchHubLeafNode>());
      final thenNode = resolvedIf.thenNode as SwitchHubLeafNode;
      expect(thenNode.sequence.length, equals(2)); // 2 controllers

      // Verify else branch (bundle-test-2 has 1 controller)
      expect(resolvedIf.elseNode, isA<SwitchHubLeafNode>());
      final elseNode = resolvedIf.elseNode! as SwitchHubLeafNode;
      expect(elseNode.sequence.length, equals(1)); // 1 controller
    });
  });
}