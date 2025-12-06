/// Status data types supported by SwitchHub devices as defined in the BLE protocol
enum StatusDataType {
  /// Local device input voltage (mV)
  voltage,

  /// Specific channel current from PowerHub device (params: channel index or comma-separated channel list for sum)
  channelCurrent,

  /// Total current from PowerHub device (sum of all channels)
  totalCurrent,

  /// Temperature from PowerHub device (params: zone - "POWER" or "CONTROL")
  temperature;

  /// Get the string representation as used in JSON configuration
  String get jsonValue {
    switch (this) {
      case StatusDataType.voltage:
        return 'VOLTAGE';
      case StatusDataType.channelCurrent:
        return 'CHANNEL_CURRENT';
      case StatusDataType.totalCurrent:
        return 'TOTAL_CURRENT';
      case StatusDataType.temperature:
        return 'TEMPERATURE';
    }
  }

  /// Parse data type from JSON string value
  static StatusDataType? fromJson(String value) {
    switch (value.toUpperCase()) {
      case 'VOLTAGE':
        return StatusDataType.voltage;
      case 'CHANNEL_CURRENT':
        return StatusDataType.channelCurrent;
      case 'TOTAL_CURRENT':
        return StatusDataType.totalCurrent;
      case 'TEMPERATURE':
        return StatusDataType.temperature;
      default:
        return null;
    }
  }

  /// Get the display unit for this data type
  String get displayUnit {
    switch (this) {
      case StatusDataType.voltage:
        return 'V';
      case StatusDataType.channelCurrent:
      case StatusDataType.totalCurrent:
        return 'A';
      case StatusDataType.temperature:
        return '°C';
    }
  }

  /// Check if this data type requires parameters
  bool get requiresParameters {
    switch (this) {
      case StatusDataType.voltage:
      case StatusDataType.totalCurrent:
        return false;
      case StatusDataType.channelCurrent:
      case StatusDataType.temperature:
        return true;
    }
  }

  /// Parse comma-separated channel list from parameter string
  static List<int> parseChannelList(String params) {
    final channels = params
        .split(',')
        .map((s) => int.parse(s.trim()))
        .toList();
    return channels;
  }

  /// Validate parameters for this data type
  String? validateParameters(String? params) {
    if (!requiresParameters) {
      return params == null || params.isEmpty ? null : 'This data type does not accept parameters';
    }

    if (params == null || params.isEmpty) {
      return 'This data type requires parameters';
    }

    switch (this) {
      case StatusDataType.channelCurrent:
        try {
          final channels = parseChannelList(params);

          // Individual channel validation
          for (final channel in channels) {
            if (channel < 0 || channel > 15) {
              return 'Channel number $channel must be between 0 and 15';
            }
          }

          // Duplicate channel detection
          if (channels.length != channels.toSet().length) {
            return 'Duplicate channels not allowed in sum parameters';
          }

          // Maximum channels limit
          if (channels.length > 8) {
            return 'Maximum 8 channels allowed in sum parameters';
          }

          return null;
        } catch (e) {
          return 'Channel parameter format error: ${e.toString()}';
        }

      case StatusDataType.temperature:
        final zone = params.toUpperCase();
        if (zone != 'POWER' && zone != 'CONTROL') {
          return 'Temperature zone must be "POWER" or "CONTROL"';
        }
        return null;

      default:
        return null;
    }
  }

  /// Get description of required parameters
  String get parameterDescription {
    switch (this) {
      case StatusDataType.voltage:
        return 'No parameters required';
      case StatusDataType.channelCurrent:
        return 'Channel index or comma-separated list (e.g., "0", "1,2,3", max 8 channels)';
      case StatusDataType.totalCurrent:
        return 'No parameters required';
      case StatusDataType.temperature:
        return 'Temperature zone: "POWER" or "CONTROL"';
    }
  }
}