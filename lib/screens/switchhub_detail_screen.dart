import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:app/providers/switch_hub_provider_riverpod.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/widgets/power/voltage_threshold_widget.dart';

class SwitchHubDetailScreen extends ConsumerStatefulWidget {
  final String controllerId;
  const SwitchHubDetailScreen({super.key, required this.controllerId});

  @override
  ConsumerState<SwitchHubDetailScreen> createState() => _SwitchHubDetailScreenState();
}

class _SwitchHubDetailScreenState extends ConsumerState<SwitchHubDetailScreen> {
  BluetoothDevice? _device;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initDevice();
    });
  }

  void _initDevice() async {
    final controller = ref.read(switchHubControllerProvider.notifier);
    // If no devices discovered yet, scan first
    if (ref.read(switchHubControllerProvider).discoveredDevices.isEmpty) {
      await controller.startScan();
    }
    final state = ref.read(switchHubControllerProvider);
    // Strip 'sh_' prefix to get raw MAC address for BLE matching
    final macAddress = widget.controllerId.startsWith('sh_')
        ? widget.controllerId.substring(3)
        : widget.controllerId;
    final match = state.discoveredDevices.where(
      (d) => d.remoteId.str == macAddress,
    );
    if (match.isNotEmpty) {
      setState(() {
        _device = match.first;
        _initialized = true;
      });
      // Auto-read thresholds
      await controller.readVoltageThresholds(_device!);
    } else {
      setState(() { _initialized = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(switchHubControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAlias() ?? 'SwitchHub'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_initialized)
              const Center(child: CircularProgressIndicator())
            else if (_device == null)
              _buildDeviceNotFound()
            else ...[
              // Error display
              if (state.errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red))),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => ref.read(switchHubControllerProvider.notifier).clearError(),
                        ),
                      ],
                    ),
                  ),
                ),
              if (state.errorMessage != null) const SizedBox(height: 16),

              // Voltage Thresholds
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.electrical_services, color: Colors.orange),
                          const SizedBox(width: 8),
                          Text('电压阈值配置', style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 16),
                      VoltageThresholdWidget(
                        initialThresholds: state.voltageThresholds,
                        onChanged: (thresholds) async {
                          if (_device != null) {
                            await ref.read(switchHubControllerProvider.notifier)
                                .setVoltageThresholds(_device!, thresholds);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Status message
              if (state.statusMessage != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(state.statusMessage!, style: TextStyle(color: Colors.blue.shade700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String? _getAlias() {
    try {
      final savedState = ref.read(savedControllerControllerProvider);
      final controller = savedState.controllers.firstWhere(
        (c) => c.controllerId == widget.controllerId,
      );
      return controller.alias;
    } catch (_) {
      return null;
    }
  }

  Widget _buildDeviceNotFound() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('未找到 SwitchHub 设备', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('请确保设备已开机且在蓝牙范围内', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await ref.read(switchHubControllerProvider.notifier).startScan();
                _initDevice();
              },
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text('重新扫描'),
            ),
          ],
        ),
      ),
    );
  }
}
