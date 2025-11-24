import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/execution_log_entry.dart';
import 'package:app/models/preset.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/models/control_command/control_command.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';

class StorageService {
  static const String _presetsKey = 'presets';
  static const String _savedControllersKey = 'saved_controllers';
  static const String _toggleScenesKey = 'toggle_scenes';
  static const String _executionLogsKey = 'orchestration_execution_logs';
  static const int _maxExecutionLogs = 100;
  
  SharedPreferences? _prefs;
  
  void _requireInitialized() {
    if (_prefs == null) {
      throw Exception('STORAGE_NOT_INITIALIZED');
    }
  }
  
  // Initialize the storage service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  // Save a preset to local storage
  Future<int> savePreset(Preset preset) async {
    _requireInitialized();
    
    try {
      // Get existing presets
      Map<String, dynamic> presets = await loadAllPresets();
      
      // Convert preset to JSON-serializable map
      Map<String, dynamic> presetMap = {
        'id': preset.id,
        'name': preset.name,
        'commandCount': preset.commandCount,
        'commands': preset.commands.map((command) {
          Map<String, dynamic> commandMap = {
            'type': command.getType(),
          };
          
          if (command is SetCommand) {
            commandMap['channel'] = command.channel;
            commandMap['value'] = command.value;
          } else if (command is FadeCommand) {
            commandMap['channel'] = command.channel;
            commandMap['targetValue'] = command.targetValue;
            commandMap['duration'] = command.duration;
          } else if (command is BlinkCommand) {
            commandMap['channel'] = command.channel;
            commandMap['period'] = command.period;
          } else if (command is StrobeCommand) {
            commandMap['channel'] = command.channel;
            commandMap['flashCount'] = command.flashCount;
            commandMap['totalDuration'] = command.totalDuration;
            commandMap['pauseDuration'] = command.pauseDuration;
          }
          
          return commandMap;
        }).toList(),
        'createdAt': preset.createdAt.toIso8601String(),
        'updatedAt': preset.updatedAt.toIso8601String(),
        'isFavorite': preset.isFavorite,
      };
      
      // Add the new preset to the map
      presets[preset.id.toString()] = presetMap;
      
      // Save to shared preferences
      String json = jsonEncode(presets);
      await _prefs!.setString(_presetsKey, json);
      
      return preset.id;
    } catch (e) {
      throw Exception('STORAGE_ERROR');
    }
  }
  
  // Load all presets from local storage
  Future<Map<String, dynamic>> loadAllPresets() async {
    _requireInitialized();
    
    try {
      String? json = _prefs!.getString(_presetsKey);
      
      if (json == null) {
        return {};
      }
      
      Map<String, dynamic> presets = jsonDecode(json);
      
      // Convert JSON maps back to Preset objects
      Map<String, dynamic> result = {};
      presets.forEach((key, value) {
        Map<String, dynamic> presetMap = value as Map<String, dynamic>;
        
        List<ControlCommand> commands = [];
        if (presetMap['commands'] != null) {
          for (var commandMap in presetMap['commands'] as List) {
            Map<String, dynamic> cmdMap = commandMap as Map<String, dynamic>;
            String type = cmdMap['type'] as String;
            
            switch (type) {
              case 'SetCommand':
                commands.add(SetCommand(
                  channel: cmdMap['channel'] as int,
                  value: cmdMap['value'] as int,
                ));
                break;
                
              case 'FadeCommand':
                commands.add(FadeCommand(
                  channel: cmdMap['channel'] as int,
                  targetValue: cmdMap['targetValue'] as int,
                  duration: cmdMap['duration'] as int,
                ));
                break;
                
              case 'BlinkCommand':
                commands.add(BlinkCommand(
                  channel: cmdMap['channel'] as int,
                  period: cmdMap['period'] as int,
                ));
                break;
                
              case 'StrobeCommand':
                commands.add(StrobeCommand(
                  channel: cmdMap['channel'] as int,
                  flashCount: cmdMap['flashCount'] as int,
                  totalDuration: cmdMap['totalDuration'] as int,
                  pauseDuration: cmdMap['pauseDuration'] as int,
                ));
                break;
            }
          }
        }
        
        result[key] = Preset(
          id: presetMap['id'] as int,
          name: presetMap['name'] as String,
          commands: commands,
          createdAt: DateTime.parse(presetMap['createdAt'] as String),
          updatedAt: DateTime.parse(presetMap['updatedAt'] as String),
          isFavorite: presetMap['isFavorite'] as bool,
        );
      });
      
      return result;
    } catch (e) {
      throw Exception('STORAGE_ERROR');
    }
  }
  
