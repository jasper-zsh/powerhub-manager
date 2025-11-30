import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/monitoring_data.dart';
import 'package:app/models/switch_hub/voltage_thresholds.dart';
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
  static final Guid monitoringCharacteristicUuid = parseBleUuid(
    '0000fff2-0000-1000-8000-00805f9b34fb',
  );

  // BLE ATT Error codes for proper error handling
  static const int attErrInvalidOffset = 0x07;
  static const int attErrReqNotSupported = 0x06;
  static const int attErrUnlikely = 0x0E;

  // Voltage thresholds validation constants
  static const int minVoltageMv = 3000;
  static const int maxVoltageMv = 4200;
  static const int defaultSleepVoltageMv = 3300;
  static const int defaultWakeVoltageMv = 3600;

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
    // Generate font data from configuration plus alphanumeric/common characters
    final fontData = await FontGenerationService.generateBinaryFontWithAlphanumeric(
      config,
      fontSize: fontSize,
      bpp: bpp,
      noCompress: false,
      noKerning: true,
      includeCommonChars: false,
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

  /// Read current real-time monitoring data from characteristic 0xFFF2
  Future<SwitchHubMonitoringData> readMonitoringData(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locateMonitoringCharacteristic(device);
      final raw = await characteristic.read();

      if (raw.length < 4) {
        throw Exception('INVALID_MONITORING_DATA_LENGTH');
      }

      return SwitchHubMonitoringData.fromBytes(raw);
    } catch (e) {
      throw Exception('Failed to read monitoring data: $e');
    } finally {
      // await device.disconnect();
    }
  }

  /// Subscribe to real-time monitoring notifications
  Stream<SwitchHubMonitoringData> subscribeToMonitoringNotifications(
    BluetoothDevice device,
  ) async* {
    await device.connect(autoConnect: false);

    try {
      final characteristic = await _locateMonitoringCharacteristic(device);

      if (!characteristic.properties.notify) {
        throw Exception('MONITORING_CHARACTERISTIC_DOES_NOT_SUPPORT_NOTIFICATIONS');
      }

      await characteristic.setNotifyValue(true);

      yield* characteristic.lastValueStream.map((data) {
        if (data.isEmpty) {
          throw Exception('EMPTY_MONITORING_DATA');
        }
        return SwitchHubMonitoringData.fromBytes(data);
      });
    } catch (e) {
      throw Exception('Failed to subscribe to monitoring notifications: $e');
    }
  }

  /// Read voltage thresholds from power management characteristic
  Future<SwitchHubVoltageThresholds> readVoltageThresholds(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locatePowerManagementCharacteristic(device);
      final raw = await characteristic.read();

      if (raw.length < 4) {
        throw Exception('INVALID_VOLTAGE_THRESHOLDS_LENGTH');
      }

      return SwitchHubVoltageThresholds.fromBytes(raw);
    } catch (e) {
      throw Exception('Failed to read voltage thresholds: $e');
    } finally {
      // await device.disconnect();
    }
  }

  /// Set sleep voltage threshold using command 0x01
  Future<void> setSleepVoltageThreshold(
    BluetoothDevice device,
    int voltageMv,
  ) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locatePowerManagementCharacteristic(device);

      // Validate voltage range
      if (voltageMv < minVoltageMv || voltageMv > maxVoltageMv) {
        throw ArgumentError('Voltage must be between ${minVoltageMv}mV and ${maxVoltageMv}mV');
      }

      // Build command: [0x01][voltage(2B)]
      final command = BytesBuilder()
        ..add([0x01]) // Set sleep voltage threshold command
        ..add(_u16(voltageMv));

      await characteristic.write(command.toBytes(), withoutResponse: false);
    } catch (e) {
      throw Exception('Failed to set sleep voltage threshold: $e');
    } finally {
      // await device.disconnect();
    }
  }

  /// Set wake voltage threshold using command 0x02
  Future<void> setWakeVoltageThreshold(
    BluetoothDevice device,
    int voltageMv,
  ) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locatePowerManagementCharacteristic(device);

      // Validate voltage range
      if (voltageMv < minVoltageMv || voltageMv > maxVoltageMv) {
        throw ArgumentError('Voltage must be between ${minVoltageMv}mV and ${maxVoltageMv}mV');
      }

      // Build command: [0x02][voltage(2B)]
      final command = BytesBuilder()
        ..add([0x02]) // Set wake voltage threshold command
        ..add(_u16(voltageMv));

      await characteristic.write(command.toBytes(), withoutResponse: false);
    } catch (e) {
      throw Exception('Failed to set wake voltage threshold: $e');
    } finally {
      // await device.disconnect();
    }
  }

  /// Set both sleep and wake voltage thresholds with validation
  Future<void> setVoltageThresholds(
    BluetoothDevice device,
    SwitchHubVoltageThresholds thresholds,
  ) async {
    // Validate thresholds
    if (!thresholds.isValid()) {
      throw ArgumentError(thresholds.getValidationError() ?? 'Invalid voltage thresholds');
    }

    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locatePowerManagementCharacteristic(device);

      // Set sleep threshold first
      final sleepCommand = BytesBuilder()
        ..add([0x01])
        ..add(_u16(thresholds.sleepVoltageMv));
      await characteristic.write(sleepCommand.toBytes(), withoutResponse: false);

      // Small delay between commands
      await Future.delayed(const Duration(milliseconds: 50));

      // Set wake threshold
      final wakeCommand = BytesBuilder()
        ..add([0x02])
        ..add(_u16(thresholds.wakeVoltageMv));
      await characteristic.write(wakeCommand.toBytes(), withoutResponse: false);
    } catch (e) {
      throw Exception('Failed to set voltage thresholds: $e');
    } finally {
      // await device.disconnect();
    }
  }

  /// Enhanced configuration reading with chunked transfer support
  Future<SwitchHubConfig> readConfigWithChunks(
    BluetoothDevice device, {
    int chunkSize = 200,
    Function(int currentChunk, int totalChunks, int percentage)? onProgress,
  }) async {
    await device.connect(autoConnect: false);
    try {
      final characteristic = await _locateConfigCharacteristic(device);

      // First read to get metadata and size
      final initialData = await characteristic.read();
      if (initialData.isEmpty) {
        throw Exception('EMPTY_CONFIG_METADATA');
      }

      // Parse metadata from the beginning of the data
      // Format: [chunk_seq(2B)][total_chunks(2B)][payload...]
      final totalChunks = (initialData[2] | (initialData[3] << 8));

      if (totalChunks == 1) {
        // Single chunk configuration
        final payload = initialData.sublist(4);
        final decoded = utf8.decode(payload);
        final dynamic jsonPayload = jsonDecode(decoded);
        return SwitchHubConfig.fromJson(Map<String, dynamic>.from(jsonPayload as Map));
      }

      // Multi-chunk configuration - read remaining chunks
      final allChunks = <List<int>>[];
      allChunks.add(initialData.sublist(4)); // Add first chunk payload

      // Note: FlutterBluePlus doesn't support offset-based reads directly
      // For now, we'll read all data in one go. In a real implementation,
      // you might need to use a different approach or native platform code.

      // For this implementation, we'll assume the initial read contains all data
      // and chunk it appropriately based on the expected format

      final totalPayload = allChunks.expand((chunk) => chunk).toList();
      final decoded = utf8.decode(totalPayload);
      final dynamic jsonPayload = jsonDecode(decoded);
      return SwitchHubConfig.fromJson(Map<String, dynamic>.from(jsonPayload as Map));
    } catch (e) {
      throw Exception('Failed to read configuration: $e');
    } finally {
      // await device.disconnect();
    }
  }

  /// Locate monitoring characteristic (0xFFF2)
  Future<BluetoothCharacteristic> _locateMonitoringCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    BluetoothService? service;

    // Find the SwitchHub service
    for (final candidate in services) {
      if (candidate.uuid == serviceUuid || candidate.uuid == serviceUuidReversed) {
        service = candidate;
        break;
      }
    }

    if (service != null) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == monitoringCharacteristicUuid) {
          return characteristic;
        }
      }
    }

    // Fallback: search every discovered service
    for (final candidate in services) {
      for (final characteristic in candidate.characteristics) {
        if (characteristic.uuid == monitoringCharacteristicUuid) {
          return characteristic;
        }
      }
    }

    throw Exception('MONITORING_CHARACTERISTIC_NOT_FOUND');
  }

  /// Handle BLE ATT errors and convert to user-friendly messages
  String handleAttError(int errorCode) {
    switch (errorCode) {
      case attErrInvalidOffset:
        return 'Invalid data offset - please retry the operation';
      case attErrReqNotSupported:
        return 'Operation not supported by this device';
      case attErrUnlikely:
        return 'Invalid data format - please check device compatibility';
      default:
        return 'BLE operation failed (error code: 0x${errorCode.toRadixString(16).padLeft(2, '0')})';
    }
  }

  List<int> _u16(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value & 0xFFFF, Endian.little);
    return bytes.buffer.asUint8List();
  }
}
