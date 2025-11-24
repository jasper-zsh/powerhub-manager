import 'dart:async';

import 'package:flutter/foundation.dart';

/// Font upload timeout configuration
class FontUploadTimeoutConfig {
  final Duration chunkTimeout;
  final Duration connectionTimeout;
  final Duration overallTimeout;
  final Duration progressReportInterval;

  const FontUploadTimeoutConfig({
    this.chunkTimeout = const Duration(seconds: 30),
    this.connectionTimeout = const Duration(seconds: 10),
    this.overallTimeout = const Duration(minutes: 10),
    this.progressReportInterval = const Duration(seconds: 1),
  });
}

/// Font upload timeout events
enum FontUploadTimeoutEvent {
  chunkTimeout,
  connectionTimeout,
  overallTimeout,
  progressReport,
}

/// Font upload timeout manager
class FontUploadTimeoutManager {
  final FontUploadTimeoutConfig config;
  final void Function(FontUploadTimeoutEvent)? onTimeout;

  Timer? _chunkTimer;
  Timer? _connectionTimer;
  Timer? _overallTimer;
  Timer? _progressReportTimer;

  DateTime? _chunkStartTime;
  DateTime? _uploadStartTime;
  DateTime? _lastActivity;

  bool _isActive = false;

  FontUploadTimeoutManager({
    this.config = const FontUploadTimeoutConfig(),
    this.onTimeout,
  });

  bool get isActive => _isActive;
  DateTime? get chunkStartTime => _chunkStartTime;
  DateTime? get uploadStartTime => _uploadStartTime;
  DateTime? get lastActivity => _lastActivity;

  /// Start timeout management for a new upload session
  void startUploadSession() {
    if (_isActive) {
      stopAllTimers();
    }

    _isActive = true;
    _uploadStartTime = DateTime.now();
    _lastActivity = DateTime.now();

    _startOverallTimer();
    _startProgressReportTimer();

    debugPrint('Font upload timeout session started');
  }

  /// Start timeout for individual chunk transmission
  void startChunkTimeout() {
    _cancelChunkTimer();
    _chunkStartTime = DateTime.now();
    _lastActivity = DateTime.now();

    _chunkTimer = Timer(config.chunkTimeout, () {
      if (_isActive) {
        debugPrint('Chunk timeout detected after ${config.chunkTimeout.inSeconds}s');
        onTimeout?.call(FontUploadTimeoutEvent.chunkTimeout);
      }
    });

    debugPrint('Chunk timeout timer started: ${config.chunkTimeout.inSeconds}s');
  }

  /// Start connection timeout
  void startConnectionTimeout() {
    _cancelConnectionTimer();

    _connectionTimer = Timer(config.connectionTimeout, () {
      if (_isActive) {
        debugPrint('Connection timeout detected after ${config.connectionTimeout.inSeconds}s');
        onTimeout?.call(FontUploadTimeoutEvent.connectionTimeout);
      }
    });

    debugPrint('Connection timeout timer started: ${config.connectionTimeout.inSeconds}s');
  }

  /// Reset chunk timeout (called when chunk is successfully sent)
  void resetChunkTimeout() {
    if (!_isActive) return;

    _cancelChunkTimer();
    _lastActivity = DateTime.now();

    debugPrint('Chunk timeout reset');
  }

  /// Update last activity time
  void updateActivity() {
    if (!_isActive) return;

    _lastActivity = DateTime.now();
    debugPrint('Activity updated');
  }

  /// Get time since chunk started
  Duration? getChunkElapsedTime() {
    if (_chunkStartTime == null) return null;
    return DateTime.now().difference(_chunkStartTime!);
  }

  /// Get time since upload started
  Duration? getUploadElapsedTime() {
    if (_uploadStartTime == null) return null;
    return DateTime.now().difference(_uploadStartTime!);
  }

  /// Get time since last activity
  Duration? getInactivityTime() {
    if (_lastActivity == null) return null;
    return DateTime.now().difference(_lastActivity!);
  }

