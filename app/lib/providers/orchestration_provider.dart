import 'package:flutter/foundation.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/execution_log_entry.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/services/storage_service.dart';
import 'package:app/services/ble_service.dart';

class CommandPreviewResult {
  CommandPreviewResult({
    required this.actions,
    required this.bundleOrder,
    List<String>? warnings,
    List<String>? missingBundles,
  }) : warnings = warnings ?? <String>[],
       missingBundles = missingBundles ?? <String>[];

  final List<CommandAction> actions;
  final List<String> bundleOrder;
  final List<String> warnings;
  final List<String> missingBundles;

  bool get hasWarnings => warnings.isNotEmpty || missingBundles.isNotEmpty;
}

class OrchestrationProvider with ChangeNotifier {
  OrchestrationProvider({StorageService? storage, BLEService? bleService})
    : _storage = storage ?? StorageService(),
      _bleService = bleService ?? BLEService();

  final StorageService _storage;
  final BLEService _bleService;
  final List<ToggleScene> _scenes = <ToggleScene>[];
  List<ExecutionLogEntry> _logs = <ExecutionLogEntry>[];
  ToggleScene? _activeScene;
  bool _isLoading = false;
  String? _errorMessage;
  final Set<String> _missingControllers = <String>{};

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ToggleScene> get scenes => List.unmodifiable(_scenes);
  ToggleScene? get activeScene => _activeScene;
  List<ExecutionLogEntry> get executionLogs => List.unmodifiable(_logs);
  Set<String> get missingControllers => Set.unmodifiable(_missingControllers);
  List<String> get activeToggleOrder =>
      _activeScene == null ? const [] : _toggleOrder(_activeScene!);
  List<ToggleState> statesForToggle(String toggleId) {
    final scene = _activeScene;
    if (scene == null) {
      return const [];
    }
    return scene.states.where((state) => state.toggleId == toggleId).toList();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _storage.init();
      final loadedScenes = await _storage.loadToggleScenes();
      final loadedLogs = await _storage.loadExecutionLogs();
      _scenes
        ..clear()
        ..addAll(loadedScenes);
      _logs = loadedLogs;
      _activeScene = _scenes.isNotEmpty ? _scenes.first : null;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to load orchestration data: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<ToggleScene> saveScene(ToggleScene scene) async {
    final nextScene = scene.copyWith();
    final saved = await _storage.upsertToggleScene(nextScene);
    final index = _scenes.indexWhere((existing) => existing.id == scene.id);
    if (index >= 0) {
      _scenes[index] = saved;
    } else {
      _scenes.add(saved);
    }
    if (_activeScene == null || _activeScene!.id == saved.id) {
      _activeScene = saved;
    }
    notifyListeners();
    return saved;
  }

  List<String> _toggleOrder(ToggleScene scene) {
    final order = <String>[];
    final seen = <String>{};
    for (final state in scene.states) {
      if (seen.add(state.toggleId)) {
        order.add(state.toggleId);
      }
    }
    return order;
  }

  Future<void> reorderToggles(int oldIndex, int newIndex) async {
    if (_activeScene == null) {
      return;
    }

    final scene = _activeScene!;
    final order = _toggleOrder(scene);
    if (oldIndex < 0 || oldIndex >= order.length) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    newIndex = newIndex.clamp(0, order.length - 1);

    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);

    final newStates = <ToggleState>[];
    for (final toggleId in order) {
      newStates.addAll(
        scene.states.where((state) => state.toggleId == toggleId),
      );
    }

    final updatedScene = scene.copyWith(states: newStates);
    await saveScene(updatedScene);
  }

  Future<void> addToggle({String? baseLabel}) async {
    if (_activeScene == null) {
      return;
    }

    final scene = _activeScene!;
    final now = DateTime.now().microsecondsSinceEpoch;
    final toggleId = 'toggle-$now';
    final label = baseLabel ?? 'Toggle ${_toggleOrder(scene).length + 1}';

    final states = List<ToggleState>.from(scene.states)
      ..addAll([
        ToggleState(
          toggleId: toggleId,
          stateId: '$toggleId-on',
          label: '$label On',
          isDefault: true,
        ),
        ToggleState(
          toggleId: toggleId,
          stateId: '$toggleId-off',
          label: '$label Off',
        ),
      ]);

    final updatedScene = scene.copyWith(states: states);
    await saveScene(updatedScene);
  }

