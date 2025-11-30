import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/controllers/switch_hub_controller.dart';
import 'package:app/models/switch_hub/monitoring_data.dart';
import 'package:app/models/switch_hub/voltage_thresholds.dart';

/// Provider for SwitchHub controller
final switchHubControllerProvider = StateNotifierProvider.autoDispose<SwitchHubController, SwitchHubState>((ref) {
  return SwitchHubController(ref);
});

/// Provider for getting current monitoring data stream
final switchHubMonitoringDataProvider = Provider.autoDispose<SwitchHubMonitoringData?>((ref) {
  return ref.watch(switchHubControllerProvider).monitoringData;
});

/// Provider for getting current voltage thresholds
final switchHubVoltageThresholdsProvider = Provider.autoDispose<SwitchHubVoltageThresholds?>((ref) {
  return ref.watch(switchHubControllerProvider).voltageThresholds;
});

/// Provider for monitoring status
final switchHubIsMonitoringProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(switchHubControllerProvider).isMonitoring;
});

/// Provider for discovered devices
final switchHubDevicesProvider = Provider.autoDispose<List>((ref) {
  return ref.watch(switchHubControllerProvider).discoveredDevices;
});

/// Provider for connection status
final switchHubConnectionStatusProvider = Provider.autoDispose<String?>((ref) {
  final state = ref.watch(switchHubControllerProvider);
  if (state.errorMessage != null) {
    return state.errorMessage;
  }
  return state.statusMessage;
});