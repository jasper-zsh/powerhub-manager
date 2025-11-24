import 'dart:convert';

/// Represents a single PowerHub command packet that should be written to the
/// SwitchHub client connection. The packet fields map directly to the JSON
/// structure defined in `SWITCHHUB_BLE.md`.
class SwitchHubCommandPacket {
  const SwitchHubCommandPacket({
    required this.mode,
    required this.channel,
    required this.payload,
    this.retry,
  });

  final int mode;
  final int channel;
  final String payload;
  final int? retry;

  /// Decodes the base64 payload into raw bytes. Used by preview logic to
  /// display human readable channel updates when possible.
  List<int> get payloadBytes => base64Decode(payload);

  SwitchHubCommandPacket copyWith({
    int? mode,
    int? channel,
    String? payload,
    int? retry,
  }) {
    return SwitchHubCommandPacket(
      mode: mode ?? this.mode,
      channel: channel ?? this.channel,
      payload: payload ?? this.payload,
      retry: retry ?? this.retry,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'channel': channel,
      'payload': payload,
      if (retry != null) 'retry': retry,
    };
  }

  factory SwitchHubCommandPacket.fromJson(Map<String, dynamic> json) {
    return SwitchHubCommandPacket(
      mode: json['mode'] as int,
      channel: json['channel'] as int,
      payload: json['payload'] as String,
      retry: json['retry'] as int?,
    );
  }
}
