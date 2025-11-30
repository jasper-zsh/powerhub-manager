import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/power_management.dart';
import 'package:app/models/monitoring_data.dart';
import 'package:app/controllers/power_management_controller.dart';

class PowerStatus extends ConsumerWidget {
  final PowerManagementConfig? powerConfig;
  final MonitoringData? monitoringData;
  final bool isConnected;

  const PowerStatus({
    super.key,
    this.powerConfig,
    this.monitoringData,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If no explicit power config provided, try to get it from the controller
    final powerState = ref.watch(powerManagementControllerProvider);
    final effectivePowerConfig = powerConfig ?? powerState.config;

    if (!isConnected) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Not connected to PowerHub',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Power Management',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    // Show loading indicator if power management is loading
                    if (powerState.isLoading && effectivePowerConfig == null)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    // Add refresh button for power management
                    if (effectivePowerConfig != null)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () {
                          ref.read(powerManagementControllerProvider.notifier).refreshConfig();
                        },
                        tooltip: 'Refresh power management configuration',
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (powerState.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            powerState.error!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            ref.read(powerManagementControllerProvider.notifier).clearError();
                          },
                          color: Colors.red.shade700,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (effectivePowerConfig != null) ...[
                  _buildPowerInfo(context, effectivePowerConfig),
                ] else if (powerState.isLoading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Loading power configuration...'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Power configuration not available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(powerManagementControllerProvider.notifier).refreshConfig();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Load Configuration'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Monitoring',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (monitoringData != null) ...[
                  _buildMonitoringInfo(context, monitoringData!),
                ] else ...[
                  Text(
                    'Monitoring data not available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPowerInfo(BuildContext context, PowerManagementConfig config) {
    return Column(
      children: [
        _buildInfoRow(
          context,
          'High Temp Threshold',
          '${config.highTempCelsius.toStringAsFixed(1)}°C',
          icon: Icons.thermostat,
          iconColor: Colors.red,
        ),
        _buildInfoRow(
          context,
          'Recovery Threshold',
          '${config.recoveryCelsius.toStringAsFixed(1)}°C',
          icon: Icons.ac_unit,
          iconColor: Colors.blue,
        ),
        _buildInfoRow(
          context,
          'Sleep Voltage',
          '${config.sleepVoltage.toStringAsFixed(1)}V',
          icon: Icons.bedtime,
          iconColor: Colors.indigo,
        ),
        _buildInfoRow(
          context,
          'Wake Voltage',
          '${config.wakeVoltage.toStringAsFixed(1)}V',
          icon: Icons.wb_sunny,
          iconColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMonitoringInfo(BuildContext context, MonitoringData data) {
    return Column(
      children: [
        _buildInfoRow(
          context,
          'Input Voltage',
          '${data.inputVoltageVolts.toStringAsFixed(2)}V',
          icon: Icons.electrical_services,
          iconColor: Colors.green,
        ),
        _buildInfoRow(
          context,
          'Power Zone Temp',
          data.powerZoneTempCelsius != null
              ? '${data.powerZoneTempCelsius!.toStringAsFixed(1)}°C'
              : 'Invalid',
          icon: Icons.local_fire_department,
          iconColor: data.powerZoneTempCelsius != null ? Colors.red : Colors.grey,
        ),
        _buildInfoRow(
          context,
          'Control Zone Temp',
          data.controlZoneTempCelsius != null
              ? '${data.controlZoneTempCelsius!.toStringAsFixed(1)}°C'
              : 'Invalid',
          icon: Icons.device_thermostat,
          iconColor: data.controlZoneTempCelsius != null ? Colors.blue : Colors.grey,
        ),
        _buildInfoRow(
          context,
          'Total Current (calc)',
          '${data.calculatedTotalCurrent.toStringAsFixed(3)}A',
          icon: Icons.electrical_services,
          iconColor: Colors.purple,
        ),
        if (data.validChannelCount < data.channelCurrents.length)
          _buildInfoRow(
            context,
            'Valid Channels',
            '${data.validChannelCount}/${data.channelCurrents.length}',
            icon: Icons.warning,
            iconColor: Colors.orange,
          ),
        _buildInfoRow(
          context,
          'System Status',
          data.statusFlags.toString(),
          icon: Icons.info,
          iconColor: Colors.blue,
        ),
        const SizedBox(height: 8),
        Text(
          'Channel Currents:',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        ...data.channelCurrents.asMap().entries.map((entry) {
          final channel = entry.key;
          final current = entry.value;
          return _buildInfoRow(
            context,
            '  CH$channel',
            '${current.toStringAsFixed(3)}A',
            icon: Icons.power,
            iconColor: _getChannelColor(channel),
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: iconColor ?? Colors.grey),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
}