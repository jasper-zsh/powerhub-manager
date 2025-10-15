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
  }) : commandBundles = commandBundles ?? [];

  final String toggleId;
  final String stateId;
  final String label;
  final bool isDefault;
  final List<CommandBundle> commandBundles;

  bool get hasCommands => commandBundles.any((bundle) => !bundle.isEmpty);

  ToggleState copyWith({
    String? toggleId,
    String? stateId,
    String? label,
    bool? isDefault,
    List<CommandBundle>? commandBundles,
  }) {
    return ToggleState(
      toggleId: toggleId ?? this.toggleId,
      stateId: stateId ?? this.stateId,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
      commandBundles:
          commandBundles ?? List<CommandBundle>.from(this.commandBundles),
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
    DateTime? createdAt,
    DateTime? updatedAt,
    this.description,
    this.isPublished = false,
  }) : states = states ?? [],
       rules = rules ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  final String id;
  final String name;
  final List<ToggleState> states;
  final List<ConditionalRule> rules;
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
    DateTime? updatedAt,
    String? description,
    bool? isPublished,
  }) {
    return ToggleScene(
      id: id,
      name: name ?? this.name,
      states: states ?? List<ToggleState>.from(this.states),
      rules: rules ?? List<ConditionalRule>.from(this.rules),
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'description': description,
      'isPublished': isPublished,
    };
  }

  factory ToggleScene.fromJson(Map<String, dynamic> json) {
    final statesJson = json['states'] as List<dynamic>? ?? <dynamic>[];
    final rulesJson = json['rules'] as List<dynamic>? ?? <dynamic>[];
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
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      description: json['description'] as String?,
      isPublished: json['isPublished'] as bool? ?? false,
    );
  }
}
