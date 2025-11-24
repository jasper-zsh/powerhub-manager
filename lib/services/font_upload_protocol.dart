import 'dart:async';

import 'package:flutter/foundation.dart';

/// Font upload protocol error types
enum FontUploadError {
  timeout,
  sequenceError,
  memoryError,
  fontApplicationFailed,
  disconnection,
  invalidResponse,
  characteristicNotFound,
  sizeExceeded,
}

/// Font upload protocol state
enum FontUploadState {
  idle,
  initializing,
  uploading,
  completing,
  success,
  error,
  cancelled,
}

/// Font status notification types
enum FontStatusType {
  progress(0xFE),
  uploadStarted(0xFF02),
  success(0xFF00),
  error(0xFF),
  memoryWarning(0xFD);

  const FontStatusType(this.value);
  final int value;
}

/// Font upload progress information
class FontUploadProgress {
  final int currentSequence;
  final int totalSequences;
  final int percentage;
  final DateTime timestamp;

  const FontUploadProgress({
    required this.currentSequence,
    required this.totalSequences,
    required this.percentage,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'FontUploadProgress(sequence: $currentSequence/$totalSequences, percentage: $percentage%)';
  }
}

/// Font upload error details
class FontUploadErrorDetails {
  final FontUploadError type;
  final String message;
  final int? errorCode;
  final int? parameter;
  final DateTime timestamp;

  const FontUploadErrorDetails({
    required this.type,
    required this.message,
    this.errorCode,
    this.parameter,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'FontUploadError(type: $type, message: $message, code: $errorCode, param: $parameter)';
  }
}

/// Memory usage warning
class MemoryWarning {
  final int bytesUsed;
  final double percentageUsed;
  final DateTime timestamp;

  const MemoryWarning({
    required this.bytesUsed,
    required this.percentageUsed,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'MemoryWarning(bytes: $bytesUsed, percentage: ${percentageUsed.toStringAsFixed(1)}%)';
  }
}

/// Font upload protocol state machine and message handling
class FontUploadProtocol {
  static const int maxFontSizeBytes = 1024 * 1024; // 1MB
  static const int maxChunkSize = 65535; // uint16_t limit
  static const int memoryWarningThreshold = 819 * 1024; // 80% of 1MB
  static const Duration chunkTimeout = Duration(seconds: 30);
  static const Duration minProgressInterval = Duration(seconds: 1);

  FontUploadState _state = FontUploadState.idle;
  int _currentSequence = 0;
  int _totalSequences = 0;
  Timer? _timeoutTimer;
  Timer? _progressRateLimitTimer;
  DateTime? _lastProgressReport;

  // Callbacks
  final void Function(FontUploadProgress)? onProgress;
  final void Function(FontUploadErrorDetails)? onError;
  final void Function()? onSuccess;
  final void Function(MemoryWarning)? onMemoryWarning;

  FontUploadProtocol({
    this.onProgress,
    this.onError,
    this.onSuccess,
    this.onMemoryWarning,
  });

  FontUploadState get state => _state;
  int get currentSequence => _currentSequence;
  int get totalSequences => _totalSequences;

  /// Initialize font upload session
  void initializeUpload(int totalBytes, {int chunkSize = 4096}) {
    if (totalBytes > maxFontSizeBytes) {
      throw ArgumentError('Font size exceeds maximum allowed size of $maxFontSizeBytes bytes');
    }

    if (chunkSize > maxChunkSize) {
      throw ArgumentError('Chunk size exceeds maximum allowed size of $maxChunkSize bytes');
    }

    _state = FontUploadState.initializing;
    _currentSequence = 0;
    _totalSequences = (totalBytes / chunkSize).ceil();

    debugPrint('Font upload initialized: $totalBytes bytes, $_totalSequences chunks of $chunkSize bytes');
  }

  /// Start font upload process
  void startUpload() {
    if (_state != FontUploadState.initializing) {
      throw StateError('Upload must be initialized before starting');
    }

    _state = FontUploadState.uploading;
    _resetTimeoutTimer();
    debugPrint('Font upload started');
  }

  /// Process chunk transmission
  void processChunkSent(int sequenceNumber) {
    if (_state != FontUploadState.uploading) {
      return;
    }

    _currentSequence = sequenceNumber;
    _resetTimeoutTimer();
    debugPrint('Font chunk sent: sequence $sequenceNumber');
  }

