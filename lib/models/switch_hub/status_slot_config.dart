import 'status_data_type.dart';

/// Status slot configuration for SwitchHub UI display as defined in SWITCHHUB_BLE.md
/// Each switch can have up to two status slots displaying real-time data from various sources.
class StatusSlot {
  const StatusSlot({
    required this.sourceMac,
    required this.dataType,
    this.params,
    this.label,
    this.value,
  });

  /// MAC address of the data source device, or "LOCAL" for the SwitchHub itself
  final String sourceMac;

  /// Type of data to display (VOLTAGE, CHANNEL_CURRENT, TOTAL_CURRENT, TEMPERATURE)
  final StatusDataType dataType;

  /// Parameters specific to the data type (channel number for current, zone for temperature)
  final String? params;

  /// Display label for the status slot
  final String? label;

  /// Current value (for display purposes, not stored in config)
  final String? value;

  /// Creates a copy with updated values
  StatusSlot copyWith({
    String? sourceMac,
    StatusDataType? dataType,
    String? params,
    String? label,
    String? value,
  }) {
    return StatusSlot(
      sourceMac: sourceMac ?? this.sourceMac,
      dataType: dataType ?? this.dataType,
      params: params ?? this.params,
      label: label ?? this.label,
      value: value ?? this.value,
    );
  }

  /// Creates a copy with updated value (for real-time display)
  StatusSlot withValue(String? newValue) {
    return copyWith(value: newValue);
  }

  /// Validates the status slot configuration
  String? validate() {
    // Validate source MAC format
    if (sourceMac != 'LOCAL' && !RegExp(r'^([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}$').hasMatch(sourceMac)) {
      return 'Invalid source MAC address format';
    }

    // Validate data type parameters
    final paramError = dataType.validateParameters(params);
    if (paramError != null) {
      return paramError;
    }

    return null;
  }

  /// Gets the display unit for this data type
  String get displayUnit => dataType.displayUnit;

  /// Gets description of this status slot for debugging/logging
  String get description {
    final paramDesc = params != null ? '($params)' : '';
    return '$dataType$paramDesc from ${sourceMac == 'LOCAL' ? 'local device' : sourceMac}';
  }

  /// Checks if this status slot represents local data
  bool get isLocal => sourceMac == 'LOCAL';

  /// Checks if this status slot requires a remote connection
  bool get requiresRemoteConnection => !isLocal;

  /// Checks if this status slot represents a multi-channel current sum
  bool get isMultiChannelCurrent {
    return dataType == StatusDataType.channelCurrent &&
           params != null &&
           params!.contains(',');
  }

  /// Gets the channel list for multi-channel current configurations
  List<int>? get channelList {
    if (!isMultiChannelCurrent) return null;
    try {
      return StatusDataType.parseChannelList(params!);
    } catch (e) {
      return null;
    }
  }

  /// Gets a default label for multi-channel current configurations
  String get defaultLabel {
    if (!isMultiChannelCurrent) return '';
    final channels = channelList;
    if (channels == null || channels.isEmpty) return '';
    return 'Channels ${channels.join(',')} Current';
  }

  Map<String, dynamic> toJson() {
    return {
      'source_mac': sourceMac,
      'data_type': dataType.jsonValue,
      if (params != null) 'params': params,
      if (label != null) 'label': label,
      if (value != null) 'value': value,
    };
  }

  factory StatusSlot.fromJson(Map<String, dynamic> json) {
    return StatusSlot(
      sourceMac: json['source_mac'] as String,
      dataType: StatusDataType.fromJson(json['data_type'] as String)!,
      params: json['params'] as String?,
      label: json['label'] as String?,
      value: json['value'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StatusSlot &&
        other.sourceMac == sourceMac &&
        other.dataType == dataType &&
        other.params == params &&
        other.label == label &&
        other.value == value;
  }

  @override
  int get hashCode {
    return Object.hash(sourceMac, dataType, params, label, value);
  }

  @override
  String toString() {
    return 'StatusSlot(sourceMac: $sourceMac, dataType: $dataType, params: $params, label: $label, value: $value)';
  }
}