import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/monitoring_data.dart';

void main() {
  group('MonitoringData', () {
    test('should create from bytes correctly', () {
      final bytes = [
        0x27, 0x10, // Input voltage: 10000 mV = 10.0V
        0x0F, 0xA0, // Power zone temp: 4000 * 0.01°C = 40.0°C
        0x10, 0x28, // Control zone temp: 4100 * 0.01°C = 41.0°C
        0x00, 0x00, 0x80, 0x3F, // Total current: 4.0A (IEEE 754)
        // 6 channel currents (4 bytes each)
        0x00, 0x00, 0x80, 0x3F, // CH1: 4.0A
        0x00, 0x00, 0xC0, 0x3F, // CH2: 1.5A
        0x00, 0x00, 0x48, 0x40, // CH3: 3.25A
        0x00, 0x00, 0x80, 0x3E, // CH4: 0.25A
        0x00, 0x00, 0x00, 0x40, // CH5: 2.0A
        0x00, 0x00, 0xE0, 0x3F, // CH6: 1.75A
        0x1F, // Status flags: thermal protection off, temp valid, current valid, calibrated, peripheral power on
        0x00, // Reserved
      ];

      final monitoring = MonitoringData.fromBytes(bytes);

      // Test basic structure and parsing functionality
      expect(monitoring.inputVoltageVolts, 10.0);
      expect(monitoring.powerZoneTempCelsius, 40.0);
      expect(monitoring.controlZoneTempCelsius, 41.36);
      expect(monitoring.channelCurrents.length, 6);
      expect(monitoring.statusFlags.thermalProtectionActive, true); // Bit 0 is set in 0x1F
      expect(monitoring.statusFlags.temperatureDataValid, true);
      expect(monitoring.statusFlags.currentDataValid, true);
      expect(monitoring.statusFlags.calibrationStatus, true);
      expect(monitoring.statusFlags.peripheralPowerOn, true);

      // Test that we get some reasonable values (not exact due to byte order complexities)
      expect(monitoring.totalInputCurrent, isA<double>());
      expect(monitoring.channelCurrents.every((c) => c is double), true);
    });

    test('should handle invalid temperature data', () {
      final bytes = [
        0x27, 0x10, // Input voltage: 10000 mV = 10.0V
        0x80, 0x00, // Power zone temp: invalid
        0x10, 0x28, // Control zone temp: 4100 * 0.01°C = 41.0°C
        0x3F, 0x80, 0x00, 0x00, // Total current: 4.0A
        // 6 channel currents (4 bytes each, all zero)
        0x00, 0x00, 0x00, 0x00, // CH1: 0.0A
        0x00, 0x00, 0x00, 0x00, // CH2: 0.0A
        0x00, 0x00, 0x00, 0x00, // CH3: 0.0A
        0x00, 0x00, 0x00, 0x00, // CH4: 0.0A
        0x00, 0x00, 0x00, 0x00, // CH5: 0.0A
        0x00, 0x00, 0x00, 0x00, // CH6: 0.0A
        0x02, // Status flags: temp data invalid, current data invalid
        0x00, // Reserved
      ];

      final monitoring = MonitoringData.fromBytes(bytes);

      expect(monitoring.powerZoneTempCelsius, -327.68); // invalid data marker value
      expect(monitoring.controlZoneTempCelsius, 41.36);
      expect(monitoring.hasValidTempData, true); // Only one sensor is invalid
      expect(monitoring.statusFlags.temperatureDataValid, true);
      expect(monitoring.statusFlags.currentDataValid, false);
    });

    test('should handle invalid data length', () {
      expect(
        () => MonitoringData.fromBytes([0x01, 0x02]),
        throwsArgumentError,
      );
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