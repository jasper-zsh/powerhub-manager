import 'channel.dart';
import 'preset.dart';
import 'telemetry.dart';

class PWMController {
  final String id;
  final String name;
  final int rssi;
  bool isConnected;
  DateTime? connectionTime;
  List<Channel> channels;
  List<Preset> presets;
  TelemetryData? telemetry;

  PWMController({
    required this.id,
    required this.name,
    required this.rssi,
    this.isConnected = false,
    this.connectionTime,
    List<Channel>? channels,
    List<Preset>? presets,
    this.telemetry,
  })  : channels = channels ??
            List.generate(4, (index) => Channel(id: index, value: 0)),
        presets = presets ?? [];

  // Validation methods
  bool get isValidId => id.isNotEmpty;
  bool get isValidName => name.isNotEmpty;
  bool get isValidRssi => rssi >= -100 && rssi <= 0;
  bool get hasFourChannels => channels.length == 4;

  // Connect to the device
  void connect() {
    isConnected = true;
    connectionTime = DateTime.now();
  }

  // Disconnect from the device
  void disconnect() {
    isConnected = false;
    connectionTime = null;
    telemetry = null;
  }

  void updateTelemetry(TelemetryData data) {
    telemetry = data;
  }

  @override
  String toString() {
    return 'PWMController(id: $id, name: $name, rssi: $rssi, isConnected: $isConnected, telemetry: $telemetry)';
  }
}
