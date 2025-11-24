import 'switch_definition.dart';

class SwitchHubConfig {
  const SwitchHubConfig({
    required this.schemaVersion,
    required this.switches,
    this.metadata,
  });

  final int schemaVersion;
  final List<SwitchHubSwitch> switches;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'schema_version': schemaVersion,
      'switches': switches.map((entry) => entry.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory SwitchHubConfig.fromJson(Map<String, dynamic> json) {
    final switchList = (json['switches'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              SwitchHubSwitch.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    return SwitchHubConfig(
      schemaVersion: json['schema_version'] as int? ?? 1,
      switches: switchList,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }
}
