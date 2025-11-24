import 'dart:typed_data';

/// Font upload notification parser utilities
class FontNotificationParser {
  // Message prefixes
  static const int progressPrefix = 0xFE;
  static const int statusPrefix = 0xFF;
  static const int memoryWarningPrefix = 0xFD;

  // Status message types
  static const int uploadStartedCode = 0x02;
  static const int successCode = 0x00;

  // Error codes
  static const int timeoutErrorCode = 0x01;
  static const int fontApplicationFailedCode = 0x03;
  static const int sequenceErrorCode = 0x04;
  static const int disconnectionErrorCode = 0x05;

  /// Parse font status notification and return parsed data
  static FontNotification? parseNotification(Uint8List data) {
    if (data.isEmpty) return null;

    final prefix = data[0];

    switch (prefix) {
      case progressPrefix:
        return _parseProgressNotification(data);
      case statusPrefix:
        return _parseStatusNotification(data);
      case memoryWarningPrefix:
        return _parseMemoryWarningNotification(data);
      default:
        return null;
    }
  }

  /// Parse progress notification [0xFE][seq_hi][seq_lo][percentage]
  static ProgressNotification? parseProgressNotification(Uint8List data) {
    if (data.length != 4 || data[0] != progressPrefix) {
      return null;
    }

    final sequence = (data[1] << 8) | data[2]; // big-endian sequence
    final percentage = data[3];

    return ProgressNotification(
      sequence: sequence,
      percentage: percentage,
      timestamp: DateTime.now(),
    );
  }

  /// Parse status notification [0xFF][code][param_hi][param_lo]
  static StatusNotification? parseStatusNotification(Uint8List data) {
    if (data.length != 4 || data[0] != statusPrefix) {
      return null;
    }

    final code = data[1];
    final parameter = (data[2] << 8) | data[3]; // big-endian parameter

    return StatusNotification(
      code: code,
      parameter: parameter,
      timestamp: DateTime.now(),
    );
  }

  /// Parse memory warning notification [0xFD][usage_hi][usage_mid][usage_lo]
  static MemoryWarningNotification? parseMemoryWarningNotification(Uint8List data) {
    if (data.length != 4 || data[0] != memoryWarningPrefix) {
      return null;
    }

    final bytesUsed = (data[1] << 16) | (data[2] << 8) | data[3]; // big-endian

    return MemoryWarningNotification(
      bytesUsed: bytesUsed,
      timestamp: DateTime.now(),
    );
  }

  /// Check if notification is an error
  static bool isErrorNotification(StatusNotification notification) {
    return notification.code != uploadStartedCode &&
           notification.code != successCode;
  }

  /// Get error type from status notification
  static FontUploadErrorType? getErrorType(StatusNotification notification) {
    switch (notification.code) {
      case timeoutErrorCode:
        return FontUploadErrorType.timeout;
      case fontApplicationFailedCode:
        return FontUploadErrorType.fontApplicationFailed;
      case sequenceErrorCode:
        return FontUploadErrorType.sequenceError;
      case disconnectionErrorCode:
        return FontUploadErrorType.disconnection;
      default:
        return null;
    }
  }

  /// Generate human-readable error message
  static String getErrorMessage(StatusNotification notification) {
    final errorType = getErrorType(notification);
    if (errorType == null) {
      return 'Unknown error code: 0x${notification.code.toRadixString(16)}';
    }

    switch (errorType) {
      case FontUploadErrorType.timeout:
        return 'Upload timeout: 30 seconds elapsed';
      case FontUploadErrorType.fontApplicationFailed:
        return 'Font application failed on device (ESP error: 0x${notification.parameter.toRadixString(16)})';
      case FontUploadErrorType.sequenceError:
        return 'Sequence error: wrong sequence number (expected unknown, got ${notification.parameter})';
      case FontUploadErrorType.disconnection:
        return 'Device disconnected during upload';
    }
  }

  static ProgressNotification _parseProgressNotification(Uint8List data) {
    return ProgressNotification(
      sequence: (data[1] << 8) | data[2],
      percentage: data[3],
      timestamp: DateTime.now(),
    );
  }

  static StatusNotification _parseStatusNotification(Uint8List data) {
    return StatusNotification(
      code: data[1],
      parameter: (data[2] << 8) | data[3],
      timestamp: DateTime.now(),
    );
  }

  static MemoryWarningNotification _parseMemoryWarningNotification(Uint8List data) {
    final bytesUsed = (data[1] << 16) | (data[2] << 8) | data[3];
    return MemoryWarningNotification(
      bytesUsed: bytesUsed,
      timestamp: DateTime.now(),
    );
  }
}

/// Base class for font notifications
abstract class FontNotification {
  final DateTime timestamp;

  const FontNotification({required this.timestamp});
}

/// Progress notification [0xFE][seq_hi][seq_lo][percentage]
class ProgressNotification extends FontNotification {
  final int sequence;
  final int percentage;

  const ProgressNotification({
    required this.sequence,
    required this.percentage,
    required super.timestamp,
  });

  @override
  String toString() {
    return 'ProgressNotification(sequence: $sequence, percentage: $percentage%)';
  }
}

/// Status notification [0xFF][code][param_hi][param_lo]
class StatusNotification extends FontNotification {
  final int code;
  final int parameter;

  const StatusNotification({
    required this.code,
    required this.parameter,
    required super.timestamp,
  });

  bool get isUploadStarted => code == 0x02;
  bool get isSuccess => code == 0x00;
  bool get isError => !isUploadStarted && !isSuccess;

  @override
  String toString() {
    final type = isError ? 'Error' : (isSuccess ? 'Success' : 'UploadStarted');
    return 'StatusNotification(type: $type, code: 0x${code.toRadixString(16)}, param: $parameter)';
  }
}

/// Memory warning notification [0xFD][usage_hi][usage_mid][usage_lo]
class MemoryWarningNotification extends FontNotification {
  final int bytesUsed;

  const MemoryWarningNotification({
    required this.bytesUsed,
    required super.timestamp,
  });

  double get percentageUsed => (bytesUsed / (1024 * 1024)) * 100;
  bool get isCritical => percentageUsed > 80;

  @override
  String toString() {
    return 'MemoryWarningNotification(bytesUsed: $bytesUsed, percentage: ${percentageUsed.toStringAsFixed(1)}%)';
  }
}

/// Font upload error types
enum FontUploadErrorType {
  timeout,
  fontApplicationFailed,
  sequenceError,
  disconnection,
}