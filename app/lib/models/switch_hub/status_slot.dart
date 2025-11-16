/// Data binding for the UI status zone. Each slot tells SwitchHub how to map a
/// monitored value from connected PowerHub devices to the on-device UI and app.
class SwitchHubStatusSlot {
  const SwitchHubStatusSlot({
    required this.sourceMac,
    required this.characteristicUuid,
    required this.offset,
    required this.length,
    required this.format,
  });

  final String sourceMac;
  final String characteristicUuid;
  final int offset;
  final int length;
  final String format;

  Map<String, dynamic> toJson() {
    return {
      'source_mac': sourceMac,
      'characteristic_uuid': characteristicUuid,
      'offset': offset,
      'length': length,
      'format': format,
    };
  }

  factory SwitchHubStatusSlot.fromJson(Map<String, dynamic> json) {
    return SwitchHubStatusSlot(
      sourceMac: json['source_mac'] as String,
      characteristicUuid: json['characteristic_uuid'] as String,
      offset: json['offset'] as int,
      length: json['length'] as int,
      format: json['format'] as String,
    );
  }
}
