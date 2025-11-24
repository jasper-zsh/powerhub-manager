import 'dart:async';

import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/services/ble_service.dart';

/// 表示一次扫描任务的最新状态
class DeviceScanState {
  const DeviceScanState({
    required this.status,
    this.devices = const <PWMController>[],
    this.error,
    this.startedAt,
    this.finishedAt,
  });

  const DeviceScanState.idle() : this(status: DeviceScanStatus.idle);

  final DeviceScanStatus status;
  final List<PWMController> devices;
  final Object? error;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  bool get hasError => status == DeviceScanStatus.failure && error != null;

  DeviceScanState copyWith({
    DeviceScanStatus? status,
    List<PWMController>? devices,
    Object? error = _noUpdate,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return DeviceScanState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      error: error == _noUpdate ? this.error : error,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }
}

enum DeviceScanStatus { idle, inProgress, success, failure }

const _noUpdate = Object();

abstract class DeviceRepository {
  DeviceScanState get currentScanState;
  Stream<DeviceScanState> get scanState;

  Future<List<PWMController>> scanForDevices({
    Duration timeout,
  });

  Future<Set<String>> scanForControllerIds(
    Iterable<String> controllerIds, {
    Duration timeout,
  });

  Future<void> connect(String controllerId);
  Future<void> disconnect();
  bool get isConnected;
  Map<String, dynamic> get connectionHealth;

  Future<List<int>> readChannelStates();
  Future<void> sendSetCommand(SetCommand command);
  Future<void> sendFadeCommand(FadeCommand command);
  Future<void> sendBlinkCommand(BlinkCommand command);
  Future<void> sendStrobeCommand(StrobeCommand command);
}

/// 直接使用 [BLEService] 的仓库实现，便于后续替换为模拟实现
class BleDeviceRepository implements DeviceRepository {
  BleDeviceRepository({BLEService? bleService})
      : _bleService = bleService ?? BLEService();

  final BLEService _bleService;
  final _scanStateController = StreamController<DeviceScanState>.broadcast();
  DeviceScanState _scanState = const DeviceScanState.idle();

  @override
  DeviceScanState get currentScanState => _scanState;

  @override
  Stream<DeviceScanState> get scanState => _scanStateController.stream;

  @override
  Future<List<PWMController>> scanForDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final startedAt = DateTime.now();
    _emitScanState(
      DeviceScanState(
        status: DeviceScanStatus.inProgress,
        startedAt: startedAt,
      ),
    );

    try {
      final devices = await _bleService.scanForDevices(
        timeout: timeout.inSeconds,
      );
      final next = DeviceScanState(
        status: DeviceScanStatus.success,
        devices: List.unmodifiable(devices),
        startedAt: startedAt,
        finishedAt: DateTime.now(),
      );
      _emitScanState(next);
      return devices;
    } catch (error, stackTrace) {
      final failure = DeviceScanState(
        status: DeviceScanStatus.failure,
        error: error,
        startedAt: startedAt,
        finishedAt: DateTime.now(),
      );
      _emitScanState(failure);
      Zone.current.handleUncaughtError(error, stackTrace);
      rethrow;
    }
  }

  @override
  Future<Set<String>> scanForControllerIds(
    Iterable<String> controllerIds, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _bleService.scanForControllerIds(
      controllerIds,
      timeout: timeout,
    );
  }

  @override
  Future<void> connect(String controllerId) {
    return _bleService.connect(controllerId);
  }

  @override
  Future<void> disconnect() {
    return _bleService.disconnect();
  }

  @override
  bool get isConnected => _bleService.isConnected;

  @override
  Map<String, dynamic> get connectionHealth =>
      _bleService.getConnectionHealthInfo();

  @override
  Future<List<int>> readChannelStates() {
    return _bleService.readChannelStates();
  }

  @override
  Future<void> sendBlinkCommand(BlinkCommand command) {
    return _bleService.sendBlinkCommand(command);
  }

  @override
  Future<void> sendFadeCommand(FadeCommand command) {
    return _bleService.sendFadeCommand(command);
  }

  @override
  Future<void> sendSetCommand(SetCommand command) {
    return _bleService.sendSetCommand(command);
  }

  @override
  Future<void> sendStrobeCommand(StrobeCommand command) {
    return _bleService.sendStrobeCommand(command);
  }

  void _emitScanState(DeviceScanState state) {
    _scanState = state;
    if (!_scanStateController.isClosed) {
      _scanStateController.add(state);
    }
  }

  void dispose() {
    if (!_scanStateController.isClosed) {
      unawaited(_scanStateController.close());
    }
  }
}
