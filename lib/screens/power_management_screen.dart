import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/power_management_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/models/power_management.dart';

class PowerManagementScreen extends ConsumerStatefulWidget {
  const PowerManagementScreen({super.key});

  @override
  ConsumerState<PowerManagementScreen> createState() => _PowerManagementScreenState();
}

class _PowerManagementScreenState extends ConsumerState<PowerManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load configuration when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshConfig();
      }
    });
  }

  Future<void> _refreshConfig() async {
    await ref.read(powerManagementControllerProvider.notifier).refreshConfig();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final powerState = ref.watch(powerManagementControllerProvider);

    final isConnected = connectionState.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isConnected ? _refreshConfig : null,
          ),
        ],
      ),
      body: _buildBody(powerState, isConnected),
    );
  }

  Widget _buildBody(powerState, bool isConnected) {
    if (!isConnected) {
      return _buildDisconnectedView();
    }

    if (powerState.isLoading && powerState.config == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshConfig,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error display
            if (powerState.error != null) ...[
              _buildErrorCard(powerState.error!),
              const SizedBox(height: 16),
            ],

            // Configuration display
            if (powerState.config != null) ...[
              _buildConfigurationCard(powerState.config!),
              const SizedBox(height: 16),
              _buildVoltageThresholdsCard(powerState.config!),
              const SizedBox(height: 16),
              _buildTemperatureThresholdsCard(powerState.config!),
              const SizedBox(height: 16),
              _buildPowerCommandsCard(),
            ],

            // Loading indicator for updates
            if (powerState.isLoading) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
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
            ],
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
          Icon(
            Icons.power_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No device connected',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Connect to a PowerHub device to manage power settings',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(powerManagementControllerProvider.notifier).clearError();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationCard(PowerManagementConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.settings,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Power Management Configuration',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Current power management settings from your PowerHub device:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoltageThresholdsCard(PowerManagementConfig config) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.electrical_services,
                  color: Colors.orange,
                ),
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
              subtitle: Text('Device will sleep when voltage drops below this level'),
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
                    onPressed: () => _showSleepVoltageDialog(config.sleepVoltage),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Wake Voltage'),
              subtitle: Text('Device will wake when voltage rises above this level'),
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
                    onPressed: () => _showWakeVoltageDialog(config.wakeVoltage),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.thermostat,
                  color: Colors.red,
                ),
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
              subtitle: Text('Thermal protection activates above this temperature'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.highTempCelsius.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showHighTempDialog(config.highTempCelsius),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              title: const Text('Recovery Temperature'),
              subtitle: Text('Thermal protection deactivates below this temperature'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${config.recoveryCelsius.toStringAsFixed(1)}°C',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showRecoveryTempDialog(config.recoveryCelsius),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerCommandsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.power_settings_new,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Power Control Commands',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Manual power control commands for your PowerHub device:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showForceSleepDialog,
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
                    onPressed: _showForceWakeDialog,
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

  void _showSleepVoltageDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Sleep Voltage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Device will sleep when voltage drops below this level'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Sleep Voltage (V)',
                hintText: 'Enter voltage between 8.0 and 15.0',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 8.0 && value <= 15.0) {
                ref.read(powerManagementControllerProvider.notifier)
                    .setSleepVoltageThreshold(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showWakeVoltageDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Wake Voltage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Device will wake when voltage rises above this level'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Wake Voltage (V)',
                hintText: 'Enter voltage between 8.0 and 15.0',
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 8.0 && value <= 15.0) {
                ref.read(powerManagementControllerProvider.notifier)
                    .setWakeVoltageThreshold(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showHighTempDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set High Temperature Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thermal protection will activate above this temperature'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Temperature (°C)',
                hintText: 'Enter temperature between 0.0 and 150.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid range: 0.0°C - 150.0°C',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0.0 && value <= 150.0) {
                ref.read(powerManagementControllerProvider.notifier)
                    .setHighTemperatureThreshold(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showRecoveryTempDialog(double currentValue) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Recovery Temperature'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Thermal protection will deactivate below this temperature'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Temperature (°C)',
                hintText: 'Enter temperature between 0.0 and 150.0',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Valid range: 0.0°C - 150.0°C',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0.0 && value <= 150.0) {
                ref.read(powerManagementControllerProvider.notifier)
                    .setRecoveryThreshold(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  void _showForceSleepDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Sleep'),
        content: const Text('Are you sure you want to force the device into sleep mode?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(powerManagementControllerProvider.notifier).forceSleep();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Force sleep command sent')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Force Sleep'),
          ),
        ],
      ),
    );
  }

  void _showForceWakeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Force Wake'),
        content: const Text('Are you sure you want to force the device to wake from sleep mode?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(powerManagementControllerProvider.notifier).forceWake();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Force wake command sent')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Force Wake'),
          ),
        ],
      ),
    );
  }
}