/// Voltage threshold configuration for SwitchHub power management
/// Format: [sleep_voltage_threshold(2B)][wake_voltage_threshold(2B)]
class SwitchHubVoltageThresholds {
  final int sleepVoltageMv;
  final int wakeVoltageMv;

  const SwitchHubVoltageThresholds({
    required this.sleepVoltageMv,
    required this.wakeVoltageMv,
  });

  /// Default voltage thresholds
  static const SwitchHubVoltageThresholds defaultThresholds = SwitchHubVoltageThresholds(
    sleepVoltageMv: 3300,
    wakeVoltageMv: 3600,
  );

  /// Parse 4-byte voltage threshold data
  factory SwitchHubVoltageThresholds.fromBytes(List<int> data) {
    if (data.length < 4) {
      throw ArgumentError('Voltage threshold data must be at least 4 bytes');
    }

    final sleepVoltage = data[0] + (data[1] << 8);
    final wakeVoltage = data[2] + (data[3] << 8);

    return SwitchHubVoltageThresholds(
      sleepVoltageMv: sleepVoltage,
      wakeVoltageMv: wakeVoltage,
    );
  }

  /// Convert to 4-byte format
  List<int> toBytes() {
    return [
      sleepVoltageMv & 0xFF,
      (sleepVoltageMv >> 8) & 0xFF,
      wakeVoltageMv & 0xFF,
      (wakeVoltageMv >> 8) & 0xFF,
    ];
  }

  /// Validate voltage thresholds
  bool isValid() {
    return wakeVoltageMv > sleepVoltageMv;
  }

  /// Get validation error message if invalid
  String? getValidationError() {
    if (wakeVoltageMv <= sleepVoltageMv) {
      return 'Wake voltage must be higher than sleep voltage';
    }

    return null;
  }

  /// Create copy with updated values
  SwitchHubVoltageThresholds copyWith({
    int? sleepVoltageMv,
    int? wakeVoltageMv,
  }) {
    return SwitchHubVoltageThresholds(
      sleepVoltageMv: sleepVoltageMv ?? this.sleepVoltageMv,
      wakeVoltageMv: wakeVoltageMv ?? this.wakeVoltageMv,
    );
  }

  @override
  String toString() {
    return 'SwitchHubVoltageThresholds('
        'sleep: ${sleepVoltageMv}mV, '
        'wake: ${wakeVoltageMv}mV'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SwitchHubVoltageThresholds &&
        other.sleepVoltageMv == sleepVoltageMv &&
        other.wakeVoltageMv == wakeVoltageMv;
  }

  @override
  int get hashCode => Object.hash(sleepVoltageMv, wakeVoltageMv);

  /// Convert to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'sleepVoltageMv': sleepVoltageMv,
      'wakeVoltageMv': wakeVoltageMv,
      'isValid': isValid(),
      'validationError': getValidationError(),
    };
  }

  /// Create from JSON
  factory SwitchHubVoltageThresholds.fromJson(Map<String, dynamic> json) {
    return SwitchHubVoltageThresholds(
      sleepVoltageMv: json['sleepVoltageMv'] as int,
      wakeVoltageMv: json['wakeVoltageMv'] as int,
    );
  }

}