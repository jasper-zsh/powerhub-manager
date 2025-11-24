import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/telemetry_controller.dart';
import 'package:app/repositories/telemetry_repository.dart';
import 'package:app/models/telemetry.dart';

import 'telemetry_controller_test.mocks.dart';

@GenerateMocks([TelemetryRepository])
void main() {
  group('TelemetryController', () {
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

    test('initial state should be loading with null data', () {
      final state = container.read(telemetryControllerProvider);
      
      expect(state.status, TelemetryStatus.loading);
      expect(state.value, null);
      expect(state.error, null);
    });

    test('startTelemetry should update state to active', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final telemetryData = TelemetryData(
        inputVoltageVolts: 12.5,
        temperatureCelsius: 25.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 1,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenAnswer((_) => Stream.value(telemetryData));
      
      await controller.startTelemetry();
      
      final state = container.read(telemetryControllerProvider);
      expect(state.status, TelemetryStatus.active);
      expect(state.value?.inputVoltageVolts, 12.5);
      expect(state.value?.temperatureCelsius, 25.0);
      verify(mockTelemetryRepository.startTelemetryStream()).called(1);
    });

    test('stopTelemetry should update state to stopped', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenAnswer((_) => Stream.empty());
      when(mockTelemetryRepository.stopTelemetryStream())
          .thenAnswer((_) async {});
      
      await controller.startTelemetry();
      await controller.stopTelemetry();
      
      final state = container.read(telemetryControllerProvider);
      expect(state.status, TelemetryStatus.stopped);
      verify(mockTelemetryRepository.stopTelemetryStream()).called(1);
    });

    test('telemetry error should update state with error', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenThrow(Exception('Telemetry failed'));
      
      await controller.startTelemetry();
      
      final state = container.read(telemetryControllerProvider);
      expect(state.status, TelemetryStatus.error);
      expect(state.error, 'Exception: Telemetry failed');
    });

    test('updateConfig should update telemetry configuration', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final newConfig = TelemetryConfig(
        telemetryIntervalMs: 2000,
        monitoringIntervalMs: 1000,
        telemetryEnabled: true,
        monitoringEnabled: true,
        autoSaveEnabled: true,
        maxRecords: 200,
      );
      
      when(mockTelemetryRepository.updateConfig(newConfig))
          .thenAnswer((_) async {});
      
      await controller.updateConfig(newConfig);
      
      verify(mockTelemetryRepository.updateConfig(newConfig)).called(1);
    });

    test('saveConfig should persist configuration', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final config = TelemetryConfig(
        telemetryIntervalMs: 1000,
        monitoringIntervalMs: 500,
        telemetryEnabled: true,
        monitoringEnabled: true,
        autoSaveEnabled: false,
        maxRecords: 100,
      );
      
      when(mockTelemetryRepository.saveConfig())
          .thenAnswer((_) async {});
      
      // First set some config
      when(mockTelemetryRepository.updateConfig(any))
          .thenAnswer((_) async {});
      await controller.updateConfig(config);
      
      // Then save it
      await controller.saveConfig();
      
      verify(mockTelemetryRepository.saveConfig()).called(1);
    });

    test('clearAllData should clear telemetry data', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      
      when(mockTelemetryRepository.clearAllData())
          .thenAnswer((_) async {});
      
      await controller.clearAllData();
      
      verify(mockTelemetryRepository.clearAllData()).called(1);
    });

    test('refreshData should fetch latest telemetry data', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final telemetryData = TelemetryData(
        inputVoltageVolts: 13.0,
        temperatureCelsius: 30.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 2,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      
      when(mockTelemetryRepository.getLatestTelemetryData())
          .thenAnswer((_) async => telemetryData);
      
      await controller.refreshData();
      
      final state = container.read(telemetryControllerProvider);
      expect(state.status, TelemetryStatus.active);
      expect(state.value?.inputVoltageVolts, 13.0);
      expect(state.value?.temperatureCelsius, 30.0);
      verify(mockTelemetryRepository.getLatestTelemetryData()).called(1);
    });

    test('enableTelemetry should start telemetry if not already active', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final telemetryData = TelemetryData(
        inputVoltageVolts: 12.5,
        temperatureCelsius: 25.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 1,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenAnswer((_) => Stream.value(telemetryData));
      
      await controller.enableTelemetry();
      
      final state = container.read(telemetryControllerProvider);
      expect(state.status, TelemetryStatus.active);
      verify(mockTelemetryRepository.startTelemetryStream()).called(1);
    });

    test('disableTelemetry should stop telemetry if active', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final telemetryData = TelemetryData(
        inputVoltageVolts: 12.5,
        temperatureCelsius: 25.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 1,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenAnswer((_) => Stream.value(telemetryData));
      when(mockTelemetryRepository.stopTelemetryStream())
          .thenAnswer((_) async {});
      
      await controller.startTelemetry();
      await controller.disableTelemetry();
      
      final state = container.read(telemetryControllerProvider);
      expect(state.status, TelemetryStatus.stopped);
      verify(mockTelemetryRepository.stopTelemetryStream()).called(1);
    });

    test('isActive should return true when telemetry is active', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final telemetryData = TelemetryData(
        inputVoltageVolts: 12.5,
        temperatureCelsius: 25.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 1,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenAnswer((_) => Stream.value(telemetryData));
      
      expect(controller.isActive, false);
      
      await controller.startTelemetry();
      
      expect(controller.isActive, true);
    });

    test('stream updates should update state', () async {
      final controller = container.read(telemetryControllerProvider.notifier);
      final telemetryData1 = TelemetryData(
        inputVoltageVolts: 12.5,
        temperatureCelsius: 25.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 1,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      final telemetryData2 = TelemetryData(
        inputVoltageVolts: 13.0,
        temperatureCelsius: 30.0,
        lastUpdateTime: DateTime.now(),
        updateCount: 2,
        config: TelemetryConfig(
          telemetryIntervalMs: 1000,
          monitoringIntervalMs: 500,
          telemetryEnabled: true,
          monitoringEnabled: true,
          autoSaveEnabled: false,
          maxRecords: 100,
        ),
      );
      
      when(mockTelemetryRepository.startTelemetryStream())
          .thenAnswer((_) => Stream.fromIterable([telemetryData1, telemetryData2]));
      
      await controller.startTelemetry();
      
      // Wait for stream to process
      await Future.delayed(const Duration(milliseconds: 100));
      
      final state = container.read(telemetryControllerProvider);
      expect(state.value?.inputVoltageVolts, 13.0);
      expect(state.value?.temperatureCelsius, 30.0);
      expect(state.value?.updateCount, 2);
    });
  });
}