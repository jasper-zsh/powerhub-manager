import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/channel.dart';
import 'package:app/models/preset.dart';
import 'package:app/controllers/device_control_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';

class ChannelControlScreen extends ConsumerWidget {
  const ChannelControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceControlState = ref.watch(deviceControlControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);
    
    final isConnected = connectionState.isConnected;
    final channels = deviceControlState.value?.channels ?? [];
    final presets = deviceControlState.value?.presets ?? [];
    final isBusy = deviceControlState.value?.isBusy ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Channel Control'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _showSavePresetDialog(ref, channels),
              tooltip: 'Save preset',
            ),
        ],
      ),
      body: _buildBody(channels, presets, isConnected, isBusy),
    );
  }

  Widget _buildBody(List<Channel> channels, List<Preset> presets, bool isConnected, bool isBusy) {
    if (!isConnected) {
      return _buildDisconnectedView();
    }

    if (isBusy) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Processing command...'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshChannels(ref),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChannelControls(channels),
            const SizedBox(height: 24),
            _buildPresetSection(presets),
            const SizedBox(height: 24),
            _buildCommandSection(channels),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No device connected',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(connectionSessionControllerProvider.notifier).connectToSavedDevice(),
            child: const Text('Connect to Saved Device'),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelControls(List<Channel> channels) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.tune,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Channel Controls',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _resetAllChannels(ref),
                  child: const Text('Reset All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...channels.asMap().entries.map((entry) {
              final channelIndex = entry.key;
              final channel = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: ChannelControlCard(
                  channel: channel,
                  channelIndex: channelIndex,
                  onValueChanged: (value) => _updateChannelValue(ref, channelIndex, value),
                  onSetCommand: () => _executeSetCommand(ref, channelIndex, channel.currentValue),
                  onFadeCommand: (duration) => _executeFadeCommand(ref, channelIndex, channel.currentValue, duration),
                  onBlinkCommand: (count, onDuration, offDuration) => _executeBlinkCommand(ref, channelIndex, count, onDuration, offDuration),
                  onStrobeCommand: (frequency) => _executeStrobeCommand(ref, channelIndex, frequency),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetSection(List<Preset> presets) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.bookmark,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Presets',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _showManagePresetsDialog(ref, presets),
                  child: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (presets.isEmpty)
              const Center(
                child: Text('No presets saved yet'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) {
                  return ActionChip(
                    label: Text(preset.name),
                    onPressed: () => _applyPreset(ref, preset),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandSection(List<Channel> channels) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flash_on,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Quick Commands',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _executeAllOn(ref, channels),
                  icon: const Icon(Icons.power),
                  label: const Text('All On'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _executeAllOff(ref, channels),
                  icon: const Icon(Icons.power_off),
                  label: const Text('All Off'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _executeAllBlink(ref, channels),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('All Blink'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _executeAllFade(ref, channels),
                  icon: const Icon(Icons.fade),
                  label: const Text('All Fade'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateChannelValue(WidgetRef ref, int channelIndex, int value) {
    ref.read(deviceControlControllerProvider.notifier).updateChannelValue(channelIndex, value);
  }

  void _executeSetCommand(WidgetRef ref, int channelIndex, int value) {
    ref.read(deviceControlControllerProvider.notifier).executeSetCommand(channelIndex, value);
  }

  void _executeFadeCommand(WidgetRef ref, int channelIndex, int value, int duration) {
    ref.read(deviceControlControllerProvider.notifier).executeFadeCommand(channelIndex, value, duration);
  }

  void _executeBlinkCommand(WidgetRef ref, int channelIndex, int count, int onDuration, int offDuration) {
    ref.read(deviceControlControllerProvider.notifier).executeBlinkCommand(channelIndex, count, onDuration, offDuration);
  }

  void _executeStrobeCommand(WidgetRef ref, int channelIndex, int frequency) {
    ref.read(deviceControlControllerProvider.notifier).executeStrobeCommand(channelIndex, frequency);
  }

  void _resetAllChannels(WidgetRef ref) {
    ref.read(deviceControlControllerProvider.notifier).resetAllChannels();
  }

  void _applyPreset(WidgetRef ref, Preset preset) {
    ref.read(deviceControlControllerProvider.notifier).applyPreset(preset);
  }

  void _executeAllOn(WidgetRef ref, List<Channel> channels) {
    for (int i = 0; i < channels.length; i++) {
      ref.read(deviceControlControllerProvider.notifier).executeSetCommand(i, 255);
    }
  }

  void _executeAllOff(WidgetRef ref, List<Channel> channels) {
    for (int i = 0; i < channels.length; i++) {
      ref.read(deviceControlControllerProvider.notifier).executeSetCommand(i, 0);
    }
  }

  void _executeAllBlink(WidgetRef ref, List<Channel> channels) {
    for (int i = 0; i < channels.length; i++) {
      ref.read(deviceControlControllerProvider.notifier).executeBlinkCommand(i, 3, 500, 500);
    }
  }

  void _executeAllFade(WidgetRef ref, List<Channel> channels) {
    for (int i = 0; i < channels.length; i++) {
      ref.read(deviceControlControllerProvider.notifier).executeFadeCommand(i, 255, 2000);
    }
  }

  void _showSavePresetDialog(WidgetRef ref, List<Channel> channels) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Preset'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Preset name',
            hintText: 'Enter preset name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(deviceControlControllerProvider.notifier).savePreset(name, channels);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Preset "$name" saved')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showManagePresetsDialog(WidgetRef ref, List<Preset> presets) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Presets'),
        content: SizedBox(
          width: double.maxFinite,
          child: presets.isEmpty
              ? const Center(child: Text('No presets available'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: presets.length,
                  itemBuilder: (context, index) {
                    final preset = presets[index];
                    return ListTile(
                      title: Text(preset.name),
                      subtitle: Text('${preset.channels.length} channels'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deletePreset(ref, preset),
                      ),
                      onTap: () => _applyPreset(ref, preset),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _deletePreset(WidgetRef ref, Preset preset) {
    ref.read(deviceControlControllerProvider.notifier).deletePreset(preset.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Preset "${preset.name}" deleted')),
    );
  }

  Future<void> _refreshChannels(WidgetRef ref) {
    return ref.read(deviceControlControllerProvider.notifier).refreshChannels();
  }
}

class ChannelControlCard extends ConsumerWidget {
  final Channel channel;
  final int channelIndex;
  final Function(int) onValueChanged;
  final VoidCallback onSetCommand;
  final Function(int) onFadeCommand;
  final Function(int, int, int) onBlinkCommand;
  final Function(int) onStrobeCommand;

  const ChannelControlCard({
    super.key,
    required this.channel,
    required this.channelIndex,
    required this.onValueChanged,
    required this.onSetCommand,
    required this.onFadeCommand,
    required this.onBlinkCommand,
    required this.onStrobeCommand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Channel ${channelIndex + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            Text(
              '${channel.currentValue}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: channel.currentValue.toDouble(),
          min: 0,
          max: 255,
          divisions: 255,
          onChanged: (value) => onValueChanged(value.round()),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: onSetCommand,
              child: const Text('Set'),
            ),
            ElevatedButton(
              onPressed: () => _showFadeDialog(context),
              child: const Text('Fade'),
            ),
            ElevatedButton(
              onPressed: () => _showBlinkDialog(context),
              child: const Text('Blink'),
            ),
            ElevatedButton(
              onPressed: () => _showStrobeDialog(context),
              child: const Text('Strobe'),
            ),
          ],
        ),
      ],
    );
  }

  void _showFadeDialog(BuildContext context) {
    final controller = TextEditingController(text: '2000');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fade Command'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Duration (ms)',
            hintText: 'Enter fade duration in milliseconds',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final duration = int.tryParse(controller.text);
              if (duration != null && duration > 0) {
                onFadeCommand(duration);
                Navigator.pop(context);
              }
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  void _showBlinkDialog(BuildContext context) {
    final countController = TextEditingController(text: '3');
    final onController = TextEditingController(text: '500');
    final offController = TextEditingController(text: '500');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Blink Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Count',
                hintText: 'Number of blinks',
              ),
            ),
            TextField(
              controller: onController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'On duration (ms)',
                hintText: 'On duration in milliseconds',
              ),
            ),
            TextField(
              controller: offController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Off duration (ms)',
                hintText: 'Off duration in milliseconds',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final count = int.tryParse(countController.text);
              final onDuration = int.tryParse(onController.text);
              final offDuration = int.tryParse(offController.text);
              if (count != null && onDuration != null && offDuration != null &&
                  count > 0 && onDuration > 0 && offDuration > 0) {
                onBlinkCommand(count, onDuration, offDuration);
                Navigator.pop(context);
              }
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }

  void _showStrobeDialog(BuildContext context) {
    final controller = TextEditingController(text: '10');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Strobe Command'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Frequency (Hz)',
            hintText: 'Enter strobe frequency in Hz',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final frequency = int.tryParse(controller.text);
              if (frequency != null && frequency > 0) {
                onStrobeCommand(frequency);
                Navigator.pop(context);
              }
            },
            child: const Text('Execute'),
          ),
        ],
      ),
    );
  }
}