  Future<void> removeToggle(String toggleId) async {
    if (_activeScene == null) {
      return;
    }

    final scene = _activeScene!;
    final states = scene.states
        .where((state) => state.toggleId != toggleId)
        .toList();
    if (states.length == scene.states.length) {
      return;
    }

    final rules = scene.rules
        .where((rule) => rule.toggleId != toggleId)
        .toList();

    final updatedScene = scene.copyWith(states: states, rules: rules);

    await saveScene(updatedScene);
  }

  Future<bool> renameToggle(String toggleId, String newToggleId) async {
    final trimmed = newToggleId.trim();
    if (_activeScene == null || trimmed.isEmpty) {
      return false;
    }
    if (toggleId == trimmed) {
      return true;
    }

    final scene = _activeScene!;
    final hasConflict = scene.states.any(
      (state) => state.toggleId == trimmed,
    );
    if (hasConflict) {
      return false;
    }

    final updatedStates = scene.states.map((state) {
      if (state.toggleId != toggleId) {
        return state;
      }
      final nextStateId = state.stateId.startsWith('$toggleId-')
          ? state.stateId.replaceFirst('$toggleId-', '$trimmed-')
          : state.stateId;
      return state.copyWith(
        toggleId: trimmed,
        stateId: nextStateId,
      );
    }).toList();

    final updatedRules = scene.rules.map((rule) {
      if (rule.toggleId != toggleId) {
        return rule;
      }
      return ConditionalRule(
        id: rule.id,
        toggleId: trimmed,
        expectedStateId: rule.expectedStateId.startsWith('$toggleId-')
            ? rule.expectedStateId.replaceFirst('$toggleId-', '$trimmed-')
            : rule.expectedStateId,
        trueBundleId: rule.trueBundleId,
        falseBundleId: rule.falseBundleId,
        description: rule.description,
      );
    }).toList();

    final updatedScene = scene.copyWith(
      states: updatedStates,
      rules: updatedRules,
    );

    await saveScene(updatedScene);
    return true;
  }

  Future<void> updateStateLabel(
    String toggleId,
    String stateId,
    String label,
  ) async {
    if (label.isEmpty) {
      return;
    }
    await _mutateState(
      toggleId,
      stateId,
      (state) => state.copyWith(label: label),
    );
  }

  Future<void> upsertCommandBundle(
    String toggleId,
    String stateId,
    CommandBundle bundle,
  ) async {
    await _mutateState(toggleId, stateId, (state) {
      final bundles = List<CommandBundle>.from(state.commandBundles);
      final index = bundles.indexWhere((existing) => existing.id == bundle.id);
      if (index >= 0) {
        bundles[index] = bundle;
      } else {
        bundles.add(bundle);
      }
      return state.copyWith(commandBundles: bundles);
    });
  }

  Future<void> removeCommandBundle(
    String toggleId,
    String stateId,
    String bundleId,
  ) async {
    await _mutateState(toggleId, stateId, (state) {
      final bundles = state.commandBundles
          .where((bundle) => bundle.id != bundleId)
          .toList();
      return state.copyWith(commandBundles: bundles);
    });
  }

  Future<void> _mutateState(
    String toggleId,
    String stateId,
    ToggleState Function(ToggleState state) transform,
  ) async {
    if (_activeScene == null) {
      return;
    }

    final scene = _activeScene!;
    final states = List<ToggleState>.from(scene.states);
    final index = states.indexWhere(
      (state) => state.toggleId == toggleId && state.stateId == stateId,
    );
    if (index < 0) {
      return;
    }

    states[index] = transform(states[index]);
    final updatedScene = scene.copyWith(states: states);
    await saveScene(updatedScene);
  }

  Future<ToggleScene> publishScene(
    String sceneId, {
    bool isPublished = true,
  }) async {
    final index = _scenes.indexWhere((scene) => scene.id == sceneId);
    if (index < 0) {
      throw ArgumentError('Scene $sceneId not found');
    }
    final updated = _scenes[index].copyWith(isPublished: isPublished);
    return saveScene(updated);
  }

  Future<void> deleteScene(String sceneId) async {
    await _storage.deleteToggleScene(sceneId);
    _scenes.removeWhere((scene) => scene.id == sceneId);
    if (_activeScene?.id == sceneId) {
      _activeScene = _scenes.isNotEmpty ? _scenes.first : null;
    }
    notifyListeners();
  }

