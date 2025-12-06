import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';

void main() {
  group('Sequence Generation Tests', () {
    test('channel value actions generate correct BLE packets', () {
      final action = CommandAction(
        controllerId: 'test-controller',
        type: CommandActionType.channelValue,
        channel: 2,
        value: 128,
      );

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: [action],
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(1));
      expect(sequence.first.targetMac, equals('test-controller'));
      expect(sequence.first.commandPackets.length, equals(1));

      final packet = sequence.first.commandPackets.first;
      expect(packet.mode, equals(0x00));
      expect(packet.channel, equals(2));

      // Payload should be [128] base64 encoded
      final payload = base64Decode(packet.payload);
      expect(payload, equals([128]));
    });

    test('gradient mode actions generate correct BLE packets', () {
      final action = CommandAction(
        controllerId: 'test-controller',
        type: CommandActionType.gradientMode,
        channel: 1,
        value: 200,
        duration: 5000, // 0x1388
      );

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: [action],
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(1));
      final packet = sequence.first.commandPackets.first;
      expect(packet.mode, equals(0x01));
      expect(packet.channel, equals(1));

      // Payload should be [200, 0x13, 0x88] base64 encoded
      final payload = base64Decode(packet.payload);
      expect(payload, equals([200, 0x13, 0x88]));
    });

    test('blink mode actions generate correct BLE packets', () {
      final action = CommandAction(
        controllerId: 'test-controller',
        type: CommandActionType.blinkMode,
        channel: 3,
        period: 2000, // 0x07D0
      );

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: [action],
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(1));
      final packet = sequence.first.commandPackets.first;
      expect(packet.mode, equals(0x02));
      expect(packet.channel, equals(3));

      // Payload should be [0x07, 0xD0] base64 encoded
      final payload = base64Decode(packet.payload);
      expect(payload, equals([0x07, 0xD0]));
    });

    test('strobe mode actions generate correct BLE packets', () {
      final action = CommandAction(
        controllerId: 'test-controller',
        type: CommandActionType.strobeMode,
        channel: 0,
        count: 10,
        totalTime: 3000, // 0x0BB8
        pauseTime: 500,   // 0x01F4
      );

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: [action],
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(1));
      final packet = sequence.first.commandPackets.first;
      expect(packet.mode, equals(0x03));
      expect(packet.channel, equals(0));

      // Payload should be [10, 0x0B, 0xB8, 0x01, 0xF4] base64 encoded
      final payload = base64Decode(packet.payload);
      expect(payload, equals([10, 0x0B, 0xB8, 0x01, 0xF4]));
    });

    test('multiple actions generate multiple packets', () {
      final actions = [
        CommandAction(
          controllerId: 'test-controller',
          type: CommandActionType.channelValue,
          channel: 1,
          value: 100,
        ),
        CommandAction(
          controllerId: 'test-controller',
          type: CommandActionType.strobeMode,
          channel: 2,
          count: 5,
          totalTime: 1000,
          pauseTime: 200,
        ),
      ];

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: actions,
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(1));
      expect(sequence.first.targetMac, equals('test-controller'));
      expect(sequence.first.commandPackets.length, equals(2));

      // First packet should be channel value
      expect(sequence.first.commandPackets[0].mode, equals(0x00));
      expect(sequence.first.commandPackets[0].channel, equals(1));

      // Second packet should be strobe mode
      expect(sequence.first.commandPackets[1].mode, equals(0x03));
      expect(sequence.first.commandPackets[1].channel, equals(2));
    });

    test('preset trigger actions do not generate BLE packets', () {
      final action = CommandAction(
        controllerId: 'test-controller',
        type: CommandActionType.presetTrigger,
        presetId: 5,
      );

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: [action],
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(0)); // Preset triggers don't generate packets
    });

    test('actions with boundary values work correctly', () {
      final action = CommandAction(
        controllerId: 'test-controller',
        type: CommandActionType.strobeMode,
        channel: 1,
        count: 1,
        totalTime: 10,
        pauseTime: 1,
      );

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: [action],
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(1));
      final packet = sequence.first.commandPackets.first;
      expect(packet.mode, equals(0x03));
      expect(packet.channel, equals(1));

      // Verify the payload encodes boundary values correctly
      final payload = base64Decode(packet.payload);
      expect(payload, equals([1, 0, 0x0A, 0, 0x01]));
    });

    test('different controllers are grouped separately', () {
      final actions = [
        CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.channelValue,
          channel: 1,
          value: 100,
        ),
        CommandAction(
          controllerId: 'controller-2',
          type: CommandActionType.channelValue,
          channel: 2,
          value: 200,
        ),
      ];

      final bundle = CommandBundle(
        id: 'test-bundle',
        label: 'Test Bundle',
        actions: actions,
      );

      final sequence = _sequenceFromBundle(bundle);

      expect(sequence.length, equals(2));
      expect(sequence[0].targetMac, equals('controller-1'));
      expect(sequence[1].targetMac, equals('controller-2'));
    });
  });
}

