import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/telemetry.dart';
import 'package:app/controllers/telemetry_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';

class TelemetrySettingsScreen extends ConsumerWidget {
  const TelemetrySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryState = ref.watch(telemetryControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);
    
    final isConnected = connectionState.isConnected;
    final config = telemetryState.value?.config;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetry Settings'),
        actions: [
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _saveSettings(ref, config),
              tooltip: 'Save settings',
            ),
        ],
      ),
      body: _buildBody(telemetryState, connectionState),
    );
  }

  Widget _buildBody(AsyncValue<TelemetryData?> telemetryState, ConnectionSessionState connectionState) {
    if (!connectionState.isConnected) {
      return _buildDisconnectedView();
    }

    return telemetryState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading telemetry settings'),
            const SizedBox(height: 8),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(telemetryControllerProvider.notifier).refreshData(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (telemetryData) => _buildSettingsForm(telemetryData!.config),
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

  Widget _buildSettingsForm(TelemetryConfig config) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSectionTitle('Update Settings'),
                _buildIntervalTile(
                  'Telemetry Interval',
                  '${config.telemetryIntervalMs}ms',
                  (value) => _updateTelemetryInterval(value),
                ),
                _buildIntervalTile(
                  'Monitoring Interval',
                  '${config.monitoringIntervalMs}ms',
                  (value) => _updateMonitoringInterval(value),
                ),
                
                const SizedBox(height: 24),
                _buildSectionTitle('Data Collection'),
                SwitchListTile(
                  title: const Text('Enable Telemetry'),
                  subtitle: const Text('Collect device telemetry data'),
                  value: config.telemetryEnabled,
                  onChanged: (value) => _updateTelemetryEnabled(value),
                ),
                SwitchListTile(
                  title: const Text('Enable Monitoring'),
                  subtitle: const Text('Collect system monitoring data'),
                  value: config.monitoringEnabled,
                  onChanged: (value) => _updateMonitoringEnabled(value),
                ),
                SwitchListTile(
                  title: const Text('Auto-save Data'),
                  subtitle: const Text('Automatically save telemetry data'),
                  value: config.autoSaveEnabled,
                  onChanged: (value) => _updateAutoSaveEnabled(value),
                ),
                
                const SizedBox(height: 24),
                _buildSectionTitle('Data Retention'),
                ListTile(
                  title: const Text('Max Records'),
                  subtitle: Text('${config.maxRecords} records'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _showMaxRecordsDialog(config.maxRecords),
                ),
                ListTile(
                  title: const Text('Clear All Data'),
                  subtitle: const Text('Remove all saved telemetry data'),
                  trailing: const Icon(Icons.delete, color: Colors.red),
                  onTap: () => _showClearDataDialog(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildIntervalTile(String title, String value, Function(int) onUpdate) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit),
      onTap: () => _showIntervalDialog(title, value, onUpdate),
    );
  }

  void _showIntervalDialog(String title, String currentValue, Function(int) onUpdate) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Interval (ms)',
            hintText: currentValue,
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
                onUpdate(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMaxRecordsDialog(int currentValue) {
    final controller = TextEditingController(text: currentValue.toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Max Records'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Maximum records to keep',
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
                _updateMaxRecords(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text('Are you sure you want to delete all saved telemetry data? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _clearAllData();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _updateTelemetryInterval(int value) {
    ref.read(telemetryControllerProvider.notifier).updateConfig(
      (config) => config.copyWith(telemetryIntervalMs: value),
    );
  }

  void _updateMonitoringInterval(int value) {
    ref.read(telemetryControllerProvider.notifier).updateConfig(
      (config) => config.copyWith(monitoringIntervalMs: value),
    );
  }

  void _updateTelemetryEnabled(bool value) {
    ref.read(telemetryControllerProvider.notifier).updateConfig(
      (config) => config.copyWith(telemetryEnabled: value),
    );
  }

  void _updateMonitoringEnabled(bool value) {
    ref.read(telemetryControllerProvider.notifier).updateConfig(
      (config) => config.copyWith(monitoringEnabled: value),
    );
  }

  void _updateAutoSaveEnabled(bool value) {
    ref.read(telemetryControllerProvider.notifier).updateConfig(
      (config) => config.copyWith(autoSaveEnabled: value),
    );
  }

  void _updateMaxRecords(int value) {
    ref.read(telemetryControllerProvider.notifier).updateConfig(
      (config) => config.copyWith(maxRecords: value),
    );
  }

  void _saveSettings(WidgetRef ref, TelemetryConfig? config) {
    if (config != null) {
      ref.read(telemetryControllerProvider.notifier).saveConfig();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved successfully')),
      );
    }
  }

  void _clearAllData() {
    ref.read(telemetryControllerProvider.notifier).clearAllData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data cleared')),
    );
  }
}
