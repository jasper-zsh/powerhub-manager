import 'control_command.dart';

class StrobeCommand extends ControlCommand {
  final int flashCount;
  final int totalDuration;
  final int pauseDuration;

  StrobeCommand({
    required int channel,
    required this.flashCount,
    required this.totalDuration,
    required this.pauseDuration,
  })  : assert(flashCount >= 0 && flashCount <= 255, 'Flash count must be between 0 and 255'),
        assert(totalDuration >= 0 && totalDuration <= 65535, 'Total duration must be between 0 and 65535'),
        assert(pauseDuration >= 0 && pauseDuration <= 65535, 'Pause duration must be between 0 and 65535'),
        super(
          channel: channel,
          rawData: [
            0x03,
            channel,
            flashCount,
            (totalDuration >> 8) & 0xFF, // Total duration MSB
            totalDuration & 0xFF, // Total duration LSB
            (pauseDuration >> 8) & 0xFF, // Pause duration MSB
            pauseDuration & 0xFF, // Pause duration LSB
          ],
        );

  // Validation methods
  bool get isValidFlashCount => flashCount >= 0 && flashCount <= 255;
  bool get isValidTotalDuration => totalDuration >= 0 && totalDuration <= 65535;
  bool get isValidPauseDuration => pauseDuration >= 0 && pauseDuration <= 65535;

  @override
  List<int> toBytes() {
    return [
      0x03,
      channel,
      flashCount,
      (totalDuration >> 8) & 0xFF, // Total duration MSB
      totalDuration & 0xFF, // Total duration LSB
      (pauseDuration >> 8) & 0xFF, // Pause duration MSB
      pauseDuration & 0xFF, // Pause duration LSB
    ];
  }

  @override
  String getType() {
    return 'StrobeCommand';
  }

  @override
  String toString() {
    return 'StrobeCommand(channel: $channel, flashCount: $flashCount, totalDuration: $totalDuration, pauseDuration: $pauseDuration)';
  }
}