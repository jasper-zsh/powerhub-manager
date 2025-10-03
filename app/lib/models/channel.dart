class Channel {
  final int id;
  int value;
  String name;
  bool isEnabled;

  Channel({
    required this.id,
    this.value = 0,
    this.name = '',
    this.isEnabled = true,
  })  : assert(id >= 0 && id <= 3, 'Channel ID must be between 0 and 3'),
        assert(value >= 0 && value <= 255, 'Channel value must be between 0 and 255');

  // Validation methods
  bool get isValidId => id >= 0 && id <= 3;
  bool get isValidValue => value >= 0 && value <= 255;
  bool get isValidName => name.isNotEmpty;

  // Update the channel value
  void updateValue(int newValue) {
    if (newValue >= 0 && newValue <= 255) {
      value = newValue;
    } else {
      throw ArgumentError('Value must be between 0 and 255');
    }
  }

  // Enable/disable the channel
  void toggleEnabled() {
    isEnabled = !isEnabled;
  }

  @override
  String toString() {
    return 'Channel(id: $id, value: $value, name: $name, isEnabled: $isEnabled)';
  }
}