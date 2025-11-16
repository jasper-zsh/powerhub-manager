import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/execution_log_entry.dart';
import 'package:app/repositories/orchestration_repository.dart';
import 'package:app/repositories/repository_providers.dart';
import 'package:app/repositories/switch_hub_command_service.dart';
import 'package:app/controllers/connection_session_controller.dart';

enum OrchestrationStatus { idle, preparing, executing, completed, failed, cancelled }

class OrchestrationState {
  const OrchestrationState({
    required this.scenes,
    required this.executionLogs,
    required this.isExecuting,
    required this.currentExecutionStep,
    required this.totalExecutionSteps,
    required this.status,
    this.missingControllers = const <String>{},
    this.errorMessage,
    this.lastExecutedAt,
  });

  factory OrchestrationState.initial() => const OrchestrationState(
        scenes: <ToggleScene>[],
        executionLogs: <ExecutionLogEntry>[],
        isExecuting: false,
        currentExecutionStep: 0,
        totalExecutionSteps: 0,
        status: OrchestrationStatus.idle,
        missingControllers: <String>{},
      );

  final List<ToggleScene> scenes;
  final List<ExecutionLogEntry> executionLogs;
  final bool isExecuting;
  final int currentExecutionStep;
  final int totalExecutionSteps;
  final OrchestrationStatus status;
  final Set<String> missingControllers;
  final String? errorMessage;
  final DateTime? lastExecutedAt;

  bool get hasError => errorMessage != null;
  bool get hasScenes => scenes.isNotEmpty;
  bool get canExecute => hasScenes && missingControllers.isEmpty && !isExecuting;

  OrchestrationState copyWith({
    List<ToggleScene>? scenes,
    List<ExecutionLogEntry>? executionLogs,
    bool? isExecuting,
    int? currentExecutionStep,
    int? totalExecutionSteps,
    OrchestrationStatus? status,
    Set<String>? missingControllers,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastExecutedAt,
  }) {
    return OrchestrationState(
      scenes: scenes ?? this.scenes,
      executionLogs: executionLogs ?? this.executionLogs,
      isExecuting: isExecuting ?? this.isExecuting,
      currentExecutionStep: currentExecutionStep ?? this.currentExecutionStep,
      totalExecutionSteps: totalExecutionSteps ?? this.totalExecutionSteps,
      status: status ?? this.status,
      missingControllers: missingControllers ?? this.missingControllers,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }
}

class OrchestrationController extends StateNotifier<OrchestrationState> {
  OrchestrationController({
    required this.ref,
    required OrchestrationRepository orchestrationRepository,
    required SwitchHubCommandService switchHubCommandService,
  })  : _orchestrationRepository = orchestrationRepository,
        _switchHubCommandService = switchHubCommandService,
        super(OrchestrationState.initial()) {
    _initialize();
  }

  final Ref ref;
  final OrchestrationRepository _orchestrationRepository;
  final SwitchHubCommandService _switchHubCommandService;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription? _executionSubscription;

  Future<void> _initialize() async {
    try {
      // Load scenes
      await loadScenes();

      // Load execution logs
      await loadExecutionLogs();

      // Listen to error stream
      _errorSubscription = _switchHubCommandService.errorStream.listen(
        (error) {
          _addExecutionLog(
            sceneId: 'system',
            status: 'failed',
            details: error,
          );
          state = state.copyWith(
            errorMessage: error,
            status: OrchestrationStatus.failed,
            isExecuting: false,
          );
        },
      );

      // Check for missing controllers
      _checkMissingControllers();
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to initialize orchestration: $error',
        status: OrchestrationStatus.failed,
      );
    }
  }

