import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/models/telemetry.dart';
import 'package:app/models/power_management.dart';
import 'package:app/models/monitoring_data.dart';
import 'package:app/services/ble_debug_helper.dart';
import 'package:app/utils/ble_uuid.dart';

// For debugging
import 'package:flutter/foundation.dart';

// For permissions
import 'package:permission_handler/permission_handler.dart';

class BLEService {
  BLEService._internal();
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;

  // PowerHub service UUIDs - handle both byte orders
  static const String serviceUuid = '119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E';
  static const String serviceUuidReversed = '5e0b0001-6f72-4761-8e3e-7a1c1b5f9b11'; // Byte-swapped version

  static const String channelStatesUuid =
      '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String controlCommandsUuid =
      '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String powerManagementUuid =
      '0000fff5-0000-1000-8000-00805f9b34fb';
  static const String monitoringUuid =
      '0000fff6-0000-1000-8000-00805f9b34fb';

  // Legacy constants for backward compatibility
  static const String SERVICE_UUID = serviceUuid;
  static const String CHANNEL_STATES_UUID = channelStatesUuid;
  static const String CONTROL_COMMANDS_UUID = controlCommandsUuid;
  static const String POWER_MANAGEMENT_UUID = powerManagementUuid;
  static const String MONITORING_UUID = monitoringUuid;
  // Note: TELEMETRY_UUID is deprecated - use MONITORING_UUID instead

  BluetoothDevice? _connectedDevice;
  BluetoothService? _service;
  TelemetryData? _lastTelemetry;

  // 连接健康检查
  Timer? _connectionHealthTimer;
  DateTime? _lastSuccessfulOperation;
  bool _connectionHealthy = true;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;

  BluetoothCharacteristic? _findCharacteristic(String targetUuid) {
    if (_service == null) {
      return null;
    }

    final targetGuid = parseBleUuid(targetUuid);

    for (final characteristic in _service!.characteristics) {
      if (characteristic.uuid == targetGuid) {
        return characteristic;
      }
    }

    return null;
  }

  // Check if BLE is supported on the device
  Future<bool> isSupported() async {
    return await FlutterBluePlus.isSupported;
  }

  // Scan for devices
  Future<List<PWMController>> scanForDevices({int timeout = 10}) async {
    debugPrint('Checking BLE support...');
    if (!await isSupported()) {
      debugPrint('BLE not supported on this device');
      throw Exception('BLE_NOT_SUPPORTED');
    }

    // Request necessary permissions
    debugPrint('Requesting BLE permissions...');
    try {
      await _requestPermissions();
    } catch (e) {
      debugPrint('Permission request failed: $e');
      rethrow;
    }

    List<PWMController> devices = [];

    debugPrint('Starting BLE scan for PowerHub devices...');
    debugPrint('Looking for service UUID: $SERVICE_UUID');

    // Start scanning
    await FlutterBluePlus.startScan(timeout: Duration(seconds: timeout));

    // Listen for scan results
    await for (List<ScanResult> results in FlutterBluePlus.scanResults) {
      debugPrint('Received ${results.length} scan results');

      final targetGuid = parseBleUuid(serviceUuid);
      final targetReversedGuid = parseBleUuid(serviceUuidReversed);

      for (ScanResult r in results) {
        debugPrint('Device: ${r.device.platformName} (${r.device.remoteId.str})');
        debugPrint('  RSSI: ${r.rssi}');
        debugPrint(
          '  Service UUIDs: ${r.advertisementData.serviceUuids.map((u) => u.str).join(', ')}',
        );

        // Debug logging for device discovery
        BLEDebugHelper.logDeviceScan(
          r.advertisementData.serviceUuids,
          r.device.platformName,
        );

        // Check if the device advertises our service UUID (normalize both sides)
        bool hasService = r.advertisementData.serviceUuids.any((uuid) {
          final matches = uuid == targetGuid || uuid == targetReversedGuid;
          if (matches) {
            debugPrint('  MATCH: Found our service UUID!');
          }
          return matches;
        });

        // Also check device name equals expected
        bool isESP32Device = r.device.platformName == 'PowerHub';
        if (isESP32Device) {
          debugPrint('  MATCH: Device name is PowerHub');
        }

        // De-duplicate by device id
        bool alreadyAdded = devices.any((d) => d.id == r.device.remoteId.str);
        if ((hasService || isESP32Device) && !alreadyAdded) {
          debugPrint('  Adding device to list: ${r.device.platformName}');
          devices.add(
            PWMController(
              id: r.device.remoteId.str,
              name: r.device.platformName.isNotEmpty ? r.device.platformName : 'PowerHub',
              rssi: r.rssi,
            ),
          );
        } else {
          debugPrint(
            '  Device does not match criteria or already added, skipping',
          );
        }
      }

      // Stop scanning after timeout or when we find devices
      if (devices.isNotEmpty) {
        debugPrint('Found ${devices.length} devices, stopping scan early');
        break;
      }
    }

    await FlutterBluePlus.stopScan();
    debugPrint('BLE scan completed. Found ${devices.length} devices.');

    return devices;
  }

