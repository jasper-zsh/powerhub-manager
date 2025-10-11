import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/channel.dart';
import 'package:app/models/preset.dart';
import 'package:app/models/control_command/control_command.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/models/telemetry.dart';

// For debugging
import 'package:flutter/foundation.dart';

// For permissions
import 'package:permission_handler/permission_handler.dart';

class BLEService {
  static const String SERVICE_UUID = '5e0b0001-6f72-4761-8e3e-7a1c1b5f9b11';
  static const String CHANNEL_STATES_UUID =
      '0000fff0-0000-1000-8000-00805f9b34fb';
  static const String CONTROL_COMMANDS_UUID =
      '0000fff1-0000-1000-8000-00805f9b34fb';
  static const String READ_PRESETS_UUID =
      '0000fff2-0000-1000-8000-00805f9b34fb';
  static const String WRITE_PRESET_UUID =
      '0000fff3-0000-1000-8000-00805f9b34fb';
  static const String EXECUTE_PRESET_UUID =
      '0000fff4-0000-1000-8000-00805f9b34fb';
  static const String TELEMETRY_UUID = '0000fff5-0000-1000-8000-00805f9b34fb';

  BluetoothDevice? _connectedDevice;
  BluetoothService? _service;
  TelemetryData? _lastTelemetry;

  /// Normalises UUID strings so that short (16-bit/32-bit) and full (128-bit)
  /// values can be compared reliably. The ESP32 advertises 16-bit UUIDs (e.g.
  /// `fff0`), while the application stores 128-bit forms. Converting both to a
  /// 32-character hex string without dashes keeps comparisons consistent.
  String _normalizeUuid(String uuid) {
    final cleaned = uuid.toLowerCase().replaceAll('-', '');

    if (cleaned.length == 4) {
      // Expand 16-bit UUID to the Bluetooth base UUID form.
      return '0000${cleaned}00001000800000805f9b34fb';
    }

    if (cleaned.length == 8) {
      // Expand 32-bit UUID to the Bluetooth base UUID form.
      return '${cleaned}00001000800000805f9b34fb';
    }

    if (cleaned.length == 32) {
      return cleaned;
    }

    // Fall back to the cleaned string if it is an unexpected length.
    return cleaned;
  }

  BluetoothCharacteristic? _findCharacteristic(String targetUuid) {
    if (_service == null) {
      return null;
    }

    final normalizedTarget = _normalizeUuid(targetUuid);

    for (final characteristic in _service!.characteristics) {
      final normalizedCharacteristic = _normalizeUuid(
        characteristic.uuid.toString(),
      );

      if (normalizedCharacteristic == normalizedTarget) {
        return characteristic;
      }
    }

    return null;
  }

