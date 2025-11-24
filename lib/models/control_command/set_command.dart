import 'control_command.dart';

class SetCommand extends ControlCommand {
  final int value;

  SetCommand({
    required int channel,
    required this.value,
  })  : assert(value >= 0 && value <= 255, 'Value must be between 0 and 255'),
        super(
          channel: channel,
          rawData: [0x00, channel, value],
        );

  // Validation methods
  bool get isValidValue => value >= 0 && value <= 255;

  @override
  List<int> toBytes() {
    return [0x00, channel, value];
  }

  @override
  String getType() {
    return 'SetCommand';
  }

  @override
  String toString() {
    return 'SetCommand(channel: $channel, value: $value)';
  }
}