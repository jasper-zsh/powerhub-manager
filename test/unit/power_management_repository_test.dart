import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/repositories/power_management_repository.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/models/power_management.dart';

import 'power_management_repository_test.mocks.dart';

@GenerateMocks([BLEService])
void main() {
  group('PowerManagementRepository', () {
    late PowerManagementRepository repository;
    late MockBLEService mockBLEService;

    setUp(() {
      mockBLEService = MockBLEService();
      repository = PowerManagementRepository(bleService: mockBLEService);
    });

    group('readConfig', () {
      test('should return PowerManagementConfig when BLE service succeeds', () async {
        // Arrange
        final expectedConfig = PowerManagementConfig(
          highTempThreshold: 6000, // 60.00°C
          recoveryThreshold: 5500, // 55.00°C
          sleepVoltageThreshold: 12500, // 12.5V
          wakeVoltageThreshold: 12600, // 12.6V
        );

        when(mockBLEService.readPowerManagementConfig())
            .thenAnswer((_) async => expectedConfig);

        // Act
        final result = await repository.readConfig();

        // Assert
        expect(result, equals(expectedConfig));
        verify(mockBLEService.readPowerManagementConfig()).called(1);
      });

      test('should throw PowerManagementException when BLE service fails', () async {
        // Arrange
        const errorMessage = 'Device not connected';
        when(mockBLEService.readPowerManagementConfig())
            .thenThrow(Exception(errorMessage));

        // Act & Assert
        expect(
          () => repository.readConfig(),
          throwsA(isA<PowerManagementException>()
              .having((e) => e.type, 'type', PowerManagementErrorType.readFailure)
              .having((e) => e.message, 'message', contains(errorMessage))),
        );
        verify(mockBLEService.readPowerManagementConfig()).called(1);
      });
    });

    group('sendCommand', () {
      test('should send command successfully when BLE service succeeds', () async {
        // Arrange
        final command = PowerCommand(
          type: PowerCommandType.setHighTempThreshold,
          parameter: 6000,
        );

        when(mockBLEService.sendPowerCommand(command))
            .thenAnswer((_) async {});

        // Act & Assert - Should not throw
        await repository.sendCommand(command);
        verify(mockBLEService.sendPowerCommand(command)).called(1);
      });

      test('should throw PowerManagementException when BLE service fails', () async {
        // Arrange
        final command = PowerCommand(
          type: PowerCommandType.forceSleep,
        );
        const errorMessage = 'Write failed';

        when(mockBLEService.sendPowerCommand(command))
            .thenThrow(Exception(errorMessage));

        // Act & Assert
        expect(
          () => repository.sendCommand(command),
          throwsA(isA<PowerManagementException>()
              .having((e) => e.type, 'type', PowerManagementErrorType.commandFailure)
              .having((e) => e.message, 'message', contains(errorMessage))),
        );
        verify(mockBLEService.sendPowerCommand(command)).called(1);
      });
    });

    group('convenience methods', () {
      test('setHighTemperatureThreshold should send correct command', () async {
        // Arrange
        const temperature = 60.0;
        final expectedCommand = PowerCommand(
          type: PowerCommandType.setHighTempThreshold,
          parameter: 6000, // 60.0°C * 100
        );

        when(mockBLEService.sendPowerCommand(any))
            .thenAnswer((_) async {});

        // Act
        await repository.setHighTemperatureThreshold(temperature);

        // Assert
        verify(mockBLEService.sendPowerCommand(expectedCommand)).called(1);
      });

      test('setRecoveryThreshold should send correct command', () async {
        // Arrange
        const temperature = 55.0;
        final expectedCommand = PowerCommand(
          type: PowerCommandType.setRecoveryThreshold,
          parameter: 5500, // 55.0°C * 100
        );

        when(mockBLEService.sendPowerCommand(any))
            .thenAnswer((_) async {});

        // Act
        await repository.setRecoveryThreshold(temperature);

        // Assert
        verify(mockBLEService.sendPowerCommand(expectedCommand)).called(1);
      });

      test('setSleepVoltageThreshold should send correct command', () async {
        // Arrange
        const voltage = 12.5;
        final expectedCommand = PowerCommand(
          type: PowerCommandType.setSleepThreshold,
          parameter: 12500, // 12.5V * 1000
        );

        when(mockBLEService.sendPowerCommand(any))
            .thenAnswer((_) async {});

        // Act
        await repository.setSleepVoltageThreshold(voltage);

        // Assert
        verify(mockBLEService.sendPowerCommand(expectedCommand)).called(1);
      });

      test('setWakeVoltageThreshold should send correct command', () async {
        // Arrange
        const voltage = 12.6;
        final expectedCommand = PowerCommand(
          type: PowerCommandType.setWakeThreshold,
          parameter: 12600, // 12.6V * 1000
        );

        when(mockBLEService.sendPowerCommand(any))
            .thenAnswer((_) async {});

        // Act
        await repository.setWakeVoltageThreshold(voltage);

        // Assert
        verify(mockBLEService.sendPowerCommand(expectedCommand)).called(1);
      });

      test('forceSleep should send correct command', () async {
        // Arrange
        final expectedCommand = PowerCommand(
          type: PowerCommandType.forceSleep,
        );

        when(mockBLEService.sendPowerCommand(any))
            .thenAnswer((_) async {});

        // Act
        await repository.forceSleep();

        // Assert
        verify(mockBLEService.sendPowerCommand(expectedCommand)).called(1);
      });

      test('forceWake should send correct command', () async {
        // Arrange
        final expectedCommand = PowerCommand(
          type: PowerCommandType.forceWake,
        );

        when(mockBLEService.sendPowerCommand(any))
            .thenAnswer((_) async {});

        // Act
        await repository.forceWake();

        // Assert
        verify(mockBLEService.sendPowerCommand(expectedCommand)).called(1);
      });
    });
  });
}