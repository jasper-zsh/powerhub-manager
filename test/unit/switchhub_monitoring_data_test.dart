import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/monitoring_data.dart';

void main() {
  group('SwitchHubMonitoringData', () {
    test('should parse 4-byte monitoring data correctly', () {
      // Test data: [voltage_lo, voltage_hi, status, reserved]
      // Voltage: 3500mV (0xD8, 0x0A), Status: 0x00, Reserved: 0x00
      final data = [0xD8, 0x0A, 0x00, 0x00];

      final monitoringData = SwitchHubMonitoringData.fromBytes(data);

      expect(monitoringData.inputVoltageMv, equals(3500));
      expect(monitoringData.statusFlags, equals(0));
      expect(monitoringData.reserved, equals(0));
      expect(monitoringData.hasTemperatureSensor, isTrue);
    });

    test('should calculate battery percentage correctly', () {
      final data = [0xD8, 0x0A, 0x00, 0x00]; // 3500mV
      final monitoringData = SwitchHubMonitoringData.fromBytes(data);

      // 3500mV should be approximately 29.2% (3500-3000)/(4200-3000)*100
      expect(monitoringData.batteryPercentage, closeTo(29.2, 0.1));
    });

    test('should identify voltage status correctly', () {
      // Test critical voltage (3200mV)
      final criticalData = [0x80, 0x0C, 0x00, 0x00]; // 3200mV
      final criticalMonitoring = SwitchHubMonitoringData.fromBytes(criticalData);
      expect(criticalMonitoring.isVoltageCritical, isTrue);
      expect(criticalMonitoring.isVoltageLow, isTrue);
      expect(criticalMonitoring.isVoltageNormal, isFalse);

      // Test normal voltage (3800mV)
      final normalData = [0xD0, 0x0E, 0x00, 0x00]; // 3800mV
      final normalMonitoring = SwitchHubMonitoringData.fromBytes(normalData);
      expect(normalMonitoring.isVoltageNormal, isTrue);
      expect(normalMonitoring.isVoltageLow, isFalse);
      expect(normalMonitoring.isVoltageCritical, isFalse);
    });

    test('should handle temperature sensor status correctly', () {
      // Bit1=0 indicates no temperature sensor
      final noTempData = [0xD8, 0x0A, 0x00, 0x00]; // status = 0x00
      final noTempMonitoring = SwitchHubMonitoringData.fromBytes(noTempData);
      expect(noTempMonitoring.hasTemperatureSensor, isTrue); // bit1=0 = no temp sensor

      // Bit1=1 indicates temperature sensor available
      final tempData = [0xD8, 0x0A, 0x02, 0x00]; // status = 0x02
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