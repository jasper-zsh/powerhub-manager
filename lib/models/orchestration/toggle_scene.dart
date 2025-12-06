import 'dart:convert';

import 'package:app/models/switch_hub/command_packet.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/switch_definition.dart';
import 'package:app/models/switch_hub/ui_config.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/orchestration/conditional_logic_manager.dart';

enum CommandActionType { channelValue, presetTrigger, gradientMode, blinkMode, strobeMode }

CommandActionType _commandActionTypeFromString(String value) {
  return CommandActionType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => CommandActionType.channelValue,
  );
}

class CommandAction {
  CommandAction({
    required this.controllerId,
    required this.type,
    this.channel,
    this.value,
    this.presetId,
    // Dynamic mode parameters
    this.duration,      // For gradientMode (ms)
    this.period,        // For blinkMode (ms)
    this.count,         // For strobeMode
    this.totalTime,     // For strobeMode (ms)
    this.pauseTime,     // For strobeMode (ms)
  }) {
    if (type == CommandActionType.channelValue) {
      assert(channel != null, 'Channel actions require a channel id');
      assert(value != null, 'Channel actions require a PWM value');
    }
    if (type == CommandActionType.presetTrigger) {
      assert(presetId != null, 'Preset trigger actions require a presetId');
    }
    if (type == CommandActionType.gradientMode) {
      assert(channel != null, 'Gradient mode actions require a channel id');
      assert(value != null, 'Gradient mode actions require a target value');
      assert(duration != null, 'Gradient mode actions require a duration');
    }
    if (type == CommandActionType.blinkMode) {
      assert(channel != null, 'Blink mode actions require a channel id');
      assert(period != null, 'Blink mode actions require a period');
    }
    if (type == CommandActionType.strobeMode) {
      assert(channel != null, 'Strobe mode actions require a channel id');
      assert(count != null, 'Strobe mode actions require a count');
      assert(totalTime != null, 'Strobe mode actions require total time');
      assert(pauseTime != null, 'Strobe mode actions require pause time');
    }
  }

  final String controllerId;
  final CommandActionType type;
  final int? channel;
  final int? value;
  final int? presetId;
  // Dynamic mode parameters
  final int? duration;      // For gradientMode (ms)
  final int? period;        // For blinkMode (ms)
  final int? count;         // For strobeMode
  final int? totalTime;     // For strobeMode (ms)
  final int? pauseTime;     // For strobeMode (ms)

  CommandAction copyWith({
    String? controllerId,
    CommandActionType? type,
    int? channel,
    int? value,
    int? presetId,
    int? duration,
    int? period,
    int? count,
    int? totalTime,
    int? pauseTime,
  }) {
    final resolvedType = type ?? this.type;
    return CommandAction(
      controllerId: controllerId ?? this.controllerId,
      type: resolvedType,
      channel: (resolvedType == CommandActionType.channelValue ||
                resolvedType == CommandActionType.gradientMode ||
                resolvedType == CommandActionType.blinkMode ||
                resolvedType == CommandActionType.strobeMode)
          ? (channel ?? this.channel)
          : null,
      value: (resolvedType == CommandActionType.channelValue ||
               resolvedType == CommandActionType.gradientMode)
          ? (value ?? this.value)
          : null,
      presetId: resolvedType == CommandActionType.presetTrigger
          ? (presetId ?? this.presetId)
          : null,
      duration: resolvedType == CommandActionType.gradientMode
          ? (duration ?? this.duration)
          : null,
      period: resolvedType == CommandActionType.blinkMode
          ? (period ?? this.period)
          : null,
      count: resolvedType == CommandActionType.strobeMode
          ? (count ?? this.count)
          : null,
      totalTime: resolvedType == CommandActionType.strobeMode
          ? (totalTime ?? this.totalTime)
          : null,
      pauseTime: resolvedType == CommandActionType.strobeMode
          ? (pauseTime ?? this.pauseTime)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'controllerId': controllerId,
      'type': type.name,
      'channel': channel,
      'value': value,
      'presetId': presetId,
      // Dynamic mode parameters
      'duration': duration,
      'period': period,
      'count': count,
      'totalTime': totalTime,
      'pauseTime': pauseTime,
    };
  }

