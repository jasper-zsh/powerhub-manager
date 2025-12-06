import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';

void main() {
  test('debug JSON export', () {
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

    print('=== Raw logic ===');
    print('Logic type: ${toggleState.logic.runtimeType}');
    if (toggleState.logic is SwitchHubIfNode) {
      final ifNode = toggleState.logic as SwitchHubIfNode;
      print('Condition: ${ifNode.condition}');
      if (ifNode.thenNode is SwitchHubLeafNode) {
        final leafNode = ifNode.thenNode as SwitchHubLeafNode;
        print('Then sequence length: ${leafNode.sequence.length}');
        for (int i = 0; i < leafNode.sequence.length; i++) {
          final item = leafNode.sequence[i];
          print('  Item $i: targetMac="${item.targetMac}", packets=${item.commandPackets.length}');
        }
      }
    }

    print('\n=== Fully resolved logic ===');
    final resolvedLogic = toggleState.fullyResolvedLogic;
    print('Resolved logic type: ${resolvedLogic.runtimeType}');
    if (resolvedLogic is SwitchHubIfNode) {
      final ifNode = resolvedLogic as SwitchHubIfNode;
      print('Condition: ${ifNode.condition}');
      if (ifNode.thenNode is SwitchHubLeafNode) {
        final leafNode = ifNode.thenNode as SwitchHubLeafNode;
        print('Resolved then sequence length: ${leafNode.sequence.length}');
        for (int i = 0; i < leafNode.sequence.length; i++) {
          final item = leafNode.sequence[i];
          print('  Resolved Item $i: targetMac="${item.targetMac}", packets=${item.commandPackets.length}');
          for (int j = 0; j < item.commandPackets.length; j++) {
            final packet = item.commandPackets[j];
            print('    Packet $j: mode=0x${packet.mode.toRadixString(2).padLeft(2, '0')}, channel=${packet.channel}, payload="${packet.payload}"');
          }
        }
      }
    }

    print('\n=== JSON Export ===');
    final json = toggleState.toJson();
    print('JSON keys: ${json.keys.toList()}');
    if (json.containsKey('logic')) {
      final logicJson = json['logic'] as Map<String, dynamic>;
      print('Logic type in JSON: ${logicJson['type']}');
      print('Logic condition in JSON: ${logicJson['condition']}');

      if (logicJson.containsKey('then')) {
        final thenJson = logicJson['then'] as Map<String, dynamic>;
        if (thenJson.containsKey('sequence')) {
          final sequenceJson = thenJson['sequence'] as List<dynamic>?;
          if (sequenceJson != null) {
            print('JSON sequence length: ${sequenceJson.length}');
            for (int i = 0; i < sequenceJson.length; i++) {
              final itemJson = sequenceJson[i] as Map<String, dynamic>;
              final packetsList = itemJson['commandPackets'] as List<dynamic>?;
              print('  JSON Item $i: targetMac="${itemJson['targetMac']}", packets=${packetsList?.length ?? 0}');
            }
          }
        }
      }
    }

    print('\n=== Full JSON ===');
    print(const JsonEncoder.withIndent('  ').convert(json));
  });
}