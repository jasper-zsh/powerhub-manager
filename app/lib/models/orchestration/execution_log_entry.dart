class ExecutionLogEntry {
  ExecutionLogEntry({
    required this.id,
    required this.sceneId,
    required this.triggerSource,
    required this.result,
    required this.triggeredAt,
    List<String>? executedBundleIds,
    List<String>? skippedActions,
    this.notes,
  })  : executedBundleIds = executedBundleIds ?? <String>[],
        skippedActions = skippedActions ?? <String>[];

  final String id;
  final String sceneId;
  final String triggerSource;
  final String result;
  final DateTime triggeredAt;
  final List<String> executedBundleIds;
  final List<String> skippedActions;
  final String? notes;

  bool get isSuccess => result.toLowerCase() == 'success';
  bool get isPartial => result.toLowerCase() == 'partial';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sceneId': sceneId,
      'triggerSource': triggerSource,
      'result': result,
      'triggeredAt': triggeredAt.toIso8601String(),
      'executedBundleIds': executedBundleIds,
      'skippedActions': skippedActions,
      'notes': notes,
    };
  }

  factory ExecutionLogEntry.fromJson(Map<String, dynamic> json) {
    return ExecutionLogEntry(
      id: json['id'] as String,
      sceneId: json['sceneId'] as String,
      triggerSource: json['triggerSource'] as String,
      result: json['result'] as String,
      triggeredAt: DateTime.parse(json['triggeredAt'] as String),
      executedBundleIds: (json['executedBundleIds'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      skippedActions: (json['skippedActions'] as List<dynamic>? ?? [])
          .map((value) => value.toString())
          .toList(),
      notes: json['notes'] as String?,
    );
  }

  ExecutionLogEntry copyWith({
    String? result,
    List<String>? executedBundleIds,
    List<String>? skippedActions,
    String? notes,
  }) {
    return ExecutionLogEntry(
      id: id,
      sceneId: sceneId,
      triggerSource: triggerSource,
      result: result ?? this.result,
      triggeredAt: triggeredAt,
      executedBundleIds:
          executedBundleIds ?? List<String>.from(this.executedBundleIds),
      skippedActions:
          skippedActions ?? List<String>.from(this.skippedActions),
      notes: notes ?? this.notes,
    );
  }
}
