import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_upload_protocol.dart';
import 'package:app/services/font_notification_parser.dart';

void main() {
  group('FontUploadProtocol', () {
    late FontUploadProtocol protocol;
    late List<FontUploadProgress> progressEvents;
    late List<FontUploadErrorDetails> errorEvents;
    late List<MemoryWarning> memoryWarningEvents;
    bool successEvent = false;

    setUp(() {
      progressEvents = [];
      errorEvents = [];
      memoryWarningEvents = [];
      successEvent = false;

      protocol = FontUploadProtocol(
        onProgress: (progress) => progressEvents.add(progress),
        onError: (error) => errorEvents.add(error),
        onSuccess: () => successEvent = true,
        onMemoryWarning: (warning) => memoryWarningEvents.add(warning),
      );
    });

    tearDown(() {
      protocol.dispose();
    });

    test('should initialize upload with valid parameters', () {
      const totalBytes = 1024;
      const chunkSize = 256;

      protocol.initializeUpload(totalBytes, chunkSize: chunkSize);

      expect(protocol.state, FontUploadState.initializing);
      expect(protocol.totalSequences, equals(4)); // 1024 / 256 = 4 chunks
    });

    test('should throw exception for font size exceeding limit', () {
      const totalBytes = 2 * 1024 * 1024; // 2MB exceeds 1MB limit
      const chunkSize = 1024;

      expect(
        () => protocol.initializeUpload(totalBytes, chunkSize: chunkSize),
        throwsArgumentError,
      );
    });

    test('should throw exception for chunk size exceeding limit', () {
      const totalBytes = 1024;
      const chunkSize = 70000; // Exceeds 65535 limit

      expect(
        () => protocol.initializeUpload(totalBytes, chunkSize: chunkSize),
        throwsArgumentError,
      );
    });

    test('should start upload after initialization', () {
      protocol.initializeUpload(1024, chunkSize: 256);
      protocol.startUpload();

      expect(protocol.state, FontUploadState.uploading);
    });

    test('should throw exception when starting upload without initialization', () {
      expect(
        () => protocol.startUpload(),
        throwsStateError,
      );
    });

    test('should process progress notification correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Progress notification: [0xFE][seq_hi][seq_lo][percentage]
      final progressData = Uint8List.fromList([0xFE, 0x00, 0x02, 0x15]); // sequence 2, 21%
      protocol.handleStatusNotification(progressData);

      expect(progressEvents.length, equals(1));
      expect(progressEvents.first.currentSequence, equals(2));
      expect(progressEvents.first.percentage, equals(21));
    });

    test('should handle upload started notification', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Upload started: [0xFF][0x02][0x00][0x00]
      final startedData = Uint8List.fromList([0xFF, 0x02, 0x00, 0x00]);
      protocol.handleStatusNotification(startedData);

      // Should not throw error, just log it
      expect(errorEvents.isEmpty, true);
    });

    test('should handle success notification', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Success: [0xFF][0x00][0x00][0x00]
      final successData = Uint8List.fromList([0xFF, 0x00, 0x00, 0x00]);
      protocol.handleStatusNotification(successData);

      expect(successEvent, true);
      expect(protocol.state, FontUploadState.success);
    });

    test('should handle timeout error correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Timeout error: [0xFF][0x01][0x00][0x00]
      final errorData = Uint8List.fromList([0xFF, 0x01, 0x00, 0x00]);
      protocol.handleStatusNotification(errorData);

      expect(errorEvents.length, equals(1));
      expect(errorEvents.first.type, FontUploadError.timeout);
      expect(protocol.state, FontUploadState.error);
    });

    test('should handle sequence error correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Sequence error: [0xFF][0x04][0x00][0x05] (wrong sequence 5)
      final errorData = Uint8List.fromList([0xFF, 0x04, 0x00, 0x05]);
      protocol.handleStatusNotification(errorData);

      expect(errorEvents.length, equals(1));
      expect(errorEvents.first.type, FontUploadError.sequenceError);
      expect(errorEvents.first.parameter, equals(5));
    });

    test('should handle font application error correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Font application failed: [0xFF][0x03][0x12][0x34] (ESP error 0x1234)
      final errorData = Uint8List.fromList([0xFF, 0x03, 0x12, 0x34]);
      protocol.handleStatusNotification(errorData);

      expect(errorEvents.length, equals(1));
      expect(errorEvents.first.type, FontUploadError.fontApplicationFailed);
      expect(errorEvents.first.parameter, equals(0x1234));
    });

    test('should handle memory warning correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Memory warning: [0xFD][usage_hi][usage_mid][usage_lo]
      // 900KB used (900 * 1024 = 921600 bytes = 0xE1000)
      final warningData = Uint8List.fromList([0xFD, 0x0E, 0x10, 0x00]);
      protocol.handleStatusNotification(warningData);

      expect(memoryWarningEvents.length, equals(1));
      expect(memoryWarningEvents.first.bytesUsed, equals(921600));
    });

    test('should ignore invalid notification data', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Invalid data (empty)
      protocol.handleStatusNotification(Uint8List(0));

      // Should not throw or change state
      expect(protocol.state, FontUploadState.uploading);
      expect(progressEvents.isEmpty, true);
      expect(errorEvents.isEmpty, true);
    });

    test('should handle unknown notification prefix', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      // Unknown prefix: [0x99][0x00][0x00][0x00]
      final unknownData = Uint8List.fromList([0x99, 0x00, 0x00, 0x00]);
      protocol.handleStatusNotification(unknownData);

      // Should not throw or change state
      expect(protocol.state, FontUploadState.uploading);
      expect(progressEvents.isEmpty, true);
      expect(errorEvents.isEmpty, true);
    });

    test('should track chunk progress correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      protocol.processChunkSent(0);
      expect(protocol.currentSequence, equals(0));

      protocol.processChunkSent(1);
      expect(protocol.currentSequence, equals(1));

      protocol.processChunkSent(2);
      expect(protocol.currentSequence, equals(2));
    });

    test('should handle completion correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      protocol.completeUpload();
      expect(protocol.state, FontUploadState.completing);
    });

    test('should cancel upload correctly', () {
      protocol.initializeUpload(1000, chunkSize: 100);
      protocol.startUpload();

      protocol.cancelUpload();
      expect(protocol.state, FontUploadState.cancelled);
    });
  });

  group('FontNotificationParser', () {
    test('should parse progress notification correctly', () {
      final data = Uint8List.fromList([0xFE, 0x00, 0x01, 0x50]); // sequence 1, 80% (big-endian)
      final notification = FontNotificationParser.parseNotification(data);

      expect(notification, isA<ProgressNotification>());
      final progress = notification as ProgressNotification;
      expect(progress.sequence, equals(1));
      expect(progress.percentage, equals(80));
    });

    test('should parse status notification correctly', () {
      final data = Uint8List.fromList([0xFF, 0x04, 0x00, 0x05]); // sequence error with param 5 (big-endian)
      final notification = FontNotificationParser.parseNotification(data);

      expect(notification, isA<StatusNotification>());
      final status = notification as StatusNotification;
      expect(status.code, equals(0x04));
      expect(status.parameter, equals(5)); // (0x00 << 8) | 0x05 = 5
      expect(status.isError, true);
    });

    test('should parse memory warning notification correctly', () {
      // Use simple values that are easy to verify
      final data = Uint8List.fromList([0xFD, 0x00, 0x00, 0x01]); // 1 byte used (big-endian)
      final notification = FontNotificationParser.parseNotification(data);

      expect(notification, isA<MemoryWarningNotification>());
      final memory = notification as MemoryWarningNotification;
      expect(memory.bytesUsed, equals(1)); // (0x00 << 16) | (0x00 << 8) | 0x01 = 1
      expect(memory.percentageUsed, lessThan(1.0));
    });

    test('should return null for invalid notification', () {
      final data = Uint8List.fromList([0x99, 0x00, 0x00, 0x00]); // Unknown prefix
      final notification = FontNotificationParser.parseNotification(data);

      expect(notification, isNull);
    });

    test('should return null for empty data', () {
      final notification = FontNotificationParser.parseNotification(Uint8List(0));

      expect(notification, isNull);
    });

    test('should identify error notifications correctly', () {
      final errorData = Uint8List.fromList([0xFF, 0x04, 0x00, 0x05]); // Sequence error
      final status = FontNotificationParser.parseStatusNotification(errorData)!;

      expect(FontNotificationParser.isErrorNotification(status), true);

      final successData = Uint8List.fromList([0xFF, 0x00, 0x00, 0x00]); // Success
      final successStatus = FontNotificationParser.parseStatusNotification(successData)!;

      expect(FontNotificationParser.isErrorNotification(successStatus), false);
    });

    test('should get error type correctly', () {
      final timeoutData = Uint8List.fromList([0xFF, 0x01, 0x00, 0x00]);
      final timeoutStatus = FontNotificationParser.parseStatusNotification(timeoutData)!;

      final errorType = FontNotificationParser.getErrorType(timeoutStatus);
      expect(errorType, FontUploadErrorType.timeout);

      final sequenceData = Uint8List.fromList([0xFF, 0x04, 0x00, 0x05]);
      final sequenceStatus = FontNotificationParser.parseStatusNotification(sequenceData)!;

      final sequenceErrorType = FontNotificationParser.getErrorType(sequenceStatus);
      expect(sequenceErrorType, FontUploadErrorType.sequenceError);
    });

    test('should generate error messages correctly', () {
      final timeoutData = Uint8List.fromList([0xFF, 0x01, 0x00, 0x00]);
      final timeoutStatus = FontNotificationParser.parseStatusNotification(timeoutData)!;

      final errorMessage = FontNotificationParser.getErrorMessage(timeoutStatus);
      expect(errorMessage, contains('timeout'));
    });

    test('should handle malformed progress notifications', () {
      final shortData = Uint8List.fromList([0xFE, 0x01, 0x00]); // Missing percentage
      final notification = FontNotificationParser.parseProgressNotification(shortData);

      expect(notification, isNull);
    });

    test('should handle malformed status notifications', () {
      final shortData = Uint8List.fromList([0xFF, 0x01]); // Missing parameter
      final notification = FontNotificationParser.parseStatusNotification(shortData);

      expect(notification, isNull);
    });

    test('should handle malformed memory warnings', () {
      final shortData = Uint8List.fromList([0xFD, 0x01, 0x00]); // Missing low byte
      final notification = FontNotificationParser.parseMemoryWarningNotification(shortData);

      expect(notification, isNull);
    });
  });
}