import 'control_command.dart';

class FadeCommand extends ControlCommand {
  final int targetValue;
  final int duration;

  FadeCommand({
    required int channel,
    required this.targetValue,
    required this.duration,
  })  : assert(targetValue >= 0 && targetValue <= 255, 'Target value must be between 0 and 255'),
        assert(duration >= 0 && duration <= 65535, 'Duration must be between 0 and 65535'),
        super(
          channel: channel,
          rawData: [
            0x01,
            channel,
            targetValue,
            (duration >> 8) & 0xFF, // Duration MSB
            duration & 0xFF, // Duration LSB
          ],
        );

  // Validation methods
  bool get isValidTargetValue => targetValue >= 0 && targetValue <= 255;
  bool get isValidDuration => duration >= 0 && duration <= 65535;

  @override
  List<int> toBytes() {
    return [
      0x01,
      channel,
      targetValue,
      (duration >> 8) & 0xFF, // Duration MSB
      duration & 0xFF, // Duration LSB
    ];
  }

  @override
  String getType() {
    return 'FadeCommand';
  }

  @override
  String toString() {
    return 'FadeCommand(channel: $channel, targetValue: $targetValue, duration: $duration)';
  }
}