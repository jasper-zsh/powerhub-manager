import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/providers/orchestration_provider_riverpod.dart';
import 'package:app/services/switch_hub_ble_service.dart';
import 'package:app/utils/ble_uuid.dart';

class SwitchHubState {
  const SwitchHubState({
    required this.isScanning,
    required this.isPushing,
    required this.discoveredDevices,
    required this.hasInitialized,
    this.statusMessage,
    this.errorMessage,
  });

  factory SwitchHubState.initial() => const SwitchHubState(
    isScanning: false,
    isPushing: false,
    discoveredDevices: <BluetoothDevice>[],
    hasInitialized: false,
  );

  final bool isScanning;
  final bool isPushing;
  final List<BluetoothDevice> discoveredDevices;
  final bool hasInitialized;
  final String? statusMessage;
  final String? errorMessage;

  SwitchHubState copyWith({
    bool? isScanning,
    bool? isPushing,
    List<BluetoothDevice>? discoveredDevices,
    bool? hasInitialized,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    final nextDevices = discoveredDevices ?? this.discoveredDevices;
    return SwitchHubState(
      isScanning: isScanning ?? this.isScanning,
      isPushing: isPushing ?? this.isPushing,
      discoveredDevices: List<BluetoothDevice>.unmodifiable(nextDevices),
      hasInitialized: hasInitialized ?? this.hasInitialized,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class SwitchHubController extends StateNotifier<SwitchHubState> {
  SwitchHubController(this.ref, {SwitchHubBleService? bleService})
    : _bleService = bleService ?? const SwitchHubBleService(),
      super(SwitchHubState.initial());

  final Ref ref;
  final SwitchHubBleService _bleService;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<void> initialize() async {
    if (state.hasInitialized) {
      return;
    }
    final orchestration = ref.read(orchestrationProviderProvider);
    if (orchestration.scenes.isEmpty) {
      await orchestration.init();
    }
    state = state.copyWith(hasInitialized: true);
  }

  Future<void> startScan() async {
    if (state.isScanning) {
      return;
    }
    state = state.copyWith(
      isScanning: true,
      discoveredDevices: const <BluetoothDevice>[],
      clearStatusMessage: true,
      clearErrorMessage: true,
    );

    final discovered = <BluetoothDevice>[];
    try {
      await _ensureBluetoothPermissions();
      if (!await FlutterBluePlus.isSupported) {
        throw Exception('设备不支持蓝牙');
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        var changed = false;
        for (final result in results) {
          _logScanResult(result);
          if (_isSwitchHub(result) &&
              !discovered.any(
                (device) => device.remoteId.str == result.device.remoteId.str,
              )) {
            discovered.add(result.device);
            changed = true;
          }
        }
        if (changed) {
          state = state.copyWith(
            discoveredDevices: List<BluetoothDevice>.unmodifiable(discovered),
          );
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
      state = state.copyWith(
        statusMessage: '发现 ${discovered.length} 个 SwitchHub 设备',
      );
    } catch (error) {
      state = state.copyWith(errorMessage: '扫描失败: $error');
    } finally {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      state = state.copyWith(isScanning: false);
    }
  }

  void _logScanResult(ScanResult result) {
    if (!kDebugMode) {
      return;
    }
    final adv = result.advertisementData;
    debugPrint('SwitchHub scan → ${result.device.remoteId.str}');
    debugPrint('  Name: ${result.device.platformName} · adv: ${adv.advName}');
    debugPrint('  RSSI: ${result.rssi}');
    debugPrint(
      '  Services: ${adv.serviceUuids.map((uuid) => uuid.str).toList()}',
    );
  }

  Future<bool> pushConfigToDevice(
    BluetoothDevice device,
    SwitchHubConfig config, {
    bool includeFontGeneration = true,
    int fontSize = 16,
    int bpp = 2,
  }) async {
    if (state.isPushing) {
      return false;
    }
    state = state.copyWith(
      isPushing: true,
      clearStatusMessage: true,
      clearErrorMessage: true,
    );
    try {
      // Push configuration first
      await _bleService.pushConfig(device, config);

      // Generate and push font data if requested
      if (includeFontGeneration) {
        await _bleService.generateAndPushFontData(
          device,
          config,
          fontSize: fontSize,
          bpp: bpp,
          onProgress: (sequence, totalSequences, percentage) {
            state = state.copyWith(statusMessage: '字库推送中: $sequence/$totalSequences ($percentage%)');
          },
        );
      }

      state = state.copyWith(
        isPushing: false,
        statusMessage: '配置推送成功: ${device.remoteId.str}',
      );
      return true;
    } catch (error) {
      state = state.copyWith(isPushing: false, errorMessage: '推送失败: $error');
      return false;
    }
  }

  Future<int> pushConfigToAll(
    Iterable<BluetoothDevice> devices,
    SwitchHubConfig config, {
    bool includeFontGeneration = true,
    int fontSize = 16,
    int bpp = 2,
  }) async {
    if (state.isPushing) {
      return 0;
    }
    state = state.copyWith(
      isPushing: true,
      clearStatusMessage: true,
      clearErrorMessage: true,
    );
    final targets = devices.toList(growable: false);
    var successCount = 0;
    try {
      for (final device in targets) {
        try {
          // Push configuration first
          await _bleService.pushConfig(device, config);

          // Generate and push font data if requested
          if (includeFontGeneration) {
            await _bleService.generateAndPushFontData(
              device,
              config,
              fontSize: fontSize,
              bpp: bpp,
              onProgress: (sequence, totalSequences, percentage) {
                state = state.copyWith(
                  statusMessage:
                      '字库推送中 (${device.remoteId.str}): $sequence/$totalSequences ($percentage%)',
                );
              },
            );
          }

          successCount++;
        } catch (_) {}
      }
      state = state.copyWith(
        isPushing: false,
        statusMessage: '批量推送完成: $successCount/${targets.length}',
      );
      return successCount;
    } catch (error) {
      state = state.copyWith(isPushing: false, errorMessage: '批量推送失败: $error');
      return successCount;
    }
  }

  void clearStatusMessage() {
    if (state.statusMessage != null) {
      state = state.copyWith(clearStatusMessage: true);
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearErrorMessage: true);
    }
  }

  Future<void> _ensureBluetoothPermissions() async {
    final permissions = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ];
    for (final permission in permissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        throw Exception('缺少蓝牙权限: ${permission.toString()}');
      }
    }
  }

  bool _isSwitchHub(ScanResult result) {
    final adv = result.advertisementData;
    if (_advertisesSwitchHubService(result)) {
      return true;
    }
    final platformName = result.device.platformName;
    final advName = adv.advName ?? '';
    final normalizedName = (advName.isNotEmpty ? advName : platformName)
        .toLowerCase();
    return normalizedName.contains('switchhub');
  }

  bool _advertisesSwitchHubService(ScanResult result) {
    bool matchesGuid(Iterable<Guid> guids) {
      return guids.any(
        (guid) =>
            guid == _switchHubServiceGuid ||
            guid == _switchHubServiceGuidReversed,
      );
    }

    final adv = result.advertisementData;
    if (matchesGuid(adv.serviceUuids)) {
      return true;
    }
    if (matchesGuid(adv.serviceData.keys)) {
      return true;
    }
    return false;
  }

  static final Guid _switchHubServiceGuid = SwitchHubBleService.serviceUuid;
  static final Guid _switchHubServiceGuidReversed = reverseBleUuid(
    SwitchHubBleService.serviceUuid.str,
  );

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}

final switchHubControllerProvider =
    StateNotifierProvider.autoDispose<SwitchHubController, SwitchHubState>((
      ref,
    ) {
      return SwitchHubController(ref);
    });
