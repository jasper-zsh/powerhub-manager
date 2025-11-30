import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/repositories/telemetry_repository.dart';
import 'package:app/models/monitoring_data.dart';

import 'monitoring_controller_test.mocks.dart';

@GenerateMocks([TelemetryRepository])
void main() {
  group('MonitoringController', () {
    late ProviderContainer container;
    late MockTelemetryRepository mockTelemetryRepository;

    setUp(() {
      mockTelemetryRepository = MockTelemetryRepository();
      
      container = ProviderContainer(
        overrides: [
          telemetryRepositoryProvider.overrideWithValue(mockTelemetryRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should be disconnected with null data', () {
      final state = container.read(monitoringControllerProvider);
      
      expect(state.status, MonitoringStatus.disconnected);
      expect(state.value, null);
      expect(state.error, null);
      expect(state.updateCount, 0);
    });

    test('startMonitoring should update state to subscribing then live', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );

      when(mockTelemetryRepository.startMonitoringStream())
          .thenAnswer((_) => Stream.value(monitoringData));

      await controller.startMonitoring();

      // Should transition to subscribing first, then live
      await Future.delayed(const Duration(milliseconds: 100));

      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.live);
      expect(state.value?.inputVoltageVolts, 12.5);
      expect(state.value?.calculatedTotalCurrent, 1.5); // 0.5 + 0.3 + 0.7
      expect(state.updateCount, 1);
      verify(mockTelemetryRepository.startMonitoringStream()).called(1);
    });

    test('stopMonitoring should update state to disconnected', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );

      when(mockTelemetryRepository.startMonitoringStream())
          .thenAnswer((_) => Stream.value(monitoringData));
      when(mockTelemetryRepository.stopMonitoringStream())
          .thenAnswer((_) async {});

      await controller.startMonitoring();
      await Future.delayed(const Duration(milliseconds: 100));
      await controller.stopMonitoring();

      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.disconnected);
      verify(mockTelemetryRepository.stopMonitoringStream()).called(1);
    });

    test('monitoring error should update state with error', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      
      when(mockTelemetryRepository.startMonitoringStream())
          .thenThrow(Exception('Monitoring failed'));
      
      await controller.startMonitoring();
      
      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.error);
      expect(state.error, 'Exception: Monitoring failed');
    });

    test('refreshData should fetch latest monitoring data', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 13000, // 13.0V in mV
        powerZoneTemp: 3500, // 35.0°C in 0.01°C units
        controlZoneTemp: 4000, // 40.0°C in 0.01°C units
        channelCurrents: [0.7, 0.5, 0.8],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: true,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );

      when(mockTelemetryRepository.getLatestMonitoringData())
          .thenAnswer((_) async => monitoringData);

      await controller.refreshData();

      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.live);
      expect(state.value?.inputVoltageVolts, 13.0);
      expect(state.value?.calculatedTotalCurrent, 2.0); // 0.7 + 0.5 + 0.8
      expect(state.value?.statusFlags.thermalProtectionActive, true);
      verify(mockTelemetryRepository.getLatestMonitoringData()).called(1);
    });

    test('enableMonitoring should start monitoring if not already active', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );
      
      when(mockTelemetryRepository.startMonitoringStream())
          .thenAnswer((_) => Stream.value(monitoringData));
      
      await controller.enableMonitoring();
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.live);
      verify(mockTelemetryRepository.startMonitoringStream()).called(1);
    });

    test('disableMonitoring should stop monitoring if active', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );
      
      when(mockTelemetryRepository.startMonitoringStream())
          .thenAnswer((_) => Stream.value(monitoringData));
      when(mockTelemetryRepository.stopMonitoringStream())
          .thenAnswer((_) async {});
      
      await controller.startMonitoring();
      await Future.delayed(const Duration(milliseconds: 100));
      await controller.disableMonitoring();
      
      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.disconnected);
      verify(mockTelemetryRepository.stopMonitoringStream()).called(1);
    });

    test('isActive should return true when monitoring is active', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );
      
      when(mockTelemetryRepository.startMonitoringStream())
          .thenAnswer((_) => Stream.value(monitoringData));
      
      expect(controller.isActive, false);
      
      await controller.startMonitoring();
      await Future.delayed(const Duration(milliseconds: 100));
      
      expect(controller.isActive, true);
    });

    test('stream updates should update state and increment update count', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData1 = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
                channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
              );
      final monitoringData2 = MonitoringData(
        inputVoltage: 13000, // 13.0V in mV
        powerZoneTemp: 3500, // 35.0°C in 0.01°C units
        controlZoneTemp: 4000, // 40.0°C in 0.01°C units
                channelCurrents: [0.7, 0.5, 0.8],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: true,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
              );
      
      when(mockTelemetryRepository.startMonitoringStream())
          .thenAnswer((_) => Stream.fromIterable([monitoringData1, monitoringData2]));
      
      await controller.startMonitoring();
      
      // Wait for stream to process
      await Future.delayed(const Duration(milliseconds: 100));
      
      final state = container.read(monitoringControllerProvider);
      expect(state.status, MonitoringStatus.live);
      expect(state.value?.inputVoltageVolts, 13.0);
      expect(state.value?.calculatedTotalCurrent, 2.0);
      expect(state.updateCount, 2);
    });

    test('getChannelCurrent should return correct channel current', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );
      
      when(mockTelemetryRepository.getLatestMonitoringData())
          .thenAnswer((_) async => monitoringData);
      
      await controller.refreshData();
      
      expect(controller.getChannelCurrent(0), 0.5);
      expect(controller.getChannelCurrent(1), 0.3);
      expect(controller.getChannelCurrent(2), 0.7);
      expect(controller.getChannelCurrent(3), 0.0); // Out of range
    });

    test('isThermalProtectionActive should return correct status', () async {
      final controller = container.read(monitoringControllerProvider.notifier);
      final monitoringData = MonitoringData(
        inputVoltage: 12500, // 12.5V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
                channelCurrents: [0.5, 0.3, 0.7],
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: true,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
              );
      
      when(mockTelemetryRepository.getLatestMonitoringData())
          .thenAnswer((_) async => monitoringData);
      
      await controller.refreshData();
      
      expect(controller.isThermalProtectionActive, true);
    });
  });
}