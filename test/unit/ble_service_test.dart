import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/ble_service.dart';

void main() {
  group('BLEService Service UUID Support', () {
    test('should support new PowerHub service UUID', () {
      // Test that we have the correct UUID defined
      expect(BLEService.serviceUuid, '119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E');
    });

    test('should have all required characteristic UUIDs defined', () {
      expect(BLEService.channelStatesUuid, '0000fff0-0000-1000-8000-00805f9b34fb');
      expect(BLEService.controlCommandsUuid, '0000fff1-0000-1000-8000-00805f9b34fb');
      expect(BLEService.powerManagementUuid, '0000fff5-0000-1000-8000-00805f9b34fb');
      expect(BLEService.monitoringUuid, '0000fff6-0000-1000-8000-00805f9b34fb');
    });

    test('should have telemetry and monitoring UUIDs defined', () {
      expect(BLEService.telemetryUuid, '0000fff5-0000-1000-8000-00805f9b34fb');
      expect(BLEService.powerManagementUuid, '0000fff5-0000-1000-8000-00805f9b34fb');
      expect(BLEService.monitoringUuid, '0000fff6-0000-1000-8000-00805f9b34fb');
    });
  });
}