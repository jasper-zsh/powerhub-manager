import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/discovery_controller.dart';
import 'package:app/repositories/device_repository.dart';
import 'package:app/models/pwm_controller.dart';

import 'discovery_controller_test.mocks.dart';

@GenerateMocks([DeviceRepository])
void main() {
  group('DiscoveryController', () {
    late ProviderContainer container;
    late MockDeviceRepository mockDeviceRepository;

    setUp(() {
      mockDeviceRepository = MockDeviceRepository();
      
      container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(mockDeviceRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should be idle with empty devices', () {
      final state = container.read(discoveryControllerProvider);
      
      expect(state.status, DiscoveryStatus.idle);
      expect(state.devices, isEmpty);
      expect(state.error, null);
    });

    test('startScan should update state to scanning', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      
      controller.startScan();
      
      final state = container.read(discoveryControllerProvider);
      expect(state.status, DiscoveryStatus.scanning);
      verify(mockDeviceRepository.startScan()).called(1);
    });

    test('stopScan should update state to idle', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      
      controller.startScan();
      controller.stopScan();
      
      final state = container.read(discoveryControllerProvider);
      expect(state.status, DiscoveryStatus.idle);
      verify(mockDeviceRepository.stopScan()).called(1);
    });

    test('device discovery should update devices list', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      final devices = [
        PWMController(
          id: 'device-1',
          name: 'Device 1',
          address: '00:11:22:33:44:55',
          rssi: -50,
        ),
        PWMController(
          id: 'device-2',
          name: 'Device 2',
          address: '00:11:22:33:44:66',
          rssi: -60,
        ),
      ];
      
      // Simulate device discovery
      for (final device in devices) {
        controller.onDeviceDiscovered(device);
      }
      
      final state = container.read(discoveryControllerProvider);
      expect(state.devices.length, 2);
      expect(state.devices[0].name, 'Device 1');
      expect(state.devices[1].name, 'Device 2');
    });

    test('duplicate devices should be filtered', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      final device = PWMController(
        id: 'device-1',
        name: 'Device 1',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );
      
      // Add the same device multiple times
      controller.onDeviceDiscovered(device);
      controller.onDeviceDiscovered(device);
      controller.onDeviceDiscovered(device);
      
      final state = container.read(discoveryControllerProvider);
      expect(state.devices.length, 1);
      expect(state.devices[0].name, 'Device 1');
    });

    test('device RSSI update should replace existing device', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      final device1 = PWMController(
        id: 'device-1',
        name: 'Device 1',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );
      final device2 = PWMController(
        id: 'device-1',
        name: 'Device 1',
        address: '00:11:22:33:44:55',
        rssi: -40, // Stronger signal
      );
      
      controller.onDeviceDiscovered(device1);
      controller.onDeviceDiscovered(device2);
      
      final state = container.read(discoveryControllerProvider);
      expect(state.devices.length, 1);
      expect(state.devices[0].rssi, -40); // Should use the stronger signal
    });

    test('scan error should update state with error', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      
      controller.onScanError('Scan failed');
      
      final state = container.read(discoveryControllerProvider);
      expect(state.status, DiscoveryStatus.error);
      expect(state.error, 'Scan failed');
    });

    test('scan completion should update state to idle', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      
      controller.startScan();
      controller.onScanCompleted();
      
      final state = container.read(discoveryControllerProvider);
      expect(state.status, DiscoveryStatus.idle);
    });

    test('clearDevices should empty the devices list', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      final device = PWMController(
        id: 'device-1',
        name: 'Device 1',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );
      
      controller.onDeviceDiscovered(device);
      controller.clearDevices();
      
      final state = container.read(discoveryControllerProvider);
      expect(state.devices, isEmpty);
    });

    test('refresh should start and stop scan', () async {
      final controller = container.read(discoveryControllerProvider.notifier);
      
      // Mock the scan stream
      final scanStream = Stream.fromIterable([
        [PWMController(
          id: 'device-1',
          name: 'Device 1',
          address: '00:11:22:33:44:55',
          rssi: -50,
        )]
      ]);
      
      when(mockDeviceRepository.scanForDevices())
          .thenAnswer((_) => scanStream);
      
      await controller.refresh();
      
      verify(mockDeviceRepository.scanForDevices()).called(1);
      
      final state = container.read(discoveryControllerProvider);
      expect(state.devices.length, 1);
      expect(state.devices[0].name, 'Device 1');
    });

    test('isScanning should return true when scanning', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      
      expect(controller.isScanning, false);
      
      controller.startScan();
      
      expect(controller.isScanning, true);
      
      controller.stopScan();
      
      expect(controller.isScanning, false);
    });

    test('getDeviceById should return correct device', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      final device1 = PWMController(
        id: 'device-1',
        name: 'Device 1',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );
      final device2 = PWMController(
        id: 'device-2',
        name: 'Device 2',
        address: '00:11:22:33:44:66',
        rssi: -60,
      );
      
      controller.onDeviceDiscovered(device1);
      controller.onDeviceDiscovered(device2);
      
      final foundDevice = controller.getDeviceById('device-1');
      expect(foundDevice, isNotNull);
      expect(foundDevice!.name, 'Device 1');
      
      final notFoundDevice = controller.getDeviceById('device-3');
      expect(notFoundDevice, isNull);
    });

    test('sortDevicesByRSSI should order devices by signal strength', () {
      final controller = container.read(discoveryControllerProvider.notifier);
      final devices = [
        PWMController(
          id: 'device-1',
          name: 'Device 1',
          address: '00:11:22:33:44:55',
          rssi: -70, // Weakest signal
        ),
        PWMController(
          id: 'device-2',
          name: 'Device 2',
          address: '00:11:22:33:44:66',
          rssi: -40, // Strongest signal
        ),
        PWMController(
          id: 'device-3',
          name: 'Device 3',
          address: '00:11:22:33:44:77',
          rssi: -55, // Medium signal
        ),
      ];
      
      for (final device in devices) {
        controller.onDeviceDiscovered(device);
      }
      
      controller.sortDevicesByRSSI();
      
      final state = container.read(discoveryControllerProvider);
      expect(state.devices[0].rssi, -40); // Strongest first
      expect(state.devices[1].rssi, -55);
      expect(state.devices[2].rssi, -70); // Weakest last
    });
  });
}