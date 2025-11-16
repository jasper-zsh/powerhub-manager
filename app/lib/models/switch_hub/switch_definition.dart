import 'logic_node.dart';
import 'ui_config.dart';

class SwitchHubSwitch {
  const SwitchHubSwitch({
    required this.switchId,
    required this.revision,
    required this.onLogic,
    required this.offLogic,
    this.uiConfig,
  });

  final int switchId;
  final int revision;
  final SwitchHubLogicNode onLogic;
  final SwitchHubLogicNode offLogic;
  final SwitchHubUiConfig? uiConfig;

  Map<String, dynamic> toJson() {
    return {
      'switch_id': switchId,
      'revision': revision,
      'on': onLogic.toJson(),
      'off': offLogic.toJson(),
      if (uiConfig != null) 'ui': uiConfig!.toJson(),
    };
  }

  factory SwitchHubSwitch.fromJson(Map<String, dynamic> json) {
    return SwitchHubSwitch(
      switchId: json['switch_id'] as int,
      revision: json['revision'] as int? ?? 0,
      onLogic: SwitchHubLogicNode.fromJson(
        Map<String, dynamic>.from(json['on'] as Map),
      ),
      offLogic: SwitchHubLogicNode.fromJson(
        Map<String, dynamic>.from(json['off'] as Map),
      ),
      uiConfig: json['ui'] == null
          ? null
          : SwitchHubUiConfig.fromJson(
              Map<String, dynamic>.from(json['ui'] as Map),
            ),
    );
  }
}
