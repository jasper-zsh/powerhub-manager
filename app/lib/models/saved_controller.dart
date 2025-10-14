
/// The connection status for a saved controller as persisted in local storage.
enum SavedControllerConnectionStatus {
  connected,
  connecting,
  disconnected,
  unavailable,
}

extension SavedControllerConnectionStatusX on SavedControllerConnectionStatus {
  String get label => name;

  static SavedControllerConnectionStatus fromLabel(String value) {
    return SavedControllerConnectionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SavedControllerConnectionStatus.disconnected,
    );
  }
}

/// Retry policy metadata used while attempting reconnections.
class RetryPolicy {
  RetryPolicy({
    required this.maxAttempts,
    required this.attemptCount,
    required this.backoff,
    this.lastAttemptAt,
  }) : assert(maxAttempts > 0, 'maxAttempts must be greater than zero');

  final int maxAttempts;
  final int attemptCount;
  final Duration backoff;
  final DateTime? lastAttemptAt;

  RetryPolicy.defaults({
    int maxAttempts = 5,
    Duration backoff = const Duration(seconds: 5),
  }) : this(
          maxAttempts: maxAttempts,
          attemptCount: 0,
          backoff: backoff,
          lastAttemptAt: null,
        );

  RetryPolicy copyWith({
    int? maxAttempts,
    int? attemptCount,
    Duration? backoff,
    DateTime? lastAttemptAt,
  }) {
    return RetryPolicy(
      maxAttempts: maxAttempts ?? this.maxAttempts,
      attemptCount: attemptCount ?? this.attemptCount,
      backoff: backoff ?? this.backoff,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxAttempts': maxAttempts,
      'attemptCount': attemptCount,
      'backoffSeconds': backoff.inSeconds,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
    };
  }

