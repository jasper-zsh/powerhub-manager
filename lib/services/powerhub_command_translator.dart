import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';
import 'package:app/utils/ble_uuid.dart';

/// Translates SwitchHub command sequences to PowerHub BLE commands
/// Handles MAC address validation, routing, and command execution
class PowerHubCommandTranslator {
  static const int maxRetries = 3;
  static const Duration defaultRetryDelay = Duration(milliseconds: 500);

  /// Execute a sequence item on target PowerHub device
  static Future<void> executeSequenceItem(
    SwitchHubSequenceItem sequenceItem, {
    Function(String)? onProgress,
    Duration? retryDelay,
  }) async {
    final delay = retryDelay ?? defaultRetryDelay;
    final targetMac = sequenceItem.targetMac;

    try {
      onProgress?.call('Connecting to PowerHub device: $targetMac');
      final device = await _findPowerHubDevice(targetMac);

      if (device == null) {
        throw Exception('POWERHUB_DEVICE_NOT_FOUND: $targetMac');
      }

      onProgress?.call('Connected to $targetMac, executing ${sequenceItem.commandPackets.length} commands');

      await device.connect(autoConnect: false);

      try {
        // Execute each command packet in sequence
        for (var i = 0; i < sequenceItem.commandPackets.length; i++) {
          final packet = sequenceItem.commandPackets[i];
          final retryCount = packet.retry ?? 0;

          onProgress?.call('Executing command ${i + 1}/${sequenceItem.commandPackets.length} (mode: 0x${packet.mode.toRadixString(16)}, channel: ${packet.channel})');

          // Apply delay before command if specified
          if (sequenceItem.delayMs != null && sequenceItem.delayMs! > 0) {
            await Future.delayed(Duration(milliseconds: sequenceItem.delayMs!));
          }

          await _executeCommandPacket(device, packet, retryCount, delay);
        }

        onProgress?.call('Successfully executed all commands on $targetMac');
      } finally {
        await device.disconnect();
      }
    } catch (e) {
      throw Exception('Failed to execute sequence on $targetMac: $e');
    }
  }

  /// Execute multiple sequence items in parallel
  static Future<void> executeSequenceItems(
    List<SwitchHubSequenceItem> sequenceItems, {
    Function(int completed, int total, String? currentDevice)? onProgress,
    bool parallel = true,
  }) async {
    if (parallel) {
      // Execute in parallel
      final futures = sequenceItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;

        return executeSequenceItem(
          item,
          onProgress: (progress) {
            onProgress?.call(index, sequenceItems.length, item.targetMac);
          },
        );
      }).toList();

