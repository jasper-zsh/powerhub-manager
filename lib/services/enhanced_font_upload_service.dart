import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:app/services/switch_hub_ble_service.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/font_upload_protocol.dart';
import 'package:app/services/font_upload_error_handler.dart' as error_handler;
import 'package:app/services/font_upload_timeout_manager.dart';

/// Enhanced font upload service with protocol compliance, error handling, and progress reporting
class EnhancedFontUploadService {
  final SwitchHubBleService _bleService = const SwitchHubBleService();
  final BLEService _ble = BLEService();

  // Protocol management
  FontUploadProtocol? _protocol;
  final error_handler.FontUploadErrorHandler _errorHandler = error_handler.FontUploadErrorHandler();
  final FontUploadTimeoutManager _timeoutManager = FontUploadTimeoutManager();

  // State management
  StreamSubscription<List<int>>? _statusNotificationSubscription;
  bool _isUploading = false;

  // Configuration
  static const int maxFontSizeBytes = 1024 * 1024; // 1MB
  static const int maxChunkSize = 65535; // uint16_t limit
  static const int defaultChunkSize = 1024; // Reduced default size for better compatibility
  static const int minChunkSize = 128; // Smaller minimum for small fonts
  static const int memoryWarningThreshold = 819 * 1024; // 80% of 1MB

  /// Upload font data with enhanced protocol support
  Future<void> uploadFontData({
    required BluetoothDevice device,
    required Uint8List fontData,
    int chunkSize = defaultChunkSize,
    Function(FontUploadProgress)? onProgress,
    Function(FontUploadErrorDetails)? onError,
    Function()? onSuccess,
    Function(MemoryWarning)? onMemoryWarning,
    bool enableRetry = true,
  }) async {
    if (_isUploading) {
      throw StateError('Font upload already in progress');
    }

    // Validate input
    _validateFontData(fontData, chunkSize);

    _isUploading = true;
    try {
      // Initialize protocol
      _protocol = FontUploadProtocol(
        onProgress: onProgress,
        onError: onError,
        onSuccess: onSuccess,
        onMemoryWarning: onMemoryWarning,
      );

      await _performUploadWithRetry(
        device: device,
        fontData: fontData,
        chunkSize: chunkSize,
        enableRetry: enableRetry,
      );

    } finally {
      await _cleanup();
      _isUploading = false;
    }
  }

  /// Upload font data with retry logic
  Future<void> _performUploadWithRetry({
    required BluetoothDevice device,
    required Uint8List fontData,
    required int chunkSize,
    required bool enableRetry,
    int attempt = 0,
  }) async {
    try {
      await _performSingleUpload(
        device: device,
        fontData: fontData,
        chunkSize: chunkSize,
      );
    } catch (e) {
      debugPrint('Font upload attempt ${attempt + 1} failed: $e');

      if (!enableRetry || attempt >= _errorHandler.retryConfig.maxRetries) {
        rethrow;
      }

      // Handle error and determine if retry is possible
      final errorResult = _handleUploadError(e, attempt);
      if (!errorResult.shouldRetry) {
        rethrow;
      }

      // Wait before retry
      await Future.delayed(errorResult.delay);

      // Adjust strategy for retry
      final adjustedChunkSize = errorResult.restartFromBeginning
          ? _getOptimizedChunkSize(fontData.length, attempt + 1, true)
          : chunkSize;

      debugPrint('Retrying font upload with chunk size: $adjustedChunkSize');

      // Retry upload
      return _performUploadWithRetry(
        device: device,
        fontData: fontData,
        chunkSize: adjustedChunkSize,
        enableRetry: enableRetry,
        attempt: attempt + 1,
      );
    }
  }

