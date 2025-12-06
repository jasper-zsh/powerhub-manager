import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';

void main() {
  group('JSON Export Bundle Resolution Tests', () {
    test('should export resolved JSON with proper controller IDs and command packets', () {
      // Create test bundles
      final testBundles = [
        CommandBundle(
          id: 'bundle-test-1',
          label: 'Test Bundle 1',
          isEnabled: true,
          actions: [
            CommandAction(
              controllerId: 'controller-001',
              channel: 1,
              type: CommandActionType.channelValue,
              value: 255,
            ),
            CommandAction(
              controllerId: 'controller-002',
              channel: 2,
              type: CommandActionType.blinkMode,
              period: 500,
            ),
          ],
        ),
      ];

      // Create a toggle state with conditional logic containing bundle references
      final toggleState = ToggleState(
        toggleId: 'SW1',
        stateId: 'ON',
        label: 'On State',
        isDefault: false,
        commandBundles: testBundles,
        logic: SwitchHubIfNode(
          condition: 'SW2.ON',
          thenNode: SwitchHubLeafNode(
            sequence: [
              SwitchHubSequenceItem(
                targetMac: 'bundle:bundle-test-1', // Bundle reference
                commandPackets: [], // Will be resolved
                delayMs: 0,
              ),
            ],
          ),
          elseNode: const SwitchHubLeafNode(sequence: []),
        ),
      );

      // Export to JSON
      final json = toggleState.toJson();

      // Parse JSON back to verify structure
      final logicJson = json['logic'] as Map<String, dynamic>;
      expect(logicJson['type'], equals('if'));
      expect(logicJson['condition'], equals('SW2.ON'));

      final thenJson = logicJson['then'] as Map<String, dynamic>;
      expect(thenJson['type'], equals('leaf'));

      final sequenceJson = thenJson['sequence'] as List<dynamic>;

      // Should have resolved bundle references to individual controllers
      expect(sequenceJson.length, equals(2)); // 2 controllers in the bundle

      // Verify first controller sequence
      final controller1 = sequenceJson.firstWhere(
        (item) => item['targetMac'] == 'controller-001',
        orElse: () => throw Exception('Controller 001 not found'),
      );
      expect(controller1['targetMac'], equals('controller-001'));

      final packets1 = controller1['commandPackets'] as List<dynamic>;
      expect(packets1.length, equals(1));

      final packet1 = packets1.first as Map<String, dynamic>;
      expect(packet1['mode'], equals(0x00)); // channelValue mode
      expect(packet1['channel'], equals(1));
      expect(packet1['payload'], isNotEmpty);

      // Verify second controller sequence
      final controller2 = sequenceJson.firstWhere(
        (item) => item['targetMac'] == 'controller-002',
        orElse: () => throw Exception('Controller 002 not found'),
      );
      expect(controller2['targetMac'], equals('controller-002'));

      final packets2 = controller2['commandPackets'] as List<dynamic>;
      expect(packets2.length, equals(1));

      final packet2 = packets2.first as Map<String, dynamic>;
      expect(packet2['mode'], equals(0x02)); // blinkMode mode
      expect(packet2['channel'], equals(2));
      expect(packet2['payload'], isNotEmpty);

      print('JSON Export Test PASSED: Bundle references properly resolved');
      print('Exported JSON: ${const JsonEncoder.withIndent('  ').convert(json)}');
    });

    test('should handle empty bundles and non-bundle references correctly', () {
      final toggleState = ToggleState(
        toggleId: 'SW1',
        stateId: 'OFF',
        label: 'Off State',
        isDefault: true,
        commandBundles: [],
        logic: SwitchHubLeafNode(
          sequence: [
            SwitchHubSequenceItem(
              targetMac: 'bundle:non-existent', // Non-existent bundle
              commandPackets: [
                SwitchHubCommandPacket(
                  mode: 0x00,
                  channel: 0,
                  payload: 'AQ==', // Base64 for [1]
                ),
              ],
              delayMs: 100,
            ),
            SwitchHubSequenceItem(
              targetMac: 'direct-controller', // Direct controller reference
              commandPackets: [
                SwitchHubCommandPacket(
                  mode: 0x01,
                  channel: 1,
                  payload: 'Af8BCA==', // Base64 for gradient mode
                ),
              ],
              delayMs: 0,
            ),
          ],
        ),
      );

      final json = toggleState.toJson();

      // Should preserve non-bundle references as-is
      final logicJson = json['logic'] as Map<String, dynamic>;
      final sequenceJson = logicJson['sequence'] as List<dynamic>;
      expect(sequenceJson.length, equals(2));

      // Non-existent bundle should be preserved
      final bundleRef = sequenceJson.firstWhere(
        (item) => item['targetMac'] == 'bundle:non-existent',
        orElse: () => throw Exception('Bundle reference not found'),
      );
      expect(bundleRef['targetMac'], equals('bundle:non-existent'));

      // Direct controller should be preserved
      final directRef = sequenceJson.firstWhere(
        (item) => item['targetMac'] == 'direct-controller',
        orElse: () => throw Exception('Direct controller not found'),
      );
      expect(directRef['targetMac'], equals('direct-controller'));
    });
  });
}