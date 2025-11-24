import 'control_command.dart';

class BlinkCommand extends ControlCommand {
  final int period;

  BlinkCommand({
    required int channel,
    required this.period,
  })  : assert(period >= 0 && period <= 65535, 'Period must be between 0 and 65535'),
        super(
          channel: channel,
          rawData: [
            0x02,
            channel,
            (period >> 8) & 0xFF, // Period MSB
            period & 0xFF, // Period LSB
          ],
        );

  // Validation methods
  bool get isValidPeriod => period >= 0 && period <= 65535;

  @override
  List<int> toBytes() {
    return [
      0x02,
      channel,
      (period >> 8) & 0xFF, // Period MSB
      period & 0xFF, // Period LSB
    ];
  }

  @override
  String getType() {
    return 'BlinkCommand';
  }

  @override
  String toString() {
    return 'BlinkCommand(channel: $channel, period: $period)';
  }
}