  // Update a preset in local storage
  Future<DateTime> updatePreset(int id, PresetUpdate update) async {
    _requireInitialized();
    
    try {
      // Get existing presets
      Map<String, dynamic> presets = await loadAllPresets();
      
      // Check if the preset exists
      if (!presets.containsKey(id.toString())) {
        throw Exception('PRESET_NOT_FOUND');
      }
      
      // Get the existing preset
      Preset existingPreset = presets[id.toString()] as Preset;
      
      // Update the preset with the new values
      Preset updatedPreset = Preset(
        id: existingPreset.id,
        name: update.name ?? existingPreset.name,
        commands: update.commands ?? existingPreset.commands,
        createdAt: existingPreset.createdAt,
        updatedAt: DateTime.now(),
        isFavorite: update.isFavorite ?? existingPreset.isFavorite,
      );
      
      // Convert updated preset to JSON-serializable map
      Map<String, dynamic> presetMap = {
        'id': updatedPreset.id,
        'name': updatedPreset.name,
        'commandCount': updatedPreset.commandCount,
        'commands': updatedPreset.commands.map((command) {
          Map<String, dynamic> commandMap = {
            'type': command.getType(),
          };
          
          if (command is SetCommand) {
            commandMap['channel'] = command.channel;
            commandMap['value'] = command.value;
          } else if (command is FadeCommand) {
            commandMap['channel'] = command.channel;
            commandMap['targetValue'] = command.targetValue;
            commandMap['duration'] = command.duration;
          } else if (command is BlinkCommand) {
            commandMap['channel'] = command.channel;
            commandMap['period'] = command.period;
          } else if (command is StrobeCommand) {
            commandMap['channel'] = command.channel;
            commandMap['flashCount'] = command.flashCount;
            commandMap['totalDuration'] = command.totalDuration;
            commandMap['pauseDuration'] = command.pauseDuration;
          }
          
          return commandMap;
        }).toList(),
        'createdAt': updatedPreset.createdAt.toIso8601String(),
        'updatedAt': updatedPreset.updatedAt.toIso8601String(),
        'isFavorite': updatedPreset.isFavorite,
      };
      
      // Update the preset in the map
      presets[id.toString()] = presetMap;
      
      // Save to shared preferences
      String json = jsonEncode(presets);
      await _prefs!.setString(_presetsKey, json);
      
      return updatedPreset.updatedAt;
    } catch (e) {
      if (e is Exception && e.toString().contains('PRESET_NOT_FOUND')) {
        rethrow;
      }
      throw Exception('STORAGE_ERROR');
    }
  }

  Future<List<SavedController>> loadSavedControllers() async {
    _requireInitialized();

    try {
      final raw = _prefs!.getString(_savedControllersKey);
      if (raw == null || raw.isEmpty) {
        return [];
      }

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((entry) => SavedController.fromJson(
                (entry as Map).cast<String, dynamic>(),
              ))
          .toList();
    } catch (_) {
      // Corrupt payloads should not crash the app; return empty list instead.
      return [];
    }
  }

  Future<void> persistSavedControllers(
    List<SavedController> controllers,
  ) async {
    _requireInitialized();

    final payload = controllers.map((controller) => controller.toJson()).toList();
    await _prefs!.setString(
      _savedControllersKey,
      jsonEncode(payload),
    );
  }