  /// Handle font status notification from device
  void handleStatusNotification(Uint8List data) {
    if (data.isEmpty) return;

    try {
      final prefix = data[0];

      switch (prefix) {
        case 0xFE: // Progress notification
          _handleProgressNotification(data);
          break;
        case 0xFF: // Error or status notification
          _handleErrorNotification(data);
          break;
        case 0xFD: // Memory warning
          _handleMemoryWarning(data);
          break;
        default:
          debugPrint('Unknown font status notification prefix: 0x${prefix.toRadixString(16)}');
      }
    } catch (e) {
      debugPrint('Error parsing font status notification: $e');
      _handleError(FontUploadError.invalidResponse, 'Failed to parse status notification');
    }
  }

  /// Complete font upload with zero-length packet
  void completeUpload() {
    if (_state != FontUploadState.uploading) {
      throw StateError('Upload not in progress');
    }

    _state = FontUploadState.completing;
    _resetTimeoutTimer();
    debugPrint('Font upload completion sent');
  }

  /// Handle successful upload confirmation
  void handleSuccessConfirmation() {
    _cleanup();
    _state = FontUploadState.success;
    debugPrint('Font upload completed successfully');
    onSuccess?.call();
  }

  /// Cancel upload and cleanup
  void cancelUpload() {
    _cleanup();
    _state = FontUploadState.cancelled;
    debugPrint('Font upload cancelled');
  }

  void _handleProgressNotification(Uint8List data) {
    if (data.length < 4) return;

    final sequenceHigh = data[1];
    final sequenceLow = data[2];
    final percentage = data[3];

    final sequence = (sequenceHigh << 8) | sequenceLow;

    // Rate limit progress reports
    final now = DateTime.now();
    if (_lastProgressReport != null &&
        now.difference(_lastProgressReport!) < minProgressInterval) {
      return;
    }

    _lastProgressReport = now;

    final progress = FontUploadProgress(
      currentSequence: sequence,
      totalSequences: _totalSequences,
      percentage: percentage,
      timestamp: now,
    );

    debugPrint('Font upload progress: $progress');
    onProgress?.call(progress);
  }

  void _handleErrorNotification(Uint8List data) {
    if (data.length < 4) return;

    final errorCode = data[1];
    final paramHigh = data[2];
    final paramLow = data[3];
    final parameter = (paramHigh << 8) | paramLow;

    FontUploadError errorType;
    String message;

    switch (errorCode) {
      case 0x01: // Timeout
        errorType = FontUploadError.timeout;
        message = 'Upload timeout: 30 seconds elapsed';
        break;
      case 0x03: // Font application failed
        errorType = FontUploadError.fontApplicationFailed;
        message = 'Font application failed on device';
        break;
      case 0x04: // Sequence error
        errorType = FontUploadError.sequenceError;
        message = 'Sequence error: expected $_currentSequence, got $parameter';
        break;
      case 0x05: // Disconnection during upload
        errorType = FontUploadError.disconnection;
        message = 'Device disconnected during upload';
        break;
      case 0x00: // Success notification
        handleSuccessConfirmation();
        return;
      case 0x02: // Upload started notification
        debugPrint('Device confirmed upload started');
        return;
      default:
        errorType = FontUploadError.invalidResponse;
        message = 'Unknown error code: 0x${errorCode.toRadixString(16)}';
    }

    _handleError(errorType, message, errorCode: errorCode, parameter: parameter);
  }

  void _handleMemoryWarning(Uint8List data) {
    if (data.length < 4) return;

    final usageHigh = data[1];
    final usageMid = data[2];
    final usageLow = data[3];

    final bytesUsed = (usageHigh << 16) | (usageMid << 8) | usageLow;
    final percentageUsed = (bytesUsed / maxFontSizeBytes) * 100;

    final warning = MemoryWarning(
      bytesUsed: bytesUsed,
      percentageUsed: percentageUsed,
      timestamp: DateTime.now(),
    );

    debugPrint('Memory warning: $warning');
    onMemoryWarning?.call(warning);
  }

  void _handleError(FontUploadError type, String message, {int? errorCode, int? parameter}) {
    _cleanup();
    _state = FontUploadState.error;

    final errorDetails = FontUploadErrorDetails(
      type: type,
      message: message,
      errorCode: errorCode,
      parameter: parameter,
      timestamp: DateTime.now(),
    );

    debugPrint('Font upload error: $errorDetails');
    onError?.call(errorDetails);
  }

  void _resetTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(chunkTimeout, () {
      if (_state == FontUploadState.uploading || _state == FontUploadState.completing) {
        _handleError(FontUploadError.timeout, 'Chunk timeout exceeded');
      }
    });
  }

  void _cleanup() {
    _timeoutTimer?.cancel();
    _progressRateLimitTimer?.cancel();
    _timeoutTimer = null;
    _progressRateLimitTimer = null;
  }

  /// Dispose resources
  void dispose() {
    _cleanup();
    debugPrint('FontUploadProtocol disposed');
  }
}