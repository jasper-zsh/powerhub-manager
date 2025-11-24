import 'package:flutter/material.dart';
import 'package:app/models/power_management.dart';
import 'package:app/models/monitoring_data.dart';

class PowerStatus extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                Text(
                  'Power Management',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (powerConfig != null) ...[
                  _buildPowerInfo(context, powerConfig!),
                ] else ...[
                  Text(
                    'Power configuration not available',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
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
        ),
        _buildInfoRow(
          context,
          'Recovery Threshold',
          '${config.recoveryCelsius.toStringAsFixed(1)}°C',
        ),
        _buildInfoRow(
          context,
          'Sleep Voltage',
          '${config.sleepVoltage.toStringAsFixed(1)}V',
        ),
        _buildInfoRow(
          context,
          'Wake Voltage',
          '${config.wakeVoltage.toStringAsFixed(1)}V',
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
        ),
        _buildInfoRow(
          context,
          'Power Zone Temp',
          data.powerZoneTempCelsius != null
              ? '${data.powerZoneTempCelsius!.toStringAsFixed(1)}°C'
              : 'Invalid',
        ),
        _buildInfoRow(
          context,
          'Control Zone Temp',
          data.controlZoneTempCelsius != null
              ? '${data.controlZoneTempCelsius!.toStringAsFixed(1)}°C'
              : 'Invalid',
        ),
        _buildInfoRow(
          context,
          'Total Current',
          '${data.totalInputCurrent.toStringAsFixed(3)}A',
        ),
        _buildInfoRow(
          context,
          'System Status',
          data.statusFlags.toString(),
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
          );
        }),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
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
}