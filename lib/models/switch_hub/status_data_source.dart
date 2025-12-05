import 'status_data_type.dart';

/// Represents a data source for status information from a remote device
/// This model tracks connection state and cached data for efficient status updates
class StatusDataSource {
  const StatusDataSource({
    required this.macAddress,
    this.deviceName,
    this.connectionStatus = ConnectionStatus.disconnected,
    this.lastUpdate,
    this.cachedData = const {},
    this.retryCount = 0,
  });

  final String macAddress;
  final String? deviceName;
  final ConnectionStatus connectionStatus;
  final DateTime? lastUpdate;
  final Map<String, String> cachedData;
  final int retryCount;

  /// Creates a copy with updated values
  StatusDataSource copyWith({
    String? macAddress,
    String? deviceName,
    ConnectionStatus? connectionStatus,
    DateTime? lastUpdate,
    Map<String, String>? cachedData,
    int? retryCount,
  }) {
    return StatusDataSource(
      macAddress: macAddress ?? this.macAddress,
      deviceName: deviceName ?? this.deviceName,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      cachedData: cachedData ?? this.cachedData,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  /// Updates the cached data for a specific data type and parameters
  StatusDataSource updateCachedData({
    required StatusDataType dataType,
    required String? params,
    required String value,
  }) {
    final key = _getDataKey(dataType, params);
    final newCachedData = Map<String, String>.from(cachedData);
    newCachedData[key] = value;

    return copyWith(
      cachedData: newCachedData,
      lastUpdate: DateTime.now(),
      retryCount: 0, // Reset retry count on successful data update
    );
  }

  /// Gets cached data for a specific data type and parameters
  String? getCachedData({
    required StatusDataType dataType,
    required String? params,
  }) {
    final key = _getDataKey(dataType, params);
    return cachedData[key];
  }

  /// Updates connection status
  StatusDataSource updateConnectionStatus(ConnectionStatus status) {
    return copyWith(
      connectionStatus: status,
      lastUpdate: DateTime.now(),
      retryCount: status == ConnectionStatus.connected ? 0 : retryCount,
    );
  }

  /// Increments retry count for connection failures
  StatusDataSource incrementRetryCount() {
    return copyWith(retryCount: retryCount + 1);
  }

  /// Checks if the data is stale based on age
  bool get isDataStale {
    if (lastUpdate == null) return true;
    final age = DateTime.now().difference(lastUpdate!);
    // Consider data stale if older than 10 seconds for remote devices
    return age.inSeconds > 10;
  }

  /// Gets a display name for this data source
  String get displayName {
    if (deviceName != null && deviceName!.isNotEmpty) {
      return deviceName!;
    }
    return macAddress;
  }

  /// Creates a cache key for the given data type and parameters
  static String _getDataKey(StatusDataType dataType, String? params) {
    if (params != null && params.isNotEmpty) {
      return '${dataType.jsonValue}_$params';
    }
    return dataType.jsonValue;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusDataSource &&
        other.macAddress == macAddress &&
        other.deviceName == deviceName &&
        other.connectionStatus == connectionStatus &&
        other.lastUpdate == lastUpdate &&
        other.retryCount == retryCount;
  }

  @override
  int get hashCode {
    return Object.hash(macAddress, deviceName, connectionStatus, lastUpdate, retryCount);
  }

  @override
  String toString() {
    return 'StatusDataSource(macAddress: $macAddress, deviceName: $deviceName, connectionStatus: $connectionStatus, retryCount: $retryCount)';
  }
}

/// Connection status for remote devices
enum ConnectionStatus {
  /// Device is disconnected and no connection attempt in progress
  disconnected,

  /// Currently attempting to connect to the device
  connecting,

  /// Successfully connected and can receive data
  connected,

  /// Connection attempt failed
  connectionFailed,

  /// Connection was established but is now lost
  connectionLost,
}