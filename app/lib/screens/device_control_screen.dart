import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/saved_controller.dart';
import 'package:app/controllers/device_control_controller.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/monitoring_controller.dart';

class DeviceControlScreen extends ConsumerWidget {
  const DeviceControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceControlState = ref.watch(deviceControlControllerProvider);
    final savedControllersState = ref.watch(savedControllerControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final monitoringState = ref.watch(monitoringControllerProvider);

    final saved = savedControllersState.controllers;
    final selectedControllerId = deviceControlState.selectedControllerId;
    final isConnected = connectionState.isConnected;

    // Get selected saved controller
    final selectedSavedController = selectedControllerId != null
        ? saved.firstWhere(
            (controller) => controller.controllerId == selectedControllerId,
            orElse: () => SavedController(controllerId: selectedControllerId, alias: 'Unknown'),
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(deviceControlControllerProvider.notifier).selectController(
                deviceControlState.selectedControllerId ?? ''
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Controller selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Selected Controller',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        if (saved.isNotEmpty)
                          DropdownButton<String>(
                            value: saved.any((controller) => controller.controllerId == selectedControllerId)
                                ? selectedControllerId
                                : null,
                            hint: Text(selectedSavedController?.alias ?? 'Select Device'),
                            icon: const Icon(Icons.bluetooth),
                            items: [
                              // Only show deselect option if we have a selected device that exists in saved list
                              if (selectedControllerId != null &&
                                  saved.any((controller) => controller.controllerId == selectedControllerId))
                                const DropdownMenuItem<String>(
                                  value: '',
                                  child: Row(
                                    children: [
                                      Icon(Icons.bluetooth_disabled, size: 16, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      const Text('Deselect'),
                                    ],
                                  ),
                                ),
                              ...saved.map((controller) => DropdownMenuItem<String>(
                                value: controller.controllerId,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bluetooth,
                                      size: 16,
                                      color: selectedControllerId == controller.controllerId
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(controller.alias),
                                    ),
                                    if (selectedControllerId == controller.controllerId)
                                      const Icon(Icons.check_circle, size: 16, color: Colors.blue),
                                  ],
                                ),
                                )),
                            ],
                            onChanged: (controllerId) {
                              if (controllerId != null) {
                                ref.read(deviceControlControllerProvider.notifier)
                                    .selectController(controllerId);
                              }
                            },
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () {
                              // Navigate to saved controllers screen to add devices
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please add devices from the Saved Controllers screen first'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Device'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${isConnected ? "Connected" : "Disconnected"}',
                      style: TextStyle(
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    if (selectedSavedController != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${selectedSavedController.controllerId}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Channel controls if connected
            if (isConnected && deviceControlState.channels.isNotEmpty) ...[
              // Quick actions
              _buildQuickActions(context, ref, deviceControlState),

              const SizedBox(height: 16),

              Card(
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
                      // Display channel controls
                      ...List.generate(deviceControlState.channels.length, (index) {
                        final channel = deviceControlState.channels[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildChannelControl(
                            context,
                            ref,
                            channel,
                            deviceControlState,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // Telemetry data
              if (isConnected) ...[
                const SizedBox(height: 16),
                _buildTelemetrySection(context, monitoringState, monitoringState),
              ],
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bluetooth_disabled,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        selectedSavedController?.alias ?? 'No device connected',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('Connect a device to control channels'),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Error message
            if (deviceControlState.errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          deviceControlState.errorMessage ?? 'Unknown error',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          ref.read(deviceControlControllerProvider.notifier).clearError();
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetrySection(BuildContext context, AsyncValue monitoringState, AsyncValue monitoringState2) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Telemetry Data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Telemetry status
            if (monitoringState is AsyncData && monitoringState.value != null)
              _buildTelemetryChips(context, monitoringState.value)
            else if (monitoringState is AsyncLoading)
              const CircularProgressIndicator()
            else if (monitoringState is AsyncError)
              Text('Error: ${monitoringState.error}', style: TextStyle(color: Colors.red)),

            const SizedBox(height: 16),

            // Monitoring status
            if (monitoringState2 is AsyncData && monitoringState2.value != null)
              _buildMonitoringChips(context, monitoringState2.value)
            else if (monitoringState2 is AsyncLoading)
              const CircularProgressIndicator()
            else if (monitoringState2 is AsyncError)
              Text('Error: ${monitoringState2.error}', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryChips(BuildContext context, monitoringData) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text('Voltage: ${monitoringData.inputVoltageVolts.toStringAsFixed(1)}V'),
          backgroundColor: Colors.blue.shade100,
        ),
        if (monitoringData.controlZoneTempCelsius != null)
          Chip(
            label: Text('Temp: ${monitoringData.controlZoneTempCelsius!.toStringAsFixed(1)}°C'),
            backgroundColor: Colors.orange.shade100,
          ),
      ],
    );
  }

  Widget _buildChannelControl(
    BuildContext context,
    WidgetRef ref,
    channel,
    DeviceControlState deviceControlState,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                if (deviceControlState.isChannelBusy(channel.id))
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
            const SizedBox(height: 16),

            // Value slider with percentage
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Value: ${channel.value}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${(channel.value / 255 * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: channel.value.toDouble(),
                  min: 0,
                  max: 255,
                  divisions: 255,
                  activeColor: _getSliderColor(channel.value),
                  onChanged: deviceControlState.isChannelBusy(channel.id)
                      ? null
                      : (value) {
                    ref.read(deviceControlControllerProvider.notifier)
                        .handleSetValue(channel.id, value.round());
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Quick action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: deviceControlState.isChannelBusy(channel.id)
                        ? null
                        : () {
                      ref.read(deviceControlControllerProvider.notifier)
                          .handleSetValue(channel.id, 0);
                    },
                    icon: const Icon(Icons.power_off, size: 16),
                    label: const Text('OFF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: deviceControlState.isChannelBusy(channel.id)
                        ? null
                        : () {
                      ref.read(deviceControlControllerProvider.notifier)
                          .handleSetValue(channel.id, 128);
                    },
                    icon: const Icon(Icons.brightness_medium, size: 16),
                    label: const Text('50%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: deviceControlState.isChannelBusy(channel.id)
                        ? null
                        : () {
                      ref.read(deviceControlControllerProvider.notifier)
                          .handleSetValue(channel.id, 255);
                    },
                    icon: const Icon(Icons.brightness_high, size: 16),
                    label: const Text('MAX'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSliderColor(int value) {
    if (value == 0) return Colors.grey;
    if (value <= 85) return Colors.green;
    if (value <= 170) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMonitoringChips(BuildContext context, monitoringData) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          label: Text('Current: ${monitoringData.totalInputCurrent.toStringAsFixed(2)}A'),
          backgroundColor: Colors.green.shade100,
        ),
        if (monitoringData.isThermalProtectionActive)
          Chip(
            label: const Text('Thermal Protection Active'),
            backgroundColor: Colors.red.shade100,
          ),
      ],
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    WidgetRef ref,
    DeviceControlState deviceControlState,
  ) {
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
                  onPressed: () => _setAllChannels(context, ref, 0),
                  icon: const Icon(Icons.power_off, size: 16),
                  label: const Text('All Off'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(context, ref, 255),
                  icon: const Icon(Icons.brightness_high, size: 16),
                  label: const Text('All On'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(context, ref, 128),
                  icon: const Icon(Icons.brightness_medium, size: 16),
                  label: const Text('All 50%'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _randomizeChannels(context, ref),
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: const Text('Random'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _setAllChannels(BuildContext context, WidgetRef ref, int value) {
    final deviceControlState = ref.read(deviceControlControllerProvider);
    for (final channel in deviceControlState.channels) {
      if (!deviceControlState.isChannelBusy(channel.id)) {
        ref.read(deviceControlControllerProvider.notifier)
            .handleSetValue(channel.id, value);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All channels set to ${value} (${(value / 255 * 100).toStringAsFixed(1)}%)'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _randomizeChannels(BuildContext context, WidgetRef ref) {
    final deviceControlState = ref.read(deviceControlControllerProvider);
    for (final channel in deviceControlState.channels) {
      if (!deviceControlState.isChannelBusy(channel.id)) {
        final randomValue = (DateTime.now().millisecond + channel.id) % 256;
        ref.read(deviceControlControllerProvider.notifier)
            .handleSetValue(channel.id, randomValue);
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Channels randomized'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}