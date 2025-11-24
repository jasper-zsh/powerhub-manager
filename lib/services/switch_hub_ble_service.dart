import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
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

  // Public access for enhanced font upload service
  static Guid get serviceUuidPublic => serviceUuid;
  static Guid get serviceUuidReversedPublic => serviceUuidReversed;
  static Guid get powerManagementCharacteristicUuidPublic => powerManagementCharacteristicUuid;

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

  /// Push font data to device using enhanced font upload protocol
  ///
  /// [device] - The Bluetooth device
  /// [fontData] - The binary font data to send
  /// [chunkSize] - Size of each chunk to send (default: 4096, max: 65535)
  /// [onProgress] - Optional callback for progress updates (sequence, totalSequences, percentage)
  ///
  /// Returns [Future<void>] when complete
  ///
  /// Protocol Format:
  /// Data chunks: [0x05][chunk_len_hi][chunk_len_lo][seq_hi][seq_lo][payload...]
  /// Completion: [0x05][0x00][0x00][final_seq_hi][final_seq_lo]
  Future<void> pushFontData(
    BluetoothDevice device,
    Uint8List fontData, {
    int chunkSize = 4096,
    Function(int sequence, int totalSequences, int percentage)? onProgress,
  }) async {
    // Validate font size (1MB max)
    const maxFontSizeBytes = 1024 * 1024;
    if (fontData.length > maxFontSizeBytes) {
      throw ArgumentError('Font size exceeds maximum allowed size of $maxFontSizeBytes bytes');
    }

    // Validate and adjust chunk size (max 65535 bytes)
    const maxChunkSize = 65535;
    if (chunkSize > maxChunkSize) {
      chunkSize = maxChunkSize;
    }

    try {
      final characteristic = await _locatePowerManagementCharacteristic(device);
      final totalSize = fontData.length;
      final totalChunks = (totalSize / chunkSize).ceil().clamp(1, 0xFFFF);

      debugPrint('Starting font upload: $totalSize bytes, $totalChunks chunks of $chunkSize bytes');

      // Send font data in chunks using exact protocol format
      for (var i = 0; i < totalChunks; i++) {
        final start = i * chunkSize;
        final end = (start + chunkSize).clamp(0, totalSize);
        final chunkPayload = fontData.sublist(start, end);

        // Build frame: [0x05][chunk_len_hi][chunk_len_lo][seq_hi][seq_lo][payload...]
        final frame = BytesBuilder()
          ..add([0x05]) // Font upload command identifier
          ..add(_u16(chunkPayload.length)) // Payload length (2 bytes)
          ..add(_u16(i)) // Chunk sequence number (2 bytes)
          ..add(chunkPayload); // Font data chunk

        // Check characteristic properties to determine write mode
        final supportsWriteWithoutResponse = characteristic.properties.writeWithoutResponse;
        debugPrint('SwitchHubBleService characteristic properties: ${characteristic.properties}');

        if (supportsWriteWithoutResponse) {
          await characteristic.write(frame.toBytes(), withoutResponse: true);
        } else {
          await characteristic.write(frame.toBytes(), withoutResponse: false);
        }

        // Calculate and notify progress
        final percentage = ((i + 1) / totalChunks * 100).round();
        if (onProgress != null) {
          onProgress(i, totalChunks, percentage);
        }

        debugPrint('Sent font chunk $i/${totalChunks - 1} (${chunkPayload.length} bytes, $percentage%)');

        // Small delay between chunks to avoid overwhelming the device
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      // Send completion packet with zero-length payload
      // After sending chunks 0, 1, 2, ..., totalChunks-1, the next expected sequence is totalChunks
      // Device validation: if (payload_len == 0 && seq != s_font_ctx.next_seq) return ESP_ERR_INVALID_STATE;
      final completionFrame = BytesBuilder()
        ..add([0x05]) // Font upload command identifier
        ..add(_u16(0)) // Zero length payload
        ..add(_u16(totalChunks)); // Device expects totalChunks (s_font_ctx.next_seq)

      // Check characteristic properties for completion packet as well
      final supportsWriteWithoutResponse = characteristic.properties.writeWithoutResponse;
      if (supportsWriteWithoutResponse) {
        await characteristic.write(completionFrame.toBytes(), withoutResponse: true);
      } else {
        await characteristic.write(completionFrame.toBytes(), withoutResponse: false);
      }
      debugPrint('Font upload completion packet sent with sequence $totalChunks (mode: ${supportsWriteWithoutResponse ? "withoutResponse" : "withResponse"})');

    } finally {
      // await device.disconnect();
    }
  }

  /// Generate and push font data for SwitchHub configuration
  ///
  /// [device] - The Bluetooth device
  /// [config] - The SwitchHub configuration
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [chunkSize] - Size of each chunk to send (default: 200)
  /// [onProgress] - Optional callback for progress updates (sequence, totalSequences, percentage)
  ///
  /// Returns [Future<void>] when complete
  Future<void> generateAndPushFontData(
    BluetoothDevice device,
    SwitchHubConfig config, {
    int fontSize = 16,
    int bpp = 2,
    int chunkSize = 200,
    Function(int sequence, int totalSequences, int percentage)? onProgress,
  }) async {
    // Generate font data from configuration with alphanumeric characters included
    final fontData = await FontGenerationService.generateBinaryFontForCharacters(
      _getAlphanumericCharacterSet(),
      fontSize: fontSize,
      bpp: bpp,
      noCompress: false,
      noKerning: true,
    );

    // Push the generated font data
    if (onProgress != null) {
      // Convert old-style callback to new style
      await pushFontData(
        device,
        fontData,
        chunkSize: chunkSize,
        onProgress: (sequence, totalSequences, percentage) {
          onProgress(sequence, totalSequences, percentage);
        },
      );
    } else {
      await pushFontData(
        device,
        fontData,
        chunkSize: chunkSize,
      );
    }
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

  /// Get comprehensive alphanumeric character set for font generation
  List<String> _getAlphanumericCharacterSet() {
    final characters = <String>{};

    // Add all uppercase letters (A-Z)
    for (int i = 65; i <= 90; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add all lowercase letters (a-z)
    for (int i = 97; i <= 122; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add all digits (0-9)
    for (int i = 48; i <= 57; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add common punctuation and symbols
    final punctuation = ' !@#\$%^&*()_+-=[]{}|;:,.<>?/~`\'"\\';
    characters.addAll(punctuation.split(''));

    // Return as sorted list for consistency
    final sortedList = characters.toList()..sort();
    return sortedList;
  }
}
