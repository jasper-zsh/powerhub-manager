import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_upload_error_handler.dart';
import 'package:app/services/font_notification_parser.dart';

void main() {
  group('FontUploadErrorHandler', () {
    late FontUploadErrorHandler errorHandler;

    setUp(() {
      errorHandler = FontUploadErrorHandler();
    });

    group('ATT Error Handling', () {
      test('should handle insufficient resources error', () {
        final exception = Exception('ATT error: insufficient resources');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.attError);
        expect(result.message, contains('Insufficient resources'));
        expect(result.recoverable, true);
      });

      test('should handle invalid attribute value length error', () {
        final exception = Exception('ATT error: invalid attribute value length');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.attError);
        expect(result.message, contains('chunk size mismatch'));
        expect(result.recoverable, true);
      });

      test('should handle unlikely error', () {
        final exception = Exception('ATT error: unlikely');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.attError);
        expect(result.message, contains('validation or application failed'));
        expect(result.recoverable, true);
      });

      test('should handle request not supported error', () {
        final exception = Exception('ATT error: request not supported');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.attError);
        expect(result.message, contains('malformed font data'));
        expect(result.recoverable, true);
      });

      test('should handle invalid state error', () {
        final exception = Exception('ATT error: invalid state');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.attError);
        expect(result.message, contains('invalid sequence or upload state'));
        expect(result.recoverable, true);
      });

      test('should handle non-recoverable authentication errors', () {
        final exception = Exception('ATT error: insufficient authentication');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, false);
        expect(result.recoverable, false);
      });

      test('should stop retrying after max attempts', () {
        final exception = Exception('ATT error: insufficient resources');
        final result = errorHandler.handleAttError(exception, 5); // Exceeds default max of 3

        expect(result.shouldRetry, false);
        expect(result.message, contains('Max retries reached'));
      });

      test('should extract error code from hex format', () {
        final exception = Exception('ATT error: 0x11 insufficient resources');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.message, contains('Insufficient resources'));
      });

      test('should extract error code from decimal format', () {
        final exception = Exception('ATT error: 17 insufficient resources');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.message, contains('Insufficient resources'));
      });

      test('should handle unknown error codes', () {
        final exception = Exception('ATT error: 0x99 unknown error');
        final result = errorHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.recoverable, true);
        expect(result.message, contains('Unknown ATT error'));
      });
    });

    group('Disconnection Handling', () {
      test('should handle disconnection with retry', () {
        final result = errorHandler.handleDisconnection(0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.disconnection);
        expect(result.message, contains('Device disconnected'));
        expect(result.recoverable, true);
      });

      test('should stop retrying disconnection after max attempts', () {
        final result = errorHandler.handleDisconnection(5);

        expect(result.shouldRetry, false);
        expect(result.message, contains('Max retries reached'));
      });
    });

    group('Protocol Error Handling', () {
      test('should handle timeout error with retry', () {
        final notification = StatusNotification(
          code: 0x01, // timeout
          parameter: 0,
          timestamp: DateTime.now(),
        );

        final result = errorHandler.handleProtocolError(notification, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.timeout);
        expect(result.message, contains('Upload timeout'));
        expect(result.recoverable, true);
      });

      test('should handle timeout error without retry after max attempts', () {
        final notification = StatusNotification(
          code: 0x01, // timeout
          parameter: 0,
          timestamp: DateTime.now(),
        );

        final result = errorHandler.handleProtocolError(notification, 5);

        expect(result.shouldRetry, false);
        expect(result.message, contains('max retries reached'));
      });

      test('should handle font application error with retry', () {
        final notification = StatusNotification(
          code: 0x03, // font application failed
          parameter: 0x1234, // ESP error code
          timestamp: DateTime.now(),
        );

        final result = errorHandler.handleProtocolError(notification, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.fontApplicationFailed);
        expect(result.message, contains('ESP error: 0x1234'));
        expect(result.recoverable, true);
      });

      test('should handle sequence error with immediate retry', () {
        final notification = StatusNotification(
          code: 0x04, // sequence error
          parameter: 5, // wrong sequence number
          timestamp: DateTime.now(),
        );

        final result = errorHandler.handleProtocolError(notification, 0);

        expect(result.shouldRetry, true);
        expect(result.delay.inMilliseconds, equals(0)); // Immediate retry
        expect(result.restartFromBeginning, true);
        expect(result.message, contains('restarting upload from beginning'));
      });

      test('should handle disconnection error with retry', () {
        final notification = StatusNotification(
          code: 0x05, // disconnection
          parameter: 0,
          timestamp: DateTime.now(),
        );

        final result = errorHandler.handleProtocolError(notification, 0);

        expect(result.shouldRetry, true);
        expect(result.error, FontUploadError.disconnection);
        expect(result.message, contains('Device disconnected'));
      });

      test('should handle unknown protocol error without retry', () {
        final notification = StatusNotification(
          code: 0x99, // unknown
          parameter: 0,
          timestamp: DateTime.now(),
        );

        final result = errorHandler.handleProtocolError(notification, 0);

        expect(result.shouldRetry, false);
        expect(result.error, FontUploadError.unknownProtocolError);
        expect(result.message, contains('Unknown protocol error'));
      });
    });

    group('Retry Configuration', () {
      test('should use custom retry configuration', () {
        final customConfig = RetryConfig(
          maxRetries: 5,
          initialDelay: Duration(seconds: 2),
          backoffMultiplier: 1.5,
          maxDelay: Duration(seconds: 20),
        );

        final customHandler = FontUploadErrorHandler(retryConfig: customConfig);
        final exception = Exception('ATT error: insufficient resources');
        final result = customHandler.handleAttError(exception, 0);

        expect(result.shouldRetry, true);
        expect(result.delay.inSeconds, equals(2)); // Initial delay
      });

      test('should calculate exponential backoff correctly', () {
        final result1 = errorHandler.handleAttError(
          Exception('ATT error: insufficient resources'),
          0,
        );
        final result2 = errorHandler.handleAttError(
          Exception('ATT error: insufficient resources'),
          1,
        );
        final result3 = errorHandler.handleAttError(
          Exception('ATT error: insufficient resources'),
          2,
        );

        expect(result1.delay.inSeconds, equals(1));
        expect(result2.delay.inSeconds, equals(2));
        expect(result3.delay.inSeconds, equals(4));
      });

      test('should cap delay at maximum', () {
        final result = errorHandler.handleAttError(
          Exception('ATT error: insufficient resources'),
          10, // Very high attempt number
        );

        expect(result.delay.inSeconds, equals(16)); // Max delay
      });
    });
  });

  group('BleAttErrors', () {
    test('should provide correct error messages', () {
      expect(BleAttErrors.getErrorMessage(BleAttErrors.insufficientResources),
          contains('Insufficient resources'));
      expect(BleAttErrors.getErrorMessage(BleAttErrors.invalidAttributeValueLength),
          contains('chunk size mismatch'));
      expect(BleAttErrors.getErrorMessage(BleAttErrors.unlikely),
          contains('validation or application failed'));
      expect(BleAttErrors.getErrorMessage(BleAttErrors.requestNotSupported),
          contains('malformed font data'));
      expect(BleAttErrors.getErrorMessage(BleAttErrors.invalidState),
          contains('invalid sequence or upload state'));
    });

    test('should determine recoverability correctly', () {
      expect(BleAttErrors.isRecoverable(BleAttErrors.insufficientResources), true);
      expect(BleAttErrors.isRecoverable(BleAttErrors.invalidAttributeValueLength), true);
      expect(BleAttErrors.isRecoverable(BleAttErrors.unlikely), true);
      expect(BleAttErrors.isRecoverable(BleAttErrors.requestNotSupported), true);
      expect(BleAttErrors.isRecoverable(BleAttErrors.invalidState), true);
      expect(BleAttErrors.isRecoverable(BleAttErrors.insufficientAuthentication), false);
      expect(BleAttErrors.isRecoverable(BleAttErrors.insufficientAuthorization), false);
    });
  });

  group('FontUploadErrorResult', () {
    test('should create error result correctly', () {
      const result = FontUploadErrorResult(
        shouldRetry: true,
        delay: Duration(seconds: 5),
        error: FontUploadError.timeout,
        message: 'Test error',
        recoverable: true,
        restartFromBeginning: false,
      );

      expect(result.shouldRetry, true);
      expect(result.delay.inSeconds, equals(5));
      expect(result.error, FontUploadError.timeout);
      expect(result.message, equals('Test error'));
      expect(result.recoverable, true);
      expect(result.restartFromBeginning, false);
    });

    test('should have meaningful toString', () {
      const result = FontUploadErrorResult(
        shouldRetry: true,
        delay: Duration(seconds: 2),
        error: FontUploadError.timeout,
        message: 'Timeout occurred',
        recoverable: true,
      );

      final stringResult = result.toString();
      expect(stringResult, contains('shouldRetry: true'));
      expect(stringResult, contains('delay: 2s'));
      expect(stringResult, contains('error: FontUploadError.timeout'));
    });
  });
}