  /// Perform single font upload attempt
  Future<void> _performSingleUpload({
    required BluetoothDevice device,
    required Uint8List fontData,
    required int chunkSize,
  }) async {
    debugPrint('Starting font upload: ${fontData.length} bytes, chunk size: $chunkSize');

    // Initialize protocol
    _protocol!.initializeUpload(fontData.length, chunkSize: chunkSize);

    // Setup status notifications (optional - may not be available on all devices)
    bool statusNotificationsEnabled = false;
    try {
      statusNotificationsEnabled = await _setupStatusNotifications();
    } catch (e) {
      debugPrint('Status notifications setup failed, continuing without them: $e');
    }

    // Start timeout management
    _timeoutManager.startUploadSession();

    // Start upload
    _protocol!.startUpload();

    debugPrint('Font upload started (status notifications: ${statusNotificationsEnabled ? "enabled" : "disabled"})');

    // Calculate chunks
    final totalChunks = (fontData.length / chunkSize).ceil().clamp(1, 0xFFFF);
    int currentSequence = 0;

    // Send chunks
    for (currentSequence = 0; currentSequence < totalChunks; currentSequence++) {
      final start = currentSequence * chunkSize;
      final end = (start + chunkSize).clamp(0, fontData.length);
      final chunkData = fontData.sublist(start, end);

      // Start chunk timeout
      _timeoutManager.startChunkTimeout();

      try {
        // Send chunk using existing BLE service
        await _sendChunk(device, chunkData, currentSequence);

        // Update protocol state
        _protocol!.processChunkSent(currentSequence);

        // Reset timeout
        _timeoutManager.resetChunkTimeout();

        // Small delay
        await Future<void>.delayed(const Duration(milliseconds: 10));

      } catch (e) {
        // Handle chunk transmission error
        final errorResult = _errorHandler.handleAttError(
          e as Exception,
          0, // This is handled at retry level
        );

        if (!errorResult.shouldRetry) {
          rethrow;
        }

        // For retryable chunk errors, restart from beginning
        final errorType = switch (errorResult.error) {
          error_handler.FontUploadError.attError => FontUploadError.timeout,
          error_handler.FontUploadError.timeout => FontUploadError.timeout,
          error_handler.FontUploadError.disconnection => FontUploadError.disconnection,
          error_handler.FontUploadError.fontApplicationFailed => FontUploadError.fontApplicationFailed,
          error_handler.FontUploadError.sequenceError => FontUploadError.sequenceError,
          error_handler.FontUploadError.sizeExceeded => FontUploadError.sizeExceeded,
          error_handler.FontUploadError.characteristicNotFound => FontUploadError.characteristicNotFound,
          error_handler.FontUploadError.unknownProtocolError => FontUploadError.invalidResponse,
        };
        throw FontUploadException(errorResult.message, errorType: errorType);
      }
    }

    // Send completion packet
    _protocol!.completeUpload();
    await _sendCompletionPacket(device, totalChunks);

    debugPrint('Font upload completed successfully');
    debugPrint('Final status: Font upload completed with ${statusNotificationsEnabled ? "status notifications" : "basic protocol"}');
  }

