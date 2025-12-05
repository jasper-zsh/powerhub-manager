import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_slot_configuration.dart';
import 'package:app/models/switch_hub/status_data_source.dart';
import 'package:app/models/switch_hub/status_data_type.dart';
import 'package:app/services/switch_hub_ble_service.dart';

/// Service for managing status data refresh and device connectivity
class StatusRefreshService {
  StatusRefreshService() : _bleService = const SwitchHubBleService();

  final SwitchHubBleService _bleService;
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, int> _retryCounters = {};
  final Map<String, Timer?> _retryTimers = {};

  Timer? _periodicRefreshTimer;
  static const Duration _defaultRefreshInterval = Duration(seconds: 2);
  static const int _maxRetryCount = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Initialize the service with status configurations
  Future<void> initialize({
    required Map<int, StatusSlotConfiguration> configurations,
    required void Function(String, StatusDataSource) onDataSourceUpdate,
    required void Function(String, String?, StatusDataType, String?) onStatusUpdate,
  }) async {
    _configurations = configurations;
    _onDataSourceUpdate = onDataSourceUpdate;
    _onStatusUpdate = onStatusUpdate;

    // Identify required remote devices
    final requiredMacs = _getRequiredRemoteMacs();

    // Initialize data sources for all required devices
    for (final mac in requiredMacs) {
      _initializeDataSource(mac);
    }

    // Start periodic refresh
    _startPeriodicRefresh();
  }

  Map<int, StatusSlotConfiguration> _configurations = {};
  void Function(String, StatusDataSource)? _onDataSourceUpdate;
  void Function(String, String?, StatusDataType, String?)? _onStatusUpdate;

  /// Register a connected device for status collection
  void registerDevice(String macAddress, BluetoothDevice device) {
    _connectedDevices[macAddress] = device;
    _resetRetryCount(macAddress);
    _updateDataSourceStatus(macAddress, ConnectionStatus.connected, device.platformName);
    debugPrint('StatusRefresh: Registered device $macAddress');
  }

  /// Unregister a device
  void unregisterDevice(String macAddress) {
    _connectedDevices.remove(macAddress);
    _updateDataSourceStatus(macAddress, ConnectionStatus.disconnected, null);
    _cancelRetryTimer(macAddress);
    debugPrint('StatusRefresh: Unregistered device $macAddress');
  }

  /// Get all registered devices
  Map<String, BluetoothDevice> get connectedDevices => Map.unmodifiable(_connectedDevices);

  /// Force a manual refresh of all status data
  Future<void> refreshAllStatus({BluetoothDevice? localDevice}) async {
    debugPrint('StatusRefresh: Starting manual refresh');

    try {
      // Refresh local data if available
      if (localDevice != null) {
        await _refreshLocalStatusData(localDevice);
      }

      // Refresh remote data from all connected devices
      await _refreshRemoteStatusData();

      debugPrint('StatusRefresh: Manual refresh completed');
    } catch (e) {
      debugPrint('StatusRefresh: Manual refresh failed: $e');
    }
  }

  /// Get connection status for a specific MAC address
  ConnectionStatus getConnectionStatus(String macAddress) {
    if (!_connectedDevices.containsKey(macAddress)) {
      return ConnectionStatus.disconnected;
    }

    final device = _connectedDevices[macAddress]!;
    return switch (device.isConnected) {
      true => ConnectionStatus.connected,
      false => ConnectionStatus.connectionLost,
    };
  }

  /// Start periodic refresh timer
  void _startPeriodicRefresh() {
    _stopPeriodicRefresh();

    _periodicRefreshTimer = Timer.periodic(_defaultRefreshInterval, (_) {
      _performPeriodicRefresh();
    });

    debugPrint('StatusRefresh: Started periodic refresh with ${_defaultRefreshInterval.inSeconds}s interval');
  }

  /// Stop periodic refresh timer
  void _stopPeriodicRefresh() {
    _periodicRefreshTimer?.cancel();
    _periodicRefreshTimer = null;
  }

  /// Perform periodic refresh of status data
  Future<void> _performPeriodicRefresh() async {
    try {
      // Note: This would need access to the local device for complete implementation
      // For now, we'll just refresh remote data

      await _refreshRemoteStatusData();
    } catch (e) {
      debugPrint('StatusRefresh: Periodic refresh failed: $e');
    }
  }

  /// Refresh local status data from SwitchHub device
  Future<void> _refreshLocalStatusData(BluetoothDevice localDevice) async {
    for (final config in _configurations.values) {
      for (final slot in config.slots) {
        if (slot.isLocal && slot.dataType == StatusDataType.voltage) {
          try {
            final voltageData = await _bleService.collectLocalVoltageData(localDevice);
            if (voltageData != null) {
              _onStatusUpdate?.call('LOCAL', null, slot.dataType, voltageData);
            }
          } catch (e) {
            debugPrint('StatusRefresh: Failed to collect local voltage data: $e');
            _onStatusUpdate?.call('LOCAL', null, slot.dataType, null);
          }
        }
      }
    }
  }

