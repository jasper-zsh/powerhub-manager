import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/repositories/device_repository.dart';
import 'package:app/repositories/repository_providers.dart';

enum ConnectionLifecycle { disconnected, connecting, connected, degraded, error }

class ConnectionSessionState {
  const ConnectionSessionState({
    required this.lifecycle,
    this.controllerId,
    this.errorMessage,
    this.connectionHealth,
    this.isBusy = false,
    this.lastAttemptAt,
    this.lastSuccessAt,
    this.lastHealthCheckAt,
  });

  factory ConnectionSessionState.initial() => const ConnectionSessionState(
        lifecycle: ConnectionLifecycle.disconnected,
      );

  final ConnectionLifecycle lifecycle;
  final String? controllerId;
  final String? errorMessage;
  final Map<String, dynamic>? connectionHealth;
  final bool isBusy;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final DateTime? lastHealthCheckAt;

  bool get isConnected =>
      lifecycle == ConnectionLifecycle.connected ||
      lifecycle == ConnectionLifecycle.degraded;

  ConnectionSessionState copyWith({
    ConnectionLifecycle? lifecycle,
    String? controllerId,
    bool clearControllerId = false,
    String? errorMessage,
    bool clearError = false,
    Map<String, dynamic>? connectionHealth,
    bool replaceConnectionHealth = false,
    bool? isBusy,
    DateTime? lastAttemptAt,
    DateTime? lastSuccessAt,
    DateTime? lastHealthCheckAt,
  }) {
    return ConnectionSessionState(
      lifecycle: lifecycle ?? this.lifecycle,
      controllerId: clearControllerId
          ? null
          : controllerId ?? this.controllerId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      connectionHealth: replaceConnectionHealth
          ? connectionHealth
          : connectionHealth ?? this.connectionHealth,
      isBusy: isBusy ?? this.isBusy,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      lastHealthCheckAt: lastHealthCheckAt ?? this.lastHealthCheckAt,
    );
  }
}

class ConnectionSessionController
    extends StateNotifier<ConnectionSessionState> {
  ConnectionSessionController({
    required this.ref,
    required DeviceRepository repository,
  })  : _repository = repository,
        super(ConnectionSessionState.initial());

  final Ref ref;
  final DeviceRepository _repository;
  Timer? _healthTimer;

  Future<void> connect(String controllerId) async {
    if (state.isBusy) {
      return;
    }

    state = state.copyWith(
      lifecycle: ConnectionLifecycle.connecting,
      controllerId: controllerId,
      isBusy: true,
      clearError: true,
      lastAttemptAt: DateTime.now(),
    );

    try {
      await _repository.connect(controllerId);
      state = state.copyWith(
        lifecycle: ConnectionLifecycle.connected,
        isBusy: false,
        lastSuccessAt: DateTime.now(),
        connectionHealth: _repository.connectionHealth,
        replaceConnectionHealth: true,
      );
      _startHealthMonitor();

      // Try to start telemetry streams, but don't fail the connection if they fail
      _startTelemetrySafely();
    } catch (error) {
      state = state.copyWith(
        lifecycle: ConnectionLifecycle.error,
        isBusy: false,
        errorMessage: 'Failed to connect: $error',
      );
      _stopHealthMonitor();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (state.lifecycle == ConnectionLifecycle.disconnected &&
        state.controllerId == null) {
      return;
    }

    state = state.copyWith(
      isBusy: true,
      clearError: true,
    );

    try {
      await _repository.disconnect();
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to disconnect: $error',
      );
    } finally {
      _stopHealthMonitor();
      _stopTelemetryStreams();
      state = state.copyWith(
        lifecycle: ConnectionLifecycle.disconnected,
        isBusy: false,
        clearControllerId: true,
        replaceConnectionHealth: true,
        connectionHealth: const <String, dynamic>{
          'healthy': false,
        },
      );
    }
  }

  void refreshHealth() {
    _updateHealthState();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  void _startHealthMonitor() {
    _healthTimer?.cancel();
    _updateHealthState();
    _healthTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _updateHealthState();
    });
  }

  void _updateHealthState() {
    final health = _repository.connectionHealth;
    final healthy = health['healthy'] != false;
    state = state.copyWith(
      replaceConnectionHealth: true,
      connectionHealth: Map<String, dynamic>.unmodifiable(health),
      lifecycle: state.lifecycle == ConnectionLifecycle.connected && !healthy
          ? ConnectionLifecycle.degraded
          : healthy
              ? ConnectionLifecycle.connected
              : state.lifecycle,
      lastHealthCheckAt: DateTime.now(),
    );
  }

  void _stopHealthMonitor() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }

  void _startTelemetryStreams() {
    ref.read(monitoringControllerProvider.notifier).startStreaming();
  }

  void _startTelemetrySafely() {
    try {
      // Try to start monitoring streams safely
      ref.read(monitoringControllerProvider.notifier).startStreaming();
    } catch (error) {
      debugPrint('Failed to start monitoring streaming: $error');
      // Don't fail the connection, just log the error
    }
  }

  void _stopTelemetryStreams() {
    ref.read(monitoringControllerProvider.notifier).stopStreaming();
  }

  @override
  void dispose() {
    _stopHealthMonitor();
    _stopTelemetryStreams();
    super.dispose();
  }
}

final connectionSessionControllerProvider =
    StateNotifierProvider<ConnectionSessionController, ConnectionSessionState>(
        (ref) {
  final repository = ref.watch(deviceRepositoryProvider);
  return ConnectionSessionController(ref: ref, repository: repository);
});
