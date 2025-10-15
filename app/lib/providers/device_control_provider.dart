import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:app/models/channel.dart';
import 'package:app/models/preset.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/saved_controller.dart';

typedef ChannelUpdateCallback = Future<void> Function(
  String controllerId,
  int channelId,
  int value,
);

typedef PresetTriggerCallback = Future<void> Function(
  String controllerId,
  int presetId,
);

typedef FadeCommandCallback = Future<void> Function(
  String controllerId,
  int channelId,
  int targetValue,
  int duration,
);

typedef BlinkCommandCallback = Future<void> Function(
  String controllerId,
  int channelId,
  int period,
);

typedef StrobeCommandCallback = Future<void> Function(
  String controllerId,
  int channelId,
  int flashCount,
  int totalDuration,
  int pauseDuration,
);

typedef DeviceReadyCallback = Future<PWMController?> Function(String controllerId);

class DeviceControlProvider with ChangeNotifier {
  DeviceControlProvider({
    required ChannelUpdateCallback onChannelUpdate,
    required PresetTriggerCallback onPresetTrigger,
    required FadeCommandCallback onFadeCommand,
    required BlinkCommandCallback onBlinkCommand,
    required StrobeCommandCallback onStrobeCommand,
    required DeviceReadyCallback onEnsureDeviceReady,
  })  : _onChannelUpdate = onChannelUpdate,
        _onPresetTrigger = onPresetTrigger,
        _onFadeCommand = onFadeCommand,
        _onBlinkCommand = onBlinkCommand,
        _onStrobeCommand = onStrobeCommand,
        _onEnsureDeviceReady = onEnsureDeviceReady;

  final ChannelUpdateCallback _onChannelUpdate;
  final PresetTriggerCallback _onPresetTrigger;
  final FadeCommandCallback _onFadeCommand;
  final BlinkCommandCallback _onBlinkCommand;
  final StrobeCommandCallback _onStrobeCommand;
  final DeviceReadyCallback _onEnsureDeviceReady;

  List<SavedController> _savedControllers = <SavedController>[];
  final Map<String, PWMController> _connectedDevices = <String, PWMController>{};
  PWMController? _activeDevice;
  String? _selectedControllerId;
  String? _pendingEnsureControllerId;
  final Set<int> _busyChannels = <int>{};
  bool _isBusy = false;
  final Map<int, Timer> _setCommandDebouncers = <int, Timer>{};
  List<int> _channelSnapshot = const <int>[];
  List<int> _presetSnapshot = const <int>[];

  List<SavedController> get savedControllers =>
      List.unmodifiable(_savedControllers);
  bool get isBusy => _isBusy;
  bool isChannelBusy(int channelId) => _busyChannels.contains(channelId);

  SavedController? get selectedSavedController {
    if (_selectedControllerId == null) {
      return null;
    }
    try {
      return _savedControllers.firstWhere(
        (controller) => controller.controllerId == _selectedControllerId,
      );
    } catch (_) {
      return null;
    }
  }

  bool get _hasAutoSelectionCandidate =>
      _savedControllers.isNotEmpty &&
      (_selectedControllerId == null ||
          !_savedControllers.any(
            (controller) => controller.controllerId == _selectedControllerId,
          ));

  bool get hasSelection => _selectedControllerId != null;

  bool get isSelectedControllerConnected {
    final device = activeDevice;
    if (device != null) {
      return device.isConnected;
    }

    final saved = selectedSavedController;
    return saved != null &&
        saved.connectionStatus == SavedControllerConnectionStatus.connected;
  }

  PWMController? get activeDevice =>
      _activeDevice != null &&
              _selectedControllerId != null &&
              _activeDevice!.id == _selectedControllerId
          ? _activeDevice
          : null;

  List<Channel> get channels => activeDevice?.channels ?? <Channel>[];
  List<Preset> get presets => activeDevice?.presets ?? <Preset>[];
  Map<String, PWMController> get connectedDevices =>
      Map.unmodifiable(_connectedDevices);

  String? get selectedControllerId => _selectedControllerId;

