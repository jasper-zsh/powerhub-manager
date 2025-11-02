import 'dart:typed_data';

class MonitoringData {
  final int inputVoltage; // mV
  final int powerZoneTemp; // 0.01°C
  final int controlZoneTemp; // 0.01°C
  final double totalInputCurrent; // A
  final List<double> channelCurrents; // 6 channels, A each
  final SystemStatusFlags statusFlags;

  const MonitoringData({
    required this.inputVoltage,
    required this.powerZoneTemp,
    required this.controlZoneTemp,
    required this.totalInputCurrent,
    required this.channelCurrents,
    required this.statusFlags,
  });

  factory MonitoringData.fromBytes(List<int> data) {
    if (data.length < 36) {
      throw ArgumentError('Monitoring data must be 36 bytes');
    }

    final byteData = ByteData.sublistView(Uint8List.fromList(data));

    final inputVoltage = byteData.getUint16(0);
    final powerZoneTemp = byteData.getInt16(2);
    final controlZoneTemp = byteData.getInt16(4);
    final totalInputCurrent = byteData.getFloat32(6);

    final channelCurrents = <double>[];
    for (int i = 0; i < 6; i++) {
      channelCurrents.add(byteData.getFloat32(10 + (i * 4)));
    }

    final statusFlags = SystemStatusFlags.fromByte(data[34]);

    return MonitoringData(
      inputVoltage: inputVoltage,
      powerZoneTemp: powerZoneTemp,
      controlZoneTemp: controlZoneTemp,
      totalInputCurrent: totalInputCurrent,
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

  @override
  String toString() {
    return 'MonitoringData('
        'voltage: ${inputVoltageVolts.toStringAsFixed(2)}V, '
        'powerTemp: ${powerZoneTempCelsius?.toStringAsFixed(2) ?? "invalid"}°C, '
        'controlTemp: ${controlZoneTempCelsius?.toStringAsFixed(2) ?? "invalid"}°C, '
        'totalCurrent: ${totalInputCurrent.toStringAsFixed(3)}A, '
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