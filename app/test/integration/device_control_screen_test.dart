import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app/models/channel.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/preset.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/providers/device_control_provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/screens/device_control_screen.dart';

PWMController _buildActiveDevice() {
  return PWMController(
    id: 'controller-1',
    name: 'Living Room',
    rssi: -45,
    isConnected: true,
    channels: List.generate(4, (index) => Channel(id: index, value: index * 40)),
    presets: [
      Preset(id: 1, name: 'Preset 1', commands: const []),
    ],
  );
}

SavedController _buildSavedController({
  required String id,
  required String alias,
  SavedControllerConnectionStatus status =
      SavedControllerConnectionStatus.disconnected,
}) {
  return SavedController(
    controllerId: id,
    alias: alias,
    connectionStatus: status,
  );
}

class _Callbacks {
  final List<(String controllerId, int channelId, int value)> channelUpdates = [];
  final List<(String controllerId, int presetId)> presetTriggers = [];
  final List<(String controllerId, int channelId, int targetValue, int duration)>
      fadeCommands = [];
  final List<(String controllerId, int channelId, int period)> blinkCommands = [];
  final List<
      (String controllerId, int channelId, int flashCount, int totalDuration, int pauseDuration)>
      strobeCommands = [];

  Future<void> onChannelUpdate(String controllerId, int channelId, int value) async {
    channelUpdates.add((controllerId, channelId, value));
  }

  Future<void> onPresetTrigger(String controllerId, int presetId) async {
    presetTriggers.add((controllerId, presetId));
  }

  Future<void> onFadeCommand(
    String controllerId,
    int channelId,
    int targetValue,
    int duration,
  ) async {
    fadeCommands.add((controllerId, channelId, targetValue, duration));
  }

  Future<void> onBlinkCommand(
    String controllerId,
    int channelId,
    int period,
  ) async {
    blinkCommands.add((controllerId, channelId, period));
  }

  Future<void> onStrobeCommand(
    String controllerId,
    int channelId,
    int flashCount,
    int totalDuration,
    int pauseDuration,
  ) async {
    strobeCommands.add((controllerId, channelId, flashCount, totalDuration, pauseDuration));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DeviceControlProvider provider;
  late _Callbacks callbacks;

  setUp(() {
    callbacks = _Callbacks();
    provider = DeviceControlProvider(
      onChannelUpdate: callbacks.onChannelUpdate,
      onPresetTrigger: callbacks.onPresetTrigger,
      onFadeCommand: callbacks.onFadeCommand,
      onBlinkCommand: callbacks.onBlinkCommand,
      onStrobeCommand: callbacks.onStrobeCommand,
      onEnsureDeviceReady: (_) async => null,
    );

    provider.syncFromAppState(
      [
        _buildSavedController(
          id: 'controller-1',
          alias: 'Living Room',
          status: SavedControllerConnectionStatus.connected,
        ),
        _buildSavedController(
          id: 'controller-2',
          alias: 'Workshop',
          status: SavedControllerConnectionStatus.disconnected,
        ),
      ],
      _buildActiveDevice(),
      [_buildActiveDevice()],
    );
  });

  Future<void> _pumpControlScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppStateProvider>(
            create: (_) => AppStateProvider(),
          ),
          ChangeNotifierProvider<DeviceControlProvider>.value(value: provider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DeviceControlScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('channel slider publishes update via callback', (tester) async {
    await _pumpControlScreen(tester);

    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(callbacks.channelUpdates, isNotEmpty);
    final update = callbacks.channelUpdates.last;
    expect(update.$1, equals('controller-1'));
  });

  testWidgets('selecting offline controller shows offline notice', (tester) async {
    await _pumpControlScreen(tester);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Workshop').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Controller is offline'), findsOneWidget);
  });

  testWidgets('triggering preset invokes callback', (tester) async {
    await _pumpControlScreen(tester);

    await provider.triggerPreset(1);
    await tester.pumpAndSettle();

    expect(callbacks.presetTriggers, isNotEmpty);
    final trigger = callbacks.presetTriggers.last;
    expect(trigger.$1, equals('controller-1'));
    expect(trigger.$2, equals(1));
  });
}
