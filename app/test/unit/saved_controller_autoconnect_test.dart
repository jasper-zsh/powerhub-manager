import 'dart:collection';

import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/shared_preferences_stub.dart';

class FakeBLEService extends BLEService {
  FakeBLEService({Set<String>? connectFailures})
      : _connectFailures = connectFailures ?? {};

  final Queue<Set<String>> _availabilityQueue = Queue();
  final Set<String> _connectFailures;
  final List<String> connectCalls = [];

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
  group('Saved controller auto-connect', () {
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

    test('connects available saved controllers and resets retry state', () async {
      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );

      bleService.enqueueAvailability({'controller-001'});

      await provider.reconcileSavedControllers(
        currentTime: DateTime(2025, 1, 1, 12),
      );

      expect(bleService.connectCalls, contains('controller-001'));
      final record = provider.connectionStatusRecords.first;
      expect(record.scanState, ScanState.idle);
      expect(record.lastResult, LastScanResult.found);
      expect(record.retryAttempts, 0);
      expect(
        provider.savedControllers.first.connectionStatus,
        SavedControllerConnectionStatus.connected,
      );
    });

    test('marks controller unavailable when retries exhausted', () async {
      await provider.saveController(
        controllerId: 'controller-002',
        alias: 'Workshop',
      );

      final updated = provider.savedControllers.first.copyWith(
        retryPolicy: RetryPolicy.defaults(
          maxAttempts: 1,
          backoff: const Duration(seconds: 10),
        ),
      );

      await storageService.persistSavedControllers([updated]);
      await provider.loadSavedControllers();

      bleService.enqueueAvailability(<String>{});

      final now = DateTime(2025, 1, 1, 12);

      await provider.reconcileSavedControllers(currentTime: now);

      final record = provider.connectionStatusRecords.first;
      expect(record.scanState, ScanState.idle);
      expect(record.lastResult, LastScanResult.notFound);
      expect(record.retryAttempts, 1);
      expect(record.nextRetryAt, isNull);
      expect(
        provider.savedControllers.first.connectionStatus,
        SavedControllerConnectionStatus.unavailable,
      );
    });
  });
}
