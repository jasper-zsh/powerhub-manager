import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/monitoring_data.dart';
import 'package:app/models/switch_hub/voltage_thresholds.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/providers/orchestration_provider_riverpod.dart';
import 'package:app/services/switch_hub_ble_service.dart';
import 'package:app/services/powerhub_command_translator.dart';
import 'package:app/utils/ble_uuid.dart';

class SwitchHubState {
  const SwitchHubState({
    required this.isScanning,
    required this.isPushing,
    required this.discoveredDevices,
    required this.hasInitialized,
    this.statusMessage,
    this.errorMessage,
    this.monitoringData,
    this.voltageThresholds,
    this.isMonitoring = false,
    this.monitoringSubscription,
  });

  factory SwitchHubState.initial() => const SwitchHubState(
    isScanning: false,
    isPushing: false,
    discoveredDevices: <BluetoothDevice>[],
    hasInitialized: false,
    isMonitoring: false,
  );

  final bool isScanning;
  final bool isPushing;
  final bool isMonitoring;
  final List<BluetoothDevice> discoveredDevices;
  final bool hasInitialized;
  final String? statusMessage;
  final String? errorMessage;
  final SwitchHubMonitoringData? monitoringData;
  final SwitchHubVoltageThresholds? voltageThresholds;
  final StreamSubscription<SwitchHubMonitoringData>? monitoringSubscription;

  SwitchHubState copyWith({
    bool? isScanning,
    bool? isPushing,
    bool? isMonitoring,
    List<BluetoothDevice>? discoveredDevices,
    bool? hasInitialized,
    String? statusMessage,
    bool clearStatusMessage = false,
    String? errorMessage,
    bool clearErrorMessage = false,
    SwitchHubMonitoringData? monitoringData,
    SwitchHubVoltageThresholds? voltageThresholds,
    StreamSubscription<SwitchHubMonitoringData>? monitoringSubscription,
    bool clearMonitoringSubscription = false,
  }) {
    final nextDevices = discoveredDevices ?? this.discoveredDevices;
    return SwitchHubState(
      isScanning: isScanning ?? this.isScanning,
      isPushing: isPushing ?? this.isPushing,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      discoveredDevices: List<BluetoothDevice>.unmodifiable(nextDevices),
      hasInitialized: hasInitialized ?? this.hasInitialized,
      statusMessage: clearStatusMessage
          ? null
          : (statusMessage ?? this.statusMessage),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      monitoringData: monitoringData ?? this.monitoringData,
      voltageThresholds: voltageThresholds ?? this.voltageThresholds,
      monitoringSubscription: clearMonitoringSubscription
          ? null
          : (monitoringSubscription ?? this.monitoringSubscription),
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
  StreamSubscription<bool>? _scanStateSubscription;
  StreamSubscription<SwitchHubMonitoringData>? _monitoringSubscription;

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

      debugPrint('[SwitchHubController] Starting scan with service filtering for ${SwitchHubBleService.serviceUuid}');
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 8),
        androidUsesFineLocation: true,
        withServices: [SwitchHubBleService.serviceUuid],
      );
      debugPrint('[SwitchHubController] Scan started');

      _scanStateSubscription = FlutterBluePlus.isScanning.listen((isScanning) {
        debugPrint('[SwitchHubController] isScanning=$isScanning');
        if (!isScanning) {
          // Don't reference scanStateSub here to avoid circular reference
          _finishScan();
        }
      });

      // Wait until scanning stops (either timeout or explicit stop).
      await FlutterBluePlus.isScanning.firstWhere((isScanning) => !isScanning);

