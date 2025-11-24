import 'package:flutter/foundation.dart';
import 'package:app/services/font_notification_parser.dart';

/// ATT Error codes for BLE operations
class BleAttErrors {
  static const int insufficientResources = 0x11;
  static const int invalidAttributeValueLength = 0x0D;
  static const int unlikely = 0x0E;
  static const int requestNotSupported = 0x06;
  static const int invalidState = 0x0A;
  static const int insufficientAuthentication = 0x05;
  static const int insufficientAuthorization = 0x08;
  static const int insufficientEncryptionKeySize = 0x0C;
  static const int invalidOffset = 0x07;
  static const int attributeNotFound = 0x0A;

  static String getErrorMessage(int errorCode) {
    switch (errorCode) {
      case insufficientResources:
        return 'Insufficient resources - device memory allocation failed';
      case invalidAttributeValueLength:
        return 'Invalid attribute value length - chunk size mismatch';
      case unlikely:
        return 'Unlikely error - font validation or application failed';
      case requestNotSupported:
        return 'Request not supported - malformed font data';
      case invalidState:
        return 'Invalid state - invalid sequence or upload state';
      case insufficientAuthentication:
        return 'Insufficient authentication - pairing required';
      case insufficientAuthorization:
        return 'Insufficient authorization - operation not permitted';
      case insufficientEncryptionKeySize:
        return 'Insufficient encryption key size - security requirements not met';
      case invalidOffset:
        return 'Invalid offset - data positioning error';
      case attributeNotFound:
        return 'Attribute not found - characteristic missing';
      default:
        return 'Unknown ATT error: 0x${errorCode.toRadixString(16)}';
    }
  }

  static bool isRecoverable(int errorCode) {
    switch (errorCode) {
      case insufficientResources:
      case invalidAttributeValueLength:
      case unlikely:
      case requestNotSupported:
      case invalidState:
        return true; // Can be recovered by restarting upload
      case insufficientAuthentication:
      case insufficientAuthorization:
      case insufficientEncryptionKeySize:
        return false; // Requires user action (pairing, etc.)
      default:
        return true;
    }
  }
}

