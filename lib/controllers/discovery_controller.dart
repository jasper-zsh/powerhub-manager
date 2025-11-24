import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/pwm_controller.dart';
import 'package:app/repositories/device_repository.dart';
import 'package:app/repositories/repository_providers.dart';

class DiscoveryState {
  const DiscoveryState({
    required this.isScanning,
    required this.devices,
    this.error,
    this.lastStartedAt,
    this.lastFinishedAt,
  });

  factory DiscoveryState.initial() => const DiscoveryState(
        isScanning: false,
        devices: <PWMController>[],
      );

  final bool isScanning;
  final List<PWMController> devices;
  final Object? error;
  final DateTime? lastStartedAt;
  final DateTime? lastFinishedAt;

  bool get hasError => error != null;

  DiscoveryState copyWith({
    bool? isScanning,
    List<PWMController>? devices,
    Object? error = _noUpdate,
    DateTime? lastStartedAt,
    DateTime? lastFinishedAt,
  }) {
    return DiscoveryState(
      isScanning: isScanning ?? this.isScanning,
      devices: devices ?? this.devices,
      error: error == _noUpdate ? this.error : error,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastFinishedAt: lastFinishedAt ?? this.lastFinishedAt,
    );
  }
}

const _noUpdate = Object();

class DiscoveryController extends StateNotifier<DiscoveryState> {
  DiscoveryController({required DeviceRepository deviceRepository})
      : _deviceRepository = deviceRepository,
        super(DiscoveryState.initial()) {
    _scanSubscription = _deviceRepository.scanState.listen(_handleScanState);
    final current = _deviceRepository.currentScanState;
    _handleScanState(current);
  }

  final DeviceRepository _deviceRepository;
  StreamSubscription<DeviceScanState>? _scanSubscription;

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    if (state.isScanning) {
      return;
    }
    try {
      await _deviceRepository.scanForDevices(timeout: timeout);
    } catch (_) {
      // 错误已经通过仓库状态流传递，这里无需重复抛出
    }
  }

  void clearError() {
    if (state.error == null) {
      return;
    }
    state = state.copyWith(error: null);
  }

  void _handleScanState(DeviceScanState scanState) {
    final devicesChanged = !listEquals(scanState.devices, state.devices);
    state = state.copyWith(
      isScanning: scanState.status == DeviceScanStatus.inProgress,
      devices: devicesChanged ? List.unmodifiable(scanState.devices) : state.devices,
      error: scanState.hasError ? scanState.error : null,
      lastStartedAt: scanState.startedAt ?? state.lastStartedAt,
      lastFinishedAt: scanState.finishedAt ?? state.lastFinishedAt,
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

final discoveryControllerProvider =
    StateNotifierProvider<DiscoveryController, DiscoveryState>((ref) {
  final repository = ref.watch(deviceRepositoryProvider);
  return DiscoveryController(deviceRepository: repository);
});
