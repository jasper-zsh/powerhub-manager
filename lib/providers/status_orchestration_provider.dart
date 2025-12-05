import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/status_slot_configuration.dart';
import 'package:app/models/switch_hub/status_data_source.dart';
import 'package:app/models/switch_hub/status_data_type.dart';
import 'package:app/services/switch_hub_ble_service.dart';

/// State for status orchestration
class StatusOrchestrationState {
  const StatusOrchestrationState({
    required this.statusConfigurations,
    required this.remoteDataSources,
    required this.isConnected,
    required this.isRefreshing,
    required this.lastUpdate,
    this.error,
  });

  factory StatusOrchestrationState.initial() => const StatusOrchestrationState(
    statusConfigurations: {},
    remoteDataSources: {},
    isConnected: false,
    isRefreshing: false,
    lastUpdate: null,
  );

  final Map<int, StatusSlotConfiguration> statusConfigurations; // switchId -> configuration
  final Map<String, StatusDataSource> remoteDataSources; // MAC -> data source
  final bool isConnected;
  final bool isRefreshing;
  final DateTime? lastUpdate;
  final String? error;

  StatusOrchestrationState copyWith({
    Map<int, StatusSlotConfiguration>? statusConfigurations,
    Map<String, StatusDataSource>? remoteDataSources,
    bool? isConnected,
    bool? isRefreshing,
    DateTime? lastUpdate,
    String? error,
  }) {
    return StatusOrchestrationState(
      statusConfigurations: statusConfigurations ?? this.statusConfigurations,
      remoteDataSources: remoteDataSources ?? this.remoteDataSources,
      isConnected: isConnected ?? this.isConnected,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusOrchestrationState &&
        mapEquals(other.statusConfigurations, statusConfigurations) &&
        mapEquals(other.remoteDataSources, remoteDataSources) &&
        other.isConnected == isConnected &&
        other.isRefreshing == isRefreshing &&
        other.lastUpdate == lastUpdate &&
        other.error == error;
  }

  @override
  int get hashCode {
    return Object.hash(
      statusConfigurations,
      remoteDataSources,
      isConnected,
      isRefreshing,
      lastUpdate,
      error,
    );
  }

  @override
  String toString() {
    return 'StatusOrchestrationState(statusConfigurations: ${statusConfigurations.length}, remoteDataSources: ${remoteDataSources.length}, isConnected: $isConnected, isRefreshing: $isRefreshing)';
  }
}

/// Controller for status orchestration state
class StatusOrchestrationController extends StateNotifier<StatusOrchestrationState> {
  StatusOrchestrationController(this.ref) : super(StatusOrchestrationState.initial());

  final Ref ref;
  final SwitchHubBleService _bleService = const SwitchHubBleService();
  Timer? _refreshTimer;

  // Map to store connected devices
  final Map<String, BluetoothDevice> _connectedDevices = {};

  /// Initialize status orchestration with a SwitchHub configuration
  Future<void> initialize(SwitchHubConfig config, {BluetoothDevice? localDevice}) async {
    try {
      state = state.copyWith(isRefreshing: true, error: null);

      // Extract status slots from configuration
      _bleService.extractStatusSlots(config);

      // Group status slots by switch ID
      final configurations = <int, StatusSlotConfiguration>{};

      for (final switchHub in config.switches) {
        if (switchHub.uiConfig?.newStatusSlots.isNotEmpty == true) {
          final slots = switchHub.uiConfig!.newStatusSlots.take(2).toList(); // Max 2 slots per switch

          configurations[switchHub.switchId] = StatusSlotConfiguration(
            slot1: slots.isNotEmpty ? slots[0] : null,
            slot2: slots.length > 1 ? slots[1] : null,
            isConfigured: slots.isNotEmpty,
          );
        }
      }

      // Initialize remote data sources
      final remoteSources = <String, StatusDataSource>{};
      for (final configuration in configurations.values) {
        for (final slot in configuration.slots) {
          if (slot.requiresRemoteConnection && !remoteSources.containsKey(slot.sourceMac)) {
            remoteSources[slot.sourceMac] = StatusDataSource(
              macAddress: slot.sourceMac,
            );
          }
        }
      }

      state = state.copyWith(
        statusConfigurations: configurations,
        remoteDataSources: remoteSources,
        isRefreshing: false,
        lastUpdate: DateTime.now(),
        isConnected: localDevice != null,
      );

      // Start periodic refresh if we have status slots to monitor
      if (configurations.isNotEmpty) {
        _startPeriodicRefresh();
      }

    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: 'Failed to initialize status orchestration: $e',
      );
    }
  }

  /// Update status value for a specific slot
  void updateStatusValue({
    required int switchId,
    required StatusDataType dataType,
    required String? params,
    required String? newValue,
  }) {
    final config = state.statusConfigurations[switchId];
    if (config == null) return;

    final updatedConfig = config.updateSlotValue(
      sourceMac: 'LOCAL', // This would need to be determined based on the slot
      dataType: dataType,
      params: params,
      newValue: newValue,
    );

    final updatedConfigs = Map<int, StatusSlotConfiguration>.from(state.statusConfigurations);
    updatedConfigs[switchId] = updatedConfig;

    state = state.copyWith(
      statusConfigurations: updatedConfigs,
      lastUpdate: DateTime.now(),
    );
  }