  // Request necessary BLE permissions
  Future<void> _requestPermissions() async {
    debugPrint('Checking and requesting BLE permissions...');

    try {
      // Check if we already have location permissions
      var locationStatus = await Permission.location.status;
      debugPrint('Current location permission status: $locationStatus');

      if (!locationStatus.isGranted) {
        debugPrint('Requesting location permission...');
        locationStatus = await Permission.location.request();
        debugPrint('Location permission request result: $locationStatus');
      }

      // On Android 12+, we also need BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions
      // Check if we already have bluetooth scan permissions
      var scanStatus = await Permission.bluetoothScan.status;
      debugPrint('Current bluetooth scan permission status: $scanStatus');

      if (!scanStatus.isGranted) {
        debugPrint('Requesting bluetooth scan permission...');
        scanStatus = await Permission.bluetoothScan.request();
        debugPrint('Bluetooth scan permission request result: $scanStatus');
      }

      // Check if we already have bluetooth connect permissions
      var connectStatus = await Permission.bluetoothConnect.status;
      debugPrint('Current bluetooth connect permission status: $connectStatus');

      if (!connectStatus.isGranted) {
        debugPrint('Requesting bluetooth connect permission...');
        connectStatus = await Permission.bluetoothConnect.request();
        debugPrint(
          'Bluetooth connect permission request result: $connectStatus',
        );
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // Continue anyway as some platforms might not support these permissions
    }

    // Also check bluetooth advertising permission on newer Android versions
    try {
      var advertiseStatus = await Permission.bluetoothAdvertise.status;
      debugPrint(
        'Current bluetooth advertise permission status: $advertiseStatus',
      );

      if (!advertiseStatus.isGranted) {
        debugPrint('Requesting bluetooth advertise permission...');
        advertiseStatus = await Permission.bluetoothAdvertise.request();
        debugPrint(
          'Bluetooth advertise permission request result: $advertiseStatus',
        );
      }
    } catch (e) {
      debugPrint('Error requesting bluetooth advertise permission: $e');
    }
  }

  // Connect to a device
  Future<void> connect(String deviceId) async {
    debugPrint('Attempting to connect to device: $deviceId');

    try {
      // If already connected to a different device, disconnect first
      if (_connectedDevice != null &&
          _connectedDevice!.isConnected &&
          _connectedDevice!.remoteId.str != deviceId) {
        debugPrint(
          'Disconnecting from current device before connecting to new one',
        );
        await disconnect();
      }

      // If already connected to the same device, just return
      if (_connectedDevice != null && _connectedDevice!.remoteId.str == deviceId) {
        if (_connectedDevice!.isConnected) {
          debugPrint('Already connected to device: $deviceId');
          // Still rediscover services to ensure we have the correct references
          await _discoverServices();
          return;
        } else {
          // Device object exists but is not connected, clean it up
          debugPrint('Device object exists but not connected, cleaning up');
          _connectedDevice = null;
          _service = null;
        }
      }

      // Create new connection
      debugPrint('Creating new BluetoothDevice instance for: $deviceId');
      _connectedDevice = BluetoothDevice.fromId(deviceId);

      debugPrint('Attempting to connect to device...');
      await _connectedDevice!.connect(timeout: Duration(seconds: 10));
      debugPrint(
        'Successfully connected to device: ${_connectedDevice!.remoteId.str}',
      );

      // Debug logging for successful connection
      BLEDebugHelper.logConnectionResult(true, '');

      // Discover services
      await _discoverServices();
      _lastTelemetry = null;

      // 建立连接健康检查
      _startConnectionHealthCheck();

      debugPrint('Successfully connected and found our service');
    } catch (e) {
      debugPrint('Connection failed with error: $e');

      // Clean up on failure
      _connectedDevice = null;
      _service = null;

      // Debug logging for failed connection
      BLEDebugHelper.logConnectionResult(false, e.toString());

      if (e is FlutterBluePlusException) {
        debugPrint(
          'FlutterBluePlusException details - error code: ${e.code}, description: ${e.description}',
        );
        if (e.code == 2) {
          throw Exception('DEVICE_NOT_FOUND');
        } else if (e.code == 3) {
          throw Exception('CONNECTION_FAILED');
        } else if (e.code == 4) {
          throw Exception('TIMEOUT');
        }
      }

      // Try to provide a more specific error message
      String errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission')) {
        throw Exception('CONNECTION_FAILED_PERMISSION');
      } else if (errorMessage.contains('timeout')) {
        throw Exception('TIMEOUT');
      } else if (errorMessage.contains('not found') ||
          errorMessage.contains('not_found')) {
        throw Exception('DEVICE_NOT_FOUND');
      } else {
        throw Exception('CONNECTION_FAILED');
      }
    }
  }