      await Future.wait(futures);
    } else {
      // Execute sequentially
      for (var i = 0; i < sequenceItems.length; i++) {
        final item = sequenceItems[i];
        onProgress?.call(i, sequenceItems.length, item.targetMac);

        await executeSequenceItem(
          item,
          onProgress: (progress) {
            onProgress?.call(i, sequenceItems.length, item.targetMac);
          },
        );
      }
    }
  }

  /// Validate MAC address format
  static bool isValidMacAddress(String mac) {
    final macRegex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return macRegex.hasMatch(mac);
  }

  /// Normalize MAC address format to uppercase with colons
  static String normalizeMacAddress(String mac) {
    return mac.toUpperCase().replaceAll('-', ':');
  }

  /// Find PowerHub device by MAC address
  static Future<BluetoothDevice?> _findPowerHubDevice(String targetMac) async {
    try {
      // Normalize MAC address
      final normalizedMac = normalizeMacAddress(targetMac);

      // Scan for devices
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      // Listen for scan results
      BluetoothDevice? targetDevice;
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (result.device.remoteId.str.toLowerCase() == normalizedMac.toLowerCase()) {
            targetDevice = result.device;
            break;
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 5));

      // Stop scanning
      await FlutterBluePlus.stopScan();
      await subscription.cancel();

      return targetDevice;
    } catch (e) {
      debugPrint('Error scanning for PowerHub device: $e');
      return null;
    }
  }

  /// Execute a single command packet on PowerHub device
  static Future<void> _executeCommandPacket(
    BluetoothDevice device,
    SwitchHubCommandPacket packet,
    int retryCount,
    Duration retryDelay,
  ) async {
    var attempts = 0;
    dynamic lastError;

    while (attempts <= retryCount) {
      try {
        // Build PowerHub command packet
        final commandBytes = _buildPowerHubCommand(packet);

        // Find the PowerHub service and characteristic
        final characteristic = await _locatePowerHubCharacteristic(device);

        // Write command to device
        await characteristic.write(commandBytes, withoutResponse: packet.mode == 0x03);

        debugPrint('Successfully executed PowerHub command: mode=0x${packet.mode.toRadixString(16)}, channel=${packet.channel}');
        return; // Success, exit retry loop
      } catch (e) {
        lastError = e;
        attempts++;
        debugPrint('PowerHub command attempt $attempts failed: $e');

        if (attempts <= retryCount) {
          await Future.delayed(retryDelay);
        }
      }
    }

    throw Exception('PowerHub command failed after $retryCount retries: $lastError');
  }

  /// Build PowerHub command packet from SwitchHub command packet
  static List<int> _buildPowerHubCommand(SwitchHubCommandPacket packet) {
    // Decode base64 payload
    final payload = base64Decode(packet.payload);

    // PowerHub command format: [mode(1B)][channel(1B)][payload...]
    final command = BytesBuilder()
      ..add([packet.mode])
      ..add([packet.channel])
      ..add(payload);

    return command.toBytes();
  }

  /// Locate PowerHub control characteristic (0xFFF1)
  static Future<BluetoothCharacteristic> _locatePowerHubCharacteristic(
    BluetoothDevice device,
  ) async {
    // PowerHub service UUID (from POWERHUB_BLE.md)
    const powerHubServiceUuid = '119B5F1B-1C7A-3E8E-6147-672F-0200-0B5E';
    final serviceUuid = parseBleUuid(powerHubServiceUuid);
    final controlCharacteristicUuid = parseBleUuid('0000fff1-0000-1000-8000-00805f9b34fb');

    final services = await device.discoverServices();

    // Find PowerHub service
    for (final service in services) {
      if (service.uuid == serviceUuid) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid == controlCharacteristicUuid) {
            return characteristic;
          }
        }
      }
    }

    throw Exception('POWERHUB_CONTROL_CHARACTERISTIC_NOT_FOUND');
  }

  /// Test connection to PowerHub device
  static Future<bool> testPowerHubConnection(String targetMac) async {
    try {
      final device = await _findPowerHubDevice(targetMac);
      if (device == null) {
        return false;
      }

      await device.connect(autoConnect: false);

      // Try to locate the characteristic to verify it's a PowerHub device
      try {
        await _locatePowerHubCharacteristic(device);
        return true;
      } catch (e) {
        return false;
      } finally {
        await device.disconnect();
      }
    } catch (e) {
      debugPrint('Error testing PowerHub connection: $e');
      return false;
    }
  }

  /// Get PowerHub device information
  static Future<Map<String, dynamic>?> getPowerHubDeviceInfo(String targetMac) async {
    try {
      final device = await _findPowerHubDevice(targetMac);
      if (device == null) {
        return null;
      }

      await device.connect(autoConnect: false);

      try {
        final services = await device.discoverServices();
        final characteristics = <Map<String, dynamic>>[];

        for (final service in services) {
          for (final characteristic in service.characteristics) {
            characteristics.add({
              'service': service.uuid.toString(),
              'characteristic': characteristic.uuid.toString(),
              'properties': characteristic.properties.toString(),
            });
          }
        }

        return {
          'name': device.platformName,
          'deviceId': device.remoteId.str,
          'services': services.length,
          'characteristics': characteristics,
        };
      } finally {
        await device.disconnect();
      }
    } catch (e) {
      debugPrint('Error getting PowerHub device info: $e');
      return null;
    }
  }
}