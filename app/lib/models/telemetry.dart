class TelemetryData {
  final int vinMillivolts;
  final int temperatureCentiDegrees;
  final int highThresholdCentiDegrees;
  final int recoverThresholdCentiDegrees;
  final int sleepThresholdMilliVolts;
  final int wakeThresholdMilliVolts;
  final int statusFlags;
  final int reservedByte;
  final int reservedWord;

  const TelemetryData({
    required this.vinMillivolts,
    required this.temperatureCentiDegrees,
    required this.highThresholdCentiDegrees,
    required this.recoverThresholdCentiDegrees,
    required this.sleepThresholdMilliVolts,
    required this.wakeThresholdMilliVolts,
    required this.statusFlags,
    this.reservedByte = 0,
    this.reservedWord = 0,
  });

  double get temperatureCelsius => temperatureCentiDegrees / 100.0;
  double get highThresholdCelsius => highThresholdCentiDegrees / 100.0;
  double get recoverThresholdCelsius => recoverThresholdCentiDegrees / 100.0;
  double get sleepThresholdVolts => sleepThresholdMilliVolts / 1000.0;
  double get wakeThresholdVolts => wakeThresholdMilliVolts / 1000.0;

  bool get isThermalProtectionActive => (statusFlags & 0x01) != 0;
  bool get isTemperatureValid => (statusFlags & 0x02) != 0;

  TelemetryData copyWith({
    int? vinMillivolts,
    int? temperatureCentiDegrees,
    int? highThresholdCentiDegrees,
    int? recoverThresholdCentiDegrees,
    int? sleepThresholdMilliVolts,
    int? wakeThresholdMilliVolts,
    int? statusFlags,
    int? reservedByte,
    int? reservedWord,
  }) {
    return TelemetryData(
      vinMillivolts: vinMillivolts ?? this.vinMillivolts,
      temperatureCentiDegrees:
          temperatureCentiDegrees ?? this.temperatureCentiDegrees,
      highThresholdCentiDegrees:
          highThresholdCentiDegrees ?? this.highThresholdCentiDegrees,
      recoverThresholdCentiDegrees:
          recoverThresholdCentiDegrees ?? this.recoverThresholdCentiDegrees,
      sleepThresholdMilliVolts:
          sleepThresholdMilliVolts ?? this.sleepThresholdMilliVolts,
      wakeThresholdMilliVolts:
          wakeThresholdMilliVolts ?? this.wakeThresholdMilliVolts,
      statusFlags: statusFlags ?? this.statusFlags,
      reservedByte: reservedByte ?? this.reservedByte,
      reservedWord: reservedWord ?? this.reservedWord,
    );
  }

  TelemetryData merge(TelemetryData update) {
    return TelemetryData(
      vinMillivolts: update.vinMillivolts,
      temperatureCentiDegrees: update.temperatureCentiDegrees,
      highThresholdCentiDegrees: update.highThresholdCentiDegrees,
      recoverThresholdCentiDegrees: update.recoverThresholdCentiDegrees,
      sleepThresholdMilliVolts: update.sleepThresholdMilliVolts,
      wakeThresholdMilliVolts: update.wakeThresholdMilliVolts,
      statusFlags: update.statusFlags != 0 ? update.statusFlags : statusFlags,
      reservedByte: update.reservedByte != 0
          ? update.reservedByte
          : reservedByte,
      reservedWord: update.reservedWord != 0
          ? update.reservedWord
          : reservedWord,
    );
  }

  static TelemetryData fromRead(List<int> bytes) {
    if (bytes.length != 16) {
      throw ArgumentError('Telemetry read payload must be 16 bytes');
    }

    return TelemetryData(
      vinMillivolts: _uint16(bytes[0], bytes[1]),
      temperatureCentiDegrees: _int16(bytes[2], bytes[3]),
      highThresholdCentiDegrees: _int16(bytes[4], bytes[5]),
      recoverThresholdCentiDegrees: _int16(bytes[6], bytes[7]),
      sleepThresholdMilliVolts: _uint16(bytes[8], bytes[9]),
      wakeThresholdMilliVolts: _uint16(bytes[10], bytes[11]),
      statusFlags: bytes[12],
      reservedByte: bytes[13],
      reservedWord: _uint16(bytes[14], bytes[15]),
    );
  }

  static TelemetryData fromNotification(
    List<int> bytes, {
    TelemetryData? previous,
  }) {
    if (bytes.length != 12) {
      throw ArgumentError('Telemetry notify payload must be 12 bytes');
    }

    final fallback =
        previous ??
        const TelemetryData(
          vinMillivolts: 0,
          temperatureCentiDegrees: 0,
          highThresholdCentiDegrees: 0,
          recoverThresholdCentiDegrees: 0,
          sleepThresholdMilliVolts: 0,
          wakeThresholdMilliVolts: 0,
          statusFlags: 0,
        );

    return fallback.copyWith(
      vinMillivolts: _uint16(bytes[0], bytes[1]),
      temperatureCentiDegrees: _int16(bytes[2], bytes[3]),
      highThresholdCentiDegrees: _int16(bytes[4], bytes[5]),
      recoverThresholdCentiDegrees: _int16(bytes[6], bytes[7]),
      sleepThresholdMilliVolts: _uint16(bytes[8], bytes[9]),
      wakeThresholdMilliVolts: _uint16(bytes[10], bytes[11]),
    );
  }

  static int _uint16(int msb, int lsb) => ((msb & 0xFF) << 8) | (lsb & 0xFF);

  static int _int16(int msb, int lsb) {
    int value = _uint16(msb, lsb);
    if (value & 0x8000 != 0) {
      value = value - 0x10000;
    }
    return value;
  }

  @override
  String toString() {
    return 'TelemetryData(vin=${vinMillivolts}mV, temp=${temperatureCentiDegrees}x0.01°C, high=${highThresholdCentiDegrees}x0.01°C, recover=${recoverThresholdCentiDegrees}x0.01°C, sleep=${sleepThresholdMilliVolts}mV, wake=${wakeThresholdMilliVolts}mV, flags=$statusFlags)';
  }
}