  factory CommandAction.fromJson(Map<String, dynamic> json) {
    return CommandAction(
      controllerId: json['controllerId'] as String,
      type: _commandActionTypeFromString(json['type'] as String),
      channel: json['channel'] as int?,
      value: json['value'] as int?,
      presetId: json['presetId'] as int?,
      // Dynamic mode parameters
      duration: json['duration'] as int?,
      period: json['period'] as int?,
      count: json['count'] as int?,
      totalTime: json['totalTime'] as int?,
      pauseTime: json['pauseTime'] as int?,
    );
  }

  /// Get English description of this action
  String get description {
    switch (type) {
      case CommandActionType.channelValue:
        return 'Channel ${channel} → ${value}';
      case CommandActionType.presetTrigger:
        return 'Trigger preset ${presetId}';
      case CommandActionType.gradientMode:
        return 'Gradient: Channel ${channel} → ${value} (${duration}ms)';
      case CommandActionType.blinkMode:
        return 'Blink: Channel ${channel} (${period}ms period)';
      case CommandActionType.strobeMode:
        return 'Strobe: Channel ${channel} (${count} flashes, ${totalTime}ms, ${pauseTime}ms pause)';
    }
  }

  /// Get Chinese description of this action
  String get chineseDescription {
    switch (type) {
      case CommandActionType.channelValue:
        return '通道 ${channel} → ${value}';
      case CommandActionType.presetTrigger:
        return '触发预设 ${presetId}';
      case CommandActionType.gradientMode:
        return '渐变: 通道${channel} → ${value} (${duration}ms)';
      case CommandActionType.blinkMode:
        return '闪烁: 通道${channel} (${period}ms周期)';
      case CommandActionType.strobeMode:
        return '频闪: 通道${channel} (${count}次闪, ${totalTime}ms, ${pauseTime}ms暂停)';
    }
  }

  /// Builds a PowerHub command packet from this action
  /// Returns null for preset triggers as they use different command types
  SwitchHubCommandPacket? buildPacketFromAction() {
    final channel = this.channel;
    final value = this.value ?? 0;

    if (channel == null) return null;

    List<int> payloadBytes = [];

    switch (type) {
      case CommandActionType.channelValue:
        // Mode 0x00: Set mode - [brightness(1 byte)]
        payloadBytes = [value & 0xFF];
        return SwitchHubCommandPacket(
          mode: 0x00,
          channel: channel,
          payload: base64Encode(payloadBytes),
        );

      case CommandActionType.gradientMode:
        // Mode 0x01: Gradient mode - [brightness(1 byte)][duration_ms(2 bytes)]
        final durationMs = duration ?? 1000;
        payloadBytes = [
          value & 0xFF,
          (durationMs >> 8) & 0xFF, // High byte
          durationMs & 0xFF,        // Low byte
        ];
        return SwitchHubCommandPacket(
          mode: 0x01,
          channel: channel,
          payload: base64Encode(payloadBytes),
        );

      case CommandActionType.blinkMode:
        // Mode 0x02: Blink mode - [period_ms(2 bytes)]
        final periodMs = period ?? 500;
        payloadBytes = [
          (periodMs >> 8) & 0xFF, // High byte
          periodMs & 0xFF,        // Low byte
        ];
        return SwitchHubCommandPacket(
          mode: 0x02,
          channel: channel,
          payload: base64Encode(payloadBytes),
        );

      case CommandActionType.strobeMode:
        // Mode 0x03: Strobe mode - [count(1 byte)][total_time_ms(2 bytes)][pause_time_ms(2 bytes)]
        final count = this.count ?? 5;
        final totalTimeMs = totalTime ?? 1000;
        final pauseTimeMs = pauseTime ?? 100;
        payloadBytes = [
          count & 0xFF,
          (totalTimeMs >> 8) & 0xFF,
          totalTimeMs & 0xFF,
          (pauseTimeMs >> 8) & 0xFF,
          pauseTimeMs & 0xFF,
        ];
        return SwitchHubCommandPacket(
          mode: 0x03,
          channel: channel,
          payload: base64Encode(payloadBytes),
        );

      case CommandActionType.presetTrigger:
        // For preset triggers, we'd need different handling
        // This would be a different command type, not part of the standard channel control
        return null;
    }
  }
}

