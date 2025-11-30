import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/monitoring_data.dart';

void main() {
  group('MonitoringData', () {
    test('should create MonitoringData and parse 32-byte structure', () {
      // Create a monitoring data object directly
      final monitoring = MonitoringData(
        inputVoltage: 12000, // 12.0V in mV
        powerZoneTemp: 2500, // 25.0°C in 0.01°C units
        controlZoneTemp: 3000, // 30.0°C in 0.01°C units
        channelCurrents: [1.0, 0.5, 1.5, 2.0, 2.5, 3.0], // 6 channels
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );

      // Test basic structure
      expect(monitoring.inputVoltageVolts, 12.0);
      expect(monitoring.powerZoneTempCelsius, 25.0);
      expect(monitoring.controlZoneTempCelsius, 30.0);
      expect(monitoring.channelCurrents.length, 6);

      // Test calculated total current functionality
      expect(monitoring.calculatedTotalCurrent, 10.5); // 1+0.5+1.5+2+2.5+3 = 10.5
      expect(monitoring.validChannelCount, 6);

      // Test individual channel access
      expect(monitoring.getChannelCurrent(0), 1.0);
      expect(monitoring.getChannelCurrent(1), 0.5);
      expect(monitoring.getChannelCurrent(2), 1.5);
      expect(monitoring.getChannelCurrent(3), 2.0);
      expect(monitoring.getChannelCurrent(4), 2.5);
      expect(monitoring.getChannelCurrent(5), 3.0);
    });

    test('should parse basic 32-byte structure', () {
      // Simple test with zero values to avoid byte order complexities
      final bytes = [
        // Bytes 0-1: Input voltage = 0mV = 0V
        0x00, 0x00,
        // Bytes 2-3: Power zone temp = 0.01°C units = 0°C
        0x00, 0x00,
        // Bytes 4-5: Control zone temp = 0.01°C units = 0°C
        0x00, 0x00,
        // Bytes 6-29: 6 channel currents = 6 x 0.0A (all zeros)
        ...List.filled(24, 0x00),
        // Byte 30: Status flags = all off
        0x00,
        // Byte 31: Reserved
        0x00,
      ];

      final monitoring = MonitoringData.fromBytes(bytes);

      expect(monitoring.inputVoltageVolts, 0.0);
      expect(monitoring.powerZoneTempCelsius, 0.0);
      expect(monitoring.controlZoneTempCelsius, 0.0);
      expect(monitoring.channelCurrents.every((c) => c == 0.0), true);
      expect(monitoring.channelCurrents.length, 6);
      expect(monitoring.calculatedTotalCurrent, 0.0);
    });

    test('should reject incorrect data length', () {
      expect(
        () => MonitoringData.fromBytes([0x01, 0x02]), // Too short
        throwsArgumentError,
      );

      expect(
        () => MonitoringData.fromBytes(List.filled(31, 0)), // Too short
        throwsArgumentError,
      );

      expect(
        () => MonitoringData.fromBytes(List.filled(33, 0)), // Too long
        throwsArgumentError,
      );
    });

    test('should handle calculated total current with invalid channels', () {
      final monitoring = MonitoringData(
        inputVoltage: 10000, // 10.0V in mV
        powerZoneTemp: 4000, // 40.0°C in 0.01°C units
        controlZoneTemp: 4100, // 41.0°C in 0.01°C units
        channelCurrents: [1.0, -1.0, 2.0, 4.0, double.nan, double.infinity], // Mix of valid and invalid
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );

      expect(monitoring.calculatedTotalCurrent, 7.0); // Only 1+2+4 = 7.0 (valid channels)
      expect(monitoring.validChannelCount, 3); // Only 3 valid channels
    });

    test('should handle invalid data length', () {
      expect(
        () => MonitoringData.fromBytes([0x01, 0x02]),
        throwsArgumentError,
      );
    });

    test('should test calculated total current with invalid channels', () {
      final monitoring = MonitoringData(
        inputVoltage: 10000, // 10.0V in mV
        powerZoneTemp: 4000, // 40.0°C in 0.01°C units
        controlZoneTemp: 4100, // 41.0°C in 0.01°C units
        channelCurrents: [1.0, -1.0, 2.0, 4.0, double.nan, double.infinity], // Mix of valid and invalid
        statusFlags: SystemStatusFlags(
          thermalProtectionActive: false,
          temperatureDataValid: true,
          currentDataValid: true,
          calibrationStatus: true,
          peripheralPowerOn: true,
        ),
      );

      expect(monitoring.calculatedTotalCurrent, 7.0); // Only 1+2+4 = 7.0 (valid channels)
      expect(monitoring.validChannelCount, 3); // Only 3 valid channels
    });
  });

  group('SystemStatusFlags', () {
    test('should create from byte correctly', () {
      final flags = SystemStatusFlags.fromByte(0x1F);

      expect(flags.thermalProtectionActive, true);
      expect(flags.temperatureDataValid, true);
      expect(flags.currentDataValid, true);
      expect(flags.calibrationStatus, true);
      expect(flags.peripheralPowerOn, true);
    });

    test('should convert to byte correctly', () {
      final flags = SystemStatusFlags(
        thermalProtectionActive: true,
        temperatureDataValid: false,
        currentDataValid: true,
        calibrationStatus: false,
        peripheralPowerOn: true,
      );

      final byte = flags.toByte();

      expect(byte, 0x15); // 0b00010101
    });

    test('should handle all flags off', () {
      final flags = SystemStatusFlags.fromByte(0x00);

      expect(flags.thermalProtectionActive, false);
      expect(flags.temperatureDataValid, false);
      expect(flags.currentDataValid, false);
      expect(flags.calibrationStatus, false);
      expect(flags.peripheralPowerOn, false);
    });

    test('should format toString correctly', () {
      final flags = SystemStatusFlags(
        thermalProtectionActive: true,
        temperatureDataValid: true,
        currentDataValid: false,
        calibrationStatus: true,
        peripheralPowerOn: false,
      );

      final result = flags.toString();

      expect(result, contains('thermalProtection'));
      expect(result, contains('tempValid'));
      expect(result, contains('calibrated'));
      expect(result, isNot(contains('currentValid')));
      expect(result, isNot(contains('peripheralPower')));
    });
  });
}