      state = state.copyWith(
        statusMessage: '发现 ${discovered.length} 个 SwitchHub 设备',
      );
    } catch (error) {
      // scanStateSub is handled inside the listen callback, no need to cancel here
      _finishScan();
      state = state.copyWith(errorMessage: '扫描失败: $error');
      debugPrint('[SwitchHubController] Scan error: $error');
    }
  }

  void _finishScan() {
    debugPrint('[SwitchHubController] Scan stopped');
    _scanSubscription?.cancel();
    _scanSubscription = null;
    state = state.copyWith(isScanning: false);
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
    final advName = adv.advName;
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

  /// Read current monitoring data from a SwitchHub device
  Future<SwitchHubMonitoringData?> readMonitoringData(BluetoothDevice device) async {
    try {
      final data = await _bleService.readMonitoringData(device);
      state = state.copyWith(
        monitoringData: data,
        statusMessage: '监测数据更新: ${data.inputVoltageMv}mV (${data.batteryPercentage.toStringAsFixed(1)}%)',
      );
      return data;
    } catch (e) {
      state = state.copyWith(errorMessage: '读取监测数据失败: $e');
      return null;
    }
  }

  /// Start real-time monitoring for a SwitchHub device
  Future<void> startMonitoring(BluetoothDevice device) async {
    if (state.isMonitoring) {
      await stopMonitoring();
    }

    try {
      state = state.copyWith(
        statusMessage: '开始监测设备: ${device.remoteId.str}',
      );

      _monitoringSubscription = _bleService
          .subscribeToMonitoringNotifications(device)
          .listen(
            (data) {
              state = state.copyWith(monitoringData: data);
            },
            onError: (error) {
              state = state.copyWith(
                isMonitoring: false,
                errorMessage: '监测错误: $error',
                clearMonitoringSubscription: true,
              );
            },
          );

      state = state.copyWith(
        isMonitoring: true,
        monitoringSubscription: _monitoringSubscription,
        statusMessage: '实时监测已启动',
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: '启动监测失败: $e',
        clearMonitoringSubscription: true,
      );
    }
  }

  /// Stop real-time monitoring
  Future<void> stopMonitoring() async {
    if (_monitoringSubscription != null) {
      await _monitoringSubscription!.cancel();
      _monitoringSubscription = null;
    }

    state = state.copyWith(
      isMonitoring: false,
      clearMonitoringSubscription: true,
      statusMessage: '实时监测已停止',
    );
  }

  /// Read voltage thresholds from a SwitchHub device
  Future<SwitchHubVoltageThresholds?> readVoltageThresholds(BluetoothDevice device) async {
    try {
      final thresholds = await _bleService.readVoltageThresholds(device);
      state = state.copyWith(
        voltageThresholds: thresholds,
        statusMessage: '电压阈值已读取: 睡眠 ${thresholds.sleepVoltageMv}mV, 唤醒 ${thresholds.wakeVoltageMv}mV',
      );
      return thresholds;
    } catch (e) {
      state = state.copyWith(errorMessage: '读取电压阈值失败: $e');
      return null;
    }
  }

  /// Set voltage thresholds for a SwitchHub device
  Future<bool> setVoltageThresholds(
    BluetoothDevice device,
    SwitchHubVoltageThresholds thresholds,
  ) async {
    try {
      // Validate thresholds
      if (!thresholds.isValid()) {
        state = state.copyWith(
          errorMessage: '无效的电压阈值: ${thresholds.getValidationError()}',
        );
        return false;
      }

      state = state.copyWith(
        statusMessage: '设置电压阈值中...',
      );

      await _bleService.setVoltageThresholds(device, thresholds);

      state = state.copyWith(
        voltageThresholds: thresholds,
        statusMessage: '电压阈值设置成功: 睡眠 ${thresholds.sleepVoltageMv}mV, 唤醒 ${thresholds.wakeVoltageMv}mV',
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: '设置电压阈值失败: $e');
      return false;
    }
  }

  /// Read configuration with chunked transfer support
  Future<SwitchHubConfig?> readConfigWithChunks(
    BluetoothDevice device, {
    Function(int currentChunk, int totalChunks, int percentage)? onProgress,
  }) async {
    try {
      state = state.copyWith(
        statusMessage: '正在读取设备配置...',
      );

      final config = await _bleService.readConfigWithChunks(
        device,
        onProgress: (currentChunk, totalChunks, percentage) {
          state = state.copyWith(
            statusMessage: '读取配置中: $currentChunk/$totalChunks ($percentage%)',
          );
          onProgress?.call(currentChunk, totalChunks, percentage);
        },
      );

      state = state.copyWith(
        statusMessage: '配置读取成功 (架构版本: ${config.schemaVersion})',
      );
      return config;
    } catch (e) {
      state = state.copyWith(errorMessage: '读取配置失败: $e');
      return null;
    }
  }

  /// Test PowerHub device connectivity
  Future<bool> testPowerHubConnection(String targetMac) async {
    try {
      if (!PowerHubCommandTranslator.isValidMacAddress(targetMac)) {
        state = state.copyWith(
          errorMessage: '无效的 MAC 地址格式: $targetMac',
        );
        return false;
      }

      state = state.copyWith(
        statusMessage: '测试 PowerHub 连接: $targetMac',
      );

      final isConnected = await PowerHubCommandTranslator.testPowerHubConnection(targetMac);

      state = state.copyWith(
        statusMessage: isConnected
            ? 'PowerHub 设备连接成功: $targetMac'
            : 'PowerHub 设备连接失败: $targetMac',
      );
      return isConnected;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'PowerHub 连接测试失败: $e',
      );
      return false;
    }
  }

  /// Execute SwitchHub command sequence
  Future<bool> executeSequenceItem(SwitchHubSequenceItem sequenceItem) async {
    try {
      if (!PowerHubCommandTranslator.isValidMacAddress(sequenceItem.targetMac)) {
        state = state.copyWith(
          errorMessage: '无效的目标 MAC 地址: ${sequenceItem.targetMac}',
        );
        return false;
      }

      state = state.copyWith(
        statusMessage: '执行命令序列到: ${sequenceItem.targetMac}',
      );

      await PowerHubCommandTranslator.executeSequenceItem(
        sequenceItem,
        onProgress: (progress) {
          state = state.copyWith(statusMessage: progress);
        },
      );

      state = state.copyWith(
        statusMessage: '命令序列执行成功: ${sequenceItem.targetMac}',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: '命令序列执行失败: $e',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanStateSubscription?.cancel();
    _monitoringSubscription?.cancel();
    super.dispose();
  }
}