/// Font upload retry configuration
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 16),
  });

  Duration getDelay(int attempt) {
    final delay = initialDelay * (backoffMultiplier * attempt);
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Font upload error handler with recovery strategies
class FontUploadErrorHandler {
  final RetryConfig retryConfig;

  FontUploadErrorHandler({
    this.retryConfig = const RetryConfig(),
  });

  /// Handle BLE ATT errors during write operations
  FontUploadErrorResult handleAttError(Exception exception, int attempt) {
    debugPrint('Handling ATT error (attempt $attempt): $exception');

    // Extract error code from exception if available
    final errorCode = _extractErrorCode(exception);
    final isRecoverable = BleAttErrors.isRecoverable(errorCode);

    if (attempt >= retryConfig.maxRetries) {
      return FontUploadErrorResult(
        shouldRetry: false,
        delay: Duration.zero,
        error: FontUploadError.attError,
        message: BleAttErrors.getErrorMessage(errorCode),
        recoverable: isRecoverable,
      );
    }

    if (!isRecoverable) {
      return FontUploadErrorResult(
        shouldRetry: false,
        delay: Duration.zero,
        error: FontUploadError.attError,
        message: BleAttErrors.getErrorMessage(errorCode),
        recoverable: false,
      );
    }

    final delay = retryConfig.getDelay(attempt);
    return FontUploadErrorResult(
      shouldRetry: true,
      delay: delay,
      error: FontUploadError.attError,
      message: '${BleAttErrors.getErrorMessage(errorCode)} - retrying in ${delay.inSeconds}s',
      recoverable: true,
    );
  }

  /// Handle device disconnection
  FontUploadErrorResult handleDisconnection(int attempt) {
    debugPrint('Handling device disconnection (attempt $attempt)');

    if (attempt >= retryConfig.maxRetries) {
      return FontUploadErrorResult(
        shouldRetry: false,
        delay: Duration.zero,
        error: FontUploadError.disconnection,
        message: 'Max retries reached for device disconnection',
        recoverable: false,
      );
    }

    final delay = retryConfig.getDelay(attempt);
    return FontUploadErrorResult(
      shouldRetry: true,
      delay: delay,
      error: FontUploadError.disconnection,
      message: 'Device disconnected - retrying in ${delay.inSeconds}s',
      recoverable: true,
    );
  }

  /// Handle font upload protocol errors from notifications
  FontUploadErrorResult handleProtocolError(StatusNotification notification, int attempt) {
    debugPrint('Handling protocol error (attempt $attempt): $notification');

    final errorType = FontNotificationParser.getErrorType(notification);
    if (errorType == null) {
      return FontUploadErrorResult(
        shouldRetry: false,
        delay: Duration.zero,
        error: FontUploadError.unknownProtocolError,
        message: 'Unknown protocol error: code 0x${notification.code.toRadixString(16)}',
        recoverable: false,
      );
    }

    switch (errorType) {
      case FontUploadErrorType.timeout:
        return _handleTimeoutError(attempt);
      case FontUploadErrorType.fontApplicationFailed:
        return _handleFontApplicationError(notification, attempt);
      case FontUploadErrorType.sequenceError:
        return _handleSequenceError(notification, attempt);
      case FontUploadErrorType.disconnection:
        return handleDisconnection(attempt);
    }
  }

  /// Handle timeout errors
  FontUploadErrorResult _handleTimeoutError(int attempt) {
    if (attempt >= retryConfig.maxRetries) {
      return FontUploadErrorResult(
        shouldRetry: false,
        delay: Duration.zero,
        error: FontUploadError.timeout,
        message: 'Upload timeout - max retries reached',
        recoverable: false,
      );
    }

    final delay = retryConfig.getDelay(attempt);
    return FontUploadErrorResult(
      shouldRetry: true,
      delay: delay,
      error: FontUploadError.timeout,
      message: 'Upload timeout - retrying with larger chunks in ${delay.inSeconds}s',
      recoverable: true,
    );
  }

  /// Handle font application failures
  FontUploadErrorResult _handleFontApplicationError(StatusNotification notification, int attempt) {
    final espErrorCode = notification.parameter;
    debugPrint('Font application failed with ESP error: 0x${espErrorCode.toRadixString(16)}');

    // Font application errors usually indicate data corruption
    if (attempt >= retryConfig.maxRetries) {
      return FontUploadErrorResult(
        shouldRetry: false,
        delay: Duration.zero,
        error: FontUploadError.fontApplicationFailed,
        message: 'Font application failed (ESP error: 0x${espErrorCode.toRadixString(16)}) - max retries reached',
        recoverable: false,
      );
    }

    final delay = retryConfig.getDelay(attempt);
    return FontUploadErrorResult(
      shouldRetry: true,
      delay: delay,
      error: FontUploadError.fontApplicationFailed,
      message: 'Font application failed - retrying with smaller chunks in ${delay.inSeconds}s',
      recoverable: true,
    );
  }

  /// Handle sequence errors
  FontUploadErrorResult _handleSequenceError(StatusNotification notification, int attempt) {
    final wrongSequence = notification.parameter;
    debugPrint('Sequence error: wrong sequence number $wrongSequence');

    // Sequence errors always require restart from beginning
    return FontUploadErrorResult(
      shouldRetry: true,
      delay: Duration.zero, // Immediate retry
      error: FontUploadError.sequenceError,
      message: 'Sequence error - restarting upload from beginning',
      recoverable: true,
      restartFromBeginning: true,
    );
  }

  /// Extract error code from BLE exception
  int _extractErrorCode(Exception exception) {
    // Try to extract error code from exception message
    final message = exception.toString().toLowerCase();

    // Look for hex error codes in the message
    final hexCodeRegex = RegExp(r'0x([0-9a-f]{2})', caseSensitive: false);
    final match = hexCodeRegex.firstMatch(message);

    if (match != null) {
      return int.parse(match.group(1)!, radix: 16);
    }

    // Look for decimal error codes
    final decCodeRegex = RegExp(r'error[:\s]+(\d+)', caseSensitive: false);
    final decMatch = decCodeRegex.firstMatch(message);

    if (decMatch != null) {
      return int.parse(decMatch.group(1)!);
    }

    // Try to match known error messages
    if (message.contains('insufficient') || message.contains('resource')) {
      return BleAttErrors.insufficientResources;
    }
    if (message.contains('length') || message.contains('size')) {
      return BleAttErrors.invalidAttributeValueLength;
    }
    if (message.contains('unlikely')) {
      return BleAttErrors.unlikely;
    }
    if (message.contains('support')) {
      return BleAttErrors.requestNotSupported;
    }
    if (message.contains('state')) {
      return BleAttErrors.invalidState;
    }

    return -1; // Unknown error code
  }
}

/// Font upload error types
enum FontUploadError {
  attError,
  timeout,
  disconnection,
  fontApplicationFailed,
  sequenceError,
  sizeExceeded,
  characteristicNotFound,
  unknownProtocolError,
}

/// Error handling result
class FontUploadErrorResult {
  final bool shouldRetry;
  final Duration delay;
  final FontUploadError error;
  final String message;
  final bool recoverable;
  final bool restartFromBeginning;

  const FontUploadErrorResult({
    required this.shouldRetry,
    required this.delay,
    required this.error,
    required this.message,
    required this.recoverable,
    this.restartFromBeginning = false,
  });

  @override
  String toString() {
    return 'FontUploadErrorResult(shouldRetry: $shouldRetry, delay: ${delay.inSeconds}s, error: $error, recoverable: $recoverable, restart: $restartFromBeginning)';
  }
}