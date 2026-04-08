import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/switch_hub/voltage_thresholds.dart';

void main() {
  group('SwitchHubVoltageThresholds', () {
    test('should create default thresholds correctly', () {
      const thresholds = SwitchHubVoltageThresholds.defaultThresholds;

      expect(thresholds.sleepVoltageMv, equals(3300));
      expect(thresholds.wakeVoltageMv, equals(3600));
      expect(thresholds.isValid(), isTrue);
    });

    test('should parse 4-byte threshold data correctly', () {
      // Test data: [sleep_lo, sleep_hi, wake_lo, wake_hi]
      // Sleep: 3300mV (0xE4, 0x0C), Wake: 3600mV (0x10, 0x0E)
      final data = [0xE4, 0x0C, 0x10, 0x0E];

      final thresholds = SwitchHubVoltageThresholds.fromBytes(data);

      expect(thresholds.sleepVoltageMv, equals(3300));
      expect(thresholds.wakeVoltageMv, equals(3600));
    });

    test('should convert to bytes and back correctly', () {
      const original = SwitchHubVoltageThresholds(
        sleepVoltageMv: 3400,
        wakeVoltageMv: 3800,
      );

      final bytes = original.toBytes();
      final reconstructed = SwitchHubVoltageThresholds.fromBytes(bytes);

      expect(reconstructed.sleepVoltageMv, equals(original.sleepVoltageMv));
      expect(reconstructed.wakeVoltageMv, equals(original.wakeVoltageMv));
    });

    test('should validate thresholds correctly', () {
      // Valid thresholds
      const validThresholds = SwitchHubVoltageThresholds(
        sleepVoltageMv: 3300,
        wakeVoltageMv: 3600,
      );
      expect(validThresholds.isValid(), isTrue);
      expect(validThresholds.getValidationError(), isNull);

      // Invalid: wake voltage not higher than sleep
      const invalidThresholds = SwitchHubVoltageThresholds(
        sleepVoltageMv: 3600,
        wakeVoltageMv: 3300,
      );
      expect(invalidThresholds.isValid(), isFalse);
      expect(invalidThresholds.getValidationError(), isNotNull);

      // Valid: no upper/lower limit enforcement, any values with wake > sleep are valid
      const lowThresholds = SwitchHubVoltageThresholds(
        sleepVoltageMv: 2000,
        wakeVoltageMv: 2500,
      );
      expect(lowThresholds.isValid(), isTrue);
      expect(lowThresholds.getValidationError(), isNull);

      const highThresholds = SwitchHubVoltageThresholds(
        sleepVoltageMv: 4500,
        wakeVoltageMv: 4600,
      );
      expect(highThresholds.isValid(), isTrue);
      expect(highThresholds.getValidationError(), isNull);
    });

    test('should create copy with updated values', () {
      const original = SwitchHubVoltageThresholds(
        sleepVoltageMv: 3300,
        wakeVoltageMv: 3600,
      );

      final updated = original.copyWith(
        sleepVoltageMv: 3400,
      );

      expect(updated.sleepVoltageMv, equals(3400));
      expect(updated.wakeVoltageMv, equals(3600)); // unchanged
    });

    test('should serialize to and from JSON correctly', () {
      const original = SwitchHubVoltageThresholds(
        sleepVoltageMv: 3450,
        wakeVoltageMv: 3750,
      );

      final json = original.toJson();
      final reconstructed = SwitchHubVoltageThresholds.fromJson(json);

      expect(reconstructed.sleepVoltageMv, equals(original.sleepVoltageMv));
      expect(reconstructed.wakeVoltageMv, equals(original.wakeVoltageMv));
    });

    test('should provide safe voltage utilities', () {
      // getSafeSleepVoltage and getSafeWakeVoltage removed - no more range clamping
    });

    test('should throw error for invalid data length', () {
      expect(() => SwitchHubVoltageThresholds.fromBytes([0x01, 0x02]), throwsArgumentError);
      expect(() => SwitchHubVoltageThresholds.fromBytes([]), throwsArgumentError);
    });
  });
}