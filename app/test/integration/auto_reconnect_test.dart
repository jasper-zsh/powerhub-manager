import 'dart:collection';

import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/shared_preferences_stub.dart';

class FakeBLEService extends BLEService {
  final Queue<Set<String>> _availabilityQueue = Queue();
  final Set<String> _connectFailures;
  final List<String> connectCalls = [];

  FakeBLEService({Set<String>? connectFailures})
      : _connectFailures = connectFailures ?? {};

  void enqueueAvailability(Set<String> availableIds) {
    _availabilityQueue.add(availableIds);
  }

  @override
  Future<Set<String>> scanForControllerIds(
    Iterable<String> controllerIds, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_availabilityQueue.isEmpty) {
      return <String>{};
    }

    final next = _availabilityQueue.removeFirst();
    return next.where(controllerIds.contains).toSet();
  }

  @override
  Future<void> connect(String deviceId) async {
    connectCalls.add(deviceId);
    if (_connectFailures.contains(deviceId)) {
      throw Exception('CONNECTION_FAILED');
    }
  }
}

void main() {
  group('Auto reconnect integration', () {
    late StorageService storageService;
    late FakeBLEService bleService;
    late AppStateProvider provider;

    setUp(() async {
      await resetSharedPreferences();
      storageService = StorageService();
      await storageService.init();

      bleService = FakeBLEService();
      provider = AppStateProvider(
        bleService: bleService,
        storageService: storageService,
      );
      await provider.init();
    });

    test('connects all saved controllers across multiple cycles', () async {
      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );

      await provider.saveController(
        controllerId: 'controller-002',
        alias: 'Workshop',
      );

      final adjustedControllers = provider.savedControllers
          .map(
            (controller) => controller.controllerId == 'controller-002'
                ? controller.copyWith(
                    retryPolicy: RetryPolicy.defaults(
                      maxAttempts: 2,
                      backoff: const Duration(seconds: 5),
                    ),
                  )
                : controller,
          )
          .toList();

      await storageService.persistSavedControllers(adjustedControllers);
      await provider.loadSavedControllers();

      final now = DateTime(2025, 1, 1, 12);

      bleService.enqueueAvailability({'controller-001'});
      await provider.reconcileSavedControllers(currentTime: now);

      expect(
        provider.savedControllers
            .firstWhere((c) => c.controllerId == 'controller-001')
            .connectionStatus,
        SavedControllerConnectionStatus.connected,
      );

      final secondRecord = provider.connectionStatusRecords
          .firstWhere((record) => record.controller.controllerId == 'controller-002');
      expect(secondRecord.scanState, ScanState.waitingRetry);
      expect(secondRecord.retryAttempts, 1);

      bleService.enqueueAvailability({'controller-002'});
      await provider.reconcileSavedControllers(
        currentTime: now.add(const Duration(seconds: 10)),
      );

      expect(
        provider.savedControllers.every(
          (controller) =>
              controller.connectionStatus ==
              SavedControllerConnectionStatus.connected,
        ),
        isTrue,
      );

      expect(bleService.connectCalls, containsAll(['controller-001', 'controller-002']));
    });
  });
}