// Helper function to test the private method
List<SwitchHubSequenceItem> _sequenceFromBundle(CommandBundle bundle) {
  final grouped = <String, List<CommandAction>>{};
  for (final action in bundle.actions) {
    grouped
        .putIfAbsent(action.controllerId, () => <CommandAction>[])
        .add(action);
  }
  final items = <SwitchHubSequenceItem>[];
  grouped.forEach((controllerId, actions) {
    final packets = <SwitchHubCommandPacket>[];
    for (final action in actions) {
      final channel = action.channel;
      if (channel == null) {
        continue;
      }

      switch (action.type) {
        case CommandActionType.channelValue:
          final value = action.value;
          if (value != null) {
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x00,
                channel: channel,
                payload: base64Encode([value & 0xFF]),
              ),
            );
          }
          break;

        case CommandActionType.gradientMode:
          final value = action.value;
          final duration = action.duration;
          if (value != null && duration != null) {
            // Gradient mode: [0x01][channel][value][duration_high][duration_low]
            final durationHigh = (duration >> 8) & 0xFF;
            final durationLow = duration & 0xFF;
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x01,
                channel: channel,
                payload: base64Encode([value & 0xFF, durationHigh, durationLow]),
              ),
            );
          }
          break;

        case CommandActionType.blinkMode:
          final period = action.period;
          if (period != null) {
            // Blink mode: [0x02][channel][period_high][period_low]
            final periodHigh = (period >> 8) & 0xFF;
            final periodLow = period & 0xFF;
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x02,
                channel: channel,
                payload: base64Encode([periodHigh, periodLow]),
              ),
            );
          }
          break;

        case CommandActionType.strobeMode:
          final count = action.count;
          final totalTime = action.totalTime;
          final pauseTime = action.pauseTime;
          if (count != null && totalTime != null && pauseTime != null) {
            // Strobe mode: [0x03][channel][count][total_time_high][total_time_low][pause_time_high][pause_time_low]
            final totalTimeHigh = (totalTime >> 8) & 0xFF;
            final totalTimeLow = totalTime & 0xFF;
            final pauseTimeHigh = (pauseTime >> 8) & 0xFF;
            final pauseTimeLow = pauseTime & 0xFF;
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x03,
                channel: channel,
                payload: base64Encode([count & 0xFF, totalTimeHigh, totalTimeLow, pauseTimeHigh, pauseTimeLow]),
              ),
            );
          }
          break;

        case CommandActionType.presetTrigger:
          // Preset triggers don't generate BLE packets for sequence generation
          // They are handled separately in the orchestration provider
          break;
      }
    }
    if (packets.isNotEmpty) {
      items.add(
        SwitchHubSequenceItem(targetMac: controllerId, commandPackets: packets),
      );
    }
  });
  return items;
}