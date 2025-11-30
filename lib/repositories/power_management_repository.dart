import 'package:app/models/power_management.dart';
import 'package:app/services/ble_service.dart';

/// Repository for PowerHub power management configuration and commands
///
/// Provides a high-level interface for power management operations,
/// abstracting away the low-level BLE service complexity.
class PowerManagementRepository {
  PowerManagementRepository({BLEService? bleService})
      : _bleService = bleService ?? BLEService();

  final BLEService _bleService;

  /// Read the current power management configuration from the device
  ///
  /// Returns a PowerManagementConfig containing temperature and voltage thresholds.
  /// Throws an exception if the device is not connected or communication fails.
  Future<PowerManagementConfig> readConfig() async {
    try {
      return await _bleService.readPowerManagementConfig();
    } catch (e) {
      throw PowerManagementException(
        'Failed to read power management configuration: $e',
        PowerManagementErrorType.readFailure,
      );
    }
  }

  /// Send a power management command to the device
  ///
  /// [command] The power command to send (e.g., set temperature threshold, force sleep)
  ///
  /// Throws an exception if the device is not connected or command fails.
  Future<void> sendCommand(PowerCommand command) async {
    try {
      await _bleService.sendPowerCommand(command);
    } catch (e) {
      throw PowerManagementException(
        'Failed to send power command: $e',
        PowerManagementErrorType.commandFailure,
      );
    }
  }

  /// Set the high temperature threshold
  ///
  /// [temperatureCelsius] Temperature in Celsius (typically 0-150°C)
  Future<void> setHighTemperatureThreshold(double temperatureCelsius) async {
    final threshold = (temperatureCelsius * 100).round();
    final command = PowerCommand(
      type: PowerCommandType.setHighTempThreshold,
      parameter: threshold,
    );
    await sendCommand(command);
  }

  /// Set the recovery temperature threshold
  ///
  /// [temperatureCelsius] Temperature in Celsius (typically 0-150°C)
  Future<void> setRecoveryThreshold(double temperatureCelsius) async {
    final threshold = (temperatureCelsius * 100).round();
    final command = PowerCommand(
      type: PowerCommandType.setRecoveryThreshold,
      parameter: threshold,
    );
    await sendCommand(command);
  }

  /// Set the sleep voltage threshold
  ///
  /// [voltage] Voltage in Volts (typically 8-15V)
  Future<void> setSleepVoltageThreshold(double voltage) async {
    final threshold = (voltage * 1000).round();
    final command = PowerCommand(
      type: PowerCommandType.setSleepThreshold,
      parameter: threshold,
    );
    await sendCommand(command);
  }

  /// Set the wake voltage threshold
  ///
  /// [voltage] Voltage in Volts (typically 8-15V)
  Future<void> setWakeVoltageThreshold(double voltage) async {
    final threshold = (voltage * 1000).round();
    final command = PowerCommand(
      type: PowerCommandType.setWakeThreshold,
      parameter: threshold,
    );
    await sendCommand(command);
  }

  /// Force the device into sleep mode
  Future<void> forceSleep() async {
    final command = PowerCommand(type: PowerCommandType.forceSleep);
    await sendCommand(command);
  }

  /// Force the device to wake from sleep mode
  Future<void> forceWake() async {
    final command = PowerCommand(type: PowerCommandType.forceWake);
    await sendCommand(command);
  }
}

/// Exception type for power management operations
enum PowerManagementErrorType {
  readFailure,
  commandFailure,
  connectionFailure,
  validationFailure,
}

/// Custom exception for power management operations
class PowerManagementException implements Exception {
  final String message;
  final PowerManagementErrorType type;
  final dynamic originalError;

  PowerManagementException(this.message, this.type, [this.originalError]);

  @override
  String toString() => 'PowerManagementException: $message';
}