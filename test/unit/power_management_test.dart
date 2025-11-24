import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/power_management.dart';

void main() {
  group('PowerManagementConfig', () {
    test('should create from bytes correctly', () {
      final bytes = [0x17, 0x70, 0x15, 0x7C, 0x30, 0xD4, 0x31, 0x38];

      final config = PowerManagementConfig.fromBytes(bytes);

      expect(config.highTempCelsius, 60.0);
      expect(config.recoveryCelsius, 55.0);
      expect(config.sleepVoltage, 12.5);
      expect(config.wakeVoltage, 12.6);
    });

    test('should convert to bytes correctly', () {
      final config = PowerManagementConfig(
        highTempThreshold: 6000, // 60.00°C
        recoveryThreshold: 5500, // 55.00°C
        sleepVoltageThreshold: 12500, // 12.5V
        wakeVoltageThreshold: 12600, // 12.6V
      );

      final bytes = config.toBytes();

      expect(bytes, [0x17, 0x70, 0x15, 0x7C, 0x30, 0xD4, 0x31, 0x38]);
    });

    test('should handle invalid data length', () {
      expect(
        () => PowerManagementConfig.fromBytes([0x01, 0x02]),
        throwsArgumentError,
      );
    });
  });

  group('PowerCommand', () {
    test('should create set sleep threshold command', () {
      final command = PowerCommand(
        type: PowerCommandType.setSleepThreshold,
        parameter: 12500, // 12.5V
      );

      final bytes = command.toBytes();

      expect(bytes, [0x01, 0x30, 0xD4]);
    });

    test('should create force sleep command', () {
      final command = PowerCommand(
        type: PowerCommandType.forceSleep,
      );

      final bytes = command.toBytes();

      expect(bytes, [0x03, 0x00, 0x00]);
    });

    test('should create set high temp threshold command', () {
      final command = PowerCommand(
        type: PowerCommandType.setHighTempThreshold,
        parameter: 6000, // 60.00°C
      );

      final bytes = command.toBytes();

      expect(bytes, [0x11, 0x17, 0x70]);
    });

    test('should parse from bytes correctly', () {
      final bytes = [0x01, 0x30, 0xD4];

      final command = PowerCommand.fromBytes(bytes);

      expect(command.type, PowerCommandType.setSleepThreshold);
      expect(command.parameter, 12500);
    });

    test('should handle invalid data length', () {
      expect(
        () => PowerCommand.fromBytes([0x01]),
        throwsArgumentError,
      );
    });
  });

  group('PowerCommandType', () {
    test('should find type by value', () {
      expect(
        PowerCommandType.fromValue(0x01),
        PowerCommandType.setSleepThreshold,
      );
      expect(
        PowerCommandType.fromValue(0x03),
        PowerCommandType.forceSleep,
      );
      expect(
        PowerCommandType.fromValue(0x11),
        PowerCommandType.setHighTempThreshold,
      );
    });

    test('should throw for invalid value', () {
      expect(
        () => PowerCommandType.fromValue(0xFF),
        throwsArgumentError,
      );
    });
  });
}