  // Discover services and find our service
  Future<void> _discoverServices() async {
    if (_connectedDevice == null) {
      throw Exception('No device connected');
    }

    debugPrint('Discovering services...');
    List<BluetoothService> services = await _connectedDevice!
        .discoverServices();
    debugPrint('Discovered ${services.length} services');

    _service = null; // Reset service reference

    // Debug logging for service discovery
    final discoveredServiceUuids = services.map((s) => s.uuid).toList();
    BLEDebugHelper.logServiceDiscovery(discoveredServiceUuids);
    final targetGuid = parseBleUuid(serviceUuid);
    final targetReversedGuid = parseBleUuid(serviceUuidReversed);

    for (BluetoothService service in services) {
      debugPrint('  Service: ${service.uuid}');
      if (service.uuid == targetGuid) {
        debugPrint('  Found our service!');
        _service = service;
        break;
      } else if (service.uuid == targetReversedGuid) {
        debugPrint('  Found our service! (reversed byte order)');
        _service = service;
        break;
      }
    }

    if (_service == null) {
      debugPrint('ERROR: Could not find our service');
      debugPrint('  Looking for service: $serviceUuid');
      debugPrint('  Or reversed: $serviceUuidReversed');
      throw Exception('Service not found');
    }
  }

  // Disconnect from the device
  Future<void> disconnect() async {
    debugPrint('Disconnecting from device...');

    try {
      if (_connectedDevice != null && _connectedDevice!.isConnected) {
        debugPrint('Disconnecting device: ${_connectedDevice!.remoteId.str}');
        await _connectedDevice!.disconnect();
        debugPrint('Successfully disconnected from device');
      } else {
        debugPrint('No device connected or device already disconnected');
      }
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    } finally {
      // Always clean up the references
      _stopConnectionHealthCheck();
      _connectedDevice = null;
      _service = null;
      _lastTelemetry = null;
      debugPrint('Cleaned up device and service references');
    }
  }

