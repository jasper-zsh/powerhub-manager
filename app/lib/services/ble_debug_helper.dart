import 'package:flutter/foundation.dart';

class BLEDebugHelper {
  static void logDeviceScan(List<String> serviceUuids, String deviceName) {
    debugPrint('=== BLE Device Scan Debug ===');
    debugPrint('Device Name: $deviceName');
    debugPrint('Service UUIDs: ${serviceUuids.join(', ')}');

    final hasNewService = serviceUuids.any((uuid) =>
        _normalizeUuid(uuid) == _normalizeUuid('119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E'));
    final hasLegacyService = serviceUuids.any((uuid) =>
        _normalizeUuid(uuid) == _normalizeUuid('5e0b0001-6f72-4761-8e3e-7a1c1b5f9b11'));

    debugPrint('Has New Service UUID: $hasNewService');
    debugPrint('Has Legacy Service UUID: $hasLegacyService');
    debugPrint('Will be recognized: ${hasNewService || hasLegacyService || deviceName == 'PowerHub'}');
    debugPrint('============================');
  }

  static void logServiceDiscovery(List<String> discoveredServices) {
    debugPrint('=== BLE Service Discovery Debug ===');
    debugPrint('Discovered ${discoveredServices.length} services:');

    for (int i = 0; i < discoveredServices.length; i++) {
      final service = discoveredServices[i];
      final normalized = _normalizeUuid(service);
      final isNewService = normalized == _normalizeUuid('119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E');
      final isLegacyService = normalized == _normalizeUuid('5e0b0001-6f72-4761-8e3e-7a1c1b5f9b11');

      debugPrint('  Service $i: $service');
      debugPrint('    Normalized: $normalized');
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

  static String _normalizeUuid(String uuid) {
    return uuid.toLowerCase().replaceAll('-', '');
  }
}