class CommandBundle {
  CommandBundle({
    required this.id,
    required this.label,
    List<CommandAction>? actions,
    this.isEnabled = true,
  }) : actions = actions ?? [];

  final String id;
  final String label;
  final List<CommandAction> actions;
  final bool isEnabled;

  bool get isEmpty => actions.isEmpty;

  Set<String> get referencedControllers {
    return actions.map((action) => action.controllerId).toSet();
  }

  CommandBundle copyWith({
    String? label,
    List<CommandAction>? actions,
    bool? isEnabled,
  }) {
    return CommandBundle(
      id: id,
      label: label ?? this.label,
      actions: actions ?? List<CommandAction>.from(this.actions),
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'isEnabled': isEnabled,
      'actions': actions.map((action) => action.toJson()).toList(),
    };
  }

  factory CommandBundle.fromJson(Map<String, dynamic> json) {
    final actionsJson = json['actions'] as List<dynamic>? ?? <dynamic>[];
    return CommandBundle(
      id: json['id'] as String,
      label: json['label'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      actions: actionsJson
          .map(
            (entry) =>
                CommandAction.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(),
    );
  }
}

class ToggleState {
  ToggleState({
    required this.toggleId,
    required this.stateId,
    required this.label,
    this.isDefault = false,
    List<CommandBundle>? commandBundles,
    this.logic,
  }) : commandBundles = commandBundles ?? [];

  final String toggleId;
  final String stateId;
  final String label;
  final bool isDefault;
  final List<CommandBundle> commandBundles;
  final SwitchHubLogicNode? logic;

  bool get hasCommands => commandBundles.any((bundle) => !bundle.isEmpty);

  bool get hasConditionalLogic {
    final result = logic != null;
    if (result && toggleId == "射灯") {
      print('DEBUG hasConditionalLogic: toggleId="$toggleId", logic=$logic, result=$result');
    }
    return result;
  }

  SwitchHubLogicNode get resolvedLogic =>
      logic ?? _logicFromCommandBundles(commandBundles);

  /// Gets the resolved logic with proper bundle reference resolution
  SwitchHubLogicNode get fullyResolvedLogic {
    final manager = const ConditionalLogicManager();
    final resolved = manager.resolveBundleReferences(resolvedLogic, commandBundles);

    
    return resolved;
  }

  ToggleState copyWith({
    String? toggleId,
    String? stateId,
    String? label,
    bool? isDefault,
    List<CommandBundle>? commandBundles,
    SwitchHubLogicNode? logic,
  }) {
    return ToggleState(
      toggleId: toggleId ?? this.toggleId,
      stateId: stateId ?? this.stateId,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      commandBundles:
          commandBundles ?? List<CommandBundle>.from(this.commandBundles),
      logic: logic ?? this.logic,
    );
  }

  Set<String> get referencedControllers {
    return commandBundles.fold<Set<String>>(
      <String>{},
      (acc, bundle) => acc..addAll(bundle.referencedControllers),
    );
  }

  /// Gets all bundle references in the conditional logic
  Set<String> get conditionalBundleReferences {
    if (logic == null) return <String>{};

    final manager = const ConditionalLogicManager();
    return manager.extractBundleReferences(logic!);
  }

  /// Validates the conditional logic in this state
  ConditionalValidationResult validateConditionalLogic(
    List<String> availableToggles,
    Map<String, String> aliases,
  ) {
    final manager = const ConditionalLogicManager();
    return manager.validateLogic(this, availableToggles, aliases);
  }

  /// Creates a conditional rule from a bundle
  ToggleState withConditionalRule(
    String bundleId,
    String condition,
    List<CommandBundle> availableBundles,
  ) {
    final manager = const ConditionalLogicManager();
    final conditionalNode = manager.createConditionalFromBundle(
      bundleId,
      availableBundles,
      condition,
    );

    return copyWith(logic: conditionalNode);
  }

  /// Gets complexity metrics for the conditional logic
  int get conditionalLogicComplexity {
    if (logic == null) return 0;

    final manager = const ConditionalLogicManager();
    return manager.validateLogic(this, [], {}).complexity;
  }

  Map<String, dynamic> toJson() {
    final result = {
      'toggleId': toggleId,
      'stateId': stateId,
      'label': label,
      'isDefault': isDefault,
      'commandBundles': commandBundles
          .map((bundle) => bundle.toJson())
          .toList(),
    };

    if (logic != null) {
      print('DEBUG JSON EXPORT: Using fullyResolvedLogic');
      final resolved = fullyResolvedLogic.toJson();
      print('DEBUG JSON EXPORT: Resolved logic keys=${(resolved as Map).keys.toList()}');
      result['logic'] = resolved;
    }

    return result;
  }

  factory ToggleState.fromJson(Map<String, dynamic> json) {
    final bundlesJson = json['commandBundles'] as List<dynamic>? ?? <dynamic>[];
    final hasLogicJson = json.containsKey('logic');
    final logicJson = json['logic'];

    print('DEBUG ToggleState.fromJson: toggleId="${json['toggleId']}", hasLogicJson=$hasLogicJson, logicJson=$logicJson');

    final logic = json['logic'] == null
        ? null
        : SwitchHubLogicNode.fromJson(
            Map<String, dynamic>.from(json['logic'] as Map),
          );

    print('DEBUG ToggleState.fromJson: parsed logic=$logic');

    return ToggleState(
      toggleId: json['toggleId'] as String,
      stateId: json['stateId'] as String,
      label: json['label'] as String,
      isDefault: json['isDefault'] as bool? ?? false,
      commandBundles: bundlesJson
          .map(
            (entry) =>
                CommandBundle.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(),
      logic: logic,
    );
  }
}

class ConditionalRule {
  ConditionalRule({
    required this.id,
    required this.toggleId,
    required this.expectedStateId,
    required this.trueBundleId,
    this.falseBundleId,
    this.description,
  });

  final String id;
  final String toggleId;
  final String expectedStateId;
  final String trueBundleId;
  final String? falseBundleId;
  final String? description;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'toggleId': toggleId,
      'expectedStateId': expectedStateId,
      'trueBundleId': trueBundleId,
      'falseBundleId': falseBundleId,
      'description': description,
    };
  }

  factory ConditionalRule.fromJson(Map<String, dynamic> json) {
    return ConditionalRule(
      id: json['id'] as String,
      toggleId: json['toggleId'] as String,
      expectedStateId: json['expectedStateId'] as String,
      trueBundleId: json['trueBundleId'] as String,
      falseBundleId: json['falseBundleId'] as String?,
      description: json['description'] as String?,
    );
  }
}

class ToggleScene {
  ToggleScene({
    required this.id,
    required this.name,
    List<ToggleState>? states,
    List<ConditionalRule>? rules,
    Map<String, int>? switchSlots,
    Map<String, List<StatusSlot>>? statusSlots,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.description,
    this.isPublished = false,
  }) : states = states ?? [],
       rules = rules ?? [],
       switchSlots = Map<String, int>.unmodifiable(
         switchSlots ?? const <String, int>{},
       ),
       statusSlots = Map<String, List<StatusSlot>>.unmodifiable(
         statusSlots ?? const <String, List<StatusSlot>>{},
       ),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final List<ToggleState> states;
  final List<ConditionalRule> rules;
  final Map<String, int> switchSlots;
  final Map<String, List<StatusSlot>> statusSlots;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final bool isPublished;