  factory RetryPolicy.fromJson(Map<String, dynamic> json) {
    return RetryPolicy(
      maxAttempts: json['maxAttempts'] as int? ?? 5,
      attemptCount: json['attemptCount'] as int? ?? 0,
      backoff: Duration(seconds: json['backoffSeconds'] as int? ?? 5),
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.parse(json['lastAttemptAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RetryPolicy &&
        other.maxAttempts == maxAttempts &&
        other.attemptCount == attemptCount &&
        other.backoff == backoff &&
        other.lastAttemptAt == lastAttemptAt;
  }

  @override
  int get hashCode => Object.hash(
        maxAttempts,
        attemptCount,
        backoff,
        lastAttemptAt,
      );
}

/// Optional metadata about the controller that can inform UI hints.
class DeviceCapabilities {
  const DeviceCapabilities({
    this.channels,
    this.firmwareVersion,
    this.supportsPresets,
  });

  final int? channels;
  final String? firmwareVersion;
  final bool? supportsPresets;

  DeviceCapabilities copyWith({
    int? channels,
    String? firmwareVersion,
    bool? supportsPresets,
  }) {
    return DeviceCapabilities(
      channels: channels ?? this.channels,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      supportsPresets: supportsPresets ?? this.supportsPresets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (channels != null) 'channels': channels,
      if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
      if (supportsPresets != null) 'supportsPresets': supportsPresets,
    };
  }

  factory DeviceCapabilities.fromJson(Map<String, dynamic> json) {
    return DeviceCapabilities(
      channels: json['channels'] as int?,
      firmwareVersion: json['firmwareVersion'] as String?,
      supportsPresets: json['supportsPresets'] as bool?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceCapabilities &&
        other.channels == channels &&
        other.firmwareVersion == firmwareVersion &&
        other.supportsPresets == supportsPresets;
  }

  @override
  int get hashCode => Object.hash(
        channels,
        firmwareVersion,
        supportsPresets,
      );
}

/// Represents a persisted BLE controller entry saved by the user.
class SavedController {
  SavedController({
    required this.controllerId,
    required String alias,
    this.lastConnectedAt,
    SavedControllerConnectionStatus connectionStatus =
        SavedControllerConnectionStatus.disconnected,
    RetryPolicy? retryPolicy,
    this.deviceCapabilities,
    this.notes,
  })  : alias = sanitizeAlias(alias),
        connectionStatus = connectionStatus,
        retryPolicy = retryPolicy ?? RetryPolicy.defaults();

  final String controllerId;
  final String alias;
  final DateTime? lastConnectedAt;
  final SavedControllerConnectionStatus connectionStatus;
  final RetryPolicy retryPolicy;
  final DeviceCapabilities? deviceCapabilities;
  final String? notes;

  static const int maxAliasLength = 32;

  static String sanitizeAlias(String alias) {
    final trimmed = alias.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Alias cannot be empty');
    }
    if (trimmed.length > maxAliasLength) {
      throw ArgumentError(
        'Alias must be at most $maxAliasLength characters long',
      );
    }
    return trimmed;
  }

  static void ensureAliasUnique(
    String alias,
    Iterable<SavedController> existingControllers, {
    String? ignoreControllerId,
  }) {
    final normalizedAlias = alias.trim().toLowerCase();
    final hasDuplicate = existingControllers.any(
      (controller) {
        if (ignoreControllerId != null &&
            controller.controllerId == ignoreControllerId) {
          return false;
        }
        return controller.alias.trim().toLowerCase() == normalizedAlias;
      },
    );
    if (hasDuplicate) {
      throw ArgumentError('Alias must be unique among saved controllers');
    }
  }

  SavedController copyWith({
    String? controllerId,
    String? alias,
    DateTime? lastConnectedAt,
    SavedControllerConnectionStatus? connectionStatus,
    RetryPolicy? retryPolicy,
    DeviceCapabilities? deviceCapabilities,
    String? notes,
  }) {
    return SavedController(
      controllerId: controllerId ?? this.controllerId,
      alias: alias ?? this.alias,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      retryPolicy: retryPolicy ?? this.retryPolicy,
      deviceCapabilities: deviceCapabilities ?? this.deviceCapabilities,
      notes: notes ?? this.notes,
    );
  }

  SavedController touchConnectedAt(DateTime timestamp) {
    return copyWith(
      lastConnectedAt: timestamp,
      connectionStatus: SavedControllerConnectionStatus.connected,
      retryPolicy: retryPolicy.copyWith(
        attemptCount: 0,
        lastAttemptAt: timestamp,
      ),
    );
  }

  SavedController incrementRetry(DateTime timestamp) {
    return copyWith(
      connectionStatus: SavedControllerConnectionStatus.connecting,
      retryPolicy: retryPolicy.copyWith(
        attemptCount: retryPolicy.attemptCount + 1,
        lastAttemptAt: timestamp,
      ),
    );
  }

  SavedController markUnavailable() {
    return copyWith(
      connectionStatus: SavedControllerConnectionStatus.unavailable,
    );
  }

  SavedController markDisconnected() {
    return copyWith(
      connectionStatus: SavedControllerConnectionStatus.disconnected,
    );
  }

  SavedController rename(
    String newAlias,
    Iterable<SavedController> existingControllers,
  ) {
    final sanitized = sanitizeAlias(newAlias);
    ensureAliasUnique(
      sanitized,
      existingControllers,
      ignoreControllerId: controllerId,
    );
    return copyWith(alias: sanitized);
  }

  Map<String, dynamic> toJson() {
    return {
      'controllerId': controllerId,
      'alias': alias,
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
      'connectionStatus': connectionStatus.label,
      'retryPolicy': retryPolicy.toJson(),
      'deviceCapabilities': deviceCapabilities?.toJson(),
      'notes': notes,
    };
  }

  factory SavedController.fromJson(Map<String, dynamic> json) {
    return SavedController(
      controllerId: json['controllerId'] as String,
      alias: json['alias'] as String,
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
      connectionStatus: SavedControllerConnectionStatusX.fromLabel(
        json['connectionStatus'] as String? ?? 'disconnected',
      ),
      retryPolicy: json['retryPolicy'] != null
          ? RetryPolicy.fromJson(
              (json['retryPolicy'] as Map).cast<String, dynamic>(),
            )
          : RetryPolicy.defaults(),
      deviceCapabilities: json['deviceCapabilities'] != null
          ? DeviceCapabilities.fromJson(
              (json['deviceCapabilities'] as Map).cast<String, dynamic>(),
            )
          : null,
      notes: json['notes'] as String?,
    );
  }

  @override
  String toString() {
    return 'SavedController(controllerId: $controllerId, alias: $alias, '
        'status: ${connectionStatus.name}, lastConnectedAt: $lastConnectedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SavedController &&
        other.controllerId == controllerId &&
        other.alias == alias &&
        other.lastConnectedAt == lastConnectedAt &&
        other.connectionStatus == connectionStatus &&
        other.retryPolicy == retryPolicy &&
        other.deviceCapabilities == deviceCapabilities &&
        other.notes == notes;
  }

  @override
  int get hashCode => Object.hash(
        controllerId,
        alias,
        lastConnectedAt,
        connectionStatus,
        retryPolicy,
        deviceCapabilities,
        notes,
      );
}