  /// Send individual chunk using exact protocol format
  Future<void> _sendChunk(BluetoothDevice device, Uint8List chunkData, int sequence) async {
    // Get power management characteristic (0xFFF1) using BLE service
    await device.connect(autoConnect: false);
    final characteristic = await _locatePowerManagementCharacteristic(device);

    // Check characteristic properties to determine write mode
    final supportsWriteWithoutResponse = characteristic.properties.writeWithoutResponse;
    final writeMode = supportsWriteWithoutResponse ? 'writeWithoutResponse' : 'writeWithResponse';

    debugPrint('Characteristic properties: ${characteristic.properties}, write mode: $writeMode');

    // Build chunk frame: [0x05][length(2B)][sequence(2B)][payload...]
    final frame = BytesBuilder()
      ..add([0x05]) // Font upload command identifier
      ..add(_u16(chunkData.length)) // Payload length (2 bytes)
      ..add(_u16(sequence)) // Sequence number (2 bytes)
      ..add(chunkData); // Font data chunk

    // Use appropriate write mode based on characteristic properties
    if (supportsWriteWithoutResponse) {
      await characteristic.write(frame.toBytes(), withoutResponse: true);
    } else {
      await characteristic.write(frame.toBytes(), withoutResponse: false);
    }

    debugPrint('Sent chunk $sequence: ${chunkData.length} bytes (mode: $writeMode)');

    // Small delay between chunks to allow device processing
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  /// Send completion packet with zero-length payload
  Future<void> _sendCompletionPacket(BluetoothDevice device, int totalChunks) async {
    debugPrint('Preparing to send completion packet (total chunks: $totalChunks)');

    // Small delay before sending completion packet to ensure last chunk is processed
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final characteristic = await _locatePowerManagementCharacteristic(device);

    // Check characteristic properties to determine write mode
    final supportsWriteWithoutResponse = characteristic.properties.writeWithoutResponse;
    final writeMode = supportsWriteWithoutResponse ? 'writeWithoutResponse' : 'writeWithResponse';

    debugPrint('Completion packet characteristic properties: ${characteristic.properties}, write mode: $writeMode');
    debugPrint('Total chunks sent: $totalChunks');

    // After sending chunks 0, 1, 2, ..., totalChunks-1, the next expected sequence is totalChunks
    // Device validation: if (payload_len == 0 && seq != s_font_ctx.next_seq) return ESP_ERR_INVALID_STATE;
    // Since s_font_ctx.next_seq should equal totalChunks after all chunks, we use totalChunks as sequence
    final completionFrame = BytesBuilder()
      ..add([0x05]) // Font upload command identifier
      ..add(_u16(0)) // Zero length payload
      ..add(_u16(totalChunks)); // Device expects totalChunks (s_font_ctx.next_seq)

    try {
      // Use appropriate write mode based on characteristic properties
      if (supportsWriteWithoutResponse) {
        await characteristic.write(completionFrame.toBytes(), withoutResponse: true);
      } else {
        await characteristic.write(completionFrame.toBytes(), withoutResponse: false);
      }
      debugPrint('Sent completion packet with sequence $totalChunks (mode: $writeMode)');
    } catch (e) {
      debugPrint('Error sending completion packet: $e');
      // Re-throw with more specific error information
      throw FontUploadException('Failed to send completion packet: $e', errorType: FontUploadError.fontApplicationFailed);
    }
  }

  /// Locate power management characteristic for font upload
  Future<BluetoothCharacteristic> _locatePowerManagementCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    BluetoothService? service;
    for (final candidate in services) {
      if (candidate.uuid == SwitchHubBleService.serviceUuidPublic ||
          candidate.uuid == SwitchHubBleService.serviceUuidReversedPublic) {
        service = candidate;
        break;
      }
    }

    if (service != null) {
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == SwitchHubBleService.powerManagementCharacteristicUuidPublic) {
          return characteristic;
        }
      }
    }

    // Fallback: search every discovered service for the power management characteristic.
    for (final candidate in services) {
      for (final characteristic in candidate.characteristics) {
        if (characteristic.uuid == SwitchHubBleService.powerManagementCharacteristicUuidPublic) {
          return characteristic;
        }
      }
    }

    throw Exception('SWITCHHUB_POWER_MANAGEMENT_CHAR_NOT_FOUND');
  }

  /// Setup status notifications from 0xFFF2 characteristic
  Future<bool> _setupStatusNotifications() async {
    try {
      // Check if device is connected
      if (!_ble.isConnected) {
        debugPrint('Device not connected, skipping status notifications');
        return false;
      }

      // Try to enable font status notifications (0xFFF2 characteristic)
      final statusStream = await _ble.enableFontStatusNotifications();

      _statusNotificationSubscription = statusStream.listen((data) {
        if (_protocol != null) {
          _protocol!.handleStatusNotification(Uint8List.fromList(data));
        }
      });

      debugPrint('Font status notifications enabled');
      return true;
    } catch (e) {
      debugPrint('Font status notifications not available: $e');
      debugPrint('Continuing without status notifications (fallback to basic upload)');
      // Don't throw exception, just log and continue without status notifications
      return false;
    }
  }

  /// Handle upload errors and determine recovery strategy
  error_handler.FontUploadErrorResult _handleUploadError(dynamic error, int attempt) {
    if (error is FontUploadException) {
      // Protocol error
      return error_handler.FontUploadErrorResult(
        shouldRetry: true,
        delay: Duration(milliseconds: 1000 * (attempt + 1)),
        error: error_handler.FontUploadError.unknownProtocolError,
        message: error.message,
        recoverable: true,
        restartFromBeginning: true,
      );
    } else if (error is Exception) {
      // BLE error
      return _errorHandler.handleAttError(error, attempt);
    } else {
      // Unknown error
      return error_handler.FontUploadErrorResult(
        shouldRetry: attempt < 2, // Retry unknown errors once
        delay: const Duration(seconds: 2),
        error: error_handler.FontUploadError.unknownProtocolError,
        message: error.toString(),
        recoverable: true,
        restartFromBeginning: true,
      );
    }
  }

  /// Get optimized chunk size based on attempt number and error history
  int _getOptimizedChunkSize(int totalSize, int attempt, bool hadError) {
    if (!hadError) {
      return defaultChunkSize;
    }

    // Reduce chunk size on errors
    int newChunkSize = defaultChunkSize;

    switch (attempt) {
      case 1:
        newChunkSize = 2048; // Half size
        break;
      case 2:
        newChunkSize = 1024; // Quarter size
        break;
      case 3:
        newChunkSize = 512; // Minimum size
        break;
      default:
        newChunkSize = minChunkSize;
    }

    // Ensure chunk size is reasonable for total size
    final maxChunks = totalSize ~/ newChunkSize + 1;
    if (maxChunks > 1000) {
      newChunkSize = (totalSize / 1000).ceil().clamp(minChunkSize, defaultChunkSize);
    }

    return newChunkSize;
  }

  /// Validate font data and chunk size
  void _validateFontData(Uint8List fontData, int chunkSize) {
    if (fontData.isEmpty) {
      throw ArgumentError('Font data cannot be empty');
    }

    if (fontData.length > maxFontSizeBytes) {
      throw ArgumentError('Font size exceeds maximum allowed size of $maxFontSizeBytes bytes');
    }

    if (chunkSize < minChunkSize || chunkSize > maxChunkSize) {
      throw ArgumentError('Chunk size must be between $minChunkSize and $maxChunkSize bytes');
    }

    // Check if chunk size would generate too many chunks
    final totalChunks = (fontData.length / chunkSize).ceil();
    if (totalChunks > 0xFFFF) {
      throw ArgumentError('Font data would generate too many chunks (max: 65535)');
    }
  }

  /// Cancel current upload
  Future<void> cancelUpload() async {
    if (_protocol != null) {
      _protocol!.cancelUpload();
    }
    await _cleanup();
    _isUploading = false;
    debugPrint('Font upload cancelled');
  }

  /// Cleanup resources
  Future<void> _cleanup() async {
    await _statusNotificationSubscription?.cancel();
    _statusNotificationSubscription = null;

    _timeoutManager.stopTimeoutManagement();
    _protocol?.dispose();
    _protocol = null;

    try {
      await _ble.disableFontStatusNotifications();
    } catch (e) {
      debugPrint('Error disabling font status notifications: $e');
    }
  }

  /// Dispose service
  Future<void> dispose() async {
    await cancelUpload();
    _timeoutManager.dispose();
    debugPrint('EnhancedFontUploadService disposed');
  }

  /// Convert integer to 16-bit little endian bytes
  List<int> _u16(int value) {
    final bytes = ByteData(2);
    bytes.setUint16(0, value & 0xFFFF, Endian.little);
    return bytes.buffer.asUint8List();
  }
}

/// Font upload exception
class FontUploadException implements Exception {
  final String message;
  final FontUploadError errorType;

  const FontUploadException(this.message, {required this.errorType});

  @override
  String toString() => 'FontUploadException: $message';
}