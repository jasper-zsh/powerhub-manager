import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/controllers/switch_hub_controller.dart';
import 'package:app/models/monitoring_data.dart';
import 'package:app/providers/switch_hub_provider_riverpod.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/widgets/monitoring/voltage_monitor_widget.dart';

class UnifiedMonitoringScreen extends ConsumerWidget {
  const UnifiedMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monitoringState = ref.watch(monitoringControllerProvider);
    final switchHubState = ref.watch(switchHubControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
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
            // PowerHub monitoring section
            if (connectionState.isConnected) ...[
              _buildSectionHeader(context, 'PowerHub', Icons.power, Colors.blue),
              const SizedBox(height: 12),
              monitoringState.when(
                data: (data) => data != null
                    ? _buildPowerHubMonitoring(context, data)
                    : const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('暂无 PowerHub 监控数据'))),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildErrorCard('PowerHub 监控错误: $error'),
              ),
              const SizedBox(height: 24),
            ],

            // SwitchHub monitoring section
            if (switchHubState.monitoringData != null || switchHubState.isMonitoring) ...[
              _buildSectionHeader(context, 'SwitchHub', Icons.bluetooth_searching, Colors.purple),
              const SizedBox(height: 12),
              _buildSwitchHubMonitoring(context, switchHubState),
            ] else if (!connectionState.isConnected && !switchHubState.isMonitoring) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.monitor_heart_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('没有已连接的设备', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('连接设备后将自动显示监控数据', style: TextStyle(color: Colors.grey)),
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

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPowerHubMonitoring(BuildContext context, MonitoringData monitoringData) {
    return Column(
      children: [
        // Telemetry cards
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('遥测数据', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildInfoChip('${monitoringData.inputVoltageVolts.toStringAsFixed(1)} V', Icons.bolt, Colors.blue),
                    if (monitoringData.controlZoneTempCelsius != null)
                      _buildInfoChip('${monitoringData.controlZoneTempCelsius!.toStringAsFixed(1)} °C', Icons.thermostat, Colors.orange),
                    _buildInfoChip('${monitoringData.calculatedTotalCurrent.toStringAsFixed(2)} A', Icons.electrical_services, Colors.green),
                    if (monitoringData.isThermalProtectionActive)
                      _buildInfoChip('热保护已激活', Icons.warning, Colors.red),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Channel currents
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('通道电流', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                ...List.generate(monitoringData.channelCurrents.length, (index) {
                  final current = monitoringData.getChannelCurrent(index);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildCurrentBar(context, '通道 ${index + 1}', current, _getChannelColor(index)),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchHubMonitoring(BuildContext context, SwitchHubState state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: VoltageMonitorWidget(monitoringData: state.monitoringData, size: VoltageMonitorSize.small),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(state.isMonitoring ? Icons.sensors : Icons.sensors_off, color: state.isMonitoring ? Colors.green : Colors.grey),
                          const SizedBox(width: 8),
                          const Text('监测状态', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.isMonitoring ? '实时监测中' : '未监测',
                        style: TextStyle(color: state.isMonitoring ? Colors.green : Colors.grey, fontWeight: FontWeight.w500),
                      ),
                      if (state.monitoringData != null) ...[
                        const SizedBox(height: 8),
                        Text('最后更新: ${DateTime.now().toString().substring(11, 19)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.monitoringData != null)
          VoltageMonitorWidget(monitoringData: state.monitoringData, size: VoltageMonitorSize.medium),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Chip(label: Text(label), avatar: Icon(icon, size: 16, color: color), backgroundColor: color.withValues(alpha: 0.1));
  }

  Widget _buildCurrentBar(BuildContext context, String label, double current, Color color) {
    const maxCurrent = 5.0;
    final percentage = (current / maxCurrent).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(label), Text('${current.toStringAsFixed(2)} A', style: const TextStyle(fontWeight: FontWeight.w500))],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.grey.shade300),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: color)),
          ),
        ),
      ],
    );
  }

  Color _getChannelColor(int index) {
    const colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal];
    return colors[index % colors.length];
  }

  Widget _buildErrorCard(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}
