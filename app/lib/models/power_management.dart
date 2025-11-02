class PowerManagementConfig {
  final int highTempThreshold; // 0.01°C units
  final int recoveryThreshold; // 0.01°C units
  final int sleepVoltageThreshold; // mV
  final int wakeVoltageThreshold; // mV

  const PowerManagementConfig({
    required this.highTempThreshold,
    required this.recoveryThreshold,
    required this.sleepVoltageThreshold,
    required this.wakeVoltageThreshold,
  });

  factory PowerManagementConfig.fromBytes(List<int> data) {
    if (data.length < 8) {
      throw ArgumentError('Power management data must be at least 8 bytes');
    }

    return PowerManagementConfig(
      highTempThreshold: (data[0] << 8) | data[1],
      recoveryThreshold: (data[2] << 8) | data[3],
      sleepVoltageThreshold: (data[4] << 8) | data[5],
      wakeVoltageThreshold: (data[6] << 8) | data[7],
    );
  }

  List<int> toBytes() {
    return [
      (highTempThreshold >> 8) & 0xFF,
      highTempThreshold & 0xFF,
      (recoveryThreshold >> 8) & 0xFF,
      recoveryThreshold & 0xFF,
      (sleepVoltageThreshold >> 8) & 0xFF,
      sleepVoltageThreshold & 0xFF,
      (wakeVoltageThreshold >> 8) & 0xFF,
      wakeVoltageThreshold & 0xFF,
    ];
  }

  double get highTempCelsius => highTempThreshold / 100.0;
  double get recoveryCelsius => recoveryThreshold / 100.0;
  double get sleepVoltage => sleepVoltageThreshold / 1000.0;
  double get wakeVoltage => wakeVoltageThreshold / 1000.0;

  @override
  String toString() {
    return 'PowerManagementConfig('
        'highTemp: ${highTempCelsius.toStringAsFixed(2)}°C, '
        'recovery: ${recoveryCelsius.toStringAsFixed(2)}°C, '
        'sleepVoltage: ${sleepVoltage.toStringAsFixed(2)}V, '
        'wakeVoltage: ${wakeVoltage.toStringAsFixed(2)}V)';
  }
}

class PowerCommand {
  final PowerCommandType type;
  final int? parameter;

  const PowerCommand({
    required this.type,
    this.parameter,
  });

  List<int> toBytes() {
    final commandByte = type.value;
    final param = parameter ?? 0;
    return [
      commandByte,
      (param >> 8) & 0xFF,
      param & 0xFF,
    ];
  }

  factory PowerCommand.fromBytes(List<int> data) {
    if (data.length < 3) {
      throw ArgumentError('Power command must be 3 bytes');
    }

    final type = PowerCommandType.fromValue(data[0]);
    final parameter = (data[1] << 8) | data[2];

    return PowerCommand(
      type: type,
      parameter: type.hasParameter ? parameter : null,
    );
  }

  @override
  String toString() {
    if (type.hasParameter) {
      return 'PowerCommand(type: $type, parameter: $parameter)';
    }
    return 'PowerCommand(type: $type)';
  }
}

enum PowerCommandType {
  setSleepThreshold(0x01, true),
  setWakeThreshold(0x02, true),
  forceSleep(0x03, false),
  forceWake(0x04, false),
  setHighTempThreshold(0x11, true),
  setRecoveryThreshold(0x12, true);

  const PowerCommandType(this.value, this.hasParameter);

  final int value;
  final bool hasParameter;

  static PowerCommandType fromValue(int value) {
    for (final type in PowerCommandType.values) {
      if (type.value == value) {
        return type;
      }
    }
    throw ArgumentError('Invalid power command type: $value');
  }
}