import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/power_management.dart';
import 'package:app/models/telemetry.dart';

void main() {
  group('New Protocol Telemetry', () {
    test('should parse new 8-byte power management format', () {
      // New power management format: high temp, recovery, sleep voltage, wake voltage
      final bytes = [
        0x17, 0x70, // High temp threshold: 6000 * 0.01°C = 60.0°C
        0x15, 0x7C, // Recovery threshold: 5500 * 0.01°C = 55.0°C
        0x30, 0xD4, // Sleep voltage: 12500 mV = 12.5V
        0x31, 0x38, // Wake voltage: 12600 mV = 12.6V
      ];

      final powerConfig = PowerManagementConfig.fromBytes(bytes);
      expect(powerConfig.highTempCelsius, 60.0);
      expect(powerConfig.recoveryCelsius, 55.0);
      expect(powerConfig.sleepVoltage, 12.5);
      expect(powerConfig.wakeVoltage, 12.6);
    });

    test('should convert power management config to telemetry format', () {
      // Simulate the conversion in the BLE service
      final powerConfig = PowerManagementConfig(
        highTempThreshold: 6000, // 60.00°C
        recoveryThreshold: 5500, // 55.00°C
        sleepVoltageThreshold: 12500, // 12.5V
        wakeVoltageThreshold: 12600, // 12.6V
      );

      // Convert to telemetry format (as done in BLE service)
      final telemetry = TelemetryData(
        vinMillivolts: 0, // Not available in new format
        temperatureCentiDegrees: powerConfig.highTempThreshold,
        highThresholdCentiDegrees: powerConfig.highTempThreshold,
        recoverThresholdCentiDegrees: powerConfig.recoveryThreshold,
        sleepThresholdMilliVolts: powerConfig.sleepVoltageThreshold,
        wakeThresholdMilliVolts: powerConfig.wakeVoltageThreshold,
        statusFlags: 0x02, // Temperature data valid
      );

      expect(telemetry.temperatureCelsius, 60.0);
      expect(telemetry.highThresholdCelsius, 60.0);
      expect(telemetry.recoverThresholdCelsius, 55.0);
      expect(telemetry.sleepThresholdVolts, 12.5);
      expect(telemetry.wakeThresholdVolts, 12.6);
      expect(telemetry.isThermalProtectionActive, false);
      expect(telemetry.isTemperatureValid, true);
    });

    test('should reject invalid data lengths', () {
      // Test various invalid lengths
      expect(
        () => PowerManagementConfig.fromBytes([0x01, 0x02, 0x03]),
        throwsArgumentError,
        reason: 'Should throw ArgumentError for 3 bytes',
      );

      expect(
        () => PowerManagementConfig.fromBytes([]),
        throwsArgumentError,
        reason: 'Should throw ArgumentError for empty list',
      );
    });

    test('should handle byte order correctly', () {
      // Test big-endian byte order - need 8 bytes total
      final bytes = [
        0x12, 0x34, // High temp: 0x1234 = 4660
        0x56, 0x78, // Recovery: 0x5678 = 22136
        0x90, 0xAB, // Sleep voltage: 0x90AB = 37035
        0xCD, 0xEF, // Wake voltage: 0xCDEF = 52719
      ];

      final config = PowerManagementConfig.fromBytes(bytes);

      expect(config.highTempThreshold, 0x1234); // 4660
      expect(config.recoveryThreshold, 0x5678); // 22136
      expect(config.sleepVoltageThreshold, 0x90AB); // 37035
      expect(config.wakeVoltageThreshold, 0xCDEF); // 52719
      expect(config.highTempCelsius, 46.60);
      expect(config.recoveryCelsius, 221.36);
      expect(config.sleepVoltage, 37.035);
      expect(config.wakeVoltage, 52.719);
    });
  });
}