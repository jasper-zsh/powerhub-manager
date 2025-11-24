import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/saved_controller.dart';
import 'package:app/repositories/repository_providers.dart';
import 'package:app/repositories/saved_controller_repository.dart';

class SavedControllerState {
  const SavedControllerState({
    required this.controllers,
    required this.isLoading,
    this.errorMessage,
    this.lastSyncedAt,
  });

  factory SavedControllerState.initial() => const SavedControllerState(
        controllers: <SavedController>[],
        isLoading: false,
      );

  final List<SavedController> controllers;
  final bool isLoading;
  final String? errorMessage;
  final DateTime? lastSyncedAt;

  bool get hasError => errorMessage != null;

  SavedControllerState copyWith({
    List<SavedController>? controllers,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastSyncedAt,
  }) {
    return SavedControllerState(
      controllers: controllers ?? this.controllers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

class SavedControllerController extends StateNotifier<SavedControllerState> {
  SavedControllerController({required SavedControllerRepository repository})
      : _repository = repository,
        super(SavedControllerState.initial()) {
    _subscription = _repository.controllersStream.listen((controllers) {
      state = state.copyWith(
        controllers: List<SavedController>.unmodifiable(controllers),
        isLoading: false,
        clearError: true,
        lastSyncedAt: DateTime.now(),
      );
    });
    // 触发首次加载
    unawaited(loadControllers());
  }

  final SavedControllerRepository _repository;
  StreamSubscription<List<SavedController>>? _subscription;

  Future<void> loadControllers() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final controllers = await _repository.loadSavedControllers();
      state = state.copyWith(
        controllers: List.unmodifiable(controllers),
        isLoading: false,
        clearError: true,
        lastSyncedAt: DateTime.now(),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load saved controllers: $error',
      );
    }
  }

  Future<SavedController> createController({
    required String controllerId,
    required String alias,
    DeviceCapabilities? deviceCapabilities,
    String? notes,
  }) async {
    try {
      final controller = SavedController(
        controllerId: controllerId,
        alias: alias,
        deviceCapabilities: deviceCapabilities,
        notes: notes,
      );
      return _addController(controller);
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to save controller: $error',
      );
      rethrow;
    }
  }

  Future<SavedController> _addController(SavedController controller) async {
    try {
      final saved = await _repository.addSavedController(controller);
      final updated = List<SavedController>.from(state.controllers)..add(saved);
      state = state.copyWith(
        controllers: List.unmodifiable(updated),
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
      return saved;
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to save controller: $error',
      );
      rethrow;
    }
  }

  Future<SavedController> renameController(
    String controllerId,
    String alias,
  ) async {
    try {
      final renamed = await _repository.renameSavedController(
        controllerId,
        alias,
      );
      final updated = state.controllers
          .map((controller) => controller.controllerId == controllerId
              ? renamed
              : controller)
          .toList(growable: false);
      state = state.copyWith(
        controllers: updated,
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
      return renamed;
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to rename controller: $error',
      );
      rethrow;
    }
  }

  Future<void> removeController(String controllerId) async {
    try {
      final controllers = await _repository.removeSavedController(controllerId);
      state = state.copyWith(
        controllers: List.unmodifiable(controllers),
        lastSyncedAt: DateTime.now(),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to remove controller: $error',
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final savedControllerControllerProvider = StateNotifierProvider<
    SavedControllerController, SavedControllerState>((ref) {
  final repository = ref.watch(savedControllerRepositoryProvider);
  return SavedControllerController(repository: repository);
});
