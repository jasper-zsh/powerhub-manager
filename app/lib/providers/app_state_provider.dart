import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/storage_service.dart';
import 'package:app/services/reconnect_manager.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/models/telemetry.dart';
import 'package:app/models/power_management.dart';
import 'package:app/models/monitoring_data.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/models/connection_status_record.dart';

class AppStateProvider with ChangeNotifier {
  AppStateProvider({
    BLEService? bleService,
    StorageService? storageService,
    ReconnectConfig? reconnectConfig,
  })  : _bleService = bleService ?? BLEService(),
        _storageService = storageService ?? StorageService(),
        _reconnectConfig = reconnectConfig ?? const ReconnectConfig();

  final BLEService _bleService;
  final StorageService _storageService;
  final ReconnectConfig _reconnectConfig;
  ReconnectManager? _reconnectManager;

  PWMController? _selectedDevice;
  List<PWMController> _discoveredDevices = [];
  List<SavedController> _savedControllers = [];
  List<ConnectionStatusRecord> _connectionStatusRecords = [];
  bool _isScanning = false;
  String _errorMessage = '';
  TelemetryData? _telemetry;
  String _telemetryError = '';
  StreamSubscription<TelemetryData>? _telemetrySubscription;

  // 监控数据
  MonitoringData? _monitoringData;
  String _monitoringError = '';
  StreamSubscription<MonitoringData>? _monitoringSubscription;
  Timer? _reconnectTimer;
  bool _autoReconnectActive = false;
  bool _reconnectInProgress = false;

  // 连接状态监听
  Timer? _connectionStatusTimer;
  bool _lastConnectionState = false;

  /// 初始化重连管理器
  void _initializeReconnectManager() {
    _reconnectManager ??= ReconnectManager(
      appStateProvider: this,
      config: _reconnectConfig,
    );
  }

