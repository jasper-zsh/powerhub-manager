import 'control_command/control_command.dart';

class Preset {
  final int id;
  final String name;
  int commandCount;
  List<ControlCommand> commands;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isFavorite;

  Preset({
    required this.id,
    required this.name,
    List<ControlCommand>? commands,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
  })  : assert(id >= 1 && id <= 255, 'Preset ID must be between 1 and 255'),
        commands = commands ?? [],
        commandCount = commands?.length ?? 0,
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Validation methods
  bool get isValidId => id >= 1 && id <= 255;
  bool get isValidName => name.isNotEmpty;
  bool get hasCommands => commands.isNotEmpty;
  bool get isValidCommandCount => commandCount == commands.length;

  // Add a command to the preset
  void addCommand(ControlCommand command) {
    commands.add(command);
    commandCount = commands.length;
    updatedAt = DateTime.now();
  }

  // Remove a command from the preset
  void removeCommand(ControlCommand command) {
    commands.remove(command);
    commandCount = commands.length;
    updatedAt = DateTime.now();
  }

  // Toggle favorite status
  void toggleFavorite() {
    isFavorite = !isFavorite;
    updatedAt = DateTime.now();
  }

  @override
  String toString() {
    return 'Preset(id: $id, name: $name, commandCount: $commandCount, isFavorite: $isFavorite)';
  }
}