  /// Update connection status for a remote device
  void updateDeviceConnectionStatus({
    required String macAddress,
    required ConnectionStatus status,
    String? deviceName,
  }) {
    final existingSource = state.remoteDataSources[macAddress];
    if (existingSource == null) return;

    final updatedSource = existingSource.copyWith(
      connectionStatus: status,
      deviceName: deviceName,
    );

    final updatedSources = Map<String, StatusDataSource>.from(state.remoteDataSources);
    updatedSources[macAddress] = updatedSource;

    state = state.copyWith(
      remoteDataSources: updatedSources,
      lastUpdate: DateTime.now(),
    );
  }

  /// Get status configuration for a specific switch
  StatusSlotConfiguration? getStatusConfiguration(int switchId) {
    return state.statusConfigurations[switchId];
  }

  /// Get all remote MAC addresses that need to be connected
  Set<String> get requiredRemoteMacs {
    final macs = <String>{};
    for (final config in state.statusConfigurations.values) {
      macs.addAll(config.remoteMacAddresses);
    }
    return macs;
  }

  /// Register a connected device for remote data collection
  void registerConnectedDevice(String macAddress, BluetoothDevice device) {
    _connectedDevices[macAddress] = device;

    // Update the data source connection status
    updateDeviceConnectionStatus(
      macAddress: macAddress,
      status: ConnectionStatus.connected,
      deviceName: device.platformName.isNotEmpty ? device.platformName : macAddress,
    );
  }

  /// Unregister a disconnected device
  void unregisterConnectedDevice(String macAddress) {
    _connectedDevices.remove(macAddress);

    // Update the data source connection status
    updateDeviceConnectionStatus(
      macAddress: macAddress,
      status: ConnectionStatus.disconnected,
    );
  }

  /// Manually refresh status data
  Future<void> refreshStatusData({BluetoothDevice? localDevice}) async {
    if (state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, error: null);

    try {
      // Collect local voltage data if we have local device and slots requiring it
      if (localDevice != null) {
        await _refreshLocalData(localDevice);
      }

      // Collect remote data from connected devices
      await _refreshRemoteData();

      state = state.copyWith(
        isRefreshing: false,
        lastUpdate: DateTime.now(),
      );

    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: 'Failed to refresh status data: $e',
      );
    }
  }

  /// Refresh local data from SwitchHub device
  Future<void> _refreshLocalData(BluetoothDevice localDevice) async {
    for (final config in state.statusConfigurations.values) {
      for (final slot in config.slots) {
        if (slot.isLocal && slot.dataType == StatusDataType.voltage) {
          final voltageData = await _bleService.collectLocalVoltageData(localDevice);
          if (voltageData != null) {
            // Update the slot with new voltage data
            slot.withValue(voltageData);
            // This is simplified - in a real implementation, we'd need to find which switch this slot belongs to
          }
        }
      }
    }
  }

  /// Refresh remote data from connected PowerHub devices
  Future<void> _refreshRemoteData() async {
    for (final config in state.statusConfigurations.values) {
      for (final slot in config.slots) {
        if (slot.requiresRemoteConnection) {
          final remoteData = await _bleService.collectRemotePowerHubData(slot, _connectedDevices);
          if (remoteData != null) {
            // Update the slot with new remote data
            slot.withValue(remoteData);
            // This is simplified - in a real implementation, we'd need to find which switch this slot belongs to
          }
        }
      }
    }
  }

  /// Start periodic refresh timer
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshStatusData();
    });
  }

  /// Stop periodic refresh timer
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Reset the controller state
  void reset() {
    stopPeriodicRefresh();
    _connectedDevices.clear();
    state = StatusOrchestrationState.initial();
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    _connectedDevices.clear();
    super.dispose();
  }
}

/// Provider for status orchestration controller
final statusOrchestrationProvider = StateNotifierProvider.autoDispose<StatusOrchestrationController, StatusOrchestrationState>((ref) {
  return StatusOrchestrationController(ref);
});

/// Provider for getting status configurations
final statusConfigurationsProvider = Provider.autoDispose<Map<int, StatusSlotConfiguration>>((ref) {
  return ref.watch(statusOrchestrationProvider).statusConfigurations;
});

/// Provider for getting remote data sources
final remoteDataSourcesProvider = Provider.autoDispose<Map<String, StatusDataSource>>((ref) {
  return ref.watch(statusOrchestrationProvider).remoteDataSources;
});

/// Provider for checking if status orchestration is active
final isStatusOrchestrationActiveProvider = Provider.autoDispose<bool>((ref) {
  final state = ref.watch(statusOrchestrationProvider);
  return state.statusConfigurations.isNotEmpty;
});

/// Provider for getting status orchestration error
final statusOrchestrationErrorProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(statusOrchestrationProvider).error;
});

/// Provider for checking if status data is refreshing
final isStatusDataRefreshingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(statusOrchestrationProvider).isRefreshing;
});