  /// Refresh remote status data from connected PowerHub devices
  Future<void> _refreshRemoteStatusData() async {
    final futures = <Future<void>>[];

    for (final config in _configurations.values) {
      for (final slot in config.slots) {
        if (slot.requiresRemoteConnection) {
          final future = _collectRemoteSlotData(slot);
          futures.add(future);
        }
      }
    }

    await Future.wait(futures, eagerError: false);
  }

  /// Collect data for a specific remote status slot
  Future<void> _collectRemoteSlotData(StatusSlot slot) async {
    final mac = slot.sourceMac;
    final device = _connectedDevices[mac];

    if (device == null) {
      debugPrint('StatusRefresh: Device not connected for $mac');
      _onStatusUpdate?.call(mac, slot.params, slot.dataType, null);
      return;
    }

    try {
      final data = await _bleService.collectRemotePowerHubData(slot, _connectedDevices);
      if (data != null) {
        _onStatusUpdate?.call(mac, slot.params, slot.dataType, data);
        _resetRetryCount(mac);
      } else {
        _onStatusUpdate?.call(mac, slot.params, slot.dataType, null);
      }
    } catch (e) {
      debugPrint('StatusRefresh: Failed to collect data from $mac: $e');
      _onStatusUpdate?.call(mac, slot.params, slot.dataType, null);
      _handleConnectionFailure(mac);
    }
  }

  /// Handle connection failure and trigger retry logic
  void _handleConnectionFailure(String macAddress) {
    final retryCount = _retryCounters[macAddress] ?? 0;

    if (retryCount >= _maxRetryCount) {
      _updateDataSourceStatus(macAddress, ConnectionStatus.connectionFailed, null);
      return;
    }

    _incrementRetryCount(macAddress);
    _updateDataSourceStatus(macAddress, ConnectionStatus.connecting, null);

    // Schedule retry
    _scheduleRetry(macAddress);
  }

  /// Schedule a retry attempt for a device
  void _scheduleRetry(String macAddress) {
    _cancelRetryTimer(macAddress);

    final retryCount = _retryCounters[macAddress] ?? 0;
    final delay = _retryDelay * (retryCount + 1); // Exponential backoff

    _retryTimers[macAddress] = Timer(delay, () async {
      debugPrint('StatusRefresh: Retrying connection to $macAddress (attempt ${retryCount + 1})');

      try {
        // Attempt to reconnect and collect data
        final device = _connectedDevices[macAddress];
        if (device != null) {
          await device.connect();
          _resetRetryCount(macAddress);
          _updateDataSourceStatus(macAddress, ConnectionStatus.connected, device.platformName);

          // Trigger refresh after successful reconnection
          await _refreshRemoteStatusData();
        }
      } catch (e) {
        debugPrint('StatusRefresh: Retry failed for $macAddress: $e');
        _handleConnectionFailure(macAddress);
      }
    });

    debugPrint('StatusRefresh: Scheduled retry for $macAddress in ${delay.inSeconds}s');
  }

  /// Cancel retry timer for a device
  void _cancelRetryTimer(String macAddress) {
    _retryTimers[macAddress]?.cancel();
    _retryTimers.remove(macAddress);
  }

  /// Get all required remote MAC addresses from configurations
  Set<String> _getRequiredRemoteMacs() {
    final macs = <String>{};
    for (final config in _configurations.values) {
      macs.addAll(config.remoteMacAddresses);
    }
    return macs;
  }

  /// Initialize data source for a MAC address
  void _initializeDataSource(String macAddress) {
    final dataSource = StatusDataSource(
      macAddress: macAddress,
      connectionStatus: _connectedDevices.containsKey(macAddress)
          ? ConnectionStatus.connected
          : ConnectionStatus.disconnected,
    );

    _onDataSourceUpdate?.call(macAddress, dataSource);
    debugPrint('StatusRefresh: Initialized data source for $macAddress');
  }

  /// Update data source connection status
  void _updateDataSourceStatus(String macAddress, ConnectionStatus status, String? deviceName) {
    final existingSource = StatusDataSource(
      macAddress: macAddress,
      deviceName: deviceName,
      connectionStatus: status,
      retryCount: _retryCounters[macAddress] ?? 0,
    );

    _onDataSourceUpdate?.call(macAddress, existingSource);
  }

  /// Reset retry count for a device
  void _resetRetryCount(String macAddress) {
    _retryCounters[macAddress] = 0;
    _cancelRetryTimer(macAddress);
  }

  /// Increment retry count for a device
  void _incrementRetryCount(String macAddress) {
    _retryCounters[macAddress] = (_retryCounters[macAddress] ?? 0) + 1;
  }

  /// Dispose of all resources
  void dispose() {
    _stopPeriodicRefresh();

    for (final timer in _retryTimers.values) {
      timer?.cancel();
    }
    _retryTimers.clear();

    _connectedDevices.clear();
    _retryCounters.clear();

    debugPrint('StatusRefresh: Service disposed');
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'connectedDevices': _connectedDevices.length,
      'requiredDevices': _getRequiredRemoteMacs().length,
      'retryTimersActive': _retryTimers.values.where((t) => t?.isActive == true).length,
      'configurationsCount': _configurations.length,
      'totalSlots': _configurations.values.fold(0, (sum, config) => sum + config.slots.length),
    };
  }
}