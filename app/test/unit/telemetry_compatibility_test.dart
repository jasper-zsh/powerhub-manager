import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/telemetry.dart';
import 'package:app/models/power_management.dart';

void main() {
  group('Telemetry Compatibility', () {
    test('should parse old 16-byte telemetry format', () {
      // Old telemetry format: voltage, temp, thresholds, sleep/wake voltages, flags, reserved
      final bytes = [
        0x27, 0x10, // Input voltage: 10000 mV = 10.0V
        0x0F, 0xA0, // Temperature: 4000 * 0.01°C = 40.0°C
        0x17, 0x70, // High threshold: 6000 * 0.01°C = 60.0°C
        0x15, 0x7C, // Recovery threshold: 5500 * 0.01°C = 55.0°C
        0x30, 0xD4, // Sleep voltage: 12500 mV = 12.5V
        0x31, 0x38, // Wake voltage: 12600 mV = 12.6V
        0x03,        // Status flags: 0x03 (thermal protection + temp valid)
        0x00,        // Reserved byte
        0x00, 0x00   // Reserved word
      ];

      final telemetry = TelemetryData.fromRead(bytes);

      expect(telemetry.vinMillivolts, 10000);
      expect(telemetry.temperatureCelsius, 40.0);
      expect(telemetry.highThresholdCelsius, 60.0);
      expect(telemetry.recoverThresholdCelsius, 55.0);
      expect(telemetry.sleepThresholdVolts, 12.5);
      expect(telemetry.wakeThresholdVolts, 12.6);
      expect(telemetry.isThermalProtectionActive, true);
      expect(telemetry.isTemperatureValid, true);
    });

    test('should handle new 8-byte power management format', () {
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
  });
}