  // Check if BLE is supported on the device
  Future<bool> isSupported() async {
    return FlutterBluePlus.isAvailable;
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

      for (ScanResult r in results) {
        debugPrint('Device: ${r.device.name} (${r.device.id.id})');
        debugPrint('  RSSI: ${r.rssi}');
        debugPrint(
          '  Service UUIDs: ${r.advertisementData.serviceUuids.map((u) => u.toString()).join(', ')}',
        );

        // Check if the device advertises our service UUID (normalize both sides)
        bool hasService = r.advertisementData.serviceUuids.any((uuid) {
          final adv = _normalizeUuid(uuid.toString());
          final target = _normalizeUuid(SERVICE_UUID);
          final matches = adv == target;
          if (matches) {
            debugPrint('  MATCH: Found our service UUID!');
          }
          return matches;
        });

        // Also check device name equals expected
        bool isESP32Device = r.device.name == 'PowerHub';
        if (isESP32Device) {
          debugPrint('  MATCH: Device name is PowerHub');
        }

        // De-duplicate by device id
        bool alreadyAdded = devices.any((d) => d.id == r.device.id.id);
        if ((hasService || isESP32Device) && !alreadyAdded) {
          debugPrint('  Adding device to list: ${r.device.name}');
          devices.add(
            PWMController(
              id: r.device.id.id,
              name: r.device.name.isNotEmpty ? r.device.name : 'PowerHub',
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
      if (devices.length > 0) {
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
          _connectedDevice!.id.id != deviceId) {
        debugPrint(
          'Disconnecting from current device before connecting to new one',
        );
        await disconnect();
      }

      // If already connected to the same device, just return
      if (_connectedDevice != null && _connectedDevice!.id.id == deviceId) {
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
        'Successfully connected to device: ${_connectedDevice!.id.id}',
      );

      // Discover services
      await _discoverServices();
      _lastTelemetry = null;

      debugPrint('Successfully connected and found our service');
    } catch (e) {
      debugPrint('Connection failed with error: $e');

      // Clean up on failure
      _connectedDevice = null;
      _service = null;

      if (e is FlutterBluePlusException) {
        debugPrint(
          'FlutterBluePlusException details - error code: ${e.errorCode}, description: ${e.description}',
        );
        if (e.errorCode == 2) {
          throw Exception('DEVICE_NOT_FOUND');
        } else if (e.errorCode == 3) {
          throw Exception('CONNECTION_FAILED');
        } else if (e.errorCode == 4) {
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

    for (BluetoothService service in services) {
      debugPrint('  Service: ${service.uuid}');
      if (_normalizeUuid(service.uuid.toString()) ==
          _normalizeUuid(SERVICE_UUID)) {
        debugPrint('  Found our service!');
        _service = service;
      }
    }

    if (_service == null) {
      debugPrint('ERROR: Could not find our service ($SERVICE_UUID)');
      throw Exception('Service not found');
    }
  }

  // Disconnect from the device
  Future<void> disconnect() async {
    debugPrint('Disconnecting from device...');

    try {
      if (_connectedDevice != null && _connectedDevice!.isConnected) {
        debugPrint('Disconnecting device: ${_connectedDevice!.id.id}');
        await _connectedDevice!.disconnect();
        debugPrint('Successfully disconnected from device');
      } else {
        debugPrint('No device connected or device already disconnected');
      }
    } catch (e) {
      debugPrint('Error during disconnect: $e');
    } finally {
      // Always clean up the references
      _connectedDevice = null;
      _service = null;
      _lastTelemetry = null;
      debugPrint('Cleaned up device and service references');
    }
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
        'Looking for channel states characteristic with UUID: $CHANNEL_STATES_UUID',
      );
      for (BluetoothCharacteristic c in _service!.characteristics) {
        debugPrint(
          '  Checking characteristic: ${c.uuid} (full: ${c.uuid.toString().toLowerCase()})',
        );
      }

      final characteristic = _findCharacteristic(CHANNEL_STATES_UUID);

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

      // Validate that we received 4 bytes
      if (value.length != 4) {
        debugPrint(
          'ERROR: Invalid data length. Expected 4 bytes, got ${value.length} bytes: $value',
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

  Future<TelemetryData> readTelemetrySnapshot() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(TELEMETRY_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      final value = await characteristic.read();

      if (value.length != 16) {
        throw Exception('INVALID_DATA');
      }

      final telemetry = TelemetryData.fromRead(value);
      _lastTelemetry = telemetry;
      return telemetry;
    } catch (e) {
      debugPrint('Failed to read telemetry with error: $e');
      if (e is ArgumentError) rethrow;
      throw Exception('READ_FAILED');
    }
  }

  Future<Stream<TelemetryData>> enableTelemetryNotifications() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(TELEMETRY_UUID);

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
            TelemetryData telemetry;
            if (value.length == 16) {
              telemetry = TelemetryData.fromRead(value);
            } else if (value.length == 12) {
              telemetry = TelemetryData.fromNotification(
                value,
                previous: _lastTelemetry,
              );
            } else {
              throw Exception('INVALID_DATA');
            }
            _lastTelemetry = telemetry;
            return telemetry;
          } catch (e) {
            debugPrint('Failed to parse telemetry notification: $e');
            rethrow;
          }
        });
  }

  Future<void> disableTelemetryNotifications() async {
    final characteristic = _findCharacteristic(TELEMETRY_UUID);
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

    final characteristic = _findCharacteristic(TELEMETRY_UUID);

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

    final characteristic = _findCharacteristic(CONTROL_COMMANDS_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
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

    final characteristic = _findCharacteristic(CONTROL_COMMANDS_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
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

    final characteristic = _findCharacteristic(CONTROL_COMMANDS_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
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

    final characteristic = _findCharacteristic(CONTROL_COMMANDS_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write(command.toBytes(), withoutResponse: true);
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  // Read all presets from device
  Future<List<Preset>> readAllPresets() async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    final characteristic = _findCharacteristic(READ_PRESETS_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      final data = await characteristic.read();
      final presets = <Preset>[];
      int index = 0;

      while (index < data.length) {
        if (index + 2 > data.length) {
          throw Exception('INVALID_DATA');
        }

        final presetId = data[index++];
        final commandCount = data[index++];

        if (presetId == 0) {
          throw Exception('INVALID_PRESET_ID');
        }

        if (commandCount == 0) {
          presets.removeWhere((preset) => preset.id == presetId);
          continue;
        }

        final commands = <ControlCommand>[];

        for (int i = 0; i < commandCount; i++) {
          if (index >= data.length) {
            throw Exception('INVALID_DATA');
          }

          final opcode = data[index];
          switch (opcode) {
            case 0x00:
              _ensureBytesAvailable(data.length, index, 3);
              final channel = data[index + 1];
              final value = data[index + 2];
              _validateChannel(channel);
              commands.add(SetCommand(channel: channel, value: value));
              index += 3;
              break;
            case 0x01:
              _ensureBytesAvailable(data.length, index, 5);
              final channel = data[index + 1];
              _validateChannel(channel);
              final targetValue = data[index + 2];
              final duration = _uint16(data[index + 3], data[index + 4]);
              commands.add(
                FadeCommand(
                  channel: channel,
                  targetValue: targetValue,
                  duration: duration,
                ),
              );
              index += 5;
              break;
            case 0x02:
              _ensureBytesAvailable(data.length, index, 4);
              final channel = data[index + 1];
              _validateChannel(channel);
              final period = _uint16(data[index + 2], data[index + 3]);
              commands.add(BlinkCommand(channel: channel, period: period));
              index += 4;
              break;
            case 0x03:
              _ensureBytesAvailable(data.length, index, 7);
              final channel = data[index + 1];
              _validateChannel(channel);
              final flashCount = data[index + 2];
              final totalDuration = _uint16(data[index + 3], data[index + 4]);
              final pauseDuration = _uint16(data[index + 5], data[index + 6]);
              commands.add(
                StrobeCommand(
                  channel: channel,
                  flashCount: flashCount,
                  totalDuration: totalDuration,
                  pauseDuration: pauseDuration,
                ),
              );
              index += 7;
              break;
            default:
              throw Exception('INVALID_DATA');
          }
        }

        presets.add(
          Preset(id: presetId, name: 'Preset $presetId', commands: commands),
        );
      }

      return presets;
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('READ_FAILED');
    }
  }

  // Save a preset to device
  Future<void> savePresetToDevice(Preset preset) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    // Validate preset parameters
    if (!preset.isValidId) {
      throw Exception('INVALID_PRESET_ID');
    }

    if (!preset.isValidCommandCount) {
      throw Exception('INVALID_COMMAND_COUNT');
    }

    final characteristic = _findCharacteristic(WRITE_PRESET_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      // Serialize the preset according to the ESP32 specification
      List<int> data = [];
      data.add(preset.id);
      data.add(preset.commandCount);

      for (ControlCommand command in preset.commands) {
        data.addAll(command.toBytes());
      }

      await characteristic.write(data, withoutResponse: true);
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  // Execute a preset
  Future<void> executePreset(int presetId) async {
    if (_connectedDevice == null || !_connectedDevice!.isConnected) {
      throw Exception('NOT_CONNECTED');
    }

    // Validate preset ID
    if (presetId < 0 || presetId > 255) {
      throw Exception('INVALID_PRESET_ID');
    }

    final characteristic = _findCharacteristic(EXECUTE_PRESET_UUID);

    if (characteristic == null) {
      throw Exception('CHARACTERISTIC_NOT_FOUND');
    }

    try {
      await characteristic.write([presetId], withoutResponse: true);
    } catch (e) {
      throw Exception('WRITE_FAILED');
    }
  }

  // Expose connection status
  bool get isConnected => _connectedDevice?.isConnected ?? false;

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
    if (channel < 0 || channel > 3) {
      throw Exception('INVALID_CHANNEL');
    }
  }

  int _uint16(int msb, int lsb) => ((msb & 0xFF) << 8) | (lsb & 0xFF);
}
