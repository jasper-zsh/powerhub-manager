import 'dart:convert';

import 'package:app/models/switch_hub/command_packet.dart';
import 'package:app/models/switch_hub/config.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/switch_definition.dart';
import 'package:app/models/switch_hub/ui_config.dart';

enum CommandActionType { channelValue, presetTrigger }

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
  }) {
    if (type == CommandActionType.channelValue) {
      assert(channel != null, 'Channel actions require a channel id');
      assert(value != null, 'Channel actions require a PWM value');
    }
    if (type == CommandActionType.presetTrigger) {
      assert(presetId != null, 'Preset trigger actions require a presetId');
    }
  }

  final String controllerId;
  final CommandActionType type;
  final int? channel;
  final int? value;
  final int? presetId;

  CommandAction copyWith({
    String? controllerId,
    CommandActionType? type,
    int? channel,
    int? value,
    int? presetId,
  }) {
    final resolvedType = type ?? this.type;
    return CommandAction(
      controllerId: controllerId ?? this.controllerId,
      type: resolvedType,
      channel: resolvedType == CommandActionType.channelValue
          ? (channel ?? this.channel)
          : null,
      value: resolvedType == CommandActionType.channelValue
          ? (value ?? this.value)
          : null,
      presetId: resolvedType == CommandActionType.presetTrigger
          ? (presetId ?? this.presetId)
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
    };
  }

  factory CommandAction.fromJson(Map<String, dynamic> json) {
    return CommandAction(
      controllerId: json['controllerId'] as String,
      type: _commandActionTypeFromString(json['type'] as String),
      channel: json['channel'] as int?,
      value: json['value'] as int?,
      presetId: json['presetId'] as int?,
    );
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

  SwitchHubLogicNode get resolvedLogic =>
      logic ?? _logicFromCommandBundles(commandBundles);

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

  Map<String, dynamic> toJson() {
    return {
      'toggleId': toggleId,
      'stateId': stateId,
      'label': label,
      'isDefault': isDefault,
      'commandBundles': commandBundles
          .map((bundle) => bundle.toJson())
          .toList(),
      if (logic != null) 'logic': logic!.toJson(),
    };
  }

  factory ToggleState.fromJson(Map<String, dynamic> json) {
    final bundlesJson = json['commandBundles'] as List<dynamic>? ?? <dynamic>[];
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
      logic: json['logic'] == null
          ? null
          : SwitchHubLogicNode.fromJson(
              Map<String, dynamic>.from(json['logic'] as Map),
            ),
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
    DateTime? createdAt,
    DateTime? updatedAt,
    this.description,
    this.isPublished = false,
  }) : states = states ?? [],
       rules = rules ?? [],
       switchSlots = Map<String, int>.unmodifiable(
         switchSlots ?? const <String, int>{},
       ),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final List<ToggleState> states;
  final List<ConditionalRule> rules;
  final Map<String, int> switchSlots;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final bool isPublished;

  bool get hasConditionalLogic => rules.isNotEmpty;

  Set<String> get referencedControllers {
    return states.fold<Set<String>>(
      <String>{},
      (acc, state) => acc..addAll(state.referencedControllers),
    );
  }

  ToggleScene copyWith({
    String? name,
    List<ToggleState>? states,
    List<ConditionalRule>? rules,
    Map<String, int>? switchSlots,
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
      final ui = SwitchHubUiConfig(
        channelLabel: toggleId,
        onLabel: onState?.label,
        offLabel: offState?.label,
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
      if (action.type != CommandActionType.channelValue) {
        continue;
      }
      final value = action.value;
      final channel = action.channel;
      if (value == null || channel == null) {
        continue;
      }
      packets.add(
        SwitchHubCommandPacket(
          mode: 0x00,
          channel: channel,
          payload: base64Encode([value & 0xFF]),
        ),
      );
    }
    if (packets.isNotEmpty) {
      items.add(
        SwitchHubSequenceItem(targetMac: controllerId, commandPackets: packets),
      );
    }
  });
  return items;
}