  Future<SavedController?> findSavedController(String controllerId) async {
    final controllers = await loadSavedControllers();
    try {
      return controllers.firstWhere(
        (controller) => controller.controllerId == controllerId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSavedControllers() async {
    _requireInitialized();
    await _prefs!.remove(_savedControllersKey);
  }

  Future<SavedController> addSavedController(
    SavedController controller,
  ) async {
    _requireInitialized();

    final controllers = await loadSavedControllers();

    SavedController.ensureAliasUnique(
      controller.alias,
      controllers,
      ignoreControllerId: controller.controllerId,
    );

    final updatedControllers = List<SavedController>.from(controllers);
    final index = updatedControllers.indexWhere(
      (existing) => existing.controllerId == controller.controllerId,
    );

    if (index >= 0) {
      updatedControllers[index] = controller;
    } else {
      updatedControllers.add(controller);
    }

    await persistSavedControllers(updatedControllers);
    return controller;
  }

  Future<SavedController> renameSavedController(
    String controllerId,
    String alias,
  ) async {
    _requireInitialized();

    final controllers = await loadSavedControllers();
    final index = controllers.indexWhere(
      (controller) => controller.controllerId == controllerId,
    );

    if (index < 0) {
      throw ArgumentError('SAVED_CONTROLLER_NOT_FOUND');
    }

    SavedController.ensureAliasUnique(
      alias,
      controllers,
      ignoreControllerId: controllerId,
    );

    final sanitizedAlias = SavedController.sanitizeAlias(alias);
    final updatedController = controllers[index].copyWith(
      alias: sanitizedAlias,
    );

    controllers[index] = updatedController;
    await persistSavedControllers(controllers);
    return updatedController;
  }

  Future<List<SavedController>> removeSavedController(
    String controllerId,
  ) async {
    _requireInitialized();

    final controllers = await loadSavedControllers();
    final updatedControllers = controllers
        .where((controller) => controller.controllerId != controllerId)
        .toList();

    if (updatedControllers.length == controllers.length) {
      throw ArgumentError('SAVED_CONTROLLER_NOT_FOUND');
    }

    await persistSavedControllers(updatedControllers);
    return updatedControllers;
  }

  Future<List<ToggleScene>> loadToggleScenes() async {
    _requireInitialized();

    final raw = _prefs!.getString(_toggleScenesKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (entry) => ToggleScene.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } catch (_) {
      // On corrupt payload reset storage to avoid crashes.
      await _prefs!.remove(_toggleScenesKey);
      return [];
    }
  }

  Future<void> persistToggleScenes(List<ToggleScene> scenes) async {
    _requireInitialized();

    final payload = scenes.map((scene) => scene.toJson()).toList();
    await _prefs!.setString(
      _toggleScenesKey,
      jsonEncode(payload),
    );
  }

  Future<ToggleScene> upsertToggleScene(ToggleScene scene) async {
    _requireInitialized();

    final scenes = await loadToggleScenes();
    final index = scenes.indexWhere((existing) => existing.id == scene.id);

    if (index >= 0) {
      scenes[index] = scene;
    } else {
      scenes.add(scene);
    }

    await persistToggleScenes(scenes);
    return scene;
  }

  Future<void> deleteToggleScene(String sceneId) async {
    _requireInitialized();

    final scenes = await loadToggleScenes();
    final updated =
        scenes.where((scene) => scene.id != sceneId).toList(growable: false);
    await persistToggleScenes(updated);
  }

  Future<List<ExecutionLogEntry>> loadExecutionLogs() async {
    _requireInitialized();

    final raw = _prefs!.getString(_executionLogsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map(
            (entry) => ExecutionLogEntry.fromJson(
              (entry as Map).cast<String, dynamic>(),
            ),
          )
          .toList();
    } catch (_) {
      await _prefs!.remove(_executionLogsKey);
      return [];
    }
  }

  Future<void> persistExecutionLogs(List<ExecutionLogEntry> logs) async {
    _requireInitialized();

    final payload = logs.map((log) => log.toJson()).toList();
    await _prefs!.setString(
      _executionLogsKey,
      jsonEncode(payload),
    );
  }

  Future<void> appendExecutionLog(ExecutionLogEntry entry) async {
    final logs = await loadExecutionLogs();
    logs.insert(0, entry);
    if (logs.length > _maxExecutionLogs) {
      logs.removeRange(_maxExecutionLogs, logs.length);
    }
    await persistExecutionLogs(logs);
  }

  Future<void> clearExecutionLogs() async {
    _requireInitialized();
    await _prefs!.remove(_executionLogsKey);
  }
  
  // Delete a preset from local storage
  Future<bool> deletePreset(int id) async {
    if (_prefs == null) {
      throw Exception('STORAGE_NOT_INITIALIZED');
    }
    
    try {
      // Get existing presets
      Map<String, dynamic> presets = await loadAllPresets();
      
      // Check if the preset exists
      if (!presets.containsKey(id.toString())) {
        return false;
      }
      
      // Remove the preset from the map
      presets.remove(id.toString());
      
      // Save to shared preferences
      String json = jsonEncode(presets);
      await _prefs!.setString(_presetsKey, json);
      
      return true;
    } catch (e) {
      throw Exception('STORAGE_ERROR');
    }
  }
}

// Helper class for updating presets
class PresetUpdate {
  final String? name;
  final List<ControlCommand>? commands;
  final bool? isFavorite;
  
  PresetUpdate({
    this.name,
    this.commands,
    this.isFavorite,
  });
}
