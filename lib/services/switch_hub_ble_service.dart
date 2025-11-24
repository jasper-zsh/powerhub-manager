import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/services/font_generation_service.dart';
import 'package:app/utils/ble_uuid.dart';

/// BLE helper dedicated to SwitchHub's configuration service. The logic follows
/// the streaming format documented in `SWITCHHUB_BLE_DESIGN.md`.
class SwitchHubBleService {
  const SwitchHubBleService();

  static final Guid serviceUuid = parseBleUuid(
    '119B5F1B-1C7A-3E8E-6147-672F-0200-0B5E',
  );
  static final Guid serviceUuidReversed = reverseBleUuid(
    '119B5F1B-1C7A-3E8E-6147-672F-0200-0B5E',
  );
  static final Guid configCharacteristicUuid = parseBleUuid(
    '0000fff3-0000-1000-8000-00805f9b34fb',
  );
  static final Guid powerManagementCharacteristicUuid = parseBleUuid(
    '0000fff1-0000-1000-8000-00805f9b34fb',
  );

  Future<void> pushConfig(
    BluetoothDevice device,
    SwitchHubConfig config, {
    int chunkSize = 200,
  }) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locateConfigCharacteristic(device);
      final payload = utf8.encode(jsonEncode(config.toJson()));
      final totalChunks = (payload.length / chunkSize).ceil().clamp(1, 0xFFFF);

      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, payload.length);
        final chunkPayload = payload.sublist(start, end);
        final frame = BytesBuilder()
          ..add(_u16(i))
          ..add(_u16(totalChunks))
          ..add(chunkPayload);
        await characteristic.write(frame.toBytes(), withoutResponse: true);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      // await device.disconnect();
    }
  }

  Future<SwitchHubConfig> readConfig(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locateConfigCharacteristic(device);
      final raw = await characteristic.read();
      if (raw.isEmpty) {
        throw Exception('EMPTY_SWITCHHUB_CONFIG');
      }
      final decoded = utf8.decode(raw);
      final dynamic payload = jsonDecode(decoded);
      return SwitchHubConfig.fromJson(
        Map<String, dynamic>.from(payload as Map),
      );
    } finally {
      await device.disconnect();
    }
  }

  Future<BluetoothCharacteristic> _locateConfigCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    BluetoothService? service;
    for (final candidate in services) {
      if (candidate.uuid == serviceUuid ||
          candidate.uuid == serviceUuidReversed) {
        service = candidate;
        break;
      }
    }

    if (service != null) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == configCharacteristicUuid) {
          return characteristic;
        }
      }
    }

    // Fallback: search every discovered service for the config characteristic.
    for (final candidate in services) {
      for (final characteristic in candidate.characteristics) {
        if (characteristic.uuid == configCharacteristicUuid) {
          return characteristic;
        }
      }
    }

    throw Exception('SWITCHHUB_CONFIG_CHAR_NOT_FOUND');
  }

  /// Push font data to device using 0x05 command (font update flow)
  ///
  /// [device] - The Bluetooth device
  /// [fontData] - The binary font data to send
  /// [chunkSize] - Size of each chunk to send (default: 200)
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Returns [Future<void>] when complete
  Future<void> pushFontData(
    BluetoothDevice device,
    Uint8List fontData, {
    int chunkSize = 200,
    Function(int current, int total)? onProgress,
  }) async {
    // await device.connect(autoConnect: false);
    try {
      final characteristic = await _locatePowerManagementCharacteristic(device);
      final totalSize = fontData.length;
      final totalChunks = (totalSize / chunkSize).ceil().clamp(1, 0xFFFF);

      // Send font data in chunks using 0x05 command format
      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, totalSize);
        final chunkPayload = fontData.sublist(start, end);

        // Build frame: [0x05][length(2B)][chunk_seq(2B)][payload...]
        final frame = BytesBuilder()
          ..add([0x05]) // Font update command
          ..add(_u16(chunkPayload.length)) // Payload length
          ..add(_u16(i)) // Chunk sequence number
          ..add(chunkPayload); // Font data chunk

        await characteristic.write(frame.toBytes(), withoutResponse: false);

        // Notify progress
        if (onProgress != null) {
          onProgress(i + 1, totalChunks);
        }

        // Small delay between chunks to avoid overwhelming the device
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    } finally {
      await device.disconnect();
    }
  }

  /// Generate and push font data for SwitchHub configuration
  ///
  /// [device] - The Bluetooth device
  /// [config] - The SwitchHub configuration
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [chunkSize] - Size of each chunk to send (default: 200)
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Returns [Future<void>] when complete
  Future<void> generateAndPushFontData(
    BluetoothDevice device,
    SwitchHubConfig config, {
    int fontSize = 16,
    int bpp = 2,
    int chunkSize = 200,
    Function(int current, int total)? onProgress,
  }) async {
    // Generate font data from configuration
    final fontData = await FontGenerationService.generateBinaryFont(
      config,
      fontSize: fontSize,
      bpp: bpp,
      noCompress: false,
      noKerning: true,
    );

    // Push the generated font data
    await pushFontData(
      device,
      fontData,
      chunkSize: chunkSize,
      onProgress: onProgress,
    );
  }

  Future<BluetoothCharacteristic> _locatePowerManagementCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    BluetoothService? service;
    for (final candidate in services) {
      if (candidate.uuid == serviceUuid ||
          candidate.uuid == serviceUuidReversed) {
        service = candidate;
        break;
      }
    }

    if (service != null) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == powerManagementCharacteristicUuid) {
          return characteristic;
        }
      }
    }

    // Fallback: search every discovered service for the power management characteristic.
    for (final candidate in services) {
      for (final characteristic in candidate.characteristics) {
        if (characteristic.uuid == powerManagementCharacteristicUuid) {
          return characteristic;
        }
      }
    }

    throw Exception('SWITCHHUB_POWER_MANAGEMENT_CHAR_NOT_FOUND');
  }

  List<int> _u16(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value & 0xFFFF, Endian.little);
    return bytes.buffer.asUint8List();
  }
}
