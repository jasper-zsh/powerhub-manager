import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/channel.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';
import 'package:app/repositories/device_repository.dart';
import 'package:app/repositories/repository_providers.dart';
import 'package:app/controllers/connection_session_controller.dart';

class DeviceControlState {
  const DeviceControlState({
    required this.selectedControllerId,
    required this.isConnected,
    required this.channels,
    required this.isBusy,
    this.activeDevice,
    this.errorMessage,
    this.busyChannels = const <int>{},
  });

  factory DeviceControlState.initial() => const DeviceControlState(
    selectedControllerId: null,
    isConnected: false,
    channels: <Channel>[],
    isBusy: false,
  );

  final String? selectedControllerId;
  final bool isConnected;
  final List<Channel> channels;
  final bool isBusy;
  final PWMController? activeDevice;
  final String? errorMessage;
  final Set<int> busyChannels;

  bool isChannelBusy(int channelId) => busyChannels.contains(channelId);

  DeviceControlState copyWith({
    String? selectedControllerId,
    bool? isConnected,
    List<Channel>? channels,
    bool? isBusy,
    PWMController? activeDevice,
    String? errorMessage,
    bool clearError = false,
    Set<int>? busyChannels,
  }) {
    return DeviceControlState(
      selectedControllerId: selectedControllerId ?? this.selectedControllerId,
      isConnected: isConnected ?? this.isConnected,
      channels: channels ?? this.channels,
      isBusy: isBusy ?? this.isBusy,
      activeDevice: activeDevice ?? this.activeDevice,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      busyChannels: busyChannels ?? this.busyChannels,
    );
  }
}

class DeviceControlController extends StateNotifier<DeviceControlState> {
  DeviceControlController({
    required this.ref,
    required DeviceRepository repository,
  }) : _repository = repository,
       super(DeviceControlState.initial()) {
    // 监听连接会话状态变化
    _connectionSessionSubscription = ref.listen(
      connectionSessionControllerProvider,
      (previous, next) => _handleConnectionSessionChange(next),
    );
  }

  final Ref ref;
  final DeviceRepository _repository;
  ProviderSubscription<ConnectionSessionState>? _connectionSessionSubscription;
  final Map<int, Timer> _setCommandDebouncers = <int, Timer>{};

  void selectController(String controllerId) {
    if (state.selectedControllerId == controllerId) {
      return;
    }

    state = state.copyWith(
      selectedControllerId: controllerId,
      clearError: true,
    );

    // 如果当前连接的设备不是选中的设备，尝试连接
    final connectionState = ref.read(connectionSessionControllerProvider);
    if (connectionState.controllerId != controllerId) {
      _connectToController(controllerId);
    }
  }

  Future<void> _connectToController(String controllerId) async {
    try {
      await ref
          .read(connectionSessionControllerProvider.notifier)
          .connect(controllerId);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Failed to connect: $error');
    }
  }

  void _handleConnectionSessionChange(ConnectionSessionState connectionState) {
    final isConnected = connectionState.isConnected;
    final controllerId = connectionState.controllerId;

    // 如果连接的设备不是当前选中的设备，忽略
    if (controllerId != state.selectedControllerId) {
      return;
    }

    // 更新连接状态
    state = state.copyWith(isConnected: isConnected, clearError: true);

    // 如果已连接，读取通道状态
    if (isConnected) {
      _refreshChannelStates();
    } else {
      // 断开连接时清理通道状态
      state = state.copyWith(channels: <Channel>[], activeDevice: null);
    }
  }

  Future<void> _refreshChannelStates() async {
    if (!state.isConnected) {
      return;
    }

    try {
      final channelValues = await _repository.readChannelStates();
      final channels = <Channel>[];

      for (int i = 0; i < channelValues.length; i++) {
        channels.add(Channel(id: i, value: channelValues[i]));
      }

      // 创建一个模拟的 PWMController 对象来存储通道状态
      final activeDevice = PWMController(
        id: state.selectedControllerId!,
        name: 'Connected Device',
        rssi: 0,
        channels: channels,
      );

      state = state.copyWith(
        channels: channels,
        activeDevice: activeDevice,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to read channel states: $error',
      );
    }
  }

  void handleSetValue(int channelId, int value) {
    // 更新预览值
    _setChannelPreview(channelId, value);

    // 防抖处理
    _setCommandDebouncers[channelId]?.cancel();
    _setCommandDebouncers[channelId] = Timer(
      const Duration(milliseconds: 150),
      () {
        _setCommandDebouncers.remove(channelId);
        updateChannel(channelId, value);
      },
    );
  }