  Future<Set<String>> scanForControllerIds(
    Iterable<String> controllerIds, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final targets = controllerIds.toSet();
    if (targets.isEmpty) {
      return <String>{};
    }

    if (!await isSupported()) {
      return <String>{};
    }

    try {
      await _requestPermissions();
    } catch (error) {
      debugPrint('scanForControllerIds: permission request failed - $error');
      rethrow;
    }

    final found = <String>{};
    final completer = Completer<void>();
    StreamSubscription<List<ScanResult>>? subscription;

    try {
      await FlutterBluePlus.startScan(timeout: timeout);

      subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final controllerId = result.device.remoteId.str;
          if (targets.contains(controllerId)) {
            found.add(controllerId);
            if (found.length == targets.length && !completer.isCompleted) {
              completer.complete();
            }
          }
        }
      });

      if (!completer.isCompleted) {
        try {
          await completer.future.timeout(timeout);
        } on TimeoutException {
          // Expected when not all devices are found before timeout.
        }
      }
    } finally {
      await FlutterBluePlus.stopScan();
      await subscription?.cancel();
    }

    return found;
  }

  // Read channel states
  Future<List<int>> readChannelStates() async {
    debugPrint('Attempting to read channel states...');

    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      debugPrint('ERROR: Not connected to device');
      throw Exception('NOT_CONNECTED');
    }

    if (_service == null) {
      debugPrint('ERROR: Service not available');
      throw Exception('SERVICE_NOT_AVAILABLE');
    }

    try {
      // Find the channel states characteristic
      debugPrint(
        'Looking for channel states characteristic with UUID: $channelStatesUuid',
      );
      for (BluetoothCharacteristic c in _service!.characteristics) {
        debugPrint(
          '  Checking characteristic: ${c.uuid} (full: ${c.uuid.toString().toLowerCase()})',
        );
      }

      final characteristic = _findCharacteristic(channelStatesUuid);

      if (characteristic == null) {
        // List all characteristics for debugging
        debugPrint('Available characteristics:');
        for (BluetoothCharacteristic c in _service!.characteristics) {
          debugPrint(
            '  - UUID: ${c.uuid} (full: ${c.uuid.toString().toLowerCase()})',
          );
          debugPrint('    Properties: ${c.properties}');
        }
        throw Exception('CHARACTERISTIC_NOT_FOUND');
      }

      debugPrint('Reading from characteristic: ${characteristic.uuid}');
      List<int> value = await characteristic.read();
      debugPrint('Read value: $value');

      // Validate that we received 6 bytes
      if (value.length != 6) {
        debugPrint(
          'ERROR: Invalid data length. Expected 6 bytes, got ${value.length} bytes: $value',
        );
        throw Exception('INVALID_DATA');
      }

      // Validate that each byte is in the valid range (0-255)
      for (int i = 0; i < value.length; i++) {
        if (value[i] < 0 || value[i] > 255) {
          debugPrint('ERROR: Invalid data value at index $i: ${value[i]}');
          throw Exception('INVALID_DATA');
        }
      }

      debugPrint('Successfully read channel states: $value');
      _recordSuccessfulOperation();
      return value;
    } catch (e) {
      debugPrint('Failed to read channel states with error: $e');

      // Try to provide a more specific error message
      String errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission')) {
        throw Exception('READ_FAILED_PERMISSION');
      } else if (errorMessage.contains('timeout')) {
        throw Exception('READ_FAILED_TIMEOUT');
      } else if (errorMessage.contains('not found') ||
          errorMessage.contains('not_found')) {
        throw Exception('READ_FAILED_CHARACTERISTIC');
      } else {
        throw Exception('READ_FAILED');
      }
    }
  }

  Future<MonitoringData> readTelemetrySnapshot() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(MONITORING_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      final value = await characteristic.read();

      debugPrint('Monitoring read raw data length: ${value.length}, bytes: $value');

      // Monitor data should be 36 bytes according to protocol
      if (value.length != 36) {
        debugPrint('Warning: Expected 36 bytes for monitoring data, got ${value.length}');
        // Don't throw error, try to parse anyway
      }

      // Parse monitoring data format (36 bytes)
      final monitoringData = MonitoringData.fromBytes(value);

      _recordSuccessfulOperation();
      return monitoringData;
    } catch (e) {
      debugPrint('Failed to read telemetry with error: $e');
      if (e is ArgumentError) rethrow;
      throw Exception('READ_FAILED');
    }
  }

  Future<Stream<MonitoringData>> enableTelemetryNotifications() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(MONITORING_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    if (!(characteristic.properties.notify ||
        characteristic.properties.indicate)) {
      throw Exception('NOTIFY_NOT_SUPPORTED');
    }

    await characteristic.setNotifyValue(true);

    return characteristic.lastValueStream
        .where((value) => value.isNotEmpty)
        .map((value) {
          try {
            debugPrint('Monitoring notification raw data length: ${value.length}, bytes: $value');

            // Monitor data should be 36 bytes according to protocol
            if (value.length != 36) {
              debugPrint('Warning: Expected 36 bytes for monitoring data, got ${value.length}');
              // Don't throw error, try to parse anyway
            }

            // Parse monitoring data format (36 bytes)
            final monitoringData = MonitoringData.fromBytes(value);

            _recordSuccessfulOperation();
            return monitoringData;
          } catch (e) {
            debugPrint('Failed to parse monitoring notification: $e');
            rethrow;
          }
        });
  }

  Future<void> disableTelemetryNotifications() async {
    final characteristic = _findCharacteristic(MONITORING_UUID);
    if (characteristic == null) {
      return;
    }

    try {
      await characteristic.setNotifyValue(false);
    } catch (e) {
      debugPrint('Failed to disable telemetry notifications: $e');
    }
  }

  Future<void> sendTelemetryCommand({
    required int commandId,
    required int parameter,
  }) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    const supportedCommands = {0x01, 0x02, 0x03, 0x04, 0x11, 0x12};
    if (!supportedCommands.contains(commandId)) {
      throw Exception('INVALID_COMMAND');
    }

    if (parameter < -0x8000 || parameter > 0xFFFF) {
      throw Exception('INVALID_PARAMETER');
    }

    final characteristic = _findCharacteristic(POWER_MANAGEMENT_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      final encodedParameter = parameter & 0xFFFF;
      await characteristic.write([
        commandId & 0xFF,
        (encodedParameter >> 8) & 0xFF,
        encodedParameter & 0xFF,
      ], withoutResponse: true);
    } catch (e) {
      debugPrint('Failed to send telemetry command: $e');
      throw Exception('WRITE_FAILED');
    }
  }

  // Send a set command
  Future<void> sendSetCommand(SetCommand command) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    // Validate command parameters
    if (!command.isValidChannel) {
      throw Exception('INVALID_CHANNEL');
    }

    if (!command.isValidValue) {
      throw Exception('INVALID_VALUE');
    }

    final characteristic = _findCharacteristic(controlCommandsUuid);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
      _recordSuccessfulOperation();
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  // Send a fade command
  Future<void> sendFadeCommand(FadeCommand command) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    // Validate command parameters
    if (!command.isValidChannel) {
      throw Exception('INVALID_CHANNEL');
    }

    if (!command.isValidTargetValue) {
      throw Exception('INVALID_TARGET_VALUE');
    }

    if (!command.isValidDuration) {
      throw Exception('INVALID_DURATION');
    }

    final characteristic = _findCharacteristic(controlCommandsUuid);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
      _recordSuccessfulOperation();
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  // Send a blink command
  Future<void> sendBlinkCommand(BlinkCommand command) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    // Validate command parameters
    if (!command.isValidChannel) {
      throw Exception('INVALID_CHANNEL');
    }

    if (!command.isValidPeriod) {
      throw Exception('INVALID_PERIOD');
    }

    final characteristic = _findCharacteristic(controlCommandsUuid);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
      _recordSuccessfulOperation();
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  // Send a strobe command
  Future<void> sendStrobeCommand(StrobeCommand command) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    // Validate command parameters
    if (!command.isValidChannel) {
      throw Exception('INVALID_CHANNEL');
    }

    if (!command.isValidFlashCount) {
      throw Exception('INVALID_FLASH_COUNT');
    }

    if (!command.isValidTotalDuration) {
      throw Exception('INVALID_TOTAL_DURATION');
    }

    if (!command.isValidPauseDuration) {
      throw Exception('INVALID_PAUSE_DURATION');
    }

    final characteristic = _findCharacteristic(controlCommandsUuid);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
      _recordSuccessfulOperation();
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  
  // 启动连接健康检查
  void _startConnectionHealthCheck() {
    if (_connectedDevice == null) return;

    debugPrint('Starting connection health check for ${_connectedDevice!.remoteId.str}');

    // 订阅设备状态变化
    _deviceStateSubscription = _connectedDevice!.connectionState.listen((state) {
      debugPrint('Device state changed: $state');
      _updateConnectionHealth(state == BluetoothConnectionState.connected);
    });

    // 初始化健康状态
    _lastSuccessfulOperation = DateTime.now();
    _connectionHealthy = true;

    // 启动定期健康检查
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _performHealthCheck();
    });

    // 延迟执行第一次健康检查，给设备初始化时间
    Timer(const Duration(seconds: 3), () {
      _performHealthCheck();
    });
  }

  // 停止连接健康检查
  void _stopConnectionHealthCheck() {
    debugPrint('Stopping connection health check');
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;
    _connectionHealthy = false;
  }

  // 更新连接健康状态
  void _updateConnectionHealth(bool healthy) {
    final previousHealthy = _connectionHealthy;
    _connectionHealthy = healthy;

    if (healthy && !previousHealthy) {
      _lastSuccessfulOperation = DateTime.now();
      debugPrint('Connection health restored');
    } else if (!healthy && previousHealthy) {
      debugPrint('Connection health degraded');
    }
  }

  // 执行健康检查
  Future<void> _performHealthCheck() async {
    if (_connectedDevice == null) {
      _updateConnectionHealth(false);
      return;
    }

    try {
      // 检查设备连接状态
      final deviceConnected = _connectedDevice!.isConnected;
      if (!deviceConnected) {
        debugPrint('Health check: Device reports not connected');
        _updateConnectionHealth(false);
        return;
      }

      // 检查服务是否可用
      if (_service == null) {
        debugPrint('Health check: Service not available');
        _updateConnectionHealth(false);
        return;
      }

      // 尝试读取通道状态作为健康检查
      final channelStatesCharacteristic = _findCharacteristic(channelStatesUuid);
      if (channelStatesCharacteristic == null) {
        debugPrint('Health check: Channel states characteristic not available');
        _updateConnectionHealth(false);
        return;
      }

      // 尝试快速读取（带超时）
      final readResult = await channelStatesCharacteristic.read().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('Health check read timeout', const Duration(seconds: 3));
        },
      );

      // 验证数据长度（容错处理，接受4-6字节范围）
      if (readResult.length < 4 || readResult.length > 6) {
        debugPrint('Health check: Invalid data length ${readResult.length}, expected 4-6');
        _updateConnectionHealth(false);
        return;
      }

      // 健康检查成功
      _updateConnectionHealth(true);
      _lastSuccessfulOperation = DateTime.now();
      debugPrint('Health check: OK (${readResult.length} bytes)');

    } catch (e) {
      debugPrint('Health check failed: $e');

      // 检查是否是超时或连接问题
      if (e is TimeoutException ||
          e.toString().contains('NOT_CONNECTED') ||
          e.toString().contains('SERVICE_NOT_AVAILABLE') ||
          e.toString().contains('CHARACTERISTIC_NOT_FOUND') ||
          e.toString().contains('READ_FAILED')) {
        _updateConnectionHealth(false);
      } else {
        // 其他错误，可能只是临时问题
        final timeSinceLastSuccess = _lastSuccessfulOperation != null
            ? DateTime.now().difference(_lastSuccessfulOperation!)
            : Duration.zero;

        // 如果超过30秒没有成功操作，标记为不健康
        if (timeSinceLastSuccess.inSeconds > 30) {
          _updateConnectionHealth(false);
        }
      }
    }
  }

  // 记录成功操作
  void _recordSuccessfulOperation() {
    _lastSuccessfulOperation = DateTime.now();
    if (!_connectionHealthy) {
      _updateConnectionHealth(true);
    }
  }

  // 获取真实的连接状态
  bool get isConnected {
    // 首先检查基础连接状态
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      return false;
    }

    // 检查健康状态
    if (!_connectionHealthy) {
      return false;
    }

    // 检查最近是否有成功操作
    if (_lastSuccessfulOperation != null) {
      final timeSinceLastSuccess = DateTime.now().difference(_lastSuccessfulOperation!);
      if (timeSinceLastSuccess.inSeconds > 60) {
        debugPrint('Connection considered stale: last success ${timeSinceLastSuccess.inSeconds}s ago');
        return false;
      }
    }

    return true;
  }

  // 获取连接健康信息
  Map<String, dynamic> getConnectionHealthInfo() {
    return {
      'healthy': _connectionHealthy,
      'lastSuccessfulOperation': _lastSuccessfulOperation,
      'deviceConnected': _connectedDevice?.isConnected ?? false,
      'timeSinceLastSuccess': _lastSuccessfulOperation != null
          ? DateTime.now().difference(_lastSuccessfulOperation!).inSeconds
          : null,
    };
  }

  void _ensureBytesAvailable(
    int totalLength,
    int startIndex,
    int requiredLength,
  ) {
    if (startIndex + requiredLength > totalLength) {
      throw Exception('INVALID_DATA');
    }
  }

  void _validateChannel(int channel) {
    if (channel < 0 || channel > 5) {
      throw Exception('INVALID_CHANNEL');
    }
  }

  int _uint16(int msb, int lsb) => ((msb & 0xFF) << 8) | (lsb & 0xFF);
  int _int16(int msb, int lsb) {
    final unsigned = ((msb & 0xFF) << 8) | (lsb & 0xFF);
    // Convert to signed 16-bit integer
    if (unsigned >= 0x8000) {
      return unsigned - 0x10000;
    }
    return unsigned;
  }

  // Power Management Methods

  Future<PowerManagementConfig> readPowerManagementConfig() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(powerManagementUuid);
    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      final value = await characteristic.read();
      if (value.length != 8) {
        throw Exception('INVALID_DATA');
      }
      return PowerManagementConfig.fromBytes(value);
    } catch (e) {
      debugPrint('Failed to read power management config: $e');
      if (e is ArgumentError) rethrow;
      throw Exception('READ_FAILED');
    }
  }

  Future<void> sendPowerCommand(PowerCommand command) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(powerManagementUuid);
    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
    } catch (e) {
      debugPrint('Failed to send power command: $e');
      throw Exception('WRITE_FAILED');
    }
  }

  // Monitoring Methods

  Future<MonitoringData> readMonitoringData() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(monitoringUuid);
    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      final value = await characteristic.read();
      if (value.length != 36) {
        throw Exception('INVALID_DATA');
      }
      return MonitoringData.fromBytes(value);
    } catch (e) {
      debugPrint('Failed to read monitoring data: $e');
      if (e is ArgumentError) rethrow;
      throw Exception('READ_FAILED');
    }
  }

  Future<Stream<MonitoringData>> enableMonitoringNotifications() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(monitoringUuid);
    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    if (!(characteristic.properties.notify || characteristic.properties.indicate)) {
      throw Exception('NOTIFY_NOT_SUPPORTED');
    }

    try {
      await characteristic.setNotifyValue(true);
      return characteristic.lastValueStream
          .where((value) => value.length == 36)
          .map((value) => MonitoringData.fromBytes(value));
    } catch (e) {
      debugPrint('Failed to enable monitoring notifications: $e');
      throw Exception('NOTIFICATION_SETUP_FAILED');
    }
  }

  Future<void> disableMonitoringNotifications() async {
    final characteristic = _findCharacteristic(monitoringUuid);
    if (characteristic == null) {
      return;
    }

    try {
      await characteristic.setNotifyValue(false);
    } catch (e) {
      debugPrint('Failed to disable monitoring notifications: $e');
    }
  }

  // Channel state notifications

  Future<Stream<List<int>>> enableChannelStateNotifications() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(channelStatesUuid);
    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    if (!(characteristic.properties.notify || characteristic.properties.indicate)) {
      throw Exception('NOTIFY_NOT_SUPPORTED');
    }

    try {
      await characteristic.setNotifyValue(true);
      return characteristic.lastValueStream
          .where((value) => value.length == 6)
          .map((value) => value);
    } catch (e) {
      debugPrint('Failed to enable channel state notifications: $e');
      throw Exception('NOTIFICATION_SETUP_FAILED');
    }
  }

  Future<void> disableChannelStateNotifications() async {
    final characteristic = _findCharacteristic(channelStatesUuid);
    if (characteristic == null) {
      return;
    }

    try {
      await characteristic.setNotifyValue(false);
    } catch (e) {
      debugPrint('Failed to disable channel state notifications: $e');
    }
  }
}
