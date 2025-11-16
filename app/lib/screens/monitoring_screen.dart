import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/monitoring_controller.dart';

class MonitoringScreen extends ConsumerWidget {
  const MonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final telemetryState = ref.watch(monitoringControllerProvider);
    final monitoringState = ref.watch(monitoringControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Monitoring'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(monitoringControllerProvider.notifier).refreshSnapshot();
              ref.read(monitoringControllerProvider.notifier).refreshSnapshot();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Telemetry Data Section
            _buildSection(
              title: 'Telemetry Data',
              child: telemetryState.when(
                data: (data) => data != null
                    ? _buildTelemetryCards(context, data)
                    : const Text('No telemetry data available'),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildErrorWidget('Telemetry error: $error'),
              ),
            ),

            const SizedBox(height: 24),

            // Monitoring Data Section
            _buildSection(
              title: 'Monitoring Data',
              child: monitoringState.when(
                data: (data) => data != null
                    ? _buildMonitoringCards(context, data)
                    : const Text('No monitoring data available'),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildErrorWidget('Monitoring error: $error'),
              ),
            ),

            const SizedBox(height: 24),

            // Channel Currents
            if (monitoringState is AsyncData && monitoringState.value != null) ...[
              _buildSection(
                title: 'Channel Currents',
                child: _buildChannelCurrents(context, monitoringState.value!),
              ),
              const SizedBox(height: 24),
            ],

            // System Status
            _buildSection(
              title: 'System Status',
              child: _buildSystemStatus(context, telemetryState, monitoringState),
            ),

            const SizedBox(height: 24),

            // Real-time Updates Info
            _buildSection(
              title: 'Real-time Updates',
              child: _buildRealtimeInfo(context, telemetryState, monitoringState),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryCards(BuildContext context, monitoringData) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildInfoCard(
          context,
          title: 'Input Voltage',
          value: '${monitoringData.inputVoltageVolts.toStringAsFixed(1)} V',
          icon: Icons.bolt,
          color: Colors.blue,
        ),
        if (monitoringData.controlZoneTempCelsius != null)
          _buildInfoCard(
            context,
            title: 'Control Zone Temp',
            value: '${monitoringData.controlZoneTempCelsius!.toStringAsFixed(1)} °C',
            icon: Icons.thermostat,
            color: Colors.orange,
          ),
        if (monitoringData.powerZoneTempCelsius != null)
          _buildInfoCard(
            context,
            title: 'Power Zone Temp',
            value: '${monitoringData.powerZoneTempCelsius!.toStringAsFixed(1)} °C',
            icon: Icons.local_fire_department,
            color: Colors.red,
          ),
      ],
    );
  }

  Widget _buildMonitoringCards(BuildContext context, monitoringData) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildInfoCard(
          context,
          title: 'Total Current',
          value: '${monitoringData.totalInputCurrent.toStringAsFixed(2)} A',
          icon: Icons.electrical_services,
          color: Colors.green,
        ),
        _buildStatusCard(
          context,
          title: 'Thermal Protection',
          status: monitoringData.isThermalProtectionActive ? 'Active' : 'Inactive',
          isActive: monitoringData.isThermalProtectionActive,
          icon: Icons.warning,
        ),
        _buildStatusCard(
          context,
          title: 'Temperature Valid',
          status: monitoringData.isTemperatureDataValid ? 'Valid' : 'Invalid',
          isActive: monitoringData.isTemperatureDataValid,
          icon: Icons.thermostat,
        ),
        _buildStatusCard(
          context,
          title: 'Current Valid',
          status: monitoringData.isCurrentDataValid ? 'Valid' : 'Invalid',
          isActive: monitoringData.isCurrentDataValid,
          icon: Icons.electrical_services,
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required String title,
    required String status,
    required bool isActive,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    color: isActive ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus(
    BuildContext context,
    AsyncValue telemetryState,
    AsyncValue monitoringState,
  ) {
    final telemetryConnected = telemetryState is AsyncData && telemetryState.value != null;
    final monitoringConnected = monitoringState is AsyncData && monitoringState.value != null;

    return Row(
      children: [
        _buildStatusIndicator(
          'Telemetry',
          telemetryConnected,
          Icons.sensors,
        ),
        const SizedBox(width: 16),
        _buildStatusIndicator(
          'Monitoring',
          monitoringConnected,
          Icons.monitor_heart,
        ),
        const SizedBox(width: 16),
        _buildStatusIndicator(
          'System',
          telemetryConnected && monitoringConnected,
          Icons.settings,
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(String label, bool connected, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                color: connected ? Colors.green : Colors.red,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                connected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  color: connected ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelCurrents(BuildContext context, monitoringData) {
    return Column(
      children: [
        // Total current
        _buildCurrentBar(
          context,
          'Total Current',
          monitoringData.totalInputCurrent,
          Colors.blue,
        ),
        const SizedBox(height: 16),

        // Individual channel currents
        ...List.generate(6, (index) {
          final channelCurrent = monitoringData.getChannelCurrent(index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCurrentBar(
              context,
              'Channel ${index + 1}',
              channelCurrent,
              _getChannelColor(index),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCurrentBar(BuildContext context, String label, double current, Color color) {
    final maxCurrent = 5.0; // Maximum expected current in Amperes
    final percentage = (current / maxCurrent).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '${current.toStringAsFixed(2)} A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade300,
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getChannelColor(int channelIndex) {
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    return colors[channelIndex % colors.length];
  }

  Widget _buildRealtimeInfo(
    BuildContext context,
    AsyncValue telemetryState,
    AsyncValue monitoringState,
  ) {
    final telemetryConnected = telemetryState is AsyncData && telemetryState.value != null;
    final monitoringConnected = monitoringState is AsyncData && monitoringState.value != null;

    return Column(
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This screen shows real-time monitoring data from your PowerHub device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.update,
              color: Colors.green,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Data updates automatically when connected to a device.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.warning_amber,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Watch for thermal protection alerts and system warnings.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorWidget(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}