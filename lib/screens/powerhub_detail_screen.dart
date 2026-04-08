import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/device_control_controller.dart';
import 'package:app/controllers/power_management_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/models/power_management.dart';

class PowerHubDetailScreen extends ConsumerStatefulWidget {
  final String controllerId;

  const PowerHubDetailScreen({super.key, required this.controllerId});

  @override
  ConsumerState<PowerHubDetailScreen> createState() =>
      _PowerHubDetailScreenState();
}

class _PowerHubDetailScreenState extends ConsumerState<PowerHubDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(deviceControlControllerProvider.notifier)
          .selectController(widget.controllerId);
      ref
          .read(powerManagementControllerProvider.notifier)
          .refreshConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final deviceState = ref.watch(deviceControlControllerProvider);
    final powerState = ref.watch(powerManagementControllerProvider);
    final monitoringState = ref.watch(monitoringControllerProvider);
    final isConnected = connectionState.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAlias()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isConnected)
              _buildDisconnectedView()
            else ...[
              // Device control error
              if (deviceState.errorMessage != null)
                _buildErrorCard(
                  deviceState.errorMessage!,
                  () => ref
                      .read(deviceControlControllerProvider.notifier)
                      .clearError(),
                ),

              // Power management error
              if (powerState.error != null) ...[
                if (deviceState.errorMessage != null)
                  const SizedBox(height: 12),
                _buildErrorCard(
                  powerState.error!,
                  () => ref
                      .read(powerManagementControllerProvider.notifier)
                      .clearError(),
                ),
              ],

              if (deviceState.errorMessage != null || powerState.error != null)
                const SizedBox(height: 16),

              // Quick actions
              if (deviceState.channels.isNotEmpty) ...[
                _buildQuickActions(deviceState),
                const SizedBox(height: 16),
              ],

              // Channel controls
              if (deviceState.channels.isNotEmpty) ...[
                _buildChannelControlsCard(deviceState),
                const SizedBox(height: 16),
              ],

              // Telemetry
              _buildTelemetrySection(monitoringState),
              const SizedBox(height: 16),

              // Power management
              _buildPowerManagementSection(powerState),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _getAlias() {
    final savedState = ref.read(savedControllerControllerProvider);
    try {
      final match = savedState.controllers.firstWhere(
        (c) => c.controllerId == widget.controllerId,
      );
      return match.alias;
    } catch (_) {
      return widget.controllerId;
    }
  }

  void _setAllChannels(int value) {
    final deviceState = ref.read(deviceControlControllerProvider);
    for (final channel in deviceState.channels) {
      if (!deviceState.isChannelBusy(channel.id)) {
        ref
            .read(deviceControlControllerProvider.notifier)
            .handleSetValue(channel.id, value);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'All channels set to $value (${(value / 255 * 100).toStringAsFixed(1)}%)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _randomizeChannels() {
    final rng = Random();
    final deviceState = ref.read(deviceControlControllerProvider);
    for (final channel in deviceState.channels) {
      if (!deviceState.isChannelBusy(channel.id)) {
        ref
            .read(deviceControlControllerProvider.notifier)
            .handleSetValue(channel.id, rng.nextInt(256));
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Channels randomized'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Color _getSliderColor(int value) {
    if (value == 0) return Colors.grey;
    if (value <= 85) return Colors.green;
    if (value <= 170) return Colors.orange;
    return Colors.red;
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------

  void _showVoltageDialog(
    String title,
    double currentValue,
    void Function(double) onSet,
  ) {
    final controller = TextEditingController(
      text: currentValue.toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Voltage (V)',
                hintText: '8.0 - 15.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid range: 8.0V - 15.0V',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= 8.0 && v <= 15.0) {
                onSet(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showTempDialog(
    String title,
    double currentValue,
    void Function(double) onSet,
  ) {
    final controller = TextEditingController(
      text: currentValue.toStringAsFixed(1),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Temperature (\u00B0C)',
                hintText: '0.0 - 150.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid range: 0.0\u00B0C - 150.0\u00B0C',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text);
              if (v != null && v >= 0.0 && v <= 150.0) {
                onSet(v);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    String title,
    String message,
    void Function() onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared card builders
  // ---------------------------------------------------------------------------

  Widget _buildErrorCard(String error, VoidCallback onDismiss) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(error, style: const TextStyle(color: Colors.red)),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _getAlias(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Device not connected',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Quick actions
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(DeviceControlState deviceState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(0),
                  icon: const Icon(Icons.power_off, size: 16),
                  label: const Text('\u5168\u90E8\u5173\u95ED'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(255),
                  icon: const Icon(Icons.brightness_high, size: 16),
                  label: const Text('\u5168\u90E8\u5F00\u542F'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(128),
                  icon: const Icon(Icons.brightness_medium, size: 16),
                  label: const Text('\u5168\u90E850%'),
                ),
                ElevatedButton.icon(
                  onPressed: _randomizeChannels,
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: const Text('\u968F\u673A'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Channel controls
  // ---------------------------------------------------------------------------

  Widget _buildChannelControlsCard(DeviceControlState deviceState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Channel Controls',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ...List.generate(deviceState.channels.length, (index) {
              final channel = deviceState.channels[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildSingleChannelControl(channel, deviceState),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleChannelControl(
    dynamic channel,
    DeviceControlState deviceState,
  ) {
    final isBusy = deviceState.isChannelBusy(channel.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.tune, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text(
              'Channel ${channel.id}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (isBusy)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                channel.value > 0 ? Icons.power : Icons.power_off,
                color: channel.value > 0 ? Colors.green : Colors.grey,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Value: ${channel.value}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${(channel.value / 255 * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        Slider(
          value: channel.value.toDouble(),
          min: 0,
          max: 255,
          divisions: 255,
          activeColor: _getSliderColor(channel.value),
          onChanged: isBusy
              ? null
              : (v) => ref
                  .read(deviceControlControllerProvider.notifier)
                  .handleSetValue(channel.id, v.round()),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => ref
                        .read(deviceControlControllerProvider.notifier)
                        .handleSetValue(channel.id, 0),
                icon: const Icon(Icons.power_off, size: 16),
                label: const Text('OFF'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => ref
                        .read(deviceControlControllerProvider.notifier)
                        .handleSetValue(channel.id, 128),
                icon: const Icon(Icons.brightness_medium, size: 16),
                label: const Text('50%'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isBusy
                    ? null
                    : () => ref
                        .read(deviceControlControllerProvider.notifier)
                        .handleSetValue(channel.id, 255),
                icon: const Icon(Icons.brightness_high, size: 16),
                label: const Text('MAX'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Telemetry
  // ---------------------------------------------------------------------------

  Widget _buildTelemetrySection(AsyncValue<dynamic> monitoringState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Telemetry',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (monitoringState is AsyncData && monitoringState.value != null)
              _buildTelemetryChips(monitoringState.value)
            else if (monitoringState is AsyncLoading)
              const Center(child: CircularProgressIndicator())
            else if (monitoringState is AsyncError)
              Text(
                'Error: ${monitoringState.error}',
                style: const TextStyle(color: Colors.red),
              )
            else
              const Text(
                'No telemetry data available',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryChips(dynamic data) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text('Voltage: ${data.inputVoltageVolts.toStringAsFixed(1)}V'),
          backgroundColor: Colors.blue.shade100,
        ),
        if (data.controlZoneTempCelsius != null)
          Chip(
            label: Text(
              'Temp: ${data.controlZoneTempCelsius!.toStringAsFixed(1)}\u00B0C',
            ),
            backgroundColor: Colors.orange.shade100,
          ),
        Chip(
          label: Text(
            'Total Current: ${data.calculatedTotalCurrent.toStringAsFixed(2)}A',
          ),
          backgroundColor: Colors.green.shade100,
        ),
        if (data.isThermalProtectionActive)
          Chip(
            label: const Text('Thermal Protection Active'),
            backgroundColor: Colors.red.shade100,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Power management section
  // ---------------------------------------------------------------------------

  Widget _buildPowerManagementSection(PowerManagementState powerState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (powerState.isLoading && powerState.config == null)
          const Center(child: CircularProgressIndicator())
        else if (powerState.config != null) ...[
          _buildVoltageThresholdsCard(powerState.config!),
          const SizedBox(height: 16),
          _buildTemperatureThresholdsCard(powerState.config!),
          const SizedBox(height: 16),
          _buildPowerControlCard(),
        ],
        if (powerState.isLoading && powerState.config != null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 16),
                    Text('Updating configuration...'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVoltageThresholdsCard(PowerManagementConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.electrical_services, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Voltage Thresholds',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Sleep Voltage'),
              subtitle: const Text(
                'Device sleeps when voltage drops below this level',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.sleepVoltage.toStringAsFixed(1)}V',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showVoltageDialog(
                      'Set Sleep Voltage',
                      config.sleepVoltage,
                      (v) => ref
                          .read(powerManagementControllerProvider.notifier)
                          .setSleepVoltageThreshold(v),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Wake Voltage'),
              subtitle: const Text(
                'Device wakes when voltage rises above this level',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.wakeVoltage.toStringAsFixed(1)}V',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showVoltageDialog(
                      'Set Wake Voltage',
                      config.wakeVoltage,
                      (v) => ref
                          .read(powerManagementControllerProvider.notifier)
                          .setWakeVoltageThreshold(v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureThresholdsCard(PowerManagementConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Temperature Thresholds',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('High Temperature Threshold'),
              subtitle: const Text(
                'Thermal protection activates above this temperature',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.highTempCelsius.toStringAsFixed(1)}\u00B0C',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showTempDialog(
                      'Set High Temperature Threshold',
                      config.highTempCelsius,
                      (v) => ref
                          .read(powerManagementControllerProvider.notifier)
                          .setHighTemperatureThreshold(v),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Recovery Temperature'),
              subtitle: const Text(
                'Thermal protection deactivates below this temperature',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.recoveryCelsius.toStringAsFixed(1)}\u00B0C',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showTempDialog(
                      'Set Recovery Temperature',
                      config.recoveryCelsius,
                      (v) => ref
                          .read(powerManagementControllerProvider.notifier)
                          .setRecoveryThreshold(v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerControlCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.power_settings_new, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Power Control',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showConfirmDialog(
                      'Force Sleep',
                      'Are you sure you want to force the device into sleep mode?',
                      () {
                        ref
                            .read(powerManagementControllerProvider.notifier)
                            .forceSleep();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Force sleep command sent'),
                          ),
                        );
                      },
                    ),
                    icon: const Icon(Icons.bedtime),
                    label: const Text('Force Sleep'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showConfirmDialog(
                      'Force Wake',
                      'Are you sure you want to force the device to wake from sleep mode?',
                      () {
                        ref
                            .read(powerManagementControllerProvider.notifier)
                            .forceWake();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Force wake command sent'),
                          ),
                        );
                      },
                    ),
                    icon: const Icon(Icons.wb_sunny),
                    label: const Text('Force Wake'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
