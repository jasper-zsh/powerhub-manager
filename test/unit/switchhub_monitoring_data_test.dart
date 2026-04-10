import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/monitoring_data.dart';

void main() {
  group('SwitchHubMonitoringData', () {
    test('should parse 4-byte monitoring data correctly', () {
      // Test data: [voltage_lo, voltage_hi, status, reserved]
      // Voltage: 12600mV (0x34, 0x31), Status: 0x00, Reserved: 0x00
      final data = [0x38, 0x31, 0x00, 0x00]; // 12600 = 0x3138

      final monitoringData = SwitchHubMonitoringData.fromBytes(data);

      expect(monitoringData.inputVoltageMv, equals(12600));
      expect(monitoringData.statusFlags, equals(0));
      expect(monitoringData.reserved, equals(0));
      expect(monitoringData.hasTemperatureSensor, isTrue);
    });

    test('should calculate battery percentage correctly for 12V automotive', () {
      // 12600mV = (12600-10500)/(14400-10500)*100 ≈ 53.8%
      final monitoringData = SwitchHubMonitoringData(
        inputVoltageMv: 12600,
        statusFlags: 0,
        reserved: 0,
      );
      expect(monitoringData.batteryPercentage, closeTo(53.8, 0.1));
    });

    test('should identify voltage status correctly for 12V automotive', () {
      // Test critical voltage (10000mV < 10500mV)
      final criticalMonitoring = SwitchHubMonitoringData(
        inputVoltageMv: 10000,
        statusFlags: 0,
        reserved: 0,
      );
      expect(criticalMonitoring.isVoltageCritical, isTrue);
      expect(criticalMonitoring.isVoltageLow, isTrue);
      expect(criticalMonitoring.isVoltageNormal, isFalse);

      // Test normal voltage (12600mV)
      final normalMonitoring = SwitchHubMonitoringData(
        inputVoltageMv: 12600,
        statusFlags: 0,
        reserved: 0,
      );
      expect(normalMonitoring.isVoltageNormal, isTrue);
      expect(normalMonitoring.isVoltageLow, isFalse);
      expect(normalMonitoring.isVoltageCritical, isFalse);

      // Test high voltage (15000mV > 14400mV)
      final highMonitoring = SwitchHubMonitoringData(
        inputVoltageMv: 15000,
        statusFlags: 0,
        reserved: 0,
      );
      expect(highMonitoring.isVoltageHigh, isTrue);
    });

    test('should handle temperature sensor status correctly', () {
      // Bit1=0 indicates no temperature sensor
      final noTempData = [0x38, 0x31, 0x00, 0x00]; // status = 0x00
      final noTempMonitoring = SwitchHubMonitoringData.fromBytes(noTempData);
      expect(noTempMonitoring.hasTemperatureSensor, isTrue); // bit1=0 = no temp sensor

      // Bit1=1 indicates temperature sensor available
      final tempData = [0x38, 0x31, 0x02, 0x00]; // status = 0x02
      final tempMonitoring = SwitchHubMonitoringData.fromBytes(tempData);
      expect(tempMonitoring.hasTemperatureSensor, isFalse); // bit1=1 = temp sensor available
    });

    test('should convert to bytes and back correctly', () {
      final original = SwitchHubMonitoringData(
        inputVoltageMv: 3750,
        statusFlags: 0x01,
        reserved: 0xFF,
      );

      final bytes = original.toBytes();
      final reconstructed = SwitchHubMonitoringData.fromBytes(bytes);

      expect(reconstructed.inputVoltageMv, equals(original.inputVoltageMv));
      expect(reconstructed.statusFlags, equals(original.statusFlags));
      expect(reconstructed.reserved, equals(original.reserved));
    });

    test('should serialize to and from JSON correctly', () {
      final original = SwitchHubMonitoringData(
        inputVoltageMv: 3600,
        statusFlags: 0x03,
        reserved: 0x00,
      );

      final json = original.toJson();
      final reconstructed = SwitchHubMonitoringData.fromJson(json);

      expect(reconstructed.inputVoltageMv, equals(original.inputVoltageMv));
      expect(reconstructed.statusFlags, equals(original.statusFlags));
      expect(reconstructed.reserved, equals(original.reserved));
    });

    test('should throw error for invalid data length', () {
      expect(() => SwitchHubMonitoringData.fromBytes([0x01, 0x02]), throwsArgumentError);
      expect(() => SwitchHubMonitoringData.fromBytes([]), throwsArgumentError);
    });
  });
}