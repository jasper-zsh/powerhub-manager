import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/preset.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/storage_service.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/models/telemetry.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/models/connection_status_record.dart';

class AppStateProvider with ChangeNotifier {
  AppStateProvider({
    BLEService? bleService,
    StorageService? storageService,
  })  : _bleService = bleService ?? BLEService(),
        _storageService = storageService ?? StorageService();

  final BLEService _bleService;
  final StorageService _storageService;

  PWMController? _selectedDevice;
  List<PWMController> _discoveredDevices = [];
  List<Preset> _localPresets = [];
  List<Preset> _devicePresets = [];
  List<SavedController> _savedControllers = [];
  List<ConnectionStatusRecord> _connectionStatusRecords = [];
  bool _isScanning = false;
  String _errorMessage = '';
  bool _isLoadingDevicePresets = false;
  String _devicePresetError = '';
  TelemetryData? _telemetry;
  String _telemetryError = '';
  StreamSubscription<TelemetryData>? _telemetrySubscription;
  Timer? _reconnectTimer;
  bool _autoReconnectActive = false;
  bool _reconnectInProgress = false;

  // Getters
  PWMController? get selectedDevice => _selectedDevice;
  List<PWMController> get discoveredDevices => _discoveredDevices;
  List<Preset> get localPresets => _localPresets;
  List<Preset> get devicePresets => _devicePresets;
  List<SavedController> get savedControllers => List.unmodifiable(_savedControllers);
  List<ConnectionStatusRecord> get connectionStatusRecords =>
      List.unmodifiable(_connectionStatusRecords);
  ConnectionDashboardSummary get connectionDashboardSummary =>
      ConnectionDashboardSummary.fromControllers(_savedControllers);
  bool get isScanning => _isScanning;
  String get errorMessage => _errorMessage;
  bool get isConnected => _selectedDevice?.isConnected ?? false;
  bool get isLoadingDevicePresets => _isLoadingDevicePresets;
  String get devicePresetError => _devicePresetError;
  TelemetryData? get telemetry => _telemetry ?? _selectedDevice?.telemetry;
  String get telemetryError => _telemetryError;
  bool get isThermalProtectionActive =>
      telemetry?.isThermalProtectionActive ?? false;

  // Initialize the provider
  Future<void> init() async {
    debugPrint('AppStateProvider: Initializing...');
    await _storageService.init();
    await loadSavedControllers();
    await loadLocalPresets();
    debugPrint('AppStateProvider: Initialization completed');
  }

  Future<void> loadSavedControllers() async {
    debugPrint('AppStateProvider: Loading saved controllers from storage');
    final controllers = await _storageService.loadSavedControllers();
    _savedControllers = controllers;
    _syncConnectionRecords();
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
      } else {
        final exhausted = controller.retryPolicy.attemptCount >=
            controller.retryPolicy.maxAttempts;

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
    _scheduleReconnectCycle();
  }

  void stopAutoReconnectLoop() {
    _autoReconnectActive = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _scheduleReconnectCycle() {
    if (!_autoReconnectActive || _reconnectInProgress) {
      return;
    }

    _reconnectInProgress = true;

    reconcileSavedControllers().catchError((error, stack) {
      debugPrint('Auto reconnect cycle error: $error');
    }).whenComplete(() async {
      _reconnectInProgress = false;

      if (!_autoReconnectActive) {
        return;
      }

      final pendingRecords = _connectionStatusRecords.where(
        (record) =>
            record.controller.connectionStatus !=
                SavedControllerConnectionStatus.connected &&
            record.controller.connectionStatus !=
                SavedControllerConnectionStatus.unavailable,
      );

      if (pendingRecords.isEmpty) {
        _autoReconnectActive = false;
        return;
      }

      final now = DateTime.now();
      Duration nextDelay = const Duration(seconds: 5);

      final waitingDelays = pendingRecords
          .where((record) =>
              record.scanState == ScanState.waitingRetry &&
              record.nextRetryAt != null)
          .map((record) => record.nextRetryAt!.difference(now))
          .where((delay) => delay > Duration.zero)
          .toList();

      if (waitingDelays.isNotEmpty) {
        waitingDelays.sort();
        nextDelay = waitingDelays.first;
      } else if (pendingRecords.any((record) => record.scanState == ScanState.scanning)) {
        nextDelay = const Duration(seconds: 3);
      }

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(nextDelay, _scheduleReconnectCycle);
    });
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
      debugPrint(
        'AppStateProvider: Successfully connected to device: ${device.name}',
      );

      debugPrint(
        'AppStateProvider: Attempting to read initial channel states...',
      );
      await readChannelStates();
      debugPrint('AppStateProvider: Completed initial channel states read');

      debugPrint('AppStateProvider: Attempting to load device presets...');
      await loadDevicePresets();
      debugPrint('AppStateProvider: Completed loading device presets');

      debugPrint('AppStateProvider: Initializing telemetry stream...');
      await _initializeTelemetry();
      debugPrint('AppStateProvider: Telemetry initialized');
    } catch (e) {
      debugPrint('AppStateProvider: Connection failed with error: $e');
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
    notifyListeners();

    try {
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
      _devicePresets = [];
      _devicePresetError = '';
      _isLoadingDevicePresets = false;
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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

  Future<void> loadDevicePresets() async {
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
      debugPrint(
        'AppStateProvider: loadDevicePresets skipped - no device connected',
      );
      _devicePresets = [];
      _devicePresetError = '';
      _isLoadingDevicePresets = false;
      notifyListeners();
      return;
    }

    debugPrint('AppStateProvider: Loading presets from device...');
    _isLoadingDevicePresets = true;
    _devicePresetError = '';
    notifyListeners();

    try {
      final presets = await _bleService.readAllPresets();
      _devicePresets = presets;
      debugPrint(
        'AppStateProvider: Loaded ${presets.length} presets from device',
      );
    } catch (e) {
      debugPrint(
        'AppStateProvider: Failed to load device presets with error: $e',
      );
      _devicePresetError = '读取设备预设失败: $e';
    } finally {
      _isLoadingDevicePresets = false;
      notifyListeners();
    }
  }

  // Update a channel value
  Future<void> updateChannelValue(int channelId, int value) async {
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
      debugPrint(
        'AppStateProvider: updateChannelValue skipped - no device connected',
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
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

  // Load local presets from storage
  Future<void> loadLocalPresets() async {
    _errorMessage = '';
    notifyListeners();

    try {
      Map<String, dynamic> presetsMap = await _storageService.loadAllPresets();
      _localPresets = presetsMap.values.cast<Preset>().toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Save a preset locally
  Future<void> saveLocalPreset(Preset preset) async {
    _errorMessage = '';
    notifyListeners();

    try {
      await _storageService.savePreset(preset);
      await loadLocalPresets();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Delete a local preset
  Future<void> deleteLocalPreset(int presetId) async {
    _errorMessage = '';
    notifyListeners();

    try {
      await _storageService.deletePreset(presetId);
      await loadLocalPresets();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  // Execute a preset
  Future<void> executePreset(int presetId) async {
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
      return;
    }

    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.executePreset(presetId);
      await readChannelStates();
      await loadDevicePresets();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> savePresetToDevice(Preset preset) async {
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }
    _errorMessage = '';
    notifyListeners();
    try {
      await _bleService.savePresetToDevice(preset);
      await loadDevicePresets();
    } catch (e) {
      _errorMessage = '写入设备预设失败: $e';
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopAutoReconnectLoop();
    _telemetrySubscription?.cancel();
    unawaited(_bleService.disableTelemetryNotifications());
    super.dispose();
  }
}
