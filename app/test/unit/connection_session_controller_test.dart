import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/repositories/device_repository.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/ble_connection.dart';

import 'connection_session_controller_test.mocks.dart';

@GenerateMocks([DeviceRepository])
void main() {
  group('ConnectionSessionController', () {
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

    test('initial state should be disconnected', () {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final state = container.read(connectionSessionControllerProvider);
      
      expect(state.status, ConnectionStatus.disconnected);
      expect(state.device, null);
      expect(state.isConnected, false);
    });

    test('connect should update state to connecting', () async {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final testDevice = PWMController(
        id: 'test-id',
        name: 'Test Device',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );

      when(mockDeviceRepository.connectToDevice(testDevice))
          .thenAnswer((_) async => true);

      controller.connectToDevice(testDevice);
      
      final state = container.read(connectionSessionControllerProvider);
      expect(state.status, ConnectionStatus.connecting);
      expect(state.device, testDevice);
    });

    test('successful connection should update state to connected', () async {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final testDevice = PWMController(
        id: 'test-id',
        name: 'Test Device',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );

      when(mockDeviceRepository.connectToDevice(testDevice))
          .thenAnswer((_) async => true);

      await controller.connectToDevice(testDevice);
      
      final state = container.read(connectionSessionControllerProvider);
      expect(state.status, ConnectionStatus.connected);
      expect(state.device, testDevice);
      expect(state.isConnected, true);
    });

    test('failed connection should update state to failed', () async {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final testDevice = PWMController(
        id: 'test-id',
        name: 'Test Device',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );

      when(mockDeviceRepository.connectToDevice(testDevice))
          .thenThrow(Exception('Connection failed'));

      await controller.connectToDevice(testDevice);
      
      final state = container.read(connectionSessionControllerProvider);
      expect(state.status, ConnectionStatus.failed);
      expect(state.lastError, 'Exception: Connection failed');
    });

    test('disconnect should update state to disconnected', () async {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final testDevice = PWMController(
        id: 'test-id',
        name: 'Test Device',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );

      when(mockDeviceRepository.connectToDevice(testDevice))
          .thenAnswer((_) async => true);
      when(mockDeviceRepository.disconnectFromDevice())
          .thenAnswer((_) async {});

      await controller.connectToDevice(testDevice);
      await controller.disconnect();
      
      final state = container.read(connectionSessionControllerProvider);
      expect(state.status, ConnectionStatus.disconnected);
      expect(state.device, null);
      expect(state.isConnected, false);
    });

    test('auto reconnect should attempt reconnection on disconnect', () async {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final testDevice = PWMController(
        id: 'test-id',
        name: 'Test Device',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );

      when(mockDeviceRepository.connectToDevice(testDevice))
          .thenAnswer((_) async => true);
      when(mockDeviceRepository.disconnectFromDevice())
          .thenAnswer((_) async {});

      await controller.connectToDevice(testDevice);
      controller.setAutoReconnect(true);
      
      // Simulate disconnection
      controller.handleDisconnection();
      
      final state = container.read(connectionSessionControllerProvider);
      expect(state.status, ConnectionStatus.reconnecting);
      expect(state.isReconnecting, true);
    });

    test('max reconnect attempts should stop reconnecting', () async {
      final controller = container.read(connectionSessionControllerProvider.notifier);
      final testDevice = PWMController(
        id: 'test-id',
        name: 'Test Device',
        address: '00:11:22:33:44:55',
        rssi: -50,
      );

      when(mockDeviceRepository.connectToDevice(testDevice))
          .thenAnswer((_) async => false); // Always fail
      when(mockDeviceRepository.disconnectFromDevice())
          .thenAnswer((_) async {});

      await controller.connectToDevice(testDevice);
      controller.setAutoReconnect(true);
      controller.setMaxReconnectAttempts(2);
      
      // Simulate disconnection
      controller.handleDisconnection();
      
      // Wait for reconnection attempts
      await Future.delayed(const Duration(seconds: 1));
      
      final state = container.read(connectionSessionControllerProvider);
      expect(state.status, ConnectionStatus.failed);
      expect(state.isReconnecting, false);
    });
  });
}