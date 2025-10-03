abstract class ControlCommand {
  final int channel;
  List<int> rawData;

  ControlCommand({
    required this.channel,
    required this.rawData,
  }) : assert(channel >= 0 && channel <= 3, 'Channel must be between 0 and 3');

  // Validation methods
  bool get isValidChannel => channel >= 0 && channel <= 3;
  bool get hasValidRawData => rawData.isNotEmpty;

  // Abstract methods that must be implemented by subclasses
  List<int> toBytes();
  String getType();

  @override
  String toString() {
    return 'ControlCommand(channel: $channel, rawData: $rawData)';
  }
}