  CommandPreviewResult previewScene(
    String sceneId, {
    required String toggleId,
    required String stateId,
  }) {
    final scene = _scenes.firstWhere(
      (candidate) => candidate.id == sceneId,
      orElse: () => throw ArgumentError('Scene $sceneId not found'),
    );

    final state = scene.states.firstWhere(
      (candidate) =>
          candidate.toggleId == toggleId && candidate.stateId == stateId,
      orElse: () => throw ArgumentError(
        'Toggle state $toggleId/$stateId not found in scene ${scene.id}',
      ),
    );

    final bundleOrder = <String>[];
    final actions = <CommandAction>[];
    final warnings = <String>[];
    final missingBundles = <String>[];

    void addBundle(CommandBundle bundle) {
      if (bundleOrder.contains(bundle.id)) {
        return;
      }
      bundleOrder.add(bundle.id);
      actions.addAll(bundle.actions);
    }

    for (final bundle in state.commandBundles) {
      addBundle(bundle);
    }

    final matchingRules = scene.rules.where(
      (rule) => rule.toggleId == toggleId,
    );

    for (final rule in matchingRules) {
      final bool matchesExpected = rule.expectedStateId == stateId;
      final String? bundleId = matchesExpected
          ? rule.trueBundleId
          : rule.falseBundleId;
      if (bundleId == null) {
        continue;
      }
      final bundle = _findBundle(scene, bundleId);
      if (bundle != null) {
        addBundle(bundle);
      } else {
        missingBundles.add(bundleId);
      }
    }

    return CommandPreviewResult(
      actions: actions,
      bundleOrder: bundleOrder,
      warnings: warnings,
      missingBundles: missingBundles,
    );
  }

  Future<void> recordExecution({
    required String sceneId,
    required String triggerSource,
    required CommandPreviewResult preview,
    bool success = true,
    String? notes,
  }) async {
    final entry = ExecutionLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sceneId: sceneId,
      triggerSource: triggerSource,
      result: success
          ? 'success'
          : (preview.missingBundles.isEmpty ? 'partial' : 'failed'),
      triggeredAt: DateTime.now(),
      executedBundleIds: preview.bundleOrder,
      skippedActions: preview.missingBundles,
      notes: notes,
    );

    await _storage.appendExecutionLog(entry);
    await _refreshExecutionLogs();
  }

  Future<void> _refreshExecutionLogs() async {
    _logs = await _storage.loadExecutionLogs();
    notifyListeners();
  }
  Future<bool> executeCommands(CommandPreviewResult preview) async {
    try {
      bool hasErrors = false;

      for (final action in preview.actions) {
        try {
          switch (action.type) {
            case CommandActionType.channelValue:
              final command = SetCommand(
                channel: action.channel!,
                value: action.value!,
              );
              await _bleService.sendSetCommand(command);
              break;
            
            case CommandActionType.presetTrigger:
              await _bleService.executePreset(action.presetId!);
              break;
          }
        } catch (e) {
          hasErrors = true;
          debugPrint('Failed to execute action for controller ${action.controllerId}: $e');
        }
      }

      return !hasErrors;
    } catch (e) {
      debugPrint('Failed to execute commands: $e');
      return false;
    }
  }

  Future<void> clearLogs() async {
    await _storage.clearExecutionLogs();
    _logs = [];
    notifyListeners();
  }

  Map<String, Set<String>> get controllerDependencies {
    final Map<String, Set<String>> dependencies = <String, Set<String>>{};
    for (final scene in _scenes) {
      for (final state in scene.states) {
        for (final controllerId in state.referencedControllers) {
          dependencies.putIfAbsent(controllerId, () => <String>{});
          dependencies[controllerId]!.add(scene.id);
        }
      }
    }
    return dependencies;
  }

  void updateControllerIndex(Iterable<String> controllerIds) {
    final current = controllerDependencies.keys.toSet();
    final saved = controllerIds.toSet();
    final missing = current.difference(saved);
    if (!setEquals(_missingControllers, missing)) {
      _missingControllers
        ..clear()
        ..addAll(missing);
      notifyListeners();
    }
  }

  CommandBundle? _findBundle(ToggleScene scene, String bundleId) {
    for (final state in scene.states) {
      for (final bundle in state.commandBundles) {
        if (bundle.id == bundleId) {
          return bundle;
        }
      }
    }
    return null;
  }
}
