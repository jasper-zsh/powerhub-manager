import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/monitoring_data.dart';
import 'package:app/repositories/repository_providers.dart';
import 'package:app/repositories/telemetry_repository.dart';

class MonitoringController
    extends StateNotifier<AsyncValue<MonitoringData?>> {
  MonitoringController({required TelemetryRepository repository})
      : _repository = repository,
        super(const AsyncValue.data(null));

  final TelemetryRepository _repository;
  StreamSubscription<MonitoringData>? _subscription;

  Future<void> refreshSnapshot() async {
    state = const AsyncValue.loading();
    try {
      final snapshot = await _repository.readMonitoringData();
      state = AsyncValue.data(snapshot);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  Future<void> startStreaming() async {
    if (_subscription != null) {
      return;
    }
    state = const AsyncValue.loading();
    try {
      final stream = await _repository.subscribeMonitoring();
      _subscription = stream.listen(
        (event) => state = AsyncValue.data(event),
        onError: (error, stackTrace) {
          state = AsyncValue.error(error, stackTrace);
          debugPrint('Monitoring stream error: $error');
        },
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      debugPrint('Failed to start monitoring streaming: $error');
      // Don't rethrow - let the connection succeed even if monitoring fails
    }
  }

  Future<void> stopStreaming() async {
    await _subscription?.cancel();
    _subscription = null;
    await _repository.unsubscribeMonitoring();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final monitoringControllerProvider = StateNotifierProvider<
    MonitoringController, AsyncValue<MonitoringData?>>((ref) {
  final repository = ref.watch(telemetryRepositoryProvider);
  return MonitoringController(repository: repository);
});
