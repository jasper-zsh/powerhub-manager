import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';

void main() {
  group('Dynamic Command Tests', () {
    group('FadeCommand Tests', () {
      test('creates fade command with required parameters', () {
        final command = FadeCommand(
          channel: 2,
          targetValue: 200,
          duration: 1500,
        );

        expect(command.channel, equals(2));
        expect(command.targetValue, equals(200));
        expect(command.duration, equals(1500));
      });

      test('creates fade command with minimum valid values', () {
        final command = FadeCommand(
          channel: 0,
          targetValue: 0,
          duration: 1,
        );

        expect(command.channel, equals(0));
        expect(command.targetValue, equals(0));
        expect(command.duration, equals(1));
      });

      test('creates fade command with maximum valid values', () {
        final command = FadeCommand(
          channel: 5,
          targetValue: 255,
          duration: 60000,
        );

        expect(command.channel, equals(5));
        expect(command.targetValue, equals(255));
        expect(command.duration, equals(60000));
      });

      test('encodes fade command to correct BLE packet format', () {
        final command = FadeCommand(
          channel: 2,
          targetValue: 200,
          duration: 1500, // 0x05DC in hex
        );

        final packet = command.toBytes();

        // Expected format: [0x01][channel][value][duration_high][duration_low]
        expect(packet, hasLength(5));
        expect(packet[0], equals(0x01)); // Fade command identifier
        expect(packet[1], equals(2)); // Channel
        expect(packet[2], equals(200)); // Target value
        expect(packet[3], equals(0x05)); // Duration high byte
        expect(packet[4], equals(0xDC)); // Duration low byte
      });

      test('encodes fade command with edge case duration', () {
        final command = FadeCommand(
          channel: 0,
          targetValue: 128,
          duration: 65535, // Maximum 16-bit value
        );

        final packet = command.toBytes();

        expect(packet, hasLength(5));
        expect(packet[0], equals(0x01));
        expect(packet[1], equals(0));
        expect(packet[2], equals(128));
        expect(packet[3], equals(0xFF)); // Duration high byte
        expect(packet[4], equals(0xFF)); // Duration low byte
      });
    });

    group('BlinkCommand Tests', () {
      test('creates blink command with required parameters', () {
        final command = BlinkCommand(
          channel: 1,
          period: 1000,
        );

        expect(command.channel, equals(1));
        expect(command.period, equals(1000));
      });

      test('creates blink command with minimum valid period', () {
        final command = BlinkCommand(
          channel: 0,
          period: 50,
        );

        expect(command.channel, equals(0));
        expect(command.period, equals(50));
      });

      test('creates blink command with maximum valid period', () {
        final command = BlinkCommand(
          channel: 5,
          period: 10000,
        );

        expect(command.channel, equals(5));
        expect(command.period, equals(10000));
      });

      test('encodes blink command to correct BLE packet format', () {
        final command = BlinkCommand(
          channel: 3,
          period: 1000, // 0x03E8 in hex
        );

        final packet = command.toBytes();

        // Expected format: [0x02][channel][period_high][period_low]
        expect(packet, hasLength(4));
        expect(packet[0], equals(0x02)); // Blink command identifier
        expect(packet[1], equals(3)); // Channel
        expect(packet[2], equals(0x03)); // Period high byte
        expect(packet[3], equals(0xE8)); // Period low byte
      });

      test('encodes blink command with edge case period', () {
        final command = BlinkCommand(
          channel: 5,
          period: 65535, // Maximum 16-bit value
        );

        final packet = command.toBytes();

        expect(packet, hasLength(4));
        expect(packet[0], equals(0x02));
        expect(packet[1], equals(5));
        expect(packet[2], equals(0xFF)); // Period high byte
        expect(packet[3], equals(0xFF)); // Period low byte
      });
    });

    group('StrobeCommand Tests', () {
      test('creates strobe command with required parameters', () {
        final command = StrobeCommand(
          channel: 3,
          flashCount: 5,
          totalDuration: 2000,
          pauseDuration: 300,
        );

        expect(command.channel, equals(3));
        expect(command.flashCount, equals(5));
        expect(command.totalDuration, equals(2000));
        expect(command.pauseDuration, equals(300));
      });

      test('creates strobe command with minimum valid values', () {
        final command = StrobeCommand(
          channel: 0,
          flashCount: 1,
          totalDuration: 10,
          pauseDuration: 1,
        );

        expect(command.channel, equals(0));
        expect(command.flashCount, equals(1));
        expect(command.totalDuration, equals(10));
        expect(command.pauseDuration, equals(1));
      });

      test('creates strobe command with maximum valid values', () {
        final command = StrobeCommand(
          channel: 5,
          flashCount: 255,
          totalDuration: 60000,
          pauseDuration: 59999,
        );

        expect(command.channel, equals(5));
        expect(command.flashCount, equals(255));
        expect(command.totalDuration, equals(60000));
        expect(command.pauseDuration, equals(59999));
      });

      test('encodes strobe command to correct BLE packet format', () {
        final command = StrobeCommand(
          channel: 2,
          flashCount: 5,
          totalDuration: 2000, // 0x07D0 in hex
          pauseDuration: 300, // 0x012C in hex
        );

        final packet = command.toBytes();

        // Expected format: [0x03][channel][count][total_time_high][total_time_low][pause_time_high][pause_time_low]
        expect(packet, hasLength(7));
        expect(packet[0], equals(0x03)); // Strobe command identifier
        expect(packet[1], equals(2)); // Channel
        expect(packet[2], equals(5)); // Flash count
        expect(packet[3], equals(0x07)); // Total duration high byte
        expect(packet[4], equals(0xD0)); // Total duration low byte
        expect(packet[5], equals(0x01)); // Pause duration high byte
        expect(packet[6], equals(0x2C)); // Pause duration low byte
      });

      test('encodes strobe command with edge case values', () {
        final command = StrobeCommand(
          channel: 5,
          flashCount: 255,
          totalDuration: 65535,
          pauseDuration: 65535,
        );

        final packet = command.toBytes();

        expect(packet, hasLength(7));
        expect(packet[0], equals(0x03));
        expect(packet[1], equals(5));
        expect(packet[2], equals(255));
        expect(packet[3], equals(0xFF)); // Total duration high byte
        expect(packet[4], equals(0xFF)); // Total duration low byte
        expect(packet[5], equals(0xFF)); // Pause duration high byte
        expect(packet[6], equals(0xFF)); // Pause duration low byte
      });
    });

    group('Command Validation', () {
      test('FadeCommand handles valid channel ranges', () {
        for (int channel = 0; channel <= 5; channel++) {
          final command = FadeCommand(
            channel: channel,
            targetValue: 128,
            duration: 1000,
          );

          expect(command.channel, equals(channel));
        }
      });

      test('BlinkCommand handles valid channel ranges', () {
        for (int channel = 0; channel <= 5; channel++) {
          final command = BlinkCommand(
            channel: channel,
            period: 1000,
          );

          expect(command.channel, equals(channel));
        }
      });

      test('StrobeCommand handles valid channel ranges', () {
        for (int channel = 0; channel <= 5; channel++) {
          final command = StrobeCommand(
            channel: channel,
            flashCount: 5,
            totalDuration: 1000,
            pauseDuration: 100,
          );

          expect(command.channel, equals(channel));
        }
      });

      test('FadeCommand handles valid target value ranges', () {
        for (int value = 0; value <= 255; value += 51) {
          final command = FadeCommand(
            channel: 2,
            targetValue: value,
            duration: 1000,
          );

          expect(command.targetValue, equals(value));
        }
      });

      test('Commands handle boundary duration values', () {
        final fadeMin = FadeCommand(channel: 2, targetValue: 128, duration: 1);
        final fadeMax = FadeCommand(channel: 2, targetValue: 128, duration: 65535);

        expect(fadeMin.duration, equals(1));
        expect(fadeMax.duration, equals(65535));

        final blinkMin = BlinkCommand(channel: 2, period: 1);
        final blinkMax = BlinkCommand(channel: 2, period: 65535);

        expect(blinkMin.period, equals(1));
        expect(blinkMax.period, equals(65535));
      });
    });

    group('Command Packet Integrity', () {
      test('FadeCommand produces consistent packets', () {
        final command1 = FadeCommand(channel: 2, targetValue: 200, duration: 1500);
        final command2 = FadeCommand(channel: 2, targetValue: 200, duration: 1500);

        final packet1 = command1.toBytes();
        final packet2 = command2.toBytes();

        expect(packet1, equals(packet2));
      });

      test('BlinkCommand produces consistent packets', () {
        final command1 = BlinkCommand(channel: 3, period: 1000);
        final command2 = BlinkCommand(channel: 3, period: 1000);

        final packet1 = command1.toBytes();
        final packet2 = command2.toBytes();

        expect(packet1, equals(packet2));
      });

      test('StrobeCommand produces consistent packets', () {
        final command1 = StrobeCommand(
          channel: 2,
          flashCount: 5,
          totalDuration: 2000,
          pauseDuration: 300,
        );
        final command2 = StrobeCommand(
          channel: 2,
          flashCount: 5,
          totalDuration: 2000,
          pauseDuration: 300,
        );

        final packet1 = command1.toBytes();
        final packet2 = command2.toBytes();

        expect(packet1, equals(packet2));
      });

      test('Different commands produce different packets', () {
        final fadeCommand = FadeCommand(channel: 2, targetValue: 200, duration: 1500);
        final blinkCommand = BlinkCommand(channel: 2, period: 1000);
        final strobeCommand = StrobeCommand(
          channel: 2,
          flashCount: 5,
          totalDuration: 2000,
          pauseDuration: 300,
        );

        final fadePacket = fadeCommand.toBytes();
        final blinkPacket = blinkCommand.toBytes();
        final strobePacket = strobeCommand.toBytes();

        expect(fadePacket, isNot(equals(blinkPacket)));
        expect(fadePacket, isNot(equals(strobePacket)));
        expect(blinkPacket, isNot(equals(strobePacket)));
      });
    });

    group('Performance Tests', () {
      test('commands create packets efficiently', () {
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          final command = FadeCommand(
            channel: 2,
            targetValue: 200,
            duration: 1500,
          );
          command.toBytes();
        }

        stopwatch.stop();

        // Should complete 1000 packet generations in reasonable time (<100ms)
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
      });

      test('packet generation is memory efficient', () {
        final packets = <List<int>>[];

        for (int i = 0; i < 100; i++) {
          final command = FadeCommand(
            channel: i % 6,
            targetValue: i % 256,
            duration: 1000 + i,
          );
          packets.add(command.toBytes());
        }

        expect(packets, hasLength(100));
        // Each packet should have consistent length
        for (final packet in packets) {
          expect(packet, hasLength(5));
        }
      });
    });
  });
}