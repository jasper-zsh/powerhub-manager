import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:app/controllers/device_control_controller.dart';
import 'package:app/repositories/device_repository.dart';
import 'package:app/models/channel.dart';
import 'package:app/models/preset.dart';
import 'package:app/models/control_command/set_command.dart';
import 'package:app/models/control_command/fade_command.dart';
import 'package:app/models/control_command/blink_command.dart';
import 'package:app/models/control_command/strobe_command.dart';

import 'device_control_controller_test.mocks.dart';

@GenerateMocks([DeviceRepository])
void main() {
  group('DeviceControlController', () {
    late ProviderContainer container;
    late MockDeviceRepository mockDeviceRepository;

    setUp(() {
      mockDeviceRepository = MockDeviceRepository();
      
      container = ProviderContainer(
        overrides: [
          deviceRepositoryProvider.overrideWithValue(mockDeviceRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have empty channels and presets', () {
      final state = container.read(deviceControlControllerProvider);
      
      expect(state.channels, isEmpty);
      expect(state.presets, isEmpty);
      expect(state.isBusy, false);
    });

    test('updateChannelValue should update channel value', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.updateChannelValue(0, 128);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.channels[0].currentValue, 128);
    });

    test('executeSetCommand should add command to queue', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.executeSetCommand(0, 255);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.isBusy, true);
      expect(state.commandQueue.length, 1);
      expect(state.commandQueue.first, isA<SetCommand>());
    });

    test('executeFadeCommand should add fade command to queue', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.executeFadeCommand(0, 255, 2000);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.isBusy, true);
      expect(state.commandQueue.length, 1);
      expect(state.commandQueue.first, isA<FadeCommand>());
    });

    test('executeBlinkCommand should add blink command to queue', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.executeBlinkCommand(0, 3, 500, 500);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.isBusy, true);
      expect(state.commandQueue.length, 1);
      expect(state.commandQueue.first, isA<BlinkCommand>());
    });

    test('executeStrobeCommand should add strobe command to queue', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.executeStrobeCommand(0, 10);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.isBusy, true);
      expect(state.commandQueue.length, 1);
      expect(state.commandQueue.first, isA<StrobeCommand>());
    });

    test('savePreset should add preset to list', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      final channels = [
        Channel(index: 0, currentValue: 128),
        Channel(index: 1, currentValue: 64),
      ];
      
      controller.savePreset('Test Preset', channels);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.presets.length, 1);
      expect(state.presets.first.name, 'Test Preset');
      expect(state.presets.first.channels, channels);
    });

    test('applyPreset should update channel values', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      final channels = [
        Channel(index: 0, currentValue: 128),
        Channel(index: 1, currentValue: 64),
      ];
      final preset = Preset(
        id: 'test-preset',
        name: 'Test Preset',
        channels: channels,
        createdAt: DateTime.now(),
      );
      
      controller.applyPreset(preset);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.channels[0].currentValue, 128);
      expect(state.channels[1].currentValue, 64);
    });

    test('deletePreset should remove preset from list', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      final channels = [
        Channel(index: 0, currentValue: 128),
        Channel(index: 1, currentValue: 64),
      ];
      
      controller.savePreset('Test Preset', channels);
      final state = container.read(deviceControlControllerProvider);
      final presetId = state.presets.first.id;
      
      controller.deletePreset(presetId);
      
      final updatedState = container.read(deviceControlControllerProvider);
      expect(updatedState.presets, isEmpty);
    });

    test('resetAllChannels should set all channels to 0', () {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      // Set some initial values
      controller.updateChannelValue(0, 128);
      controller.updateChannelValue(1, 64);
      
      controller.resetAllChannels();
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.channels[0].currentValue, 0);
      expect(state.channels[1].currentValue, 0);
    });

    test('refreshChannels should fetch latest channel data', () async {
      final controller = container.read(deviceControlControllerProvider.notifier);
      final channels = [
        Channel(index: 0, currentValue: 128),
        Channel(index: 1, currentValue: 64),
      ];
      
      when(mockDeviceRepository.getChannelSnapshot())
          .thenAnswer((_) async => channels);
      
      await controller.refreshChannels();
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.channels, channels);
      verify(mockDeviceRepository.getChannelSnapshot()).called(1);
    });

    test('command execution should update busy state', () async {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.executeSetCommand(0, 255);
      
      // Should be busy while command is in queue
      let state = container.read(deviceControlControllerProvider);
      expect(state.isBusy, true);
      
      // Simulate command completion
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should not be busy after command execution
      state = container.read(deviceControlControllerProvider);
      expect(state.isBusy, false);
    });

    test('multiple commands should be executed in order', () async {
      final controller = container.read(deviceControlControllerProvider.notifier);
      
      controller.executeSetCommand(0, 128);
      controller.executeSetCommand(1, 64);
      controller.executeSetCommand(2, 255);
      
      final state = container.read(deviceControlControllerProvider);
      expect(state.commandQueue.length, 3);
      expect(state.commandQueue[0], isA<SetCommand>());
      expect(state.commandQueue[1], isA<SetCommand>());
      expect(state.commandQueue[2], isA<SetCommand>());
    });
  });
}