  bool get hasConditionalLogic => rules.isNotEmpty || states.any((state) => state.hasConditionalLogic);

  bool get hasModernConditionalLogic => states.any((state) => state.hasConditionalLogic);

  Set<String> get referencedControllers {
    return states.fold<Set<String>>(
      <String>{},
      (acc, state) => acc..addAll(state.referencedControllers),
    );
  }

  /// Gets all unique toggle IDs referenced in conditional logic
  Set<String> get conditionalToggleReferences {
    final references = <String>{};
    for (final state in states) {
      if (state.hasConditionalLogic) {
        final bundleRefs = state.conditionalBundleReferences;
        for (final bundleId in bundleRefs) {
          // Extract toggle references from bundle (simplified approach)
          references.add(state.toggleId);
        }
      }
    }
    return references;
  }

  /// Validates all conditional logic in the scene
  Map<String, ConditionalValidationResult> validateAllConditionalLogic() {
    final results = <String, ConditionalValidationResult>{};
    final availableToggles = states.map((s) => s.toggleId).toSet().toList();

    // Build aliases map from states
    final aliases = <String, String>{};
    // TODO: Extract actual aliases from state configuration

    for (final state in states) {
      if (state.hasConditionalLogic) {
        final result = state.validateConditionalLogic(availableToggles, aliases);
        results['${state.toggleId}.${state.stateId}'] = result;
      }
    }

    return results;
  }

