/// Real-time monitoring data from SwitchHub device
/// Format: [voltage(2B)][status_flags(1B)][reserved(1B)]
class SwitchHubMonitoringData {
  final int inputVoltageMv;
  final int statusFlags;
  final int reserved;

  const SwitchHubMonitoringData({
    required this.inputVoltageMv,
    required this.statusFlags,
    this.reserved = 0,
  });

  /// Parse 4-byte monitoring data packet
  factory SwitchHubMonitoringData.fromBytes(List<int> data) {
    if (data.length < 4) {
      throw ArgumentError('Monitoring data must be at least 4 bytes');
    }

    final voltage = (data[0] + (data[1] << 8));
    final flags = data[2];
    final reserved = data[3];

    return SwitchHubMonitoringData(
      inputVoltageMv: voltage,
      statusFlags: flags,
      reserved: reserved,
    );
  }

  /// Convert to 4-byte format
  List<int> toBytes() {
    return [
      inputVoltageMv & 0xFF,
      (inputVoltageMv >> 8) & 0xFF,
      statusFlags & 0xFF,
      reserved & 0xFF,
    ];
  }

  /// Check if temperature sensor is available (bit1=0 indicates no temperature)
  bool get hasTemperatureSensor => (statusFlags & 0x02) == 0;

  /// Get battery level percentage (approximate)
  double get batteryPercentage {
    // Approximate battery level based on voltage
    // 4.2V = 100%, 3.0V = 0%
    const minVoltage = 3000;
    const maxVoltage = 4200;
    final percentage = ((inputVoltageMv - minVoltage) / (maxVoltage - minVoltage)) * 100;
    return percentage.clamp(0.0, 100.0);
  }

  /// Check if voltage is critically low
  bool get isVoltageCritical => inputVoltageMv < 3200;

  /// Check if voltage is low
  bool get isVoltageLow => inputVoltageMv < 3400;

  /// Check if voltage is normal
  bool get isVoltageNormal => inputVoltageMv >= 3400 && inputVoltageMv <= 4100;

  /// Check if voltage is high
  bool get isVoltageHigh => inputVoltageMv > 4100;

  @override
  String toString() {
    return 'SwitchHubMonitoringData('
        'voltage: ${inputVoltageMv}mV (${batteryPercentage.toStringAsFixed(1)}%), '
        'flags: 0x${statusFlags.toRadixString(16).padLeft(2, '0')}, '
        'hasTemp: $hasTemperatureSensor'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SwitchHubMonitoringData &&
        other.inputVoltageMv == inputVoltageMv &&
        other.statusFlags == statusFlags &&
        other.reserved == reserved;
  }

  @override
  int get hashCode => Object.hash(inputVoltageMv, statusFlags, reserved);

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'inputVoltageMv': inputVoltageMv,
      'statusFlags': statusFlags,
      'reserved': reserved,
      'batteryPercentage': batteryPercentage,
      'hasTemperatureSensor': hasTemperatureSensor,
    };
  }

  /// Create from JSON
  factory SwitchHubMonitoringData.fromJson(Map<String, dynamic> json) {
    return SwitchHubMonitoringData(
      inputVoltageMv: json['inputVoltageMv'] as int,
      statusFlags: json['statusFlags'] as int,
      reserved: json['reserved'] as int? ?? 0,
    );
  }
}