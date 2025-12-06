import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/status_data_type.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_slot_configuration.dart';
import 'package:app/models/switch_hub/status_data_source.dart';

void main() {
  group('StatusSlot', () {
    test('creates StatusSlot with required fields', () {
      const statusSlot = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );

      expect(statusSlot.sourceMac, 'LOCAL');
      expect(statusSlot.dataType, StatusDataType.voltage);
      expect(statusSlot.params, isNull);
      expect(statusSlot.label, isNull);
      expect(statusSlot.value, isNull);
    });

    test('creates StatusSlot with all fields', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
        label: 'Channel 0 Current',
        value: '1.25A',
      );

      expect(statusSlot.sourceMac, 'AA:BB:CC:DD:EE:FF');
      expect(statusSlot.dataType, StatusDataType.channelCurrent);
      expect(statusSlot.params, '0');
      expect(statusSlot.label, 'Channel 0 Current');
      expect(statusSlot.value, '1.25A');
    });

    test('copyWith creates new instance with updated values', () {
      const original = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );

      final updated = original.copyWith(value: '12.5V');

      expect(updated.sourceMac, original.sourceMac);
      expect(updated.dataType, original.dataType);
      expect(updated.value, '12.5V');
    });

    test('withValue creates new instance with updated value', () {
      const original = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );

      final updated = original.withValue('12.5V');

      expect(updated.value, '12.5V');
      expect(updated == original, isFalse);
    });

    test('validate returns null for valid configuration', () {
      const statusSlot = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );

      expect(statusSlot.validate(), isNull);
    });

    test('validate returns error for invalid MAC address', () {
      const statusSlot = StatusSlot(
        sourceMac: 'INVALID_MAC',
        dataType: StatusDataType.voltage,
      );

      expect(statusSlot.validate(), 'Invalid source MAC address format');
    });

    test('validate returns error for invalid channel number', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '20', // Invalid channel number
      );

      expect(statusSlot.validate(), 'Channel number 20 must be between 0 and 15');
    });

    test('validate returns error for invalid temperature zone', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.temperature,
        params: 'INVALID_ZONE',
      );

      expect(statusSlot.validate(), 'Temperature zone must be "POWER" or "CONTROL"');
    });

    test('validate accepts multi-channel parameters', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,2',
      );

      expect(statusSlot.validate(), isNull);
    });

    test('validate rejects invalid channel in multi-channel parameters', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,16,2',
      );

      expect(statusSlot.validate(), 'Channel number 16 must be between 0 and 15');
    });

    test('validate rejects duplicate channels in multi-channel parameters', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,0',
      );

      expect(statusSlot.validate(), 'Duplicate channels not allowed in sum parameters');
    });

    test('validate rejects too many channels in multi-channel parameters', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1,2,3,4,5,6,7,8',
      );

      expect(statusSlot.validate(), 'Maximum 8 channels allowed in sum parameters');
    });

    test('validate rejects malformed multi-channel parameters', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0,1.5,2',
      );

      expect(statusSlot.validate(), startsWith('Channel parameter format error:'));
    });

    test('validate accepts mixed order multi-channel parameters', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '3,1,4',
      );

      expect(statusSlot.validate(), isNull);
    });

    test('validate accepts single channel with whitespace', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: ' 5 ',
      );

      expect(statusSlot.validate(), isNull);
    });

    test('validate accepts multi-channel with whitespace', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: ' 1 , 2 , 3 ',
      );

      expect(statusSlot.validate(), isNull);
    });

    test('isLocal returns true for LOCAL source', () {
      const statusSlot = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );

      expect(statusSlot.isLocal, isTrue);
      expect(statusSlot.requiresRemoteConnection, isFalse);
    });

    test('isLocal returns false for remote MAC', () {
      const statusSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.voltage,
      );

      expect(statusSlot.isLocal, isFalse);
      expect(statusSlot.requiresRemoteConnection, isTrue);
    });

    test('JSON serialization and deserialization', () {
      const original = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
        label: 'Channel 0 Current',
      );

      final json = original.toJson();
      final deserialized = StatusSlot.fromJson(json);

      expect(deserialized.sourceMac, original.sourceMac);
      expect(deserialized.dataType, original.dataType);
      expect(deserialized.params, original.params);
      expect(deserialized.label, original.label);
    });
  });

  group('StatusSlotConfiguration', () {
    test('creates empty configuration', () {
      const config = StatusSlotConfiguration();

      expect(config.slot1, isNull);
      expect(config.slot2, isNull);
      expect(config.isConfigured, isFalse);
      expect(config.slots, isEmpty);
    });

    test('creates configuration with slots', () {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );
      const slot2 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        slot2: slot2,
        isConfigured: true,
      );

      expect(config.slot1, slot1);
      expect(config.slot2, slot2);
      expect(config.isConfigured, isTrue);
      expect(config.slots, hasLength(2));
    });

    test('updateSlotValue updates matching slot', () {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );
      const slot2 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        slot2: slot2,
      );

      final updated = config.updateSlotValue(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        params: null,
        newValue: '12.5V',
      );

      expect(updated.slot1?.value, '12.5V');
      expect(updated.slot2?.value, isNull);
    });

    test('validate returns all validation errors', () {
      const slot1 = StatusSlot(
        sourceMac: 'INVALID_MAC',
        dataType: StatusDataType.voltage,
      );
      const slot2 = StatusSlot(
        sourceMac: 'ANOTHER_INVALID',
        dataType: StatusDataType.channelCurrent,
        params: '20',
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        slot2: slot2,
      );

      final errors = config.validate();
      expect(errors, hasLength(2));
      expect(errors[0], contains('Slot 1'));
      expect(errors[1], contains('Slot 2'));
    });

    test('requiresRemoteConnection returns true when slots need remote devices', () {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );
      const slot2 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        slot2: slot2,
      );

      expect(config.requiresRemoteConnection, isTrue);
    });

    test('remoteMacAddresses returns unique remote MAC addresses', () {
      const slot1 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.voltage,
      );
      const slot2 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF', // Same MAC
        dataType: StatusDataType.channelCurrent,
        params: '0',
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        slot2: slot2,
      );

      final macs = config.remoteMacAddresses;
      expect(macs, hasLength(1));
      expect(macs.first, 'AA:BB:CC:DD:EE:FF');
    });
  });

  group('StatusDataSource', () {
    test('creates StatusDataSource with required fields', () {
      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(dataSource.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(dataSource.deviceName, isNull);
      expect(dataSource.connectionStatus, ConnectionStatus.disconnected);
      expect(dataSource.lastUpdate, isNull);
      expect(dataSource.cachedData, isEmpty);
      expect(dataSource.retryCount, 0);
    });

    test('updateCachedData stores and retrieves data', () {
      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final updated = dataSource.updateCachedData(
        dataType: StatusDataType.voltage,
        params: null,
        value: '12.5V',
      );

      expect(updated.cachedData['VOLTAGE'], '12.5V');
      expect(updated.lastUpdate, isNotNull);
      expect(updated.retryCount, 0);
    });

    test('getCachedData retrieves correct data', () {
      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final updated = dataSource.updateCachedData(
        dataType: StatusDataType.channelCurrent,
        params: '0',
        value: '1.25A',
      );

      expect(updated.getCachedData(dataType: StatusDataType.channelCurrent, params: '0'), '1.25A');
      expect(updated.getCachedData(dataType: StatusDataType.voltage, params: null), isNull);
    });

    test('updateConnectionStatus updates connection state', () {
      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final connected = dataSource.updateConnectionStatus(ConnectionStatus.connected);

      expect(connected.connectionStatus, ConnectionStatus.connected);
      expect(connected.lastUpdate, isNotNull);
    });

    test('isDataStale returns true for old data', () {
      final dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        lastUpdate: DateTime.now().subtract(const Duration(seconds: 15)),
      );

      expect(dataSource.isDataStale, isTrue);
    });

    test('isDataStale returns false for fresh data', () {
      final dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        lastUpdate: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      expect(dataSource.isDataStale, isFalse);
    });

    test('displayName returns device name when available', () {
      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        deviceName: 'My PowerHub',
      );

      expect(dataSource.displayName, 'My PowerHub');
    });

    test('displayName returns MAC address when device name is null', () {
      const dataSource = StatusDataSource(
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(dataSource.displayName, 'AA:BB:CC:DD:EE:FF');
    });
  });

  group('ConnectionStatus', () {
    test('ConnectionStatus enum values are defined', () {
      expect(ConnectionStatus.disconnected, isNotNull);
      expect(ConnectionStatus.connecting, isNotNull);
      expect(ConnectionStatus.connected, isNotNull);
      expect(ConnectionStatus.connectionFailed, isNotNull);
      expect(ConnectionStatus.connectionLost, isNotNull);
    });
  });
}