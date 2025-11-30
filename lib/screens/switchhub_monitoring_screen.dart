import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/widgets/monitoring/voltage_monitor_widget.dart';
import 'package:app/widgets/power/voltage_threshold_widget.dart';
import 'package:app/providers/switch_hub_provider_riverpod.dart';
import 'package:app/controllers/switch_hub_controller.dart';

/// Screen for SwitchHub real-time monitoring and power management
class SwitchHubMonitoringScreen extends ConsumerStatefulWidget {
  const SwitchHubMonitoringScreen({super.key});

  @override
  ConsumerState<SwitchHubMonitoringScreen> createState() => _SwitchHubMonitoringScreenState();
}

class _SwitchHubMonitoringScreenState extends ConsumerState<SwitchHubMonitoringScreen> {
  BluetoothDevice? selectedDevice;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(switchHubControllerProvider);
    final controllerNotifier = ref.read(switchHubControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SwitchHub 监测'),
        actions: [
          if (selectedDevice != null) ...[
            IconButton(
              icon: Icon(
                controller.isMonitoring ? Icons.stop : Icons.play_arrow,
              ),
              onPressed: () async {
                if (controller.isMonitoring) {
                  await controllerNotifier.stopMonitoring();
                } else {
                  await controllerNotifier.startMonitoring(selectedDevice!);
                }
              },
              tooltip: controller.isMonitoring ? '停止监测' : '开始监测',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await controllerNotifier.readMonitoringData(selectedDevice!);
              },
              tooltip: '刷新数据',
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSelector(controller),
            const SizedBox(height: 16),
            if (selectedDevice != null) ...[
              _buildStatusCards(controller, controllerNotifier),
              const SizedBox(height: 16),
              _buildMonitoringSection(controller),
              const SizedBox(height: 16),
              _buildPowerManagementSection(controller, controllerNotifier),
            ] else ...[
              _buildEmptyState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector(SwitchHubState controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '选择设备',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (controller.discoveredDevices.isEmpty)
              const Text('未发现设备，请先扫描 SwitchHub 设备')
            else
              DropdownButtonFormField<BluetoothDevice>(
                initialValue: selectedDevice,
                decoration: const InputDecoration(
                  labelText: 'SwitchHub 设备',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bluetooth),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: controller.discoveredDevices.map((device) {
                  final displayName = device.platformName.isNotEmpty
                      ? device.platformName
                      : '未知设备';
                  final displayMac = device.remoteId.str;

                  return DropdownMenuItem(
                    value: device,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: 48,
                        maxHeight: 56,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            displayMac,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (device) {
                  setState(() {
                    selectedDevice = device;
                  });
                },
                isDense: true,
                menuMaxHeight: 200,
                itemHeight: 56,
                icon: const Icon(Icons.arrow_drop_down),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final controllerNotifier = ref.read(switchHubControllerProvider.notifier);
                    await controllerNotifier.startScan();
                  },
                  icon: controller.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  label: Text(controller.isScanning ? '扫描中...' : '扫描设备'),
                ),
                const SizedBox(width: 12),
                if (controller.statusMessage != null)
                  Expanded(
                    child: Text(
                      controller.statusMessage!,
                      style: TextStyle(
                        color: controller.errorMessage != null
                            ? Colors.red
                            : Colors.green.shade600,
                        fontSize: 12,
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

  Widget _buildStatusCards(SwitchHubState state, SwitchHubController controller) {
    return Row(
      children: [
        Expanded(
          child: VoltageMonitorWidget(
            monitoringData: state.monitoringData,
            size: VoltageMonitorSize.small,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildConnectionStatusCard(state),
        ),
      ],
    );
  }

  Widget _buildConnectionStatusCard(SwitchHubState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  state.isMonitoring ? Icons.sensors : Icons.sensors_off,
                  color: state.isMonitoring ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                const Text(
                  '监测状态',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.isMonitoring ? '实时监测中' : '未监测',
              style: TextStyle(
                color: state.isMonitoring ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (state.monitoringData != null) ...[
              const SizedBox(height: 8),
              Text(
                '最后更新: ${DateTime.now().toString().substring(11, 19)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringSection(SwitchHubState controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '实时监测',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        VoltageMonitorWidget(
          monitoringData: controller.monitoringData,
          size: VoltageMonitorSize.medium,
        ),
      ],
    );
  }

  Widget _buildPowerManagementSection(SwitchHubState state, SwitchHubController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '电源管理',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        VoltageThresholdWidget(
          initialThresholds: state.voltageThresholds,
          onChanged: (thresholds) async {
            if (selectedDevice != null) {
              await controller.setVoltageThresholds(selectedDevice!, thresholds);
            }
          },
        ),
        const SizedBox(height: 16),
        _buildPowerActionButtons(controller),
      ],
    );
  }

  Widget _buildPowerActionButtons(SwitchHubController controller) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: selectedDevice != null ? () async {
              await controller.readVoltageThresholds(selectedDevice!);
            } : null,
            icon: const Icon(Icons.download),
            label: const Text('读取阈值'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: selectedDevice != null ? () async {
              await controller.readConfigWithChunks(selectedDevice!);
            } : null,
            icon: const Icon(Icons.settings),
            label: const Text('读取配置'),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_disabled,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '请选择 SwitchHub 设备',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '扫描并连接设备以开始监测',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}