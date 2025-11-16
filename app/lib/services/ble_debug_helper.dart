import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/utils/ble_uuid.dart';

class BLEDebugHelper {
  static final Guid _powerHubServiceGuid =
      parseBleUuid('119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E');
  static final Guid _powerHubLegacyServiceGuid =
      parseBleUuid('5e0b0001-6f72-4761-8e3e-7a1c1b5f9b11');

  static void logDeviceScan(Iterable<Guid> serviceUuids, String deviceName) {
    debugPrint('=== BLE Device Scan Debug ===');
    debugPrint('Device Name: $deviceName');
    debugPrint('Service UUIDs: ${serviceUuids.map((u) => u.str).join(', ')}');

    final hasNewService = serviceUuids.any((uuid) => uuid == _powerHubServiceGuid);
    final hasLegacyService =
        serviceUuids.any((uuid) => uuid == _powerHubLegacyServiceGuid);

    debugPrint('Has New Service UUID: $hasNewService');
    debugPrint('Has Legacy Service UUID: $hasLegacyService');
    debugPrint('Will be recognized: ${hasNewService || hasLegacyService || deviceName == 'PowerHub'}');
    debugPrint('============================');
  }

  static void logServiceDiscovery(Iterable<Guid> discoveredServices) {
    debugPrint('=== BLE Service Discovery Debug ===');
    final services = discoveredServices.toList();
    debugPrint('Discovered ${services.length} services:');

    for (int i = 0; i < services.length; i++) {
      final service = services[i];
      final isNewService = service == _powerHubServiceGuid;
      final isLegacyService = service == _powerHubLegacyServiceGuid;

      debugPrint('  Service $i: ${service.str}');
      debugPrint('    Normalized: ${service.toString()}');
      debugPrint('    Is New Service: $isNewService');
      debugPrint('    Is Legacy Service: $isLegacyService');
      debugPrint('    Supported: ${isNewService || isLegacyService}');
    }
    debugPrint('==================================');
  }

  static void logConnectionResult(bool success, String error) {
    debugPrint('=== BLE Connection Result ===');
    debugPrint('Success: $success');
    if (!success && error.isNotEmpty) {
      debugPrint('Error: $error');

      // Provide helpful troubleshooting hints
      if (error.contains('Service not found')) {
        debugPrint('');
        debugPrint('Troubleshooting:');
        debugPrint('1. Make sure the ESP32 is running the latest PowerHub firmware');
        debugPrint('2. Check if the device is advertising one of these service UUIDs:');
        debugPrint('   - New: 119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E');
        debugPrint('   - Legacy: 5e0b0001-6f72-4761-8e3e-7a1c1b5f9b11');
        debugPrint('3. Ensure the device name is "PowerHub" (case-sensitive)');
        debugPrint('4. Try restarting the ESP32 device');
      } else if (error.contains('DEVICE_NOT_FOUND')) {
        debugPrint('');
        debugPrint('Troubleshooting:');
        debugPrint('1. Make sure the device is powered on and in range');
        debugPrint('2. Check if Bluetooth is enabled on your phone');
        debugPrint('3. Try scanning again to refresh the device list');
      }
    }
    debugPrint('============================');
  }

}
