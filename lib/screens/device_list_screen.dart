import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/discovery_controller.dart';
import 'package:app/providers/switch_hub_provider_riverpod.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/screens/powerhub_detail_screen.dart';
import 'package:app/screens/switchhub_detail_screen.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedState = ref.watch(savedControllerControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设备管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(savedControllerControllerProvider.notifier).loadControllers();
            },
          ),
        ],
      ),
      body: savedState.controllers.isEmpty
          ? _buildEmptyState(context, ref)
          : _buildDeviceList(context, ref, savedState),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDeviceDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.devices_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('没有已保存的设备', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('添加你的第一个设备以开始', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDeviceDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加设备'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BuildContext context, WidgetRef ref, SavedControllerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.controllers.length,
      itemBuilder: (context, index) {
        final controller = state.controllers[index];
        return _buildDeviceCard(context, ref, controller);
      },
    );
  }

  Widget _buildDeviceCard(BuildContext context, WidgetRef ref, SavedController controller) {
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final isConnected = connectionState.isConnected &&
        connectionState.controllerId == controller.controllerId;
    final isConnecting = connectionState.lifecycle == ConnectionLifecycle.connecting &&
        connectionState.controllerId == controller.controllerId;

    final isSwitchHub = controller.controllerId.startsWith('sh_');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isConnected
              ? Colors.green.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          child: Icon(
            isSwitchHub ? Icons.bluetooth_searching : Icons.bluetooth,
            color: isConnected ? Colors.green : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                controller.alias,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: isConnected ? Colors.green : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSwitchHub ? Colors.purple.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isSwitchHub ? 'SwitchHub' : 'PowerHub',
                style: TextStyle(
                  fontSize: 10,
                  color: isSwitchHub ? Colors.purple : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(controller.controllerId),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnecting ? Colors.orange : isConnected ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isConnecting ? '连接中...' : isConnected ? '已连接' : '未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: isConnecting ? Colors.orange : isConnected ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isConnected && !isConnecting)
              IconButton(
                icon: const Icon(Icons.bluetooth_connected, size: 20),
                onPressed: () => _connectToDevice(context, ref, controller.controllerId),
                tooltip: '连接',
              )
            else if (isConnecting)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else
              IconButton(
                icon: const Icon(Icons.bluetooth_disabled, size: 20),
                onPressed: () => _disconnectDevice(context, ref),
                tooltip: '断开',
              ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'connect', child: ListTile(leading: Icon(Icons.bluetooth_connected), title: Text('连接'))),
                const PopupMenuItem(value: 'disconnect', child: ListTile(leading: Icon(Icons.bluetooth_disabled), title: Text('断开'))),
                const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit), title: Text('重命名'))),
                const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('删除'))),
              ],
              onSelected: (value) {
                if (value == 'connect') {
                  _connectToDevice(context, ref, controller.controllerId);
                } else if (value == 'disconnect') {
                  _disconnectDevice(context, ref);
                } else if (value == 'rename') {
                  _showRenameDialog(context, ref, controller);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, ref, controller.controllerId);
                }
              },
            ),
          ],
        ),
        onTap: () {
          if (isSwitchHub) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SwitchHubDetailScreen(controllerId: controller.controllerId),
            ));
          } else {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PowerHubDetailScreen(controllerId: controller.controllerId),
            ));
          }
        },
      ),
    );
  }

  void _showAddDeviceDialog(BuildContext context, WidgetRef ref) {
    final aliasController = TextEditingController();
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加设备'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('选择设备类型并扫描，或添加一个样例设备。', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: aliasController,
                  decoration: const InputDecoration(labelText: '设备名称', hintText: '为设备输入一个名称'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: '备注（可选）', hintText: '输入设备备注信息'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeviceSelectionDialog(context, ref, aliasController.text),
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('PowerHub'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showSwitchHubSelectionDialog(context, ref, aliasController.text),
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('SwitchHub'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _addSampleController(context, ref, aliasController.text, notesController.text),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('添加样例'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ],
        ),
      ),
    );
  }

  void _showSwitchHubSelectionDialog(BuildContext context, WidgetRef ref, String alias) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final switchHubState = ref.watch(switchHubControllerProvider);
          return AlertDialog(
            title: const Text('扫描 SwitchHub 设备'),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: _buildSwitchHubSelectionContent(context, ref, switchHubState, alias),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
              if (!switchHubState.isScanning)
                ElevatedButton.icon(
                  onPressed: () => ref.read(switchHubControllerProvider.notifier).startScan(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('扫描'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSwitchHubSelectionContent(BuildContext context, WidgetRef ref, switchHubState, String alias) {
    if (switchHubState.isScanning && switchHubState.discoveredDevices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Text('正在搜索 SwitchHub 设备...'),
          ],
        ),
      );
    }

    if (switchHubState.discoveredDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('未发现 SwitchHub 设备', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('请确认 SwitchHub 设备已开机且在附近', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('可用设备 (${switchHubState.discoveredDevices.length})', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: switchHubState.discoveredDevices.length,
            itemBuilder: (context, index) {
              final device = switchHubState.discoveredDevices[index];
              final displayName = device.platformName.isNotEmpty ? device.platformName : 'SwitchHub';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.withOpacity(0.1),
                    child: const Icon(Icons.bluetooth_searching, color: Colors.purple, size: 20),
                  ),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('MAC: ${device.remoteId.str}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(); // Close both dialogs
                    _addSwitchHubDevice(context, ref, device, alias);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addSwitchHubDevice(BuildContext context, WidgetRef ref, dynamic device, String alias) async {
    try {
      final macAddress = device.remoteId.str;
      final displayName = device.platformName.isNotEmpty ? device.platformName : 'SwitchHub';
      final controllerAlias = alias.isEmpty ? displayName : alias;

      await ref.read(savedControllerControllerProvider.notifier).createController(
        controllerId: 'sh_$macAddress',
        alias: controllerAlias,
        notes: 'SwitchHub device added on ${DateTime.now().toString().substring(0, 19)}\nMAC: $macAddress',
        deviceCapabilities: const DeviceCapabilities(channels: 0, supportsPresets: false),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$controllerAlias (SwitchHub) 添加成功'), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加 SwitchHub 设备失败: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showDeviceSelectionDialog(BuildContext context, WidgetRef ref, String alias) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final discoveryState = ref.watch(discoveryControllerProvider);
          return AlertDialog(
            title: const Text('选择设备'),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: _buildDeviceSelectionContent(context, ref, discoveryState, alias),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
              if (!discoveryState.isScanning)
                ElevatedButton.icon(
                  onPressed: () => ref.read(discoveryControllerProvider.notifier).startScan(),
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('扫描'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceSelectionContent(BuildContext context, WidgetRef ref, discoveryState, String alias) {
    if (discoveryState.isScanning && discoveryState.devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Text('正在搜索设备...'),
          ],
        ),
      );
    }

    if (discoveryState.devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('未发现设备', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('请确认设备已开机且在附近', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('可用设备 (${discoveryState.devices.length})', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: discoveryState.devices.length,
            itemBuilder: (context, index) {
              final device = discoveryState.devices[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.bluetooth, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  title: Text(device.name.isNotEmpty ? device.name : '未知设备', style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text('ID: ${device.id}'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                    _addControllerFromDevice(context, ref, device, alias);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addControllerFromDevice(BuildContext context, WidgetRef ref, PWMController device, String alias) async {
    try {
      final deviceName = device.name.isNotEmpty ? device.name : 'PowerHub Device';
      final controllerAlias = alias.isEmpty ? deviceName : alias;

      await ref.read(savedControllerControllerProvider.notifier).createController(
        controllerId: device.id,
        alias: controllerAlias,
        notes: 'Added from device discovery on ${DateTime.now().toString().substring(0, 19)}\nDevice: $deviceName\nID: ${device.id}',
        deviceCapabilities: const DeviceCapabilities(channels: 6, supportsPresets: false),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$controllerAlias 添加成功'), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加设备失败: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _addSampleController(BuildContext context, WidgetRef ref, String alias, String notes) async {
    if (alias.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入设备名称'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      await ref.read(savedControllerControllerProvider.notifier).createController(
        controllerId: 'sample_${DateTime.now().millisecondsSinceEpoch}',
        alias: alias.trim(),
        notes: notes.trim().isEmpty ? null : notes.trim(),
        deviceCapabilities: const DeviceCapabilities(channels: 6, supportsPresets: false),
      );

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${alias.trim()} 添加成功（样例）'), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加样例设备失败: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, SavedController controller) {
    final textController = TextEditingController(text: controller.alias);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名设备'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(labelText: '设备名称', hintText: '输入新的设备名称'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                ref.read(savedControllerControllerProvider.notifier).renameController(
                  controller.controllerId, textController.text,
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String controllerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除设备'),
        content: const Text('确认删除此设备？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              ref.read(savedControllerControllerProvider.notifier).removeController(controllerId);
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _connectToDevice(BuildContext context, WidgetRef ref, String controllerId) async {
    try {
      await ref.read(connectionSessionControllerProvider.notifier).connect(controllerId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已连接到 $controllerId'), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接失败: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _disconnectDevice(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(connectionSessionControllerProvider.notifier).disconnect();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已断开连接'), backgroundColor: Colors.blue),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('断开失败: $error'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
