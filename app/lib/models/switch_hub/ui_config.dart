import 'status_slot.dart';

/// User interface definition packaged alongside the logic tree. The labels map
/// directly to the four UI regions documented in `SWITCHHUB_BLE.md`.
class SwitchHubUiConfig {
  const SwitchHubUiConfig({
    this.channelLabel,
    this.onLabel,
    this.offLabel,
    List<SwitchHubStatusSlot>? statusSlots,
  }) : statusSlots = statusSlots ?? const <SwitchHubStatusSlot>[];

  final String? channelLabel;
  final String? onLabel;
  final String? offLabel;
  final List<SwitchHubStatusSlot> statusSlots;

  SwitchHubUiConfig copyWith({
    String? channelLabel,
    String? onLabel,
    String? offLabel,
    List<SwitchHubStatusSlot>? statusSlots,
  }) {
    return SwitchHubUiConfig(
      channelLabel: channelLabel ?? this.channelLabel,
      onLabel: onLabel ?? this.onLabel,
      offLabel: offLabel ?? this.offLabel,
      statusSlots:
          statusSlots ?? List<SwitchHubStatusSlot>.from(this.statusSlots),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (channelLabel != null) 'channel_label': channelLabel,
      if (onLabel != null) 'on_label': onLabel,
      if (offLabel != null) 'off_label': offLabel,
      if (statusSlots.isNotEmpty)
        'status_slots': statusSlots.map((slot) => slot.toJson()).toList(),
    };
  }

  factory SwitchHubUiConfig.fromJson(Map<String, dynamic> json) {
    final slots = (json['status_slots'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              SwitchHubStatusSlot.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    return SwitchHubUiConfig(
      channelLabel: json['channel_label'] as String?,
      onLabel: json['on_label'] as String?,
      offLabel: json['off_label'] as String?,
      statusSlots: slots,
    );
  }
}