  /// Check if any timeout is approaching warning threshold
  FontUploadTimeoutWarning? checkTimeoutWarnings() {
    if (!_isActive) return null;

    // Check chunk timeout warning (80% of timeout)
    final chunkElapsed = getChunkElapsedTime();
    if (chunkElapsed != null && _chunkTimer != null) {
      final warningThreshold = Duration(milliseconds: (config.chunkTimeout.inMilliseconds * 0.8).round());
      if (chunkElapsed > warningThreshold) {
        final remaining = config.chunkTimeout - chunkElapsed;
        return FontUploadTimeoutWarning(
          type: FontUploadTimeoutEvent.chunkTimeout,
          timeRemaining: remaining,
          warningMessage: 'Chunk timeout approaching in ${remaining.inSeconds}s',
        );
      }
    }

    // Check connection timeout warning (80% of timeout)
    final connectionElapsed = getInactivityTime();
    if (_connectionTimer != null && connectionElapsed != null) {
      final warningThreshold = Duration(milliseconds: (config.connectionTimeout.inMilliseconds * 0.8).round());
      if (connectionElapsed > warningThreshold) {
        final remaining = config.connectionTimeout - connectionElapsed;
        return FontUploadTimeoutWarning(
          type: FontUploadTimeoutEvent.connectionTimeout,
          timeRemaining: remaining,
          warningMessage: 'Connection timeout approaching in ${remaining.inSeconds}s',
        );
      }
    }

    // Check overall timeout warning (80% of timeout)
    final uploadElapsed = getUploadElapsedTime();
    if (uploadElapsed != null) {
      final warningThreshold = Duration(milliseconds: (config.overallTimeout.inMilliseconds * 0.8).round());
      if (uploadElapsed > warningThreshold) {
        final remaining = config.overallTimeout - uploadElapsed;
        return FontUploadTimeoutWarning(
          type: FontUploadTimeoutEvent.overallTimeout,
          timeRemaining: remaining,
          warningMessage: 'Overall upload timeout approaching in ${remaining.inMinutes}s',
        );
      }
    }

    return null;
  }

  /// Stop timeout management
  void stopTimeoutManagement() {
    if (!_isActive) return;

    _isActive = false;
    stopAllTimers();

    debugPrint('Font upload timeout management stopped');
  }

  void stopAllTimers() {
    _cancelChunkTimer();
    _cancelConnectionTimer();
    _cancelOverallTimer();
    _cancelProgressReportTimer();

    debugPrint('All timeout timers cancelled');
  }

  void _startOverallTimer() {
    _overallTimer = Timer(config.overallTimeout, () {
      if (_isActive) {
        debugPrint('Overall upload timeout detected after ${config.overallTimeout.inMinutes}s');
        onTimeout?.call(FontUploadTimeoutEvent.overallTimeout);
      }
    });

    debugPrint('Overall timeout timer started: ${config.overallTimeout.inMinutes}s');
  }

  void _startProgressReportTimer() {
    _progressReportTimer = Timer.periodic(config.progressReportInterval, (timer) {
      if (_isActive) {
        onTimeout?.call(FontUploadTimeoutEvent.progressReport);
      }
    });

    debugPrint('Progress report timer started: every ${config.progressReportInterval.inSeconds}s');
  }

  void _cancelChunkTimer() {
    _chunkTimer?.cancel();
    _chunkTimer = null;
    _chunkStartTime = null;
  }

  void _cancelConnectionTimer() {
    _connectionTimer?.cancel();
    _connectionTimer = null;
  }

  void _cancelOverallTimer() {
    _overallTimer?.cancel();
    _overallTimer = null;
  }

  void _cancelProgressReportTimer() {
    _progressReportTimer?.cancel();
    _progressReportTimer = null;
  }

  /// Get timeout status summary
  FontUploadTimeoutStatus getTimeoutStatus() {
    return FontUploadTimeoutStatus(
      isActive: _isActive,
      chunkElapsedTime: getChunkElapsedTime(),
      uploadElapsedTime: getUploadElapsedTime(),
      inactivityTime: getInactivityTime(),
      chunkTimerActive: _chunkTimer != null,
      connectionTimerActive: _connectionTimer != null,
      overallTimerActive: _overallTimer != null,
    );
  }

  /// Dispose resources
  void dispose() {
    stopTimeoutManagement();
    debugPrint('FontUploadTimeoutManager disposed');
  }
}

/// Font upload timeout warning
class FontUploadTimeoutWarning {
  final FontUploadTimeoutEvent type;
  final Duration timeRemaining;
  final String warningMessage;

  const FontUploadTimeoutWarning({
    required this.type,
    required this.timeRemaining,
    required this.warningMessage,
  });

  @override
  String toString() {
    return 'FontUploadTimeoutWarning(type: $type, remaining: ${timeRemaining.inSeconds}s, message: $warningMessage)';
  }
}

/// Font upload timeout status
class FontUploadTimeoutStatus {
  final bool isActive;
  final Duration? chunkElapsedTime;
  final Duration? uploadElapsedTime;
  final Duration? inactivityTime;
  final bool chunkTimerActive;
  final bool connectionTimerActive;
  final bool overallTimerActive;

  const FontUploadTimeoutStatus({
    required this.isActive,
    this.chunkElapsedTime,
    this.uploadElapsedTime,
    this.inactivityTime,
    required this.chunkTimerActive,
    required this.connectionTimerActive,
    required this.overallTimerActive,
  });

  @override
  String toString() {
    return 'FontUploadTimeoutStatus('
        'active: $isActive, '
        'chunk: ${chunkElapsedTime?.inSeconds ?? 0}s, '
        'upload: ${uploadElapsedTime?.inMinutes ?? 0}m, '
        'inactive: ${inactivityTime?.inSeconds ?? 0}s, '
        'timers: chunk=$chunkTimerActive, conn=$connectionTimerActive, overall=$overallTimerActive'
        ')';
  }
}