/// Status data types supported by SwitchHub devices as defined in the BLE protocol
enum StatusDataType {
  /// Local device input voltage (mV)
  voltage,

  /// Specific channel current from PowerHub device (params: channel index)
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
        final channel = int.tryParse(params);
        if (channel == null) {
          return 'Channel parameter must be a number';
        }
        if (channel < 0 || channel > 15) {
          return 'Channel number must be between 0 and 15';
        }
        return null;

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
        return 'Channel index (0-15)';
      case StatusDataType.totalCurrent:
        return 'No parameters required';
      case StatusDataType.temperature:
        return 'Temperature zone: "POWER" or "CONTROL"';
    }
  }
}