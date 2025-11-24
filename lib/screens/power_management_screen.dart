import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/power_management.dart';
import 'package:app/controllers/device_control_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';

class PowerManagementScreen extends ConsumerWidget {
  const PowerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceControlState = ref.watch(deviceControlControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);
    
    final isConnected = connectionState.isConnected;
    final powerState = deviceControlState.value?.powerManagement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Management'),
      ),
      body: _buildBody(powerState, isConnected),
    );
  }

  Widget _buildBody(PowerManagementState? powerState, bool isConnected) {
    if (!isConnected) {
      return _buildDisconnectedView();
    }

    if (powerState == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refreshPowerState(ref),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPowerStatusCard(powerState),
            const SizedBox(height: 16),
            _buildPowerControlCard(powerState),
            const SizedBox(height: 16),
            _buildBatteryCard(powerState),
            const SizedBox(height: 16),
            _buildPowerSettingsCard(powerState),
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
            Icons.power_off,
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

  Widget _buildPowerStatusCard(PowerManagementState powerState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.power,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Power Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'System Power',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Switch(
                  value: powerState.systemPowerOn,
                  onChanged: (value) => _toggleSystemPower(ref, value),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Peripheral Power',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Switch(
                  value: powerState.peripheralPowerOn,
                  onChanged: (value) => _togglePeripheralPower(ref, value),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Deep Sleep Mode',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Switch(
                  value: powerState.deepSleepMode,
                  onChanged: (value) => _toggleDeepSleep(ref, value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerControlCard(PowerManagementState powerState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings_power,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Power Control',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Restart System'),
              subtitle: const Text('Restart the device system'),
              leading: const Icon(Icons.restart_alt),
              onTap: () => _showRestartDialog(ref),
            ),
            ListTile(
              title: const Text('Shutdown System'),
              subtitle: const Text('Shutdown the device system'),
              leading: const Icon(Icons.power_settings_new),
              onTap: () => _showShutdownDialog(ref),
            ),
            ListTile(
              title: const Text('Reset to Factory'),
              subtitle: const Text('Reset device to factory settings'),
              leading: const Icon(Icons.restore),
              onTap: () => _showFactoryResetDialog(ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard(PowerManagementState powerState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.battery_full,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Battery Information',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Battery Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${powerState.batteryLevel}%',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                        color: _getBatteryColor(powerState.batteryLevel),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: powerState.batteryLevel / 100.0,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getBatteryColor(powerState.batteryLevel),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Charging Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  powerState.isCharging ? 'Charging' : 'Not Charging',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                        color: powerState.isCharging ? Colors.green : Colors.grey,
                      ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Battery Voltage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${powerState.batteryVoltage.toStringAsFixed(2)}V',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(
                        color: _getBatteryVoltageColor(powerState.batteryVoltage),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerSettingsCard(PowerManagementState powerState) {
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
                  color: Colors.purple,
                ),
                const SizedBox(width: 8),
                Text(
                  'Power Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Auto Sleep Timeout'),
              subtitle: Text('${powerState.autoSleepTimeoutMinutes} minutes'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showAutoSleepTimeoutDialog(powerState.autoSleepTimeoutMinutes),
            ),
            ListTile(
              title: const Text('Low Power Threshold'),
              subtitle: Text('${powerState.lowPowerThreshold}%'),
              trailing: const Icon(Icons.edit),
              onTap: () => _showLowPowerThresholdDialog(powerState.lowPowerThreshold),
            ),
            SwitchListTile(
              title: const Text('Power Saving Mode'),
              subtitle: const Text('Enable power saving features'),
              value: powerState.powerSavingMode,
              onChanged: (value) => _togglePowerSavingMode(ref, value),
            ),
            SwitchListTile(
              title: const Text('Wake on Motion'),
              subtitle: const Text('Wake device on motion detection'),
              value: powerState.wakeOnMotion,
              onChanged: (value) => _toggleWakeOnMotion(ref, value),
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level <= 20) return Colors.red;
    if (level <= 50) return Colors.orange;
    return Colors.green;
  }

  Color _getBatteryVoltageColor(double voltage) {
    if (voltage < 3.0) return Colors.red;
    if (voltage < 3.5) return Colors.orange;
    return Colors.green;
  }

  void _toggleSystemPower(WidgetRef ref, bool value) {
    ref.read(deviceControlControllerProvider.notifier).toggleSystemPower(value);
  }

  void _togglePeripheralPower(WidgetRef ref, bool value) {
    ref.read(deviceControlControllerProvider.notifier).togglePeripheralPower(value);
  }

  void _toggleDeepSleep(WidgetRef ref, bool value) {
    ref.read(deviceControlControllerProvider.notifier).toggleDeepSleep(value);
  }

  void _togglePowerSavingMode(WidgetRef ref, bool value) {
    ref.read(deviceControlControllerProvider.notifier).togglePowerSavingMode(value);
  }

  void _toggleWakeOnMotion(WidgetRef ref, bool value) {
    ref.read(deviceControlControllerProvider.notifier).toggleWakeOnMotion(value);
  }

  void _showRestartDialog(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart System'),
        content: const Text('Are you sure you want to restart the device system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(deviceControlControllerProvider.notifier).restartSystem();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('System restart initiated')),
              );
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _showShutdownDialog(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shutdown System'),
        content: const Text('Are you sure you want to shutdown the device system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(deviceControlControllerProvider.notifier).shutdownSystem();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('System shutdown initiated')),
              );
            },
            child: const Text('Shutdown'),
          ),
        ],
      ),
    );
  }

  void _showFactoryResetDialog(WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text('Are you sure you want to reset the device to factory settings? This will erase all saved data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(deviceControlControllerProvider.notifier).factoryReset();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Factory reset initiated')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showAutoSleepTimeoutDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Sleep Timeout'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Timeout (minutes)',
            hintText: 'Enter timeout in minutes',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                ref.read(deviceControlControllerProvider.notifier).setAutoSleepTimeout(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLowPowerThresholdDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Low Power Threshold'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Threshold (%)',
            hintText: 'Enter threshold percentage',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0 && value <= 100) {
                ref.read(deviceControlControllerProvider.notifier).setLowPowerThreshold(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshPowerState(WidgetRef ref) {
    return ref.read(deviceControlControllerProvider.notifier).refreshPowerState();
  }
}