  void _setChannelPreview(int channelId, int value) {
    if (channelId < 0 || channelId >= state.channels.length) {
      return;
    }

    final updatedChannels = <Channel>[];
    for (int i = 0; i < state.channels.length; i++) {
      if (i == channelId) {
        // 创建一个新的 Channel 实例，因为 Channel 没有 copyWith 方法
        final channel = state.channels[i];
        updatedChannels.add(
          Channel(
            id: channel.id,
            value: value,
            name: channel.name,
            isEnabled: channel.isEnabled,
          ),
        );
      } else {
        updatedChannels.add(state.channels[i]);
      }
    }

    state = state.copyWith(channels: updatedChannels);
  }

  Future<void> updateChannel(int channelId, int value) async {
    if (!state.isConnected || state.selectedControllerId == null) {
      return;
    }

    final busyChannels = Set<int>.from(state.busyChannels)..add(channelId);
    state = state.copyWith(busyChannels: busyChannels, clearError: true);

    try {
      final command = SetCommand(channel: channelId, value: value);
      await _repository.sendSetCommand(command);
    } catch (error) {
      state = state.copyWith(errorMessage: 'Failed to update channel: $error');
      // 恢复原始值
      _setChannelPreview(channelId, state.channels[channelId].value);
    } finally {
      final newBusyChannels = Set<int>.from(state.busyChannels)
        ..remove(channelId);
      state = state.copyWith(busyChannels: newBusyChannels);
    }
  }

  Future<void> sendFadeCommand({
    required int channelId,
    required int targetValue,
    required int duration,
  }) async {
    if (!state.isConnected || state.selectedControllerId == null) {
      throw Exception('Not connected');
    }

    final busyChannels = Set<int>.from(state.busyChannels)..add(channelId);
    state = state.copyWith(
      busyChannels: busyChannels,
      isBusy: true,
      clearError: true,
    );

    try {
      final command = FadeCommand(
        channel: channelId,
        targetValue: targetValue,
        duration: duration,
      );
      await _repository.sendFadeCommand(command);

      // 更新通道预览值
      _setChannelPreview(channelId, targetValue);
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to send fade command: $error',
      );
      rethrow;
    } finally {
      final newBusyChannels = Set<int>.from(state.busyChannels)
        ..remove(channelId);
      state = state.copyWith(busyChannels: newBusyChannels, isBusy: false);
    }
  }

  Future<void> sendBlinkCommand({
    required int channelId,
    required int period,
  }) async {
    if (!state.isConnected || state.selectedControllerId == null) {
      throw Exception('Not connected');
    }

    final busyChannels = Set<int>.from(state.busyChannels)..add(channelId);
    state = state.copyWith(
      busyChannels: busyChannels,
      isBusy: true,
      clearError: true,
    );

    try {
      final command = BlinkCommand(channel: channelId, period: period);
      await _repository.sendBlinkCommand(command);
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to send blink command: $error',
      );
      rethrow;
    } finally {
      final newBusyChannels = Set<int>.from(state.busyChannels)
        ..remove(channelId);
      state = state.copyWith(busyChannels: newBusyChannels, isBusy: false);
    }
  }

  Future<void> sendStrobeCommand({
    required int channelId,
    required int flashCount,
    required int totalDuration,
    required int pauseDuration,
  }) async {
    if (!state.isConnected || state.selectedControllerId == null) {
      throw Exception('Not connected');
    }

    final busyChannels = Set<int>.from(state.busyChannels)..add(channelId);
    state = state.copyWith(
      busyChannels: busyChannels,
      isBusy: true,
      clearError: true,
    );

    try {
      final command = StrobeCommand(
        channel: channelId,
        flashCount: flashCount,
        totalDuration: totalDuration,
        pauseDuration: pauseDuration,
      );
      await _repository.sendStrobeCommand(command);
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to send strobe command: $error',
      );
      rethrow;
    } finally {
      final newBusyChannels = Set<int>.from(state.busyChannels)
        ..remove(channelId);
      state = state.copyWith(busyChannels: newBusyChannels, isBusy: false);
    }
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  @override
  void dispose() {
    for (final timer in _setCommandDebouncers.values) {
      timer.cancel();
    }
    _setCommandDebouncers.clear();
    _connectionSessionSubscription?.close();
    super.dispose();
  }
}

final deviceControlControllerProvider =
    StateNotifierProvider<DeviceControlController, DeviceControlState>((ref) {
      final repository = ref.watch(deviceRepositoryProvider);
      return DeviceControlController(ref: ref, repository: repository);
    });
