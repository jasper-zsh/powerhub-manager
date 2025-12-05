import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_slot_configuration.dart';
import 'package:app/models/switch_hub/status_data_type.dart';
import 'package:app/models/switch_hub/status_data_source.dart';
import 'package:app/providers/status_orchestration_provider.dart';
void main() {
  group('StatusOrchestrationProvider Tests', () {
    late ProviderContainer container;
    late StatusOrchestrationController controller;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(statusOrchestrationProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is correct', () {
      final state = container.read(statusOrchestrationProvider);

      expect(state.statusConfigurations, isEmpty);
      expect(state.remoteDataSources, isEmpty);
      expect(state.isConnected, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.error, isNull);
    });

    test('initializes with basic scenario', () async {
      // Create a basic config with no status slots
      const config = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Test the provider behavior when no status slots are present
      await controller.initialize(config);

      final state = container.read(statusOrchestrationProvider);
      expect(state.isRefreshing, isFalse);
    });

    test('updates status value correctly', () {
      // Start with empty state
      expect(container.read(statusOrchestrationProvider).statusConfigurations, isEmpty);

      // Update status value for a switch
      controller.updateStatusValue(
        switchId: 1,
        dataType: StatusDataType.voltage,
        params: null,
        newValue: '12.5V',
      );

      // The state should remain unchanged since no configuration exists for switch 1
      final state = container.read(statusOrchestrationProvider);
      expect(state.statusConfigurations[1], isNull);
    });

    test('updates device connection status correctly', () {
      // Update connection status for a device
      controller.updateDeviceConnectionStatus(
        macAddress: 'AA:BB:CC:DD:EE:FF',
        status: ConnectionStatus.connected,
        deviceName: 'Test Device',
      );

      // The state should remain unchanged since no data source exists for this MAC
      final state = container.read(statusOrchestrationProvider);
      expect(state.remoteDataSources['AA:BB:CC:DD:EE:FF'], isNull);
    });

    test('gets required remote MACs correctly', () {
      // Initially no configurations, so no required MACs
      expect(controller.requiredRemoteMacs, isEmpty);
    });

    test('resets state correctly', () {
      // Reset the controller directly
      controller.reset();

      // Verify state is back to initial
      final state = container.read(statusOrchestrationProvider);
      expect(state.statusConfigurations, isEmpty);
      expect(state.remoteDataSources, isEmpty);
      expect(state.isConnected, isFalse);
      expect(state.isRefreshing, isFalse);
      expect(state.error, isNull);
    });
  });

  group('Status Configuration Tests', () {
    test('creates status configuration correctly', () {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        label: '电压',
      );

      const slot2 = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.channelCurrent,
        params: '0',
        label: '电流',
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        slot2: slot2,
        isConfigured: true,
      );

      expect(config.slot1, equals(slot1));
      expect(config.slot2, equals(slot2));
      expect(config.isConfigured, isTrue);
      expect(config.slots, hasLength(2));
      expect(config.requiresRemoteConnection, isTrue);
      expect(config.remoteMacAddresses, contains('AA:BB:CC:DD:EE:FF'));
    });

    test('updates slot value correctly', () {
      const slot1 = StatusSlot(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
      );

      const config = StatusSlotConfiguration(
        slot1: slot1,
        isConfigured: true,
      );

      final updatedConfig = config.updateSlotValue(
        sourceMac: 'LOCAL',
        dataType: StatusDataType.voltage,
        params: null,
        newValue: '12.5V',
      );

      expect(updatedConfig.slot1?.value, equals('12.5V'));
    });

    test('validates configuration correctly', () {
      const validSlot = StatusSlot(
        sourceMac: 'AA:BB:CC:DD:EE:FF',
        dataType: StatusDataType.voltage,
      );

      const invalidSlot = StatusSlot(
        sourceMac: 'INVALID_MAC',
        dataType: StatusDataType.voltage,
      );

      const config = StatusSlotConfiguration(
        slot1: validSlot,
        slot2: invalidSlot,
        isConfigured: true,
      );

      final errors = config.validate();
      expect(errors, hasLength(1));
      expect(errors.first, contains('Slot 2'));
      expect(errors.first, contains('Invalid source MAC address'));
    });
  });
}