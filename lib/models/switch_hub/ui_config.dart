import 'package:flutter/foundation.dart';
import 'status_slot.dart';
import 'status_slot_config.dart';

/// User interface definition packaged alongside the logic tree. The labels map
/// directly to the four UI regions documented in `SWITCHHUB_BLE.md`.
class SwitchHubUiConfig {
  const SwitchHubUiConfig({
    this.channelLabel,
    this.onLabel,
    this.offLabel,
    List<SwitchHubStatusSlot>? statusSlots,
    List<StatusSlot>? newStatusSlots,
  }) : statusSlots = statusSlots ?? const <SwitchHubStatusSlot>[],
       newStatusSlots = newStatusSlots ?? const <StatusSlot>[];

  final String? channelLabel;
  final String? onLabel;
  final String? offLabel;
  final List<SwitchHubStatusSlot> statusSlots;

  /// New status slot format as defined in SWITCHHUB_BLE.md protocol
  final List<StatusSlot> newStatusSlots;

  SwitchHubUiConfig copyWith({
    String? channelLabel,
    String? onLabel,
    String? offLabel,
    List<SwitchHubStatusSlot>? statusSlots,
    List<StatusSlot>? newStatusSlots,
  }) {
    return SwitchHubUiConfig(
      channelLabel: channelLabel ?? this.channelLabel,
      onLabel: onLabel ?? this.onLabel,
      offLabel: offLabel ?? this.offLabel,
      statusSlots:
          statusSlots ?? List<SwitchHubStatusSlot>.from(this.statusSlots),
      newStatusSlots:
          newStatusSlots ?? List<StatusSlot>.from(this.newStatusSlots),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (channelLabel != null) 'channel_label': channelLabel,
      if (onLabel != null) 'on_label': onLabel,
      if (offLabel != null) 'off_label': offLabel,
      if (statusSlots.isNotEmpty)
        'status_slots': statusSlots.map((slot) => slot.toJson()).toList(),
      if (newStatusSlots.isNotEmpty)
        'status_slots': newStatusSlots.map((slot) => slot.toJson()).toList(),
    };
  }

  factory SwitchHubUiConfig.fromJson(Map<String, dynamic> json) {
    // Try to parse legacy status slots first
    final legacySlots = (json['status_slots'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              SwitchHubStatusSlot.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();

    // Try to parse new format status slots
    List<StatusSlot> newSlots = [];
    try {
      newSlots = (json['status_slots'] as List<dynamic>? ?? [])
          .map(
            (entry) => StatusSlot.fromJson(Map<String, dynamic>.from(entry as Map)),
          )
          .toList();
    } catch (e) {
      // If parsing new format fails, stick with legacy format
      debugPrint('Failed to parse new status slot format: $e');
    }

    return SwitchHubUiConfig(
      channelLabel: json['channel_label'] as String?,
      onLabel: json['on_label'] as String?,
      offLabel: json['off_label'] as String?,
      statusSlots: legacySlots,
      newStatusSlots: newSlots,
    );
  }
}