  Future<void> loadScenes() async {
    try {
      final scenes = await _orchestrationRepository.loadScenes();
      state = state.copyWith(
        scenes: List<ToggleScene>.unmodifiable(scenes),
        clearError: true,
      );
      _checkMissingControllers();
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to load scenes: $error',
      );
    }
  }

  Future<void> loadExecutionLogs() async {
    try {
      final logs = await _orchestrationRepository.loadExecutionLogs();
      state = state.copyWith(
        executionLogs: List<ExecutionLogEntry>.unmodifiable(
          logs.reversed.toList(), // Newest logs first
        ),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to load execution logs: $error',
      );
    }
  }

  Future<ToggleScene> saveScene({
    required String name,
    required List<ToggleState> states,
    String? description,
  }) async {
    try {
      final scene = ToggleScene(
        id: _generateSceneId(),
        name: name,
        states: states,
        description: description,
      );

      final savedScene = await _orchestrationRepository.upsertScene(scene);

      final updatedScenes = List<ToggleScene>.from(state.scenes)
        ..add(savedScene);

      state = state.copyWith(
        scenes: List<ToggleScene>.unmodifiable(updatedScenes),
        clearError: true,
      );

      _addExecutionLog(
        sceneId: scene.id,
        status: 'saved',
        details: 'Scene "${scene.name}" saved successfully',
      );

      _checkMissingControllers();
      return savedScene;
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to save scene: $error',
      );
      rethrow;
    }
  }

  Future<ToggleScene> updateScene(ToggleScene scene) async {
    try {
      final updatedScene = scene.copyWith(updatedAt: DateTime.now());
      final savedScene = await _orchestrationRepository.upsertScene(updatedScene);

      final updatedScenes = state.scenes
          .map((s) => s.id == scene.id ? savedScene : s)
          .toList();

      state = state.copyWith(
        scenes: List<ToggleScene>.unmodifiable(updatedScenes),
        clearError: true,
      );

      _addExecutionLog(
        sceneId: scene.id,
        status: 'updated',
        details: 'Scene "${scene.name}" updated successfully',
      );

      _checkMissingControllers();
      return savedScene;
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to update scene: $error',
      );
      rethrow;
    }
  }

  Future<void> deleteScene(String sceneId) async {
    try {
      final scene = state.scenes.firstWhere((s) => s.id == sceneId);

      await _orchestrationRepository.deleteScene(sceneId);

      final updatedScenes = state.scenes.where((s) => s.id != sceneId).toList();
      state = state.copyWith(
        scenes: List<ToggleScene>.unmodifiable(updatedScenes),
        clearError: true,
      );

      _addExecutionLog(
        sceneId: sceneId,
        status: 'deleted',
        details: 'Scene "${scene.name}" deleted successfully',
      );

      _checkMissingControllers();
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to delete scene: $error',
      );
    }
  }

  Future<ExecutionPreview> previewExecution(String sceneId) async {
    try {
      final scene = state.scenes.firstWhere((s) => s.id == sceneId);
      return await _switchHubCommandService.previewExecution(scene);
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to preview execution: $error',
      );
      rethrow;
    }
  }

  Future<void> executeScene(String sceneId) async {
    if (state.isExecuting) {
      state = state.copyWith(
        errorMessage: 'Another execution is already in progress',
      );
      return;
    }

    try {
      final scene = state.scenes.firstWhere((s) => s.id == sceneId);

      // Check for missing controllers
      _checkMissingControllers();
      if (state.missingControllers.isNotEmpty) {
        state = state.copyWith(
          errorMessage: 'Cannot execute: missing controllers: ${state.missingControllers.join(', ')}',
        );
        return;
      }

      state = state.copyWith(
        isExecuting: true,
        status: OrchestrationStatus.preparing,
        currentExecutionStep: 0,
        clearError: true,
      );

      _addExecutionLog(
        sceneId: sceneId,
        status: 'started',
        details: 'Started executing scene "${scene.name}"',
      );

      // Listen to execution status
      _executionSubscription?.cancel();
      _executionSubscription = _switchHubCommandService
          .executeScene(scene)
          .listen(
        _handleExecutionUpdate,
        onError: _handleExecutionError,
        onDone: _handleExecutionDone,
      );
    } catch (error) {
      state = state.copyWith(
        isExecuting: false,
        status: OrchestrationStatus.failed,
        errorMessage: 'Failed to start execution: $error',
      );

      _addExecutionLog(
        sceneId: sceneId,
        status: 'failed',
        details: 'Execution failed to start: $error',
      );
    }
  }

  Future<void> stopExecution() async {
    if (!state.isExecuting) {
      return;
    }

    try {
      await _switchHubCommandService.stopExecution();
      _executionSubscription?.cancel();

      state = state.copyWith(
        isExecuting: false,
        status: OrchestrationStatus.cancelled,
      );

      _addExecutionLog(
        sceneId: 'current',
        status: 'cancelled',
        details: 'Execution was cancelled by user',
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to stop execution: $error',
      );
    }
  }

  Future<void> clearExecutionLogs() async {
    try {
      await _orchestrationRepository.clearExecutionLogs();
      state = state.copyWith(
        executionLogs: <ExecutionLogEntry>[],
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: 'Failed to clear execution logs: $error',
      );
    }
  }

  void _handleExecutionUpdate(ExecutionUpdate update) {
    state = state.copyWith(
      isExecuting: update.status != ExecutionStatus.completed &&
          update.status != ExecutionStatus.failed &&
          update.status != ExecutionStatus.cancelled,
      status: _mapExecutionStatus(update.status),
      currentExecutionStep: update.currentStep,
      totalExecutionSteps: update.totalSteps,
      clearError: true,
    );
  }

  void _handleExecutionError(error) {
    state = state.copyWith(
      isExecuting: false,
      status: OrchestrationStatus.failed,
      errorMessage: 'Execution failed: $error',
    );

    _addExecutionLog(
      sceneId: 'current',
      status: 'failed',
      details: 'Execution failed: $error',
    );
  }

  void _handleExecutionDone() {
    state = state.copyWith(
      isExecuting: false,
      status: OrchestrationStatus.completed,
      lastExecutedAt: DateTime.now(),
    );

    _addExecutionLog(
      sceneId: 'current',
      status: 'completed',
      details: 'Execution completed successfully',
    );
  }

  void _checkMissingControllers() {
    final allReferencedControllers = <String>{};
    for (final scene in state.scenes) {
      allReferencedControllers.addAll(scene.referencedControllers);
    }

    // Get currently connected controller
    final connectionState = ref.read(connectionSessionControllerProvider);
    final connectedControllerId = connectionState.controllerId;

    final missingControllers = allReferencedControllers
        .where((id) => id != connectedControllerId)
        .toSet();

    state = state.copyWith(
      missingControllers: missingControllers,
    );
  }

  void _addExecutionLog({
    required String sceneId,
    required String status,
    required String details,
  }) async {
    try {
      final logEntry = ExecutionLogEntry(
        id: _generateLogId(),
        sceneId: sceneId,
        triggerSource: 'manual',
        result: status,
        triggeredAt: DateTime.now(),
      );

      await _orchestrationRepository.appendExecutionLog(logEntry);

      // Update local log list
      final updatedLogs = <ExecutionLogEntry>[
        logEntry,
        ...state.executionLogs,
      ];

      state = state.copyWith(
        executionLogs: List<ExecutionLogEntry>.unmodifiable(updatedLogs),
      );
    } catch (error) {
      // Log failure should not affect main functionality
      debugPrint('Failed to add execution log: $error');
    }
  }

  OrchestrationStatus _mapExecutionStatus(ExecutionStatus status) {
    switch (status) {
      case ExecutionStatus.idle:
        return OrchestrationStatus.idle;
      case ExecutionStatus.preparing:
        return OrchestrationStatus.preparing;
      case ExecutionStatus.executing:
        return OrchestrationStatus.executing;
      case ExecutionStatus.completed:
        return OrchestrationStatus.completed;
      case ExecutionStatus.failed:
        return OrchestrationStatus.failed;
      case ExecutionStatus.cancelled:
        return OrchestrationStatus.cancelled;
    }
  }

  String _generateSceneId() {
    return 'scene_${DateTime.now().millisecondsSinceEpoch}_${Object().hashCode}';
  }

  String _generateLogId() {
    return 'log_${DateTime.now().millisecondsSinceEpoch}_${Object().hashCode}';
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _executionSubscription?.cancel();
    super.dispose();
  }
}

final orchestrationControllerProvider =
    StateNotifierProvider<OrchestrationController, OrchestrationState>((ref) {
  final orchestrationRepository = ref.watch(orchestrationRepositoryProvider);
  final switchHubCommandService = ref.watch(switchHubCommandServiceProvider);
  return OrchestrationController(
    ref: ref,
    orchestrationRepository: orchestrationRepository,
    switchHubCommandService: switchHubCommandService,
  );
});