  @override
  void dispose() {
    for (final timer in _setCommandDebouncers.values) {
      timer.cancel();
    }
    _setCommandDebouncers.clear();
    super.dispose();
  }

  void _scheduleEnsure(String controllerId) {
    if (_pendingEnsureControllerId == controllerId) {
      return;
    }
    _pendingEnsureControllerId = controllerId;
    scheduleMicrotask(() async {
      if (_selectedControllerId != controllerId) {
        if (_pendingEnsureControllerId == controllerId) {
          _pendingEnsureControllerId = null;
        }
        return;
      }
      try {
        final device = await _onEnsureDeviceReady(controllerId);
        if (_selectedControllerId == controllerId && device != null) {
          _connectedDevices[device.id] = device;
          if (device.id != controllerId) {
            _connectedDevices[controllerId] = device;
          }
          final channelSnapshot =
              device.channels.map((channel) => channel.value).toList(growable: false);
          final presetSnapshot =
              device.presets.map((preset) => preset.id).toList(growable: false);
          final activeChanged = !identical(_activeDevice, device);
          final channelsChanged = !listEquals(channelSnapshot, _channelSnapshot);
          final presetsChanged = !listEquals(presetSnapshot, _presetSnapshot);
          _activeDevice = device;
          if (channelsChanged) {
            _channelSnapshot = channelSnapshot;
          }
          if (presetsChanged) {
            _presetSnapshot = presetSnapshot;
          }
          if (activeChanged || channelsChanged || presetsChanged) {
            notifyListeners();
          }
        }
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'device_control_provider',
            context: ErrorDescription('ensuring controller state'),
          ),
        );
      } finally {
        if (_pendingEnsureControllerId == controllerId) {
          _pendingEnsureControllerId = null;
        }
      }
    });
  }

  void syncFromAppState(
    List<SavedController> savedControllers,
    PWMController? selectedDevice,
    List<PWMController> connectedDevices,
  ) {
    final newSaved = List<SavedController>.from(savedControllers);
    final savedChanged = !listEquals(newSaved, _savedControllers);
    if (savedChanged) {
      _savedControllers = newSaved;
    }

    final nextConnected = <String, PWMController>{};
    for (final device in connectedDevices) {
      if (device.isConnected) {
        nextConnected[device.id] = device;
      }
    }
    if (selectedDevice?.isConnected == true) {
      nextConnected[selectedDevice!.id] = selectedDevice;
    }
    final connectedChanged = !_mapsEqual(nextConnected, _connectedDevices);
    if (connectedChanged) {
      _connectedDevices
        ..clear()
        ..addAll(nextConnected);
    }

    String? nextSelectedId = _selectedControllerId;
    if (_savedControllers.isEmpty) {
      nextSelectedId = null;
    } else if (_hasAutoSelectionCandidate) {
      nextSelectedId = _savedControllers.first.controllerId;
    }
    final selectionChanged = nextSelectedId != _selectedControllerId;
    _selectedControllerId = nextSelectedId;

    PWMController? nextActive;
    if (_selectedControllerId != null) {
      nextActive = _connectedDevices[_selectedControllerId!];
      if (nextActive == null &&
          selectedDevice != null &&
          selectedDevice.id == _selectedControllerId) {
        nextActive = selectedDevice;
      }
    } else {
      nextActive = null;
    }
    final activeChanged = !identical(nextActive, _activeDevice);

    final nextChannelSnapshot = nextActive != null
        ? nextActive.channels.map((channel) => channel.value).toList(growable: false)
        : const <int>[];
    final channelsChanged = !listEquals(nextChannelSnapshot, _channelSnapshot);

    final nextPresetSnapshot = nextActive != null
        ? nextActive.presets.map((preset) => preset.id).toList(growable: false)
        : const <int>[];
    final presetsChanged = !listEquals(nextPresetSnapshot, _presetSnapshot);

    _activeDevice = nextActive;
    if (channelsChanged) {
      _channelSnapshot = nextChannelSnapshot;
    }
    if (presetsChanged) {
      _presetSnapshot = nextPresetSnapshot;
    }

    if (_selectedControllerId != null &&
        (_activeDevice == null || !_activeDevice!.isConnected)) {
      _scheduleEnsure(_selectedControllerId!);
    }

    if (savedChanged ||
        connectedChanged ||
        selectionChanged ||
        activeChanged ||
        channelsChanged ||
        presetsChanged) {
      notifyListeners();
    }
  }

  void selectController(String controllerId) {
    if (_selectedControllerId == controllerId) {
      return;
    }
    if (!_savedControllers
        .any((controller) => controller.controllerId == controllerId)) {
      return;
    }
    _selectedControllerId = controllerId;
    _activeDevice = _connectedDevices[controllerId];
    _channelSnapshot = _activeDevice != null
        ? _activeDevice!.channels.map((channel) => channel.value).toList(growable: false)
        : const <int>[];
    _presetSnapshot = _activeDevice != null
        ? _activeDevice!.presets.map((preset) => preset.id).toList(growable: false)
        : const <int>[];
    notifyListeners();

    _scheduleEnsure(controllerId);
  }

  void handleSetValue(int channelId, int value) {
    setChannelPreview(channelId, value);
    _setCommandDebouncers[channelId]?.cancel();
    _setCommandDebouncers[channelId] = Timer(
      const Duration(milliseconds: 150),
      () {
        _setCommandDebouncers.remove(channelId);
        updateChannel(channelId, value);
      },
    );
  }

  void setChannelPreview(int channelId, int value) {
    final device = activeDevice;
    if (device == null ||
        channelId < 0 ||
        channelId >= device.channels.length) {
      return;
    }
    device.channels[channelId].updateValue(value);
    _channelSnapshot =
        device.channels.map((channel) => channel.value).toList(growable: false);
    notifyListeners();
  }

  bool _mapsEqual(
    Map<String, PWMController> a,
    Map<String, PWMController> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (!identical(other, entry.value)) {
        return false;
      }
    }
    return true;
  }

  Future<void> updateChannel(int channelId, int value) async {
    final controllerId = _selectedControllerId;
    if (controllerId == null) {
      return;
    }

    _busyChannels.add(channelId);
    notifyListeners();

    try {
      await _onChannelUpdate(controllerId, channelId, value);
    } finally {
      _busyChannels.remove(channelId);
      notifyListeners();
    }
  }

  Future<void> sendFadeCommand(
    int channelId,
    int targetValue,
    int duration,
  ) async {
    final controllerId = _selectedControllerId;
    if (controllerId == null) {
      return;
    }

    _busyChannels.add(channelId);
    notifyListeners();

    try {
      await _onFadeCommand(controllerId, channelId, targetValue, duration);
    } finally {
      _busyChannels.remove(channelId);
      notifyListeners();
    }
  }

  Future<void> sendBlinkCommand(
    int channelId,
    int period,
  ) async {
    final controllerId = _selectedControllerId;
    if (controllerId == null) {
      return;
    }

    _busyChannels.add(channelId);
    notifyListeners();

    try {
      await _onBlinkCommand(controllerId, channelId, period);
    } finally {
      _busyChannels.remove(channelId);
      notifyListeners();
    }
  }

  Future<void> sendStrobeCommand(
    int channelId,
    int flashCount,
    int totalDuration,
    int pauseDuration,
  ) async {
    final controllerId = _selectedControllerId;
    if (controllerId == null) {
      return;
    }

    _busyChannels.add(channelId);
    notifyListeners();

    try {
      await _onStrobeCommand(
        controllerId,
        channelId,
        flashCount,
        totalDuration,
        pauseDuration,
      );
    } finally {
      _busyChannels.remove(channelId);
      notifyListeners();
    }
  }

  Future<void> triggerPreset(int presetId) async {
    final controllerId = _selectedControllerId;
    if (controllerId == null) {
      return;
    }

    _isBusy = true;
    notifyListeners();

    try {
      await _onPresetTrigger(controllerId, presetId);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
