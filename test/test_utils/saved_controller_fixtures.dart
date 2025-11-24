import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';

int _controllerSeed = 0;

String _nextControllerId() {
  _controllerSeed += 1;
  return 'controller-${_controllerSeed.toString().padLeft(3, '0')}';
}

SavedController buildSavedControllerFixture({
  String? controllerId,
  String? alias,
  SavedControllerConnectionStatus status =
      SavedControllerConnectionStatus.connected,
  DateTime? lastConnectedAt,
  RetryPolicy? retryPolicy,
  DeviceCapabilities? capabilities,
  String? notes,
}) {
  return SavedController(
    controllerId: controllerId ?? _nextControllerId(),
    alias: alias ?? 'Controller $_controllerSeed',
    connectionStatus: status,
    lastConnectedAt: lastConnectedAt,
    retryPolicy: retryPolicy ?? RetryPolicy.defaults(),
    deviceCapabilities: capabilities ??
        const DeviceCapabilities(
          channels: 4,
          supportsPresets: true,
        ),
    notes: notes,
  );
}

ConnectionStatusRecord buildConnectionStatusRecordFixture({
  String? controllerId,
  SavedControllerConnectionStatus? controllerStatus,
  ScanState scanState = ScanState.idle,
  LastScanResult lastResult = LastScanResult.found,
  String? errorReason,
  int retryAttempts = 0,
  DateTime? lastScanAt,
  DateTime? nextRetryAt,
}) {
  final savedController = buildSavedControllerFixture(
    controllerId: controllerId,
    status: controllerStatus ?? SavedControllerConnectionStatus.connected,
  );

  return ConnectionStatusRecord(
    controller: savedController,
    scanState: scanState,
    lastResult: lastResult,
    errorReason: errorReason,
    retryAttempts: retryAttempts,
    lastScanAt: lastScanAt,
    nextRetryAt: nextRetryAt,
  );
}

List<SavedController> buildSavedControllerListFixture(int count) {
  return List.generate(
    count,
    (_) => buildSavedControllerFixture(),
  );
}
