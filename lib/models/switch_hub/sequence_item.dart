import 'command_packet.dart';

/// Describes the actual work SwitchHub should perform for a particular target
/// PowerHub device. Each sequence item corresponds to the JSON `sequence_item`
/// definition in `SWITCHHUB_BLE.md`.
class SwitchHubSequenceItem {
  const SwitchHubSequenceItem({
    required this.targetMac,
    required this.commandPackets,
    this.delayMs,
  });

  final String targetMac;
  final List<SwitchHubCommandPacket> commandPackets;
  final int? delayMs;

  bool get hasDelay => delayMs != null && delayMs! > 0;

  SwitchHubSequenceItem copyWith({
    String? targetMac,
    List<SwitchHubCommandPacket>? commandPackets,
    int? delayMs,
  }) {
    return SwitchHubSequenceItem(
      targetMac: targetMac ?? this.targetMac,
      commandPackets:
          commandPackets ?? List<SwitchHubCommandPacket>.from(this.commandPackets),
      delayMs: delayMs ?? this.delayMs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'target_mac': targetMac,
      'command_packets':
          commandPackets.map((packet) => packet.toJson()).toList(),
      if (delayMs != null) 'delay_ms': delayMs,
    };
  }

  factory SwitchHubSequenceItem.fromJson(Map<String, dynamic> json) {
    final packets = (json['command_packets'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              SwitchHubCommandPacket.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    return SwitchHubSequenceItem(
      targetMac: json['target_mac'] as String,
      commandPackets: packets,
      delayMs: json['delay_ms'] as int?,
    );
  }
}
