import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/power_management_controller.dart';
import 'package:app/repositories/power_management_repository.dart';
import 'package:app/models/power_management.dart';

import 'power_management_controller_test.mocks.dart';

@GenerateMocks([PowerManagementRepository])
void main() {
  group('PowerManagementController', () {
    late PowerManagementController controller;
    late MockPowerManagementRepository mockRepository;

    setUp(() {
      mockRepository = MockPowerManagementRepository();
      controller = PowerManagementController(repository: mockRepository);
    });

    test('should start with initial empty state', () {
      expect(controller.state.config, isNull);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
      expect(controller.state.lastOperation, isNull);
    });

    group('refreshConfig', () {
      test('should update state with config when repository succeeds', () async {
        // Arrange
        final config = PowerManagementConfig(
          highTempThreshold: 6000,
          recoveryThreshold: 5500,
          sleepVoltageThreshold: 12500,
          wakeVoltageThreshold: 12600,
        );

        when(mockRepository.readConfig()).thenAnswer((_) async => config);

        // Act
        await controller.refreshConfig();

        // Assert
        expect(controller.state.config, equals(config));
        expect(controller.state.isLoading, isFalse);
        expect(controller.state.error, isNull);
        expect(controller.state.lastOperation, equals(PowerManagementOperation.readConfig));
        verify(mockRepository.readConfig()).called(1);
      });

      test('should update state with error when repository fails', () async {
        // Arrange
        const errorMessage = 'Device not connected';
        when(mockRepository.readConfig())
            .thenThrow(PowerManagementException(
              errorMessage,
              PowerManagementErrorType.readFailure,
            ));

        // Act
        await controller.refreshConfig();

        // Assert
        expect(controller.state.config, isNull);
        expect(controller.state.isLoading, isFalse);
        expect(controller.state.error, anyOf(contains(errorMessage), contains('Failed to read power management configuration')));
        expect(controller.state.lastOperation, equals(PowerManagementOperation.readConfig));
        verify(mockRepository.readConfig()).called(1);
      });
    });

    group('setHighTemperatureThreshold', () {
      test('should update config when repository succeeds with valid input', () async {
        // Arrange
        const temperature = 60.0;
        final config = PowerManagementConfig(
          highTempThreshold: (temperature * 100).round(),
          recoveryThreshold: 5500,
          sleepVoltageThreshold: 12500,
          wakeVoltageThreshold: 12600,
        );

        when(mockRepository.setHighTemperatureThreshold(temperature))
            .thenAnswer((_) async {});
        when(mockRepository.readConfig()).thenAnswer((_) async => config);

        // Act
        await controller.setHighTemperatureThreshold(temperature);

        // Assert
        verify(mockRepository.setHighTemperatureThreshold(temperature)).called(1);
        verify(mockRepository.readConfig()).called(1);
        expect(controller.state.config, equals(config));
        expect(controller.state.isLoading, isFalse);
      });

      test('should set error state for invalid temperature input', () async {
        // Arrange
        const invalidTemperature = -10.0;

        // Act
        await controller.setHighTemperatureThreshold(invalidTemperature);

        // Assert
        expect(controller.state.error, contains('High temperature must be between'));
        verifyNever(mockRepository.setHighTemperatureThreshold(any));
      });

      test('should update state with error when repository fails', () async {
        // Arrange
        const temperature = 60.0;
        const errorMessage = 'Command failed';

        when(mockRepository.setHighTemperatureThreshold(temperature))
            .thenThrow(PowerManagementException(
              errorMessage,
              PowerManagementErrorType.commandFailure,
            ));

        // Act
        await controller.setHighTemperatureThreshold(temperature);

        // Assert
        expect(controller.state.error, anyOf(contains(errorMessage), contains('Failed to read power management configuration')));
        verify(mockRepository.setHighTemperatureThreshold(temperature)).called(1);
      });
    });

    group('setWakeVoltageThreshold', () {
      test('should update config when repository succeeds with valid input', () async {
        // Arrange
        const voltage = 12.6;
        final config = PowerManagementConfig(
          highTempThreshold: 6000,
          recoveryThreshold: 5500,
          sleepVoltageThreshold: 12500,
          wakeVoltageThreshold: (voltage * 1000).round(),
        );

        when(mockRepository.setWakeVoltageThreshold(voltage))
            .thenAnswer((_) async {});
        when(mockRepository.readConfig()).thenAnswer((_) async => config);

        // Act
        await controller.setWakeVoltageThreshold(voltage);

        // Assert
        verify(mockRepository.setWakeVoltageThreshold(voltage)).called(1);
        verify(mockRepository.readConfig()).called(1);
        expect(controller.state.config, equals(config));
      });

      test('should set error state for invalid voltage input', () async {
        // Arrange
        const invalidVoltage = 20.0;

        // Act
        await controller.setWakeVoltageThreshold(invalidVoltage);

        // Assert
        expect(controller.state.error, contains('Wake voltage must be between'));
        verifyNever(mockRepository.setWakeVoltageThreshold(any));
      });
    });

    group('forceSleep', () {
      test('should send sleep command and update operation state', () async {
        // Arrange
        when(mockRepository.forceSleep()).thenAnswer((_) async {});

        // Act
        await controller.forceSleep();

        // Assert
        verify(mockRepository.forceSleep()).called(1);
        expect(controller.state.lastOperation, equals(PowerManagementOperation.forceSleep));
        expect(controller.state.isLoading, isFalse);
      });

      test('should update state with error when force sleep fails', () async {
        // Arrange
        const errorMessage = 'Sleep command failed';
        when(mockRepository.forceSleep()).thenThrow(PowerManagementException(
          errorMessage,
          PowerManagementErrorType.commandFailure,
        ));

        // Act
        await controller.forceSleep();

        // Assert
        expect(controller.state.error, anyOf(contains(errorMessage), contains('Failed to read power management configuration')));
        expect(controller.state.lastOperation, equals(PowerManagementOperation.forceSleep));
      });
    });

    group('clearError', () {
      test('should clear error state', () {
        // Arrange - set an error first
        controller.state = controller.state.copyWith(error: 'Test error');

        // Act
        controller.clearError();

        // Assert
        expect(controller.state.error, isNull);
      });
    });

    group('clearLastOperation', () {
      test('should clear last operation state', () {
        // Arrange - set an operation first
        controller.state = controller.state.copyWith(
          lastOperation: PowerManagementOperation.forceSleep,
        );

        // Act
        controller.clearLastOperation();

        // Assert
        expect(controller.state.lastOperation, isNull);
      });
    });
  });
}