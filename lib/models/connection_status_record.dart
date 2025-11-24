import 'package:app/models/saved_controller.dart';

/// Lifecycle state of the foreground scanning loop.
enum ScanState {
  idle,
  scanning,
  waitingRetry,
}

/// Result of the most recent scan for a given controller.
enum LastScanResult {
  found,
  notFound,
  error,
}

class ConnectionStatusRecord {
  ConnectionStatusRecord({
    required this.controller,
    this.scanState = ScanState.idle,
    this.lastResult = LastScanResult.found,
    this.errorReason,
    this.retryAttempts = 0,
    this.lastScanAt,
    this.nextRetryAt,
  });

  final SavedController controller;
  final ScanState scanState;
  final LastScanResult lastResult;
  final String? errorReason;
  final int retryAttempts;
  final DateTime? lastScanAt;
  final DateTime? nextRetryAt;

  ConnectionStatusRecord copyWith({
    SavedController? controller,
    ScanState? scanState,
    LastScanResult? lastResult,
    String? errorReason,
    int? retryAttempts,
    DateTime? lastScanAt,
    DateTime? nextRetryAt,
  }) {
    return ConnectionStatusRecord(
      controller: controller ?? this.controller,
      scanState: scanState ?? this.scanState,
      lastResult: lastResult ?? this.lastResult,
      errorReason: errorReason ?? this.errorReason,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'controller': controller.toJson(),
      'scanState': scanState.name,
      'lastResult': lastResult.name,
      'errorReason': errorReason,
      'retryAttempts': retryAttempts,
      'lastScanAt': lastScanAt?.toIso8601String(),
      'nextRetryAt': nextRetryAt?.toIso8601String(),
    };
  }

  factory ConnectionStatusRecord.fromJson(Map<String, dynamic> json) {
    return ConnectionStatusRecord(
      controller: SavedController.fromJson(
        (json['controller'] as Map).cast<String, dynamic>(),
      ),
      scanState: ScanState.values.firstWhere(
        (state) => state.name == json['scanState'],
        orElse: () => ScanState.idle,
      ),
      lastResult: LastScanResult.values.firstWhere(
        (result) => result.name == json['lastResult'],
        orElse: () => LastScanResult.notFound,
      ),
      errorReason: json['errorReason'] as String?,
      retryAttempts: json['retryAttempts'] as int? ?? 0,
      lastScanAt: json['lastScanAt'] != null
          ? DateTime.parse(json['lastScanAt'] as String)
          : null,
      nextRetryAt: json['nextRetryAt'] != null
          ? DateTime.parse(json['nextRetryAt'] as String)
          : null,
    );
  }
}

class ConnectionDashboardSummary {
  const ConnectionDashboardSummary({
    required this.totalSaved,
    required this.connectedCount,
    required this.recoveringCount,
    required this.unavailableCount,
  });

  final int totalSaved;
  final int connectedCount;
  final int recoveringCount;
  final int unavailableCount;

  factory ConnectionDashboardSummary.fromControllers(
    Iterable<SavedController> controllers,
  ) {
    int connected = 0;
    int recovering = 0;
    int unavailable = 0;

    for (final controller in controllers) {
      switch (controller.connectionStatus) {
        case SavedControllerConnectionStatus.connected:
          connected += 1;
          break;
        case SavedControllerConnectionStatus.connecting:
          recovering += 1;
          break;
        case SavedControllerConnectionStatus.unavailable:
          unavailable += 1;
          break;
        case SavedControllerConnectionStatus.disconnected:
          break;
      }
    }

    return ConnectionDashboardSummary(
      totalSaved: controllers.length,
      connectedCount: connected,
      recoveringCount: recovering,
      unavailableCount: unavailable,
    );
  }
}
