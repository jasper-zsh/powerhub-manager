import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/repositories/device_repository.dart';
import 'package:app/repositories/orchestration_repository.dart';
import 'package:app/repositories/saved_controller_repository.dart';
import 'package:app/repositories/switch_hub_command_service.dart';
import 'package:app/repositories/telemetry_repository.dart';
import 'package:app/services/ble_service.dart';

final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final repository = BleDeviceRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

final telemetryRepositoryProvider = Provider<TelemetryRepository>((ref) {
  return TelemetryRepository();
});

final savedControllerRepositoryProvider =
    Provider<SavedControllerRepository>((ref) {
  return SavedControllerRepository();
});

final orchestrationRepositoryProvider =
    Provider<OrchestrationRepository>((ref) {
  return OrchestrationRepository();
});

final switchHubCommandServiceProvider = Provider<SwitchHubCommandService>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  final commandService = BleSwitchHubCommandService(
    bleService: bleService,
  );
  ref.onDispose(commandService.dispose);
  return commandService;
});

// Provider for BLE service
final bleServiceProvider = Provider<BLEService>((ref) {
  return BLEService();
});
