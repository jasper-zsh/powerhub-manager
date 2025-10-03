import 'package:flutter/foundation.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/channel.dart';
import 'package:app/models/preset.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/storage_service.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';

class AppStateProvider with ChangeNotifier {
  final BLEService _bleService = BLEService();
  final StorageService _storageService = StorageService();
  
  PWMController? _selectedDevice;
  List<PWMController> _discoveredDevices = [];
  List<Preset> _localPresets = [];
  List<Preset> _devicePresets = [];
  bool _isScanning = false;
  String _errorMessage = '';
  bool _isLoadingDevicePresets = false;
  String _devicePresetError = '';
  
  // Getters
  PWMController? get selectedDevice => _selectedDevice;
  List<PWMController> get discoveredDevices => _discoveredDevices;
  List<Preset> get localPresets => _localPresets;
  List<Preset> get devicePresets => _devicePresets;
  bool get isScanning => _isScanning;
  String get errorMessage => _errorMessage;
  bool get isConnected => _selectedDevice?.isConnected ?? false;
  bool get isLoadingDevicePresets => _isLoadingDevicePresets;
  String get devicePresetError => _devicePresetError;
  
  // Initialize the provider
  Future<void> init() async {
    debugPrint('AppStateProvider: Initializing...');
    await _storageService.init();
    await loadLocalPresets();
    debugPrint('AppStateProvider: Initialization completed');
  }
  
  // Scan for devices
  Future<void> scanForDevices({int timeout = 10}) async {
    _isScanning = true;
    _errorMessage = '';
    debugPrint('AppStateProvider: Starting device scan...');
    notifyListeners();
    
    try {
      _discoveredDevices = await _bleService.scanForDevices(timeout: timeout);
      debugPrint('AppStateProvider: Scan completed. Found ${_discoveredDevices.length} devices.');
    } catch (e) {
      debugPrint('AppStateProvider: Scan failed with error: $e');
      String error = e.toString();
      if (error.contains('PERMISSION_DENIED')) {
        _errorMessage = 'Bluetooth permission denied. Please grant Bluetooth permissions in app settings and try again.';
      } else if (error.contains('BLE_NOT_SUPPORTED')) {
        _errorMessage = 'Bluetooth is not supported on this device.';
      } else {
        _errorMessage = 'Failed to scan for devices. Please make sure Bluetooth is enabled and try again.';
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
          debugPrint('Device not found in discovered devices, creating new one');
          return PWMController(id: deviceId, name: 'Unknown Device', rssi: 0);
        },
      );
      
      device.connect();
      _selectedDevice = device;
      debugPrint('AppStateProvider: Successfully connected to device: ${device.name}');
      
      debugPrint('AppStateProvider: Attempting to read initial channel states...');
      await readChannelStates();
      debugPrint('AppStateProvider: Completed initial channel states read');

      debugPrint('AppStateProvider: Attempting to load device presets...');
      await loadDevicePresets();
      debugPrint('AppStateProvider: Completed loading device presets');
    } catch (e) {
      debugPrint('AppStateProvider: Connection failed with error: $e');
      String error = e.toString();
      if (error.contains('DEVICE_NOT_FOUND')) {
        _errorMessage = 'Device not found. Please make sure the device is powered on and in range.';
      } else if (error.contains('CONNECTION_FAILED')) {
        _errorMessage = 'Failed to connect to device. Please try again.';
      } else if (error.contains('TIMEOUT')) {
        _errorMessage = 'Connection timeout. Please try again.';
      } else if (error.contains('PERMISSION')) {
        _errorMessage = 'Connection failed due to permissions. Please check Bluetooth permissions.';
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
      debugPrint('AppStateProvider: Not connected to device, skipping readChannelStates');
      return;
    }
    
    debugPrint('AppStateProvider: Reading channel states...');
    _errorMessage = '';
    notifyListeners();
    
    try {
      List<int> states = await _bleService.readChannelStates();
      debugPrint('AppStateProvider: Read channel states: $states');
      
      for (int i = 0; i < states.length && i < _selectedDevice!.channels.length; i++) {
        _selectedDevice!.channels[i].updateValue(states[i]);
        debugPrint('AppStateProvider: Updated channel $i to value ${states[i]}');
      }
    } catch (e) {
      debugPrint('AppStateProvider: Failed to read channel states with error: $e');
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

  Future<void> loadDevicePresets() async {
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
      debugPrint('AppStateProvider: loadDevicePresets skipped - no device connected');
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
      debugPrint('AppStateProvider: Loaded ${presets.length} presets from device');
    } catch (e) {
      debugPrint('AppStateProvider: Failed to load device presets with error: $e');
      _devicePresetError = '读取设备预设失败: $e';
    } finally {
      _isLoadingDevicePresets = false;
      notifyListeners();
    }
  }

  // Update a channel value
  Future<void> updateChannelValue(int channelId, int value) async {
    if (_selectedDevice == null || !_selectedDevice!.isConnected) {
      debugPrint('AppStateProvider: updateChannelValue skipped - no device connected');
      return;
    }

    if (channelId < 0 || channelId >= _selectedDevice!.channels.length) {
      debugPrint('AppStateProvider: updateChannelValue received invalid channel ID: $channelId');
      return;
    }
    
    _errorMessage = '';
    debugPrint('AppStateProvider: Updating channel $channelId to value $value');
    
    final previousValue = _selectedDevice!.channels[channelId].value;
    _selectedDevice!.channels[channelId].updateValue(value);
    notifyListeners();

    try {
      debugPrint('AppStateProvider: Sending SetCommand to channel $channelId with value $value');
      await _bleService
          .sendSetCommand(SetCommand(channel: channelId, value: value));
      debugPrint('AppStateProvider: SetCommand completed for channel $channelId');
    } catch (e) {
      debugPrint('AppStateProvider: SetCommand failed for channel $channelId with error: $e');
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
      debugPrint('AppStateProvider: sendFadeCommand skipped - no device connected');
      throw Exception('NOT_CONNECTED');
    }

    debugPrint(
        'AppStateProvider: Sending FadeCommand channel=$channelId target=$targetValue duration=$duration');
    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.sendFadeCommand(FadeCommand(
        channel: channelId,
        targetValue: targetValue,
        duration: duration,
      ));

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
      debugPrint('AppStateProvider: sendBlinkCommand skipped - no device connected');
      throw Exception('NOT_CONNECTED');
    }

    debugPrint(
        'AppStateProvider: Sending BlinkCommand channel=$channelId period=$period');
    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.sendBlinkCommand(BlinkCommand(
        channel: channelId,
        period: period,
      ));

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
      debugPrint('AppStateProvider: sendStrobeCommand skipped - no device connected');
      throw Exception('NOT_CONNECTED');
    }

    debugPrint(
        'AppStateProvider: Sending StrobeCommand channel=$channelId flashCount=$flashCount totalDuration=$totalDuration pauseDuration=$pauseDuration');
    _errorMessage = '';
    notifyListeners();

    try {
      await _bleService.sendStrobeCommand(StrobeCommand(
        channel: channelId,
        flashCount: flashCount,
        totalDuration: totalDuration,
        pauseDuration: pauseDuration,
      ));

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
}
