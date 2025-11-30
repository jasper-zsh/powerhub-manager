import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/power_management.dart';
import 'package:app/repositories/power_management_repository.dart';
import 'package:app/repositories/repository_providers.dart';

/// State for power management configuration and operations
class PowerManagementState {
  const PowerManagementState({
    this.config,
    this.isLoading = false,
    this.error,
    this.lastOperation,
  });

  final PowerManagementConfig? config;
  final bool isLoading;
  final String? error;
  final PowerManagementOperation? lastOperation;

  PowerManagementState copyWith({
    PowerManagementConfig? config,
    bool? isLoading,
    String? error,
    PowerManagementOperation? lastOperation,
    bool clearError = false,
    bool clearLastOperation = false,
  }) {
    return PowerManagementState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      lastOperation: clearLastOperation ? null : lastOperation ?? this.lastOperation,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PowerManagementState &&
        other.config == config &&
        other.isLoading == isLoading &&
        other.error == error &&
        other.lastOperation == lastOperation;
  }

  @override
  int get hashCode {
    return config.hashCode ^
        isLoading.hashCode ^
        error.hashCode ^
        lastOperation.hashCode;
  }
}

/// Represents the last power management operation performed
enum PowerManagementOperation {
  readConfig,
  setHighTempThreshold,
  setRecoveryThreshold,
  setSleepVoltage,
  setWakeVoltage,
  forceSleep,
  forceWake,
}

/// Controller for managing PowerHub power management configuration
class PowerManagementController
    extends StateNotifier<PowerManagementState> {
  PowerManagementController({required PowerManagementRepository repository})
      : _repository = repository,
        super(const PowerManagementState());

  final PowerManagementRepository _repository;

  /// Refresh the power management configuration from the device
  Future<void> refreshConfig() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final config = await _repository.readConfig();
      state = state.copyWith(
        config: config,
        isLoading: false,
        lastOperation: PowerManagementOperation.readConfig,
      );
    } catch (e) {
      debugPrint('Failed to refresh power management config: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.readConfig,
      );
    }
  }

  /// Set the high temperature threshold
  ///
  /// [temperatureCelsius] Temperature in Celsius (0-150°C)
  Future<void> setHighTemperatureThreshold(double temperatureCelsius) async {
    if (!_validateTemperature(temperatureCelsius)) {
      state = state.copyWith(
        error: 'High temperature must be between 0°C and 150°C',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.setHighTemperatureThreshold(temperatureCelsius);
      await refreshConfig(); // Refresh to verify the change
      state = state.copyWith(
        isLoading: false,
        lastOperation: PowerManagementOperation.setHighTempThreshold,
      );
    } catch (e) {
      debugPrint('Failed to set high temperature threshold: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.setHighTempThreshold,
      );
    }
  }

  /// Set the recovery temperature threshold
  ///
  /// [temperatureCelsius] Temperature in Celsius (0-150°C)
  Future<void> setRecoveryThreshold(double temperatureCelsius) async {
    if (!_validateTemperature(temperatureCelsius)) {
      state = state.copyWith(
        error: 'Recovery temperature must be between 0°C and 150°C',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.setRecoveryThreshold(temperatureCelsius);
      await refreshConfig(); // Refresh to verify the change
      state = state.copyWith(
        isLoading: false,
        lastOperation: PowerManagementOperation.setRecoveryThreshold,
      );
    } catch (e) {
      debugPrint('Failed to set recovery threshold: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.setRecoveryThreshold,
      );
    }
  }

  /// Set the sleep voltage threshold
  ///
  /// [voltage] Voltage in Volts (8-15V)
  Future<void> setSleepVoltageThreshold(double voltage) async {
    if (!_validateVoltage(voltage)) {
      state = state.copyWith(
        error: 'Sleep voltage must be between 8V and 15V',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.setSleepVoltageThreshold(voltage);
      await refreshConfig(); // Refresh to verify the change
      state = state.copyWith(
        isLoading: false,
        lastOperation: PowerManagementOperation.setSleepVoltage,
      );
    } catch (e) {
      debugPrint('Failed to set sleep voltage threshold: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.setSleepVoltage,
      );
    }
  }

  /// Set the wake voltage threshold
  ///
  /// [voltage] Voltage in Volts (8-15V)
  Future<void> setWakeVoltageThreshold(double voltage) async {
    if (!_validateVoltage(voltage)) {
      state = state.copyWith(
        error: 'Wake voltage must be between 8V and 15V',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.setWakeVoltageThreshold(voltage);
      await refreshConfig(); // Refresh to verify the change
      state = state.copyWith(
        isLoading: false,
        lastOperation: PowerManagementOperation.setWakeVoltage,
      );
    } catch (e) {
      debugPrint('Failed to set wake voltage threshold: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.setWakeVoltage,
      );
    }
  }

  /// Force the device into sleep mode
  Future<void> forceSleep() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.forceSleep();
      state = state.copyWith(
        isLoading: false,
        lastOperation: PowerManagementOperation.forceSleep,
      );
    } catch (e) {
      debugPrint('Failed to force sleep: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.forceSleep,
      );
    }
  }

  /// Force the device to wake from sleep mode
  Future<void> forceWake() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _repository.forceWake();
      state = state.copyWith(
        isLoading: false,
        lastOperation: PowerManagementOperation.forceWake,
      );
    } catch (e) {
      debugPrint('Failed to force wake: $e');
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
        lastOperation: PowerManagementOperation.forceWake,
      );
    }
  }

  /// Clear any error state
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Clear the last operation state
  void clearLastOperation() {
    state = state.copyWith(clearLastOperation: true);
  }

  /// Validate temperature value
  bool _validateTemperature(double temperature) {
    return temperature >= 0.0 && temperature <= 150.0;
  }

  /// Validate voltage value
  bool _validateVoltage(double voltage) {
    return voltage >= 8.0 && voltage <= 15.0;
  }

  /// Get user-friendly error message from exception
  String _getErrorMessage(dynamic error) {
    if (error is PowerManagementException) {
      switch (error.type) {
        case PowerManagementErrorType.readFailure:
          return 'Failed to read power management configuration from device';
        case PowerManagementErrorType.commandFailure:
          return 'Failed to send power command to device';
        case PowerManagementErrorType.connectionFailure:
          return 'Device connection lost';
        case PowerManagementErrorType.validationFailure:
          return 'Invalid configuration value';
      }
    }
    return 'An unexpected error occurred: ${error.toString()}';
  }
}

/// Provider for the power management controller
final powerManagementControllerProvider =
    StateNotifierProvider<PowerManagementController, PowerManagementState>(
        (ref) {
  final repository = ref.watch(powerManagementRepositoryProvider);
  return PowerManagementController(repository: repository);
});