  /// 启动连接状态监听
  void _startConnectionStatusMonitoring() {
    debugPrint('AppStateProvider: Starting connection status monitoring');
    _connectionStatusTimer?.cancel();
    _connectionStatusTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkConnectionStatus();
    });

    // 立即检查一次
    _checkConnectionStatus();
  }

  /// 停止连接状态监听
  void _stopConnectionStatusMonitoring() {
    debugPrint('AppStateProvider: Stopping connection status monitoring');
    _connectionStatusTimer?.cancel();
    _connectionStatusTimer = null;
  }

  /// 检查连接状态变化
  void _checkConnectionStatus() {
    final currentConnectionState = isConnected;

    if (currentConnectionState != _lastConnectionState) {
      debugPrint('AppStateProvider: Connection status changed from $_lastConnectionState to $currentConnectionState');
      _lastConnectionState = currentConnectionState;

      // 如果连接状态改变，通知监听者
      notifyListeners();

      // 如果连接断开，清理相关状态
      if (!currentConnectionState) {
        _handleDisconnection();
      }
    }
  }

  /// 处理连接断开
  void _handleDisconnection() {
    debugPrint('AppStateProvider: Handling device disconnection');

    // 更新保存的控制器状态为断开
    if (_selectedDevice != null) {
      markControllerDisconnected(_selectedDevice!.id);
      debugPrint('AppStateProvider: Updated saved controller status to disconnected: ${_selectedDevice!.id}');
    }

    // 清理遥测数据
    _telemetry = null;
    _telemetryError = '';

    // 停止遥测订阅
    _telemetrySubscription?.cancel();
    _telemetrySubscription = null;

    // 清理监控数据
    _monitoringData = null;
    _monitoringError = '';

    // 停止监控订阅
    _monitoringSubscription?.cancel();
    _monitoringSubscription = null;

    // 尝试禁用遥测通知
    try {
      Future.microtask(() => _bleService.disableTelemetryNotifications());
    } catch (e) {
      debugPrint('AppStateProvider: Error disabling telemetry notifications: $e');
    }

    // 停止监控通知
    try {
      Future.microtask(() => _bleService.disableMonitoringNotifications());
    } catch (e) {
      debugPrint('AppStateProvider: Error disabling monitoring notifications: $e');
    }

    // 清理通道状态通知
    try {
      Future.microtask(() => _bleService.disableChannelStateNotifications());
    } catch (e) {
      debugPrint('AppStateProvider: Error disabling channel state notifications: $e');
    }
  }

  /// 获取重连管理器
  ReconnectManager get reconnectManager {
    _initializeReconnectManager();
    return _reconnectManager!;
  }

  /// 获取重连统计信息
  Map<String, dynamic> get reconnectStatistics {
    return reconnectManager.getStatistics();
  }

  /// 手动触发重连
  Future<void> triggerReconnect() async {
    await reconnectManager.triggerReconnect();
  }

  /// 重置重连计数器
  void resetReconnectCounters() {
    reconnectManager.resetCounters();
  }

  /// 重置特定设备的重连计数器
  void resetReconnectCounter(String controllerId) {
    reconnectManager.resetCounter(controllerId);
  }

  // Getters
  PWMController? get selectedDevice => _selectedDevice;
  List<PWMController> get discoveredDevices => _discoveredDevices;
  List<SavedController> get savedControllers => List.unmodifiable(_savedControllers);
  List<ConnectionStatusRecord> get connectionStatusRecords =>
      List.unmodifiable(_connectionStatusRecords);
  ConnectionDashboardSummary get connectionDashboardSummary =>
      ConnectionDashboardSummary.fromControllers(_savedControllers);
  List<PWMController> get connectedControllers {
    final controllers = <PWMController>[];
    if (_selectedDevice != null && isConnected) {
      controllers.add(_selectedDevice!);
    }
    controllers.addAll(
      _discoveredDevices.where(
        (controller) =>
            controller.isConnected && controller.id != _selectedDevice?.id,
      ),
    );
    return controllers;
  }
  bool get isScanning => _isScanning;
  String get errorMessage => _errorMessage;
  bool get isConnected {
    // 使用BLE服务的健康检查结果
    if (_selectedDevice == null) return false;

    // 首先检查设备基础连接状态 - 这个检查已经在isConnected getter中包含了
    // 移除重复检查，直接使用BLE服务的健康状态检查

    // 使用BLE服务的健康连接状态
    final bleServiceHealth = _bleService.getConnectionHealthInfo();
    if (!bleServiceHealth['healthy']) return false;

    // 检查最近是否有成功操作
    final timeSinceLastSuccess = bleServiceHealth['timeSinceLastSuccess'] as int?;
    if (timeSinceLastSuccess != null && timeSinceLastSuccess > 60) {
      debugPrint('AppStateProvider: Connection considered stale (${timeSinceLastSuccess}s since last success)');
      return false;
    }

    return true;
  }
  TelemetryData? get telemetry => _telemetry ?? _selectedDevice?.telemetry;
  String get telemetryError => _telemetryError;

  // 监控数据getter
  MonitoringData? get monitoringData => _monitoringData;
  String get monitoringError => _monitoringError;

  bool get isThermalProtectionActive {
    // 优先使用监控数据
    if (_monitoringData?.statusFlags.thermalProtectionActive == true) {
      return true;
    }

    final telemetryData = telemetry;
    if (telemetryData == null) return false;
    return telemetryData.isThermalProtectionActive;
  }

  // 获取输入电压（优先使用监控数据）
  double? get inputVoltage {
    if (_monitoringData != null) {
      return _monitoringData!.inputVoltageVolts;
    }

    final telemetryData = telemetry;
    if (telemetryData == null) return null;
    return telemetryData.vinMillivolts / 1000.0;
  }

  // 获取电源区温度
  double? get powerZoneTemperature {
    return _monitoringData?.powerZoneTempCelsius;
  }

  // 获取控制区温度
  double? get controlZoneTemperature {
    return _monitoringData?.controlZoneTempCelsius;
  }

  // 检查是否有有效的温度数据
  bool get hasValidTemperatureData {
    if (_monitoringData != null) {
      return _monitoringData!.hasValidTempData;
    }

    final telemetryData = telemetry;
    return telemetryData != null && telemetryData.temperatureCelsius > -273;
  }
  PWMController? getConnectedController(String controllerId) {
    if (_selectedDevice != null &&
        _selectedDevice!.id == controllerId &&
        isConnected) {
      return _selectedDevice;
    }

    try {
      return _discoveredDevices.firstWhere(
        (controller) => controller.id == controllerId && controller.isConnected,
      );
    } catch (_) {
      return null;
    }
  }

  // Initialize the provider
  Future<void> init() async {
    debugPrint('AppStateProvider: Initializing...');
    await _storageService.init();
    await loadSavedControllers();
    debugPrint('AppStateProvider: Initialization completed');
  }

  Future<void> loadSavedControllers() async {
    debugPrint('AppStateProvider: Loading saved controllers from storage');
    final rawControllers = await _storageService.loadSavedControllers();
    _savedControllers = rawControllers
        .map(
          (controller) => controller.copyWith(
            connectionStatus: SavedControllerConnectionStatus.disconnected,
            retryPolicy: controller.retryPolicy.copyWith(
              attemptCount: 0,
              lastAttemptAt: null,
            ),
          ),
        )
        .toList();
    _connectionStatusRecords = [];
    _syncConnectionRecords();
    await _storageService.persistSavedControllers(_savedControllers);
    notifyListeners();
  }

  Future<SavedController> saveController({
    required String controllerId,
    required String alias,
    DeviceCapabilities? deviceCapabilities,
    String? notes,
  }) async {
    try {
      final savedController = SavedController(
        controllerId: controllerId,
        alias: alias,
        deviceCapabilities: deviceCapabilities,
        notes: notes,
      );

      final persisted = await _storageService.addSavedController(
        savedController,
      );

      _errorMessage = '';
      _upsertSavedController(persisted);
      notifyListeners();
      return persisted;
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString() ??
          'Alias already exists. Choose a different name.';
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = 'Failed to save controller: $error';
      notifyListeners();
      rethrow;
    }
  }

  void _upsertSavedController(SavedController controller) {
    final existingIndex = _savedControllers.indexWhere(
      (item) => item.controllerId == controller.controllerId,
    );

    if (existingIndex >= 0) {
      _savedControllers[existingIndex] = controller;
    } else {
      _savedControllers = List.of(_savedControllers)..add(controller);
    }
    _syncConnectionRecords();
  }

  void _syncConnectionRecords() {
    final existing = {
      for (final record in _connectionStatusRecords)
        record.controller.controllerId: record,
    };

    _connectionStatusRecords = _savedControllers
        .map(
          (controller) => existing[controller.controllerId]?.copyWith(
                controller: controller,
              ) ??
              ConnectionStatusRecord(controller: controller),
        )
        .toList();
  }

  void _updateSavedControllerConnectionStatus(
    String controllerId,
    SavedControllerConnectionStatus status, {
    DateTime? timestamp,
  }) {
    final index = _savedControllers.indexWhere(
      (controller) => controller.controllerId == controllerId,
    );
    if (index == -1) {
      debugPrint(
        'AppStateProvider: Unable to update connection status for $controllerId '
        '- controller not found',
      );
      return;
    }

    final current = _savedControllers[index];
    SavedController updated;
    final now = timestamp ?? DateTime.now();

    switch (status) {
      case SavedControllerConnectionStatus.connected:
        updated = current.touchConnectedAt(now);
        break;
      case SavedControllerConnectionStatus.connecting:
        updated = current.copyWith(
          connectionStatus: SavedControllerConnectionStatus.connecting,
          retryPolicy: current.retryPolicy.copyWith(
            lastAttemptAt: now,
          ),
        );
        break;
      case SavedControllerConnectionStatus.disconnected:
        updated = current.markDisconnected();
        break;
      case SavedControllerConnectionStatus.unavailable:
        updated = current.markUnavailable();
        break;
    }

    _savedControllers[index] = updated;
    _syncConnectionRecords();
    debugPrint(
      'AppStateProvider: Updated $controllerId status -> ${updated.connectionStatus}',
    );
    unawaited(_storageService.persistSavedControllers(_savedControllers));
    notifyListeners();
  }

  void markControllerConnected(String controllerId) {
    debugPrint('AppStateProvider: markControllerConnected($controllerId)');

    // 验证设备是否真的连接了
    if (!isConnected) {
      debugPrint('AppStateProvider: WARNING - markControllerConnected called but device is not actually connected');
      return;
    }

    if (_selectedDevice?.id != controllerId) {
      debugPrint('AppStateProvider: WARNING - markControllerConnected called for wrong device (expected: ${_selectedDevice?.id}, got: $controllerId)');
      return;
    }

    _updateSavedControllerConnectionStatus(
      controllerId,
      SavedControllerConnectionStatus.connected,
    );
  }

  void markControllerDisconnected(String controllerId) {
    debugPrint('AppStateProvider: markControllerDisconnected($controllerId)');
    _updateSavedControllerConnectionStatus(
      controllerId,
      SavedControllerConnectionStatus.disconnected,
    );
  }

  void markControllerUnavailable(String controllerId) {
    debugPrint('AppStateProvider: markControllerUnavailable($controllerId)');
    _updateSavedControllerConnectionStatus(
      controllerId,
      SavedControllerConnectionStatus.unavailable,
    );
  }

  void markControllerConnecting(String controllerId) {
    debugPrint('AppStateProvider: markControllerConnecting($controllerId)');
    _updateSavedControllerConnectionStatus(
      controllerId,
      SavedControllerConnectionStatus.connecting,
    );
  }

  Future<SavedController> renameSavedController(
    String controllerId,
    String alias,
  ) async {
    try {
      final updated = await _storageService.renameSavedController(
        controllerId,
        alias,
      );

      _savedControllers = _savedControllers
          .map((controller) => controller.controllerId == controllerId
              ? updated
              : controller)
          .toList();
      _syncConnectionRecords();
      _errorMessage = '';
      notifyListeners();
      return updated;
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString() ?? 'Alias already exists.';
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = 'Failed to rename controller: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> removeSavedController(String controllerId) async {
    try {
      final updatedControllers = await _storageService.removeSavedController(
        controllerId,
      );

      _savedControllers = updatedControllers;
      _syncConnectionRecords();
      _errorMessage = '';
      notifyListeners();
    } on ArgumentError catch (error) {
      _errorMessage = error.message?.toString() ?? 'Saved controller not found';
      notifyListeners();
      rethrow;
    } catch (error) {
      _errorMessage = 'Failed to remove controller: $error';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> reorderSavedControllers(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final controllers = List<SavedController>.from(_savedControllers);
    final item = controllers.removeAt(oldIndex);
    controllers.insert(newIndex, item);
    _savedControllers = controllers;
    _syncConnectionRecords();
    await _storageService.persistSavedControllers(_savedControllers);
    notifyListeners();
  }

  Future<void> reconcileSavedControllers({DateTime? currentTime}) async {
    if (_savedControllers.isEmpty) {
      return;
    }

    final now = currentTime ?? DateTime.now();
    final controllerMap = {
      for (final controller in _savedControllers)
        controller.controllerId: controller,
    };

    final recordMap = {
      for (final record in _connectionStatusRecords)
        record.controller.controllerId: record,
    };

    final attemptIds = <String>{};

    for (final controller in _savedControllers) {
      final record = recordMap[controller.controllerId] ??
          ConnectionStatusRecord(controller: controller);

      if (controller.connectionStatus ==
          SavedControllerConnectionStatus.connected) {
        recordMap[controller.controllerId] = record.copyWith(
          controller: controller,
          scanState: ScanState.idle,
          lastResult: LastScanResult.found,
          retryAttempts: 0,
          nextRetryAt: null,
          errorReason: null,
        );
        continue;
      }

      final shouldWait = record.scanState == ScanState.waitingRetry &&
          record.nextRetryAt != null &&
          record.nextRetryAt!.isAfter(now);

      if (shouldWait) {
        recordMap[controller.controllerId] = record.copyWith(
          controller: controller,
        );
        continue;
      }

      final incremented = controller.incrementRetry(now);
      controllerMap[controller.controllerId] = incremented;
      attemptIds.add(controller.controllerId);
      recordMap[controller.controllerId] = record.copyWith(
        controller: incremented,
        scanState: ScanState.scanning,
        lastScanAt: now,
        retryAttempts: incremented.retryPolicy.attemptCount,
      );
    }

    Set<String> availableIds = <String>{};

    if (attemptIds.isNotEmpty) {
      try {
        availableIds = await _bleService.scanForControllerIds(
          attemptIds,
        );
        if (availableIds.isNotEmpty) {
          _errorMessage = '';
        }
      } catch (error) {
        _errorMessage = 'Failed to scan for saved controllers: $error';
      }
    }

    for (final controllerId in attemptIds) {
      var controller = controllerMap[controllerId]!;
      var record = recordMap[controllerId]!;

      if (availableIds.contains(controllerId)) {
        final alreadyConnected = getConnectedController(controllerId);
        if (alreadyConnected != null && alreadyConnected.isConnected) {
          debugPrint(
            'reconcileSavedControllers: $controllerId already connected, skipping reconnect',
          );
          controller = controller.touchConnectedAt(now);
          record = record.copyWith(
            controller: controller,
            scanState: ScanState.idle,
            lastResult: LastScanResult.found,
            retryAttempts: 0,
            nextRetryAt: null,
            errorReason: null,
          );
        } else {
          try {
            await _bleService.connect(controllerId);
            controller = controller.touchConnectedAt(now);
            record = record.copyWith(
              controller: controller,
              scanState: ScanState.idle,
              lastResult: LastScanResult.found,
              retryAttempts: 0,
              nextRetryAt: null,
              errorReason: null,
            );
          } catch (error) {
            final exhausted = controller.retryPolicy.attemptCount >=
                controller.retryPolicy.maxAttempts;
            controller =
                exhausted ? controller.markUnavailable() : controller.markDisconnected();
            record = record.copyWith(
              controller: controller,
              scanState: exhausted ? ScanState.idle : ScanState.waitingRetry,
              lastResult: LastScanResult.error,
              errorReason: error.toString(),
              retryAttempts: controller.retryPolicy.attemptCount,
              nextRetryAt:
                  exhausted ? null : now.add(controller.retryPolicy.backoff),
              lastScanAt: now,
            );
            _errorMessage = 'Failed to connect to ${controller.alias}: $error';
          }
        }
      } else {
        final exhausted = controller.retryPolicy.attemptCount >=
            controller.retryPolicy.maxAttempts;

        final alreadyConnected = getConnectedController(controllerId);
        if (alreadyConnected != null && alreadyConnected.isConnected) {
          debugPrint(
            'reconcileSavedControllers: $controllerId reported missing but active connection detected',
          );
          controller = controller.touchConnectedAt(now);
          record = record.copyWith(
            controller: controller,
            scanState: ScanState.idle,
            lastResult: LastScanResult.found,
            retryAttempts: 0,
            nextRetryAt: null,
            errorReason: null,
          );
        } else {
          controller =
              exhausted ? controller.markUnavailable() : controller.markDisconnected();

          record = record.copyWith(
            controller: controller,
            scanState: exhausted ? ScanState.idle : ScanState.waitingRetry,
            lastResult: LastScanResult.notFound,
            retryAttempts: controller.retryPolicy.attemptCount,
            nextRetryAt:
                exhausted ? null : now.add(controller.retryPolicy.backoff),
            lastScanAt: now,
            errorReason: exhausted ? 'Device unreachable' : null,
          );
        }
      }

      controllerMap[controllerId] = controller;
      recordMap[controllerId] = record;
    }

    _savedControllers = _savedControllers
        .map((controller) => controllerMap[controller.controllerId]!)
        .toList();

    _connectionStatusRecords = _savedControllers
        .map(
          (controller) => recordMap[controller.controllerId] ??
              ConnectionStatusRecord(controller: controller),
        )
        .toList();

    await _storageService.persistSavedControllers(_savedControllers);
    notifyListeners();
  }

  void startAutoReconnectLoop() {
    if (_autoReconnectActive) {
      return;
    }
    _autoReconnectActive = true;
    reconnectManager.start();
    debugPrint('AppStateProvider: Started enhanced auto reconnect loop');
  }

  void stopAutoReconnectLoop() {
    _autoReconnectActive = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    reconnectManager.stop();
    debugPrint('AppStateProvider: Stopped enhanced auto reconnect loop');
  }

  
  // Scan for devices
  Future<void> scanForDevices({int timeout = 10}) async {
    _isScanning = true;
    _errorMessage = '';
    debugPrint('AppStateProvider: Starting device scan...');
    notifyListeners();

    try {
      _discoveredDevices = await _bleService.scanForDevices(timeout: timeout);
      debugPrint(
        'AppStateProvider: Scan completed. Found ${_discoveredDevices.length} devices.',
      );
    } catch (e) {
      debugPrint('AppStateProvider: Scan failed with error: $e');
      String error = e.toString();
      if (error.contains('PERMISSION_DENIED')) {
        _errorMessage =
            'Bluetooth permission denied. Please grant Bluetooth permissions in app settings and try again.';
      } else if (error.contains('BLE_NOT_SUPPORTED')) {
        _errorMessage = 'Bluetooth is not supported on this device.';
      } else {
        _errorMessage =
            'Failed to scan for devices. Please make sure Bluetooth is enabled and try again.';
      }
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  // Connect to a device
  Future<void> connectToDevice(String deviceId) async {
    debugPrint('AppStateProvider: Attempting to connect to device: $deviceId');
    _errorMessage = '';
    notifyListeners();

    try {
      markControllerConnecting(deviceId);

      await _bleService.connect(deviceId);

      PWMController? device = _discoveredDevices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () {
          debugPrint(
            'Device not found in discovered devices, creating new one',
          );
          return PWMController(id: deviceId, name: 'Unknown Device', rssi: 0);
        },
      );

      device.connect();
      _selectedDevice = device;

      // Reset reconnect counter when connection succeeds
      reconnectManager.resetReconnectForController(deviceId);

      debugPrint(
        'AppStateProvider: Successfully connected to device: ${device.name}',
      );

      // 启动连接状态监听
      _startConnectionStatusMonitoring();

      // 给BLE服务时间启动健康检查
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint(
        'AppStateProvider: Attempting to read initial channel states...',
      );
      await readChannelStates();
      debugPrint('AppStateProvider: Completed initial channel states read');

      // 只有在成功读取通道状态后才标记为已连接
      if (isConnected) {
        markControllerConnected(deviceId);
        debugPrint('AppStateProvider: Device connection confirmed and marked as connected');
      } else {
        debugPrint('AppStateProvider: WARNING - Connection established but health check failed');
      }

      debugPrint('AppStateProvider: Initializing telemetry stream...');
      await _initializeTelemetry();
      debugPrint('AppStateProvider: Telemetry initialized');

      debugPrint('AppStateProvider: Initializing monitoring stream...');
      await _initializeMonitoring();
      debugPrint('AppStateProvider: Monitoring initialized');
    } catch (e) {
      debugPrint('AppStateProvider: Connection failed with error: $e');
      markControllerDisconnected(deviceId);
      String error = e.toString();
      if (error.contains('DEVICE_NOT_FOUND')) {
        _errorMessage =
            'Device not found. Please make sure the device is powered on and in range.';
      } else if (error.contains('CONNECTION_FAILED')) {
        _errorMessage = 'Failed to connect to device. Please try again.';
      } else if (error.contains('TIMEOUT')) {
        _errorMessage = 'Connection timeout. Please try again.';
      } else if (error.contains('PERMISSION')) {
        _errorMessage =
            'Connection failed due to permissions. Please check Bluetooth permissions.';
      } else {
        _errorMessage = 'Connection failed: $error';
      }
    } finally {
      notifyListeners();
    }
  }

  // Disconnect from the current device
  Future<void> disconnectFromDevice() async {
    debugPrint('AppStateProvider: Disconnecting from device');
    _errorMessage = '';

    // 停止连接状态监听
    _stopConnectionStatusMonitoring();

    notifyListeners();

    try {
      final controllerId = _selectedDevice?.id;
      await _bleService.disconnect();
      if (_telemetrySubscription != null) {
        await _telemetrySubscription!.cancel();
        _telemetrySubscription = null;
      }
      await _bleService.disableTelemetryNotifications();
      _telemetry = null;
      _telemetryError = '';
      _selectedDevice?.disconnect();
      _selectedDevice = null;
      if (controllerId != null) {
        markControllerDisconnected(controllerId);
      }
      debugPrint('AppStateProvider: Successfully disconnected');
    } catch (e) {
      debugPrint('AppStateProvider: Disconnect failed with error: $e');
      _errorMessage = 'Failed to disconnect: $e';
    } finally {
      notifyListeners();
    }
  }

  // Read channel states from the connected device
  Future<void> readChannelStates() async {
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: Not connected to device, skipping readChannelStates',
      );
      return;
    }

    debugPrint('AppStateProvider: Reading channel states...');
    _errorMessage = '';
    notifyListeners();

    try {
      List<int> states = await _bleService.readChannelStates();
      debugPrint('AppStateProvider: Read channel states: $states');

      for (
        int i = 0;
        i < states.length && i < _selectedDevice!.channels.length;
        i++
      ) {
        _selectedDevice!.channels[i].updateValue(states[i]);
        debugPrint(
          'AppStateProvider: Updated channel $i to value ${states[i]}',
        );
      }
    } catch (e) {
      debugPrint(
        'AppStateProvider: Failed to read channel states with error: $e',
      );
      String error = e.toString();
      if (error.contains('NOT_CONNECTED')) {
        _errorMessage = 'Not connected to device.';
      } else if (error.contains('SERVICE_NOT_AVAILABLE')) {
        _errorMessage = 'Service not available.';
      } else if (error.contains('CHARACTERISTIC_NOT_FOUND')) {
        _errorMessage = 'Channel states characteristic not found.';
      } else if (error.contains('INVALID_DATA')) {
        _errorMessage = 'Invalid data received from device.';
      } else if (error.contains('TIMEOUT')) {
        _errorMessage = 'Read operation timed out.';
      } else {
        _errorMessage = 'Failed to read channel states: $error';
      }
    } finally {
      notifyListeners();
    }
  }

  Future<void> _refreshTelemetrySnapshot({bool fireListeners = true}) async {
    if (!isConnected) {
      return;
    }

    try {
      final snapshot = await _bleService.readTelemetrySnapshot();
      _telemetry = snapshot;
      _selectedDevice?.updateTelemetry(snapshot);
      _telemetryError = '';
    } catch (e) {
      _telemetryError = '读取设备遥测失败: $e';
    } finally {
      if (fireListeners) {
        notifyListeners();
      }
    }
  }

  Future<void> _initializeTelemetry() async {
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: Telemetry initialization skipped - no device connected',
      );
      return;
    }

    await _refreshTelemetrySnapshot();

    try {
      final stream = await _bleService.enableTelemetryNotifications();

      if (_telemetrySubscription != null) {
        await _telemetrySubscription!.cancel();
      }

      _telemetrySubscription = stream.listen(
        (telemetryUpdate) {
          _telemetry = telemetryUpdate;
          _selectedDevice?.updateTelemetry(telemetryUpdate);
          _telemetryError = '';
          notifyListeners();
        },
        onError: (error) {
          _telemetryError = '遥测更新失败: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      _telemetryError = '遥测订阅失败: $e';
      notifyListeners();
    }
  }

  Future<void> _initializeMonitoring() async {
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: Monitoring initialization skipped - no device connected',
      );
      return;
    }

    try {
      final stream = await enableMonitoringNotifications();

      if (_monitoringSubscription != null) {
        await _monitoringSubscription!.cancel();
      }

      _monitoringSubscription = stream.listen(
        (monitoringUpdate) {
          _monitoringData = monitoringUpdate;
          _monitoringError = '';
          notifyListeners();
        },
        onError: (error) {
          _monitoringError = '监控更新失败: $error';
          notifyListeners();
        },
      );
    } catch (e) {
      _monitoringError = '监控订阅失败: $e';
      notifyListeners();
    }
  }

  Future<void> refreshTelemetry() async {
    await _refreshTelemetrySnapshot();
  }

  Future<void> setSleepThreshold(int millivolts) async {
    await _sendTelemetryCommand(
      commandId: 0x01,
      parameter: millivolts,
      validator: (value) => value >= 0 && value <= 65535,
      validationError: '睡眠电压阈值必须在 0-65535 mV 范围内。',
    );
  }

  Future<void> setWakeThreshold(int millivolts) async {
    await _sendTelemetryCommand(
      commandId: 0x02,
      parameter: millivolts,
      validator: (value) => value >= 0 && value <= 65535,
      validationError: '唤醒电压阈值必须在 0-65535 mV 范围内。',
    );
  }

  Future<void> forceSleep() async {
    await _sendTelemetryCommand(
      commandId: 0x03,
      parameter: 0,
      refreshAfter: true,
    );
  }

  Future<void> forceWake() async {
    await _sendTelemetryCommand(
      commandId: 0x04,
      parameter: 0,
      refreshAfter: true,
    );
  }

  Future<void> setHighTemperatureThreshold(int centiDegrees) async {
    await _sendTelemetryCommand(
      commandId: 0x11,
      parameter: centiDegrees,
      validator: (value) => value >= -32768 && value <= 32767,
      validationError: '高温阈值必须在 -327.68 至 327.67 摄氏度之间。',
    );
  }

  Future<void> setRecoverTemperatureThreshold(int centiDegrees) async {
    await _sendTelemetryCommand(
      commandId: 0x12,
      parameter: centiDegrees,
      validator: (value) => value >= -32768 && value <= 32767,
      validationError: '恢复阈值必须在 -327.68 至 327.67 摄氏度之间。',
    );
  }

  Future<void> _sendTelemetryCommand({
    required int commandId,
    required int parameter,
    bool Function(int value)? validator,
    String? validationError,
    bool refreshAfter = true,
  }) async {
    if (!isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    if (validator != null && !validator(parameter)) {
      throw ArgumentError(validationError ?? '遥测参数不合法');
    }

    try {
      await _bleService.sendTelemetryCommand(
        commandId: commandId,
        parameter: parameter,
      );

      if (refreshAfter) {
        await _refreshTelemetrySnapshot();
      }
    } catch (e) {
      _telemetryError = '遥测指令发送失败: $e';
      notifyListeners();
      rethrow;
    }
  }

  
  // Power Management Methods

  Future<PowerManagementConfig> readPowerManagementConfig() async {
    if (!isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    try {
      return await _bleService.readPowerManagementConfig();
    } catch (e) {
      _errorMessage = 'Failed to read power management config: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendPowerCommand(PowerCommand command) async {
    if (!isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    try {
      await _bleService.sendPowerCommand(command);
    } catch (e) {
      _errorMessage = 'Failed to send power command: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Monitoring Methods

  Future<MonitoringData> readMonitoringData() async {
    if (!isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    try {
      return await _bleService.readMonitoringData();
    } catch (e) {
      _errorMessage = 'Failed to read monitoring data: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Stream<MonitoringData>> enableMonitoringNotifications() async {
    if (!isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    try {
      return await _bleService.enableMonitoringNotifications();
    } catch (e) {
      _errorMessage = 'Failed to enable monitoring notifications: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disableMonitoringNotifications() async {
    try {
      await _bleService.disableMonitoringNotifications();
    } catch (e) {
      debugPrint('Failed to disable monitoring notifications: $e');
    }
  }

  // Channel state notifications

  Future<Stream<List<int>>> enableChannelStateNotifications() async {
    if (!isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    try {
      return await _bleService.enableChannelStateNotifications();
    } catch (e) {
      _errorMessage = 'Failed to enable channel state notifications: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> disableChannelStateNotifications() async {
    try {
      await _bleService.disableChannelStateNotifications();
    } catch (e) {
      debugPrint('Failed to disable channel state notifications: $e');
    }
  }

  // Update a channel value
  Future<void> updateChannelValue(int channelId, int value) async {
    // 使用新的连接状态检查
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: updateChannelValue skipped - device not connected or unhealthy',
      );
      return;
    }

    if (channelId < 0 || channelId >= _selectedDevice!.channels.length) {
      debugPrint(
        'AppStateProvider: updateChannelValue received invalid channel ID: $channelId',
      );
      return;
    }

    _errorMessage = '';
    debugPrint('AppStateProvider: Updating channel $channelId to value $value');

    final previousValue = _selectedDevice!.channels[channelId].value;
    _selectedDevice!.channels[channelId].updateValue(value);
    notifyListeners();

    try {
      debugPrint(
        'AppStateProvider: Sending SetCommand to channel $channelId with value $value',
      );
      await _bleService.sendSetCommand(
        SetCommand(channel: channelId, value: value),
      );
      debugPrint(
        'AppStateProvider: SetCommand completed for channel $channelId',
      );
    } catch (e) {
      debugPrint(
        'AppStateProvider: SetCommand failed for channel $channelId with error: $e',
      );
      _selectedDevice!.channels[channelId].updateValue(previousValue);
      _errorMessage = '发送设置命令失败: $e';
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendFadeCommand({
    required int channelId,
    required int targetValue,
    required int duration,
  }) async {
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: sendFadeCommand skipped - no device connected',
      );
      throw Exception('NOT_CONNECTED');
    }

    debugPrint(
      'AppStateProvider: Sending FadeCommand channel=$channelId target=$targetValue duration=$duration',
    );
    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.sendFadeCommand(
        FadeCommand(
          channel: channelId,
          targetValue: targetValue,
          duration: duration,
        ),
      );

      if (channelId >= 0 && channelId < _selectedDevice!.channels.length) {
        _selectedDevice!.channels[channelId].updateValue(targetValue);
      }

      debugPrint('AppStateProvider: FadeCommand sent successfully');
    } catch (e) {
      debugPrint('AppStateProvider: FadeCommand failed with error: $e');
      _errorMessage = '渐变指令发送失败: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendBlinkCommand({
    required int channelId,
    required int period,
  }) async {
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: sendBlinkCommand skipped - no device connected',
      );
      throw Exception('NOT_CONNECTED');
    }

    debugPrint(
      'AppStateProvider: Sending BlinkCommand channel=$channelId period=$period',
    );
    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.sendBlinkCommand(
        BlinkCommand(channel: channelId, period: period),
      );

      debugPrint('AppStateProvider: BlinkCommand sent successfully');
    } catch (e) {
      debugPrint('AppStateProvider: BlinkCommand failed with error: $e');
      _errorMessage = '闪烁指令发送失败: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> sendStrobeCommand({
    required int channelId,
    required int flashCount,
    required int totalDuration,
    required int pauseDuration,
  }) async {
    if (!isConnected) {
      debugPrint(
        'AppStateProvider: sendStrobeCommand skipped - no device connected',
      );
      throw Exception('NOT_CONNECTED');
    }

    debugPrint(
      'AppStateProvider: Sending StrobeCommand channel=$channelId flashCount=$flashCount totalDuration=$totalDuration pauseDuration=$pauseDuration',
    );
    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.sendStrobeCommand(
        StrobeCommand(
          channel: channelId,
          flashCount: flashCount,
          totalDuration: totalDuration,
          pauseDuration: pauseDuration,
        ),
      );

      debugPrint('AppStateProvider: StrobeCommand sent successfully');
    } catch (e) {
      debugPrint('AppStateProvider: StrobeCommand failed with error: $e');
      _errorMessage = '爆闪指令发送失败: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopAutoReconnectLoop();
    _stopConnectionStatusMonitoring();
    _reconnectManager?.dispose();
    _telemetrySubscription?.cancel();
    Future.microtask(() => _bleService.disableTelemetryNotifications());
    super.dispose();
  }
}