  /// Gets total complexity of all conditional logic in the scene
  int get totalConditionalLogicComplexity {
    return states.fold(0, (sum, state) => sum + state.conditionalLogicComplexity);
  }

  /// Gets states with conditional logic
  List<ToggleState> get statesWithConditionalLogic {
    return states.where((state) => state.hasConditionalLogic).toList();
  }

  /// Gets states without conditional logic (traditional states)
  List<ToggleState> get statesWithoutConditionalLogic {
    return states.where((state) => !state.hasConditionalLogic).toList();
  }

  /// Migrates legacy ConditionalRule to modern SwitchHubIfNode
  ToggleScene migrateLegacyConditionalRules() {
    if (rules.isEmpty) return this;

    final migratedStates = <ToggleState>[];
    final processedRules = <String>{};

    for (final rule in rules) {
      if (!processedRules.contains(rule.id)) {
        // Find the state that this rule applies to
        final targetState = states.where((state) =>
          state.toggleId == rule.toggleId && state.stateId == rule.expectedStateId
        ).firstOrNull;

        if (targetState != null) {
          final condition = '${rule.toggleId}.${rule.expectedStateId}';
          final migratedState = targetState.withConditionalRule(
            rule.trueBundleId,
            condition,
            targetState.commandBundles,
          );

          migratedStates.add(migratedState);
          processedRules.add(rule.id);
        }
      }
    }

    // Replace old states with migrated ones and remove old rules
    return copyWith(
      states: states.map((state) {
        final migrated = migratedStates.where((ms) =>
          ms.toggleId == state.toggleId && ms.stateId == state.stateId
        ).firstOrNull;
        return migrated ?? state;
      }).toList(),
      rules: [], // Remove legacy rules after migration
    );
  }

