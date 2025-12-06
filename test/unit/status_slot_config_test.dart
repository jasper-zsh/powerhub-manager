import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_data_type.dart';

void main() {
  group('StatusSlot Multi-Channel Configuration Tests', () {
    test('isMultiChannelCurrent returns true for multi-channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,2',
      );

      expect(statusSlot.isMultiChannelCurrent, isTrue);
    });

    test('isMultiChannelCurrent returns false for single channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '5',
      );

      expect(statusSlot.isMultiChannelCurrent, isFalse);
    });

    test('isMultiChannelCurrent returns false for non-current data types', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.voltage,
        params: 'anything',
      );

      expect(statusSlot.isMultiChannelCurrent, isFalse);
    });

    test('channelList returns parsed channels for multi-channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,2',
      );

      expect(statusSlot.channelList, equals([0, 1, 2]));
    });

    test('channelList returns null for single channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '5',
      );

      expect(statusSlot.channelList, isNull);
    });

    test('channelList returns null for invalid multi-channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,invalid,2',
      );

      expect(statusSlot.channelList, isNull);
    });

    test('defaultLabel generates correct label for multi-channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,2',
      );

      expect(statusSlot.defaultLabel, equals('Channels 0,1,2 Current'));
    });

    test('defaultLabel returns empty for single channel config', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '5',
      );

      expect(statusSlot.defaultLabel, isEmpty);
    });

    test('JSON serialization preserves multi-channel params', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,2',
        label: 'Custom Label',
      );

      final json = statusSlot.toJson();
      expect(json['params'], equals('0,1,2'));

      final restored = StatusSlot.fromJson(json);
      expect(restored.params, equals('0,1,2'));
      expect(restored.isMultiChannelCurrent, isTrue);
      expect(restored.channelList, equals([0, 1, 2]));
    });
  });
}