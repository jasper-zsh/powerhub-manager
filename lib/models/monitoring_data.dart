import 'dart:typed_data';

class MonitoringData {
  final int inputVoltage; // mV
  final int powerZoneTemp; // 0.01°C
  final int controlZoneTemp; // 0.01°C
  final List<double> channelCurrents; // variable channels, A each
  final SystemStatusFlags statusFlags;

  const MonitoringData({
    required this.inputVoltage,
    required this.powerZoneTemp,
    required this.controlZoneTemp,
    required this.channelCurrents,
    required this.statusFlags,
  });

  factory MonitoringData.fromBytes(List<int> data) {
    if (data.length != 32) {
      throw ArgumentError('Monitoring data must be exactly 32 bytes, got ${data.length}');
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(data));

    // Parse fixed structure
    final inputVoltage = byteData.getUint16(0);        // bytes 0-1: Input voltage (mV)
    final powerZoneTemp = byteData.getInt16(2);         // bytes 2-3: Power zone temp (0.01°C)
    final controlZoneTemp = byteData.getInt16(4);        // bytes 4-5: Control zone temp (0.01°C)

    // Parse 6 channel currents (bytes 6-29: 6 x 4-byte floats)
    final channelCurrents = <double>[];
    for (int i = 0; i < 6; i++) {
      final offset = 6 + (i * 4);
      channelCurrents.add(byteData.getFloat32(offset));
    }

    // Parse status flags (byte 30)
    final statusFlags = SystemStatusFlags.fromByte(data[30]);

    return MonitoringData(
      inputVoltage: inputVoltage,
      powerZoneTemp: powerZoneTemp,
      controlZoneTemp: controlZoneTemp,
      channelCurrents: channelCurrents,
      statusFlags: statusFlags,
    );
  }

  double get inputVoltageVolts => inputVoltage / 1000.0;

  double? get powerZoneTempCelsius {
    if (powerZoneTemp == 0x8000) return null; // Invalid data marker
    return powerZoneTemp / 100.0;
  }

  double? get controlZoneTempCelsius {
    if (controlZoneTemp == 0x8000) return null; // Invalid data marker
    return controlZoneTemp / 100.0;
  }

  bool get hasValidTempData =>
      powerZoneTemp != 0x8000 && controlZoneTemp != 0x8000;

  double getChannelCurrent(int channelIndex) {
    if (channelIndex < 0 || channelIndex >= channelCurrents.length) {
      return 0.0;
    }
    return channelCurrents[channelIndex];
  }

  /// Calculates total current by summing all valid per-channel currents
  /// Returns 0.0 if no valid channel currents are available
  double get calculatedTotalCurrent {
    return channelCurrents
        .where((current) => current >= 0 && !current.isNaN && !current.isInfinite)
        .fold(0.0, (sum, current) => sum + current);
  }

  /// Returns the number of channels with valid current readings
  int get validChannelCount {
    return channelCurrents
        .where((current) => current >= 0 && !current.isNaN && !current.isInfinite)
        .length;
  }

  bool get isThermalProtectionActive => statusFlags.thermalProtectionActive;
  bool get isTemperatureDataValid => statusFlags.temperatureDataValid;
  bool get isCurrentDataValid => statusFlags.currentDataValid;

  @override
  String toString() {
    return 'MonitoringData('
        'voltage: ${inputVoltageVolts.toStringAsFixed(2)}V, '
        'powerTemp: ${powerZoneTempCelsius?.toStringAsFixed(2) ?? "invalid"}°C, '
        'controlTemp: ${controlZoneTempCelsius?.toStringAsFixed(2) ?? "invalid"}°C, '
        'channelCurrents: ${channelCurrents.map((c) => c.toStringAsFixed(3)).join("A, ")}A, '
        'status: $statusFlags)';
  }
}

class SystemStatusFlags {
  final bool thermalProtectionActive;
  final bool temperatureDataValid;
  final bool currentDataValid;
  final bool calibrationStatus;
  final bool peripheralPowerOn;

  const SystemStatusFlags({
    required this.thermalProtectionActive,
    required this.temperatureDataValid,
    required this.currentDataValid,
    required this.calibrationStatus,
    required this.peripheralPowerOn,
  });

  factory SystemStatusFlags.fromByte(int byte) {
    return SystemStatusFlags(
      thermalProtectionActive: (byte & 0x01) != 0,
      temperatureDataValid: (byte & 0x02) != 0,
      currentDataValid: (byte & 0x04) != 0,
      calibrationStatus: (byte & 0x08) != 0,
      peripheralPowerOn: (byte & 0x10) != 0,
    );
  }

  int toByte() {
    int result = 0;
    if (thermalProtectionActive) result |= 0x01;
    if (temperatureDataValid) result |= 0x02;
    if (currentDataValid) result |= 0x04;
    if (calibrationStatus) result |= 0x08;
    if (peripheralPowerOn) result |= 0x10;
    return result;
  }

  @override
  String toString() {
    final flags = <String>[];
    if (thermalProtectionActive) flags.add('thermalProtection');
    if (temperatureDataValid) flags.add('tempValid');
    if (currentDataValid) flags.add('currentValid');
    if (calibrationStatus) flags.add('calibrated');
    if (peripheralPowerOn) flags.add('peripheralPower');

    return 'SystemStatusFlags(${flags.join(", ")})';
  }
}