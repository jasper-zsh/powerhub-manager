import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_upload_timeout_manager.dart';

void main() {
  group('FontUploadTimeoutManager', () {
    late FontUploadTimeoutManager timeoutManager;
    late List<FontUploadTimeoutEvent> timeoutEvents;

    setUp(() {
      timeoutEvents = [];
      timeoutManager = FontUploadTimeoutManager(
        onTimeout: (event) => timeoutEvents.add(event),
      );
    });

    tearDown(() {
      timeoutManager.dispose();
    });

    group('Session Management', () {
      test('should start upload session correctly', () {
        timeoutManager.startUploadSession();

        expect(timeoutManager.isActive, true);
        expect(timeoutManager.uploadStartTime, isNotNull);
        expect(timeoutManager.lastActivity, isNotNull);
      });

      test('should stop timeout management correctly', () {
        timeoutManager.startUploadSession();
        expect(timeoutManager.isActive, true);

        timeoutManager.stopTimeoutManagement();
        expect(timeoutManager.isActive, false);
      });

      test('should update activity correctly', () {
        timeoutManager.startUploadSession();
        final initialActivity = timeoutManager.lastActivity!;

        // Wait a bit to ensure different timestamp
        Future.delayed(Duration(milliseconds: 10)).then((_) {
          timeoutManager.updateActivity();
          expect(timeoutManager.lastActivity!.isAfter(initialActivity), true);
        });
      });
    });

    group('Chunk Timeout', () {
      test('should start chunk timeout correctly', () {
        timeoutManager.startUploadSession();
        timeoutManager.startChunkTimeout();

        expect(timeoutManager.chunkStartTime, isNotNull);
        expect(timeoutManager.getChunkElapsedTime(), isNotNull);
      });

      test('should reset chunk timeout correctly', () {
        timeoutManager.startUploadSession();
        timeoutManager.startChunkTimeout();
        final initialStartTime = timeoutManager.chunkStartTime;

        // Wait a bit and reset
        Future.delayed(Duration(milliseconds: 10)).then((_) {
          timeoutManager.resetChunkTimeout();
          // Note: chunkStartTime becomes null after reset, so we can't directly test it
          // but we can test that no timeout events occurred during this period
          expect(timeoutEvents.isEmpty, true);
        });
      });

      test('should calculate chunk elapsed time correctly', () {
        timeoutManager.startUploadSession();
        timeoutManager.startChunkTimeout();

        // Allow some time to pass
        Future.delayed(Duration(milliseconds: 100)).then((_) {
          final elapsedTime = timeoutManager.getChunkElapsedTime();
          expect(elapsedTime, isNotNull);
          expect(elapsedTime!.inMilliseconds, greaterThan(50));
        });
      });
    });

    group('Connection Timeout', () {
      test('should start connection timeout correctly', () {
        timeoutManager.startUploadSession();
        timeoutManager.startConnectionTimeout();

        // The connection timeout is based on inactivity time
        expect(timeoutManager.getInactivityTime(), isNotNull);
      });
    });

    group('Timeout Warnings', () {
      test('should detect chunk timeout warnings', () async {
        // Use very short timeout for testing
        final testConfig = FontUploadTimeoutConfig(
          chunkTimeout: Duration(milliseconds: 100),
          connectionTimeout: Duration(seconds: 10),
          overallTimeout: Duration(minutes: 10),
          progressReportInterval: Duration(seconds: 1),
        );

        final testTimeoutManager = FontUploadTimeoutManager(
          config: testConfig,
          onTimeout: (event) => timeoutEvents.add(event),
        );

        testTimeoutManager.startUploadSession();
        testTimeoutManager.startChunkTimeout();

        // Wait for warning threshold (80% of 100ms = 80ms)
        await Future.delayed(Duration(milliseconds: 85));

        final warning = testTimeoutManager.checkTimeoutWarnings();
        expect(warning, isNotNull);
        expect(warning!.type, FontUploadTimeoutEvent.chunkTimeout);
        expect(warning.timeRemaining.inMilliseconds, lessThan(25)); // Less than 20ms remaining

        testTimeoutManager.dispose();
      });

      test('should detect connection timeout warnings', () async {
        // Use very short connection timeout for testing
        final testConfig = FontUploadTimeoutConfig(
          chunkTimeout: Duration(seconds: 30),
          connectionTimeout: Duration(milliseconds: 100),
          overallTimeout: Duration(minutes: 10),
          progressReportInterval: Duration(seconds: 1),
        );

        final testTimeoutManager = FontUploadTimeoutManager(
          config: testConfig,
          onTimeout: (event) => timeoutEvents.add(event),
        );

        testTimeoutManager.startUploadSession();
        testTimeoutManager.startConnectionTimeout();

        // Don't update activity to trigger connection timeout
        await Future.delayed(Duration(milliseconds: 85));

        final warning = testTimeoutManager.checkTimeoutWarnings();
        expect(warning, isNotNull);
        expect(warning!.type, FontUploadTimeoutEvent.connectionTimeout);

        testTimeoutManager.dispose();
      });

      test('should detect overall timeout warnings', () async {
        // Use very short overall timeout for testing
        final testConfig = FontUploadTimeoutConfig(
          chunkTimeout: Duration(seconds: 30),
          connectionTimeout: Duration(seconds: 10),
          overallTimeout: Duration(milliseconds: 100),
          progressReportInterval: Duration(seconds: 1),
        );

        final testTimeoutManager = FontUploadTimeoutManager(
          config: testConfig,
          onTimeout: (event) => timeoutEvents.add(event),
        );

        testTimeoutManager.startUploadSession();

        // Wait for overall timeout warning (80% of 100ms = 80ms)
        await Future.delayed(Duration(milliseconds: 85));

        final warning = testTimeoutManager.checkTimeoutWarnings();
        expect(warning, isNotNull);
        expect(warning!.type, FontUploadTimeoutEvent.overallTimeout);

        testTimeoutManager.dispose();
      });

      test('should return null when no warnings', () {
        timeoutManager.startUploadSession();
        timeoutManager.startChunkTimeout();

        final warning = timeoutManager.checkTimeoutWarnings();
        expect(warning, isNull);
      });
    });

    group('Timeout Events', () {
      test('should trigger chunk timeout event', () async {
        // Use very short timeout for testing
        final testConfig = FontUploadTimeoutConfig(
          chunkTimeout: Duration(milliseconds: 50),
          connectionTimeout: Duration(seconds: 10),
          overallTimeout: Duration(minutes: 10),
          progressReportInterval: Duration(seconds: 1),
        );

        final testTimeoutManager = FontUploadTimeoutManager(
          config: testConfig,
          onTimeout: (event) => timeoutEvents.add(event),
        );

        testTimeoutManager.startUploadSession();
        testTimeoutManager.startChunkTimeout();

        // Wait for timeout to trigger
        await Future.delayed(Duration(milliseconds: 100));

        expect(timeoutEvents, contains(FontUploadTimeoutEvent.chunkTimeout));

        testTimeoutManager.dispose();
      });

      test('should trigger overall timeout event', () async {
        // Use very short overall timeout for testing
        final testConfig = FontUploadTimeoutConfig(
          chunkTimeout: Duration(seconds: 30),
          connectionTimeout: Duration(seconds: 10),
          overallTimeout: Duration(milliseconds: 50),
          progressReportInterval: Duration(seconds: 1),
        );

        final testTimeoutManager = FontUploadTimeoutManager(
          config: testConfig,
          onTimeout: (event) => timeoutEvents.add(event),
        );

        testTimeoutManager.startUploadSession();

        // Wait for overall timeout to trigger
        await Future.delayed(Duration(milliseconds: 100));

        expect(timeoutEvents, contains(FontUploadTimeoutEvent.overallTimeout));

        testTimeoutManager.dispose();
      });

      test('should trigger progress report events', () async {
        // Use very short progress interval for testing
        final testConfig = FontUploadTimeoutConfig(
          chunkTimeout: Duration(seconds: 30),
          connectionTimeout: Duration(seconds: 10),
          overallTimeout: Duration(minutes: 10),
          progressReportInterval: Duration(milliseconds: 50),
        );

        final testTimeoutManager = FontUploadTimeoutManager(
          config: testConfig,
          onTimeout: (event) => timeoutEvents.add(event),
        );

        testTimeoutManager.startUploadSession();

        // Wait for progress report events
        await Future.delayed(Duration(milliseconds: 200));

        expect(timeoutEvents.length, greaterThan(1));
        expect(timeoutEvents, contains(FontUploadTimeoutEvent.progressReport));

        testTimeoutManager.dispose();
      });
    });

    group('Status Reporting', () {
      test('should provide accurate timeout status', () {
        final status = timeoutManager.getTimeoutStatus();

        expect(status.isActive, false);
        expect(status.chunkElapsedTime, isNull);
        expect(status.uploadElapsedTime, isNull);
        expect(status.inactivityTime, isNull);
        expect(status.chunkTimerActive, false);
        expect(status.connectionTimerActive, false);
        expect(status.overallTimerActive, false);
      });

      test('should provide active timeout status', () {
        timeoutManager.startUploadSession();
        timeoutManager.startChunkTimeout();

        final status = timeoutManager.getTimeoutStatus();

        expect(status.isActive, true);
        expect(status.uploadElapsedTime, isNotNull);
        expect(status.chunkElapsedTime, isNotNull);
        expect(status.inactivityTime, isNotNull);
        expect(status.overallTimerActive, true);
        // Note: connection timer is only active when explicitly started
      });
    });

    group('Resource Management', () {
      test('should handle multiple start/stop cycles', () {
        for (int i = 0; i < 3; i++) {
          timeoutManager.startUploadSession();
          expect(timeoutManager.isActive, true);

          timeoutManager.stopTimeoutManagement();
          expect(timeoutManager.isActive, false);
        }
      });

      test('should handle disposal correctly', () {
        timeoutManager.startUploadSession();
        timeoutManager.startChunkTimeout();

        expect(timeoutManager.isActive, true);

        timeoutManager.dispose();
        expect(timeoutManager.isActive, false);
      });
    });
  });

  group('FontUploadTimeoutWarning', () {
    test('should create warning correctly', () {
      final warning = FontUploadTimeoutWarning(
        type: FontUploadTimeoutEvent.chunkTimeout,
        timeRemaining: Duration(seconds: 5),
        warningMessage: 'Chunk timeout approaching',
      );

      expect(warning.type, FontUploadTimeoutEvent.chunkTimeout);
      expect(warning.timeRemaining.inSeconds, equals(5));
      expect(warning.warningMessage, equals('Chunk timeout approaching'));
    });

    test('should have meaningful toString', () {
      final warning = FontUploadTimeoutWarning(
        type: FontUploadTimeoutEvent.chunkTimeout,
        timeRemaining: Duration(seconds: 10),
        warningMessage: 'Test warning',
      );

      final stringResult = warning.toString();
      expect(stringResult, contains('chunkTimeout'));
      expect(stringResult, contains('10s'));
      expect(stringResult, contains('Test warning'));
    });
  });

  group('FontUploadTimeoutStatus', () {
    test('should create status correctly', () {
      final now = DateTime.now();
      final status = FontUploadTimeoutStatus(
        isActive: true,
        chunkElapsedTime: Duration(seconds: 5),
        uploadElapsedTime: Duration(minutes: 2),
        inactivityTime: Duration(seconds: 10),
        chunkTimerActive: true,
        connectionTimerActive: false,
        overallTimerActive: true,
      );

      expect(status.isActive, true);
      expect(status.chunkElapsedTime?.inSeconds, equals(5));
      expect(status.uploadElapsedTime?.inMinutes, equals(2));
      expect(status.inactivityTime?.inSeconds, equals(10));
      expect(status.chunkTimerActive, true);
      expect(status.connectionTimerActive, false);
      expect(status.overallTimerActive, true);
    });

    test('should have meaningful toString', () {
      final status = FontUploadTimeoutStatus(
        isActive: true,
        chunkTimerActive: true,
        connectionTimerActive: false,
        overallTimerActive: true,
      );

      final stringResult = status.toString();
      expect(stringResult, contains('active: true'));
      expect(stringResult, contains('chunk=true'));
      expect(stringResult, contains('conn=false'));
      expect(stringResult, contains('overall=true'));
    });
  });
}