  ToggleScene copyWith({
    String? name,
    List<ToggleState>? states,
    List<ConditionalRule>? rules,
    Map<String, int>? switchSlots,
    Map<String, List<StatusSlot>>? statusSlots,
    DateTime? updatedAt,
    String? description,
    bool? isPublished,
  }) {
    return ToggleScene(
      id: id,
      name: name ?? this.name,
      states: states ?? List<ToggleState>.from(this.states),
      rules: rules ?? List<ConditionalRule>.from(this.rules),
      switchSlots: switchSlots ?? Map<String, int>.from(this.switchSlots),
      statusSlots: statusSlots ?? Map<String, List<StatusSlot>>.from(this.statusSlots),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      description: description ?? this.description,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'states': states.map((state) => state.toJson()).toList(),
      'rules': rules.map((rule) => rule.toJson()).toList(),
      'switchSlots': switchSlots,
      'statusSlots': statusSlots.map((key, value) => MapEntry(key, value.map((slot) => slot.toJson()).toList())),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'isPublished': isPublished,
    };
  }

  factory ToggleScene.fromJson(Map<String, dynamic> json) {
    final statesJson = json['states'] as List<dynamic>? ?? <dynamic>[];
    final rulesJson = json['rules'] as List<dynamic>? ?? <dynamic>[];
    final switchSlots = <String, int>{};
    final rawSlots = json['switchSlots'];
    if (rawSlots is Map) {
      rawSlots.forEach((key, value) {
        final slotValue = value is num
            ? value.toInt()
            : int.tryParse(value.toString());
        if (slotValue != null && slotValue > 0) {
          switchSlots[key.toString()] = slotValue;
        }
      });
    }

    // Parse status slots
    final statusSlots = <String, List<StatusSlot>>{};
    final rawStatusSlots = json['statusSlots'];
    if (rawStatusSlots is Map) {
      rawStatusSlots.forEach((key, value) {
        if (value is List) {
          final slots = <StatusSlot>[];
          for (final slotJson in value) {
            try {
              slots.add(StatusSlot.fromJson(Map<String, dynamic>.from(slotJson as Map)));
            } catch (e) {
              // Skip invalid status slot configurations
              continue;
            }
          }
          if (slots.isNotEmpty) {
            statusSlots[key.toString()] = slots;
          }
        }
      });
    }

    return ToggleScene(
      id: json['id'] as String,
      name: json['name'] as String,
      states: statesJson
          .map(
            (entry) =>
                ToggleState.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList(),
      rules: rulesJson
          .map(
            (entry) => ConditionalRule.fromJson(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList(),
      switchSlots: switchSlots,
      statusSlots: statusSlots,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      description: json['description'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
    );
  }
}

extension SwitchHubSceneAdapter on ToggleScene {
  SwitchHubConfig toSwitchHubConfig({int schemaVersion = 1}) {
    final grouped = <String, List<ToggleState>>{};
    for (final state in states) {
      grouped.putIfAbsent(state.toggleId, () => <ToggleState>[]).add(state);
    }

    final switches = <SwitchHubSwitch>[];
    final usedSlots = <int>{};
    var nextAutoSlot = 1;

    int reserveAutoSlot() {
      while (usedSlots.contains(nextAutoSlot)) {
        nextAutoSlot++;
      }
      final slot = nextAutoSlot;
      usedSlots.add(slot);
      nextAutoSlot++;
      return slot;
    }

    grouped.forEach((toggleId, toggleStates) {
      final onState = _resolveState(toggleStates, suffix: 'on');
      final offState = _resolveState(toggleStates, suffix: 'off');
      // Get status slots for this toggle ID from the scene
      final toggleStatusSlots = statusSlots[toggleId] ?? <StatusSlot>[];

      final ui = SwitchHubUiConfig(
        channelLabel: toggleId,
        onLabel: onState?.label,
        offLabel: offState?.label,
        newStatusSlots: toggleStatusSlots,
      );
      final explicitSlot = switchSlots[toggleId];
      final switchId = explicitSlot != null && explicitSlot > 0
          ? (usedSlots.add(explicitSlot) ? explicitSlot : reserveAutoSlot())
          : reserveAutoSlot();
      switches.add(
        SwitchHubSwitch(
          switchId: switchId,
          revision: updatedAt.millisecondsSinceEpoch & 0xFFFF,
          onLogic: (onState ?? toggleStates.first).resolvedLogic,
          offLogic: (offState ?? toggleStates.first).resolvedLogic,
          uiConfig: ui,
        ),
      );
    });

    return SwitchHubConfig(
      schemaVersion: schemaVersion,
      switches: switches,
      metadata: {
        'scene_id': id,
        'scene_name': name,
        'updated_at': updatedAt.toIso8601String(),
      },
    );
  }
}

ToggleState? _resolveState(List<ToggleState> states, {required String suffix}) {
  final lowerSuffix = suffix.toLowerCase();
  for (final state in states) {
    if (state.stateId.toLowerCase().endsWith(lowerSuffix)) {
      return state;
    }
  }
  return null;
}

SwitchHubLogicNode _logicFromCommandBundles(List<CommandBundle> bundles) {
  final sequences = <SwitchHubSequenceItem>[];
  for (final bundle in bundles) {
    sequences.addAll(_sequenceFromBundle(bundle));
  }
  return SwitchHubLeafNode(sequence: sequences);
}

List<SwitchHubSequenceItem> _sequenceFromBundle(CommandBundle bundle) {
  final grouped = <String, List<CommandAction>>{};
  for (final action in bundle.actions) {
    grouped
        .putIfAbsent(action.controllerId, () => <CommandAction>[])
        .add(action);
  }
  final items = <SwitchHubSequenceItem>[];
  grouped.forEach((controllerId, actions) {
    final packets = <SwitchHubCommandPacket>[];
    for (final action in actions) {
      final channel = action.channel;
      if (channel == null) {
        continue;
      }

      switch (action.type) {
        case CommandActionType.channelValue:
          final value = action.value;
          if (value != null) {
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x00,
                channel: channel,
                payload: base64Encode([value & 0xFF]),
              ),
            );
          }
          break;

        case CommandActionType.gradientMode:
          final value = action.value;
          final duration = action.duration;
          if (value != null && duration != null) {
            // Gradient mode: [0x01][channel][value][duration_high][duration_low]
            final durationHigh = (duration >> 8) & 0xFF;
            final durationLow = duration & 0xFF;
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x01,
                channel: channel,
                payload: base64Encode([value & 0xFF, durationHigh, durationLow]),
              ),
            );
          }
          break;

        case CommandActionType.blinkMode:
          final period = action.period;
          if (period != null) {
            // Blink mode: [0x02][channel][period_high][period_low]
            final periodHigh = (period >> 8) & 0xFF;
            final periodLow = period & 0xFF;
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x02,
                channel: channel,
                payload: base64Encode([periodHigh, periodLow]),
              ),
            );
          }
          break;

        case CommandActionType.strobeMode:
          final count = action.count;
          final totalTime = action.totalTime;
          final pauseTime = action.pauseTime;
          if (count != null && totalTime != null && pauseTime != null) {
            // Strobe mode: [0x03][channel][count][total_time_high][total_time_low][pause_time_high][pause_time_low]
            final totalTimeHigh = (totalTime >> 8) & 0xFF;
            final totalTimeLow = totalTime & 0xFF;
            final pauseTimeHigh = (pauseTime >> 8) & 0xFF;
            final pauseTimeLow = pauseTime & 0xFF;
            packets.add(
              SwitchHubCommandPacket(
                mode: 0x03,
                channel: channel,
                payload: base64Encode([count & 0xFF, totalTimeHigh, totalTimeLow, pauseTimeHigh, pauseTimeLow]),
              ),
            );
          }
          break;

        case CommandActionType.presetTrigger:
          // Preset triggers don't generate BLE packets for sequence generation
          // They are handled separately in the orchestration provider
          break;
      }
    }
    if (packets.isNotEmpty) {
      items.add(
        SwitchHubSequenceItem(targetMac: controllerId, commandPackets: packets),
      );
    }
  });
  return items;
}
