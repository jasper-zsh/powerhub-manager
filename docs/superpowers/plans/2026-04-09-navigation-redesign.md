# Navigation Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce bottom navigation from 6 tabs to 3 by folding device configuration into detail pages accessed from a unified device list.

**Architecture:** Replace flat 6-tab `NavigationBar` with 3 tabs (开关编排, 设备管理, 设备监控). Device configuration (Control, Power, SwitchHub config) moves into `Navigator.push` detail pages that auto-load on entry. All existing providers/controllers are reused unchanged.

**Tech Stack:** Flutter, Riverpod, flutter_blue_plus, existing provider layer unchanged.

---

## File Map

**Create:**
- `lib/screens/device_list_screen.dart` — Unified device list (PowerHub + SwitchHub)
- `lib/screens/powerhub_detail_screen.dart` — PowerHub config (PWM + power management), auto-loads on entry
- `lib/screens/switchhub_detail_screen.dart` — SwitchHub config (voltage thresholds), auto-loads on entry
- `lib/screens/unified_monitoring_screen.dart` — All connected devices' monitoring data merged

**Modify:**
- `lib/main.dart` — 6 tabs → 3 tabs, new imports

**Remove (after new screens work):**
- `lib/screens/saved_controller_management_screen.dart`
- `lib/screens/device_control_screen.dart`
- `lib/screens/power_management_screen.dart`
- `lib/screens/switchhub_monitoring_screen.dart`
- `lib/screens/monitoring_screen.dart`

---

### Task 1: Update main.dart navigation to 3 tabs

**Files:**
- Modify: `lib/main.dart`

This task updates the navigation shell first so we have a skeleton to fill in. The new screens will be placeholder stubs that get replaced in subsequent tasks.

- [ ] **Step 1: Create placeholder screen files**

Create minimal placeholder screens so `main.dart` compiles:

`lib/screens/device_list_screen.dart`:
```dart
import 'package:flutter/material.dart';

class DeviceListScreen extends StatelessWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备管理')),
      body: const Center(child: Text('Device List')),
    );
  }
}
```

`lib/screens/unified_monitoring_screen.dart`:
```dart
import 'package:flutter/material.dart';

class UnifiedMonitoringScreen extends StatelessWidget {
  const UnifiedMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设备监控')),
      body: const Center(child: Text('Unified Monitoring')),
    );
  }
}
```

- [ ] **Step 2: Update main.dart imports and navigation**

Replace the entire `MainNavigationShell` widget and imports in `lib/main.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/screens/orchestration_screen.dart';
import 'package:app/screens/device_list_screen.dart';
import 'package:app/screens/unified_monitoring_screen.dart';

void main() {
  if (kDebugMode) {
    debugPrint('Starting PowerHub Manager app...');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'PowerHub Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        navigationBarTheme: const NavigationBarThemeData(
          height: 56,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 3,
        ),
      ),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavigationBarIndexProvider);

    final pages = const [
      OrchestrationScreen(),
      DeviceListScreen(),
      UnifiedMonitoringScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.toggle_on_outlined),
            selectedIcon: Icon(Icons.toggle_on),
            label: '开关编排',
          ),
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '设备管理',
          ),
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart),
            label: '设备监控',
          ),
        ],
        onDestinationSelected: (index) {
          ref.read(bottomNavigationBarIndexProvider.notifier).state = index;
        },
      ),
    );
  }
}

final bottomNavigationBarIndexProvider = StateProvider<int>((ref) => 0);
```

- [ ] **Step 3: Run analysis to verify compilation**

Run: `dart analyze lib/main.dart lib/screens/device_list_screen.dart lib/screens/unified_monitoring_screen.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/screens/device_list_screen.dart lib/screens/unified_monitoring_screen.dart
git commit -m "refactor: reduce navigation from 6 tabs to 3 (开关编排/设备管理/设备监控)"
```

---

### Task 2: Build DeviceListScreen

**Files:**
- Modify: `lib/screens/device_list_screen.dart`

This screen merges PowerHub and SwitchHub devices into a unified list. It reuses the existing `savedControllerControllerProvider` for PowerHub devices and `switchHubControllerProvider` for SwitchHub device scanning/discovery. Tapping a PowerHub device navigates to `PowerHubDetailScreen`; tapping a SwitchHub device navigates to `SwitchHubDetailScreen`.

- [ ] **Step 1: Implement DeviceListScreen**

Replace `lib/screens/device_list_screen.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/discovery_controller.dart';
import 'package:app/controllers/switch_hub_controller.dart';
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

    // Determine device type based on controllerId prefix
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
            Text(
              controller.alias,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isConnected ? Colors.green : null,
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
                    color: isConnecting
                        ? Colors.orange
                        : isConnected
                            ? Colors.green
                            : Colors.grey,
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
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
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
        onTap: () => _navigateToDetail(context, ref, controller, isConnected),
      ),
    );
  }

  void _navigateToDetail(BuildContext context, WidgetRef ref, SavedController controller, bool isConnected) {
    final isSwitchHub = controller.controllerId.startsWith('sh_');
    if (isSwitchHub) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SwitchHubDetailScreen(controllerId: controller.controllerId),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PowerHubDetailScreen(controllerId: controller.controllerId),
        ),
      );
    }
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
                const Text('扫描附近的 PowerHub 设备，或添加一个样例设备进行测试。', style: TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                TextField(
                  controller: aliasController,
                  decoration: const InputDecoration(
                    labelText: '设备名称',
                    hintText: '为设备输入一个名称',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: '备注（可选）',
                    hintText: '输入设备备注信息',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeviceSelectionDialog(context, ref, aliasController.text),
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('扫描设备'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
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
              child: Column(
                children: [
                  if (discoveryState.isScanning) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('扫描中...', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                                Text('已发现 ${discoveryState.devices.length} 个设备', style: TextStyle(color: Colors.blue.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (discoveryState.devices.isEmpty && !discoveryState.isScanning)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('未发现设备', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text('请确认设备已开机且在附近', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else if (discoveryState.devices.isEmpty && discoveryState.isScanning)
                    const Expanded(child: Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 48, color: Colors.blue),
                        SizedBox(height: 16),
                        Text('正在搜索设备...'),
                      ],
                    )))
                  else
                    Expanded(
                      child: Column(
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
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
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
          decoration: const InputDecoration(
            labelText: '设备名称',
            hintText: '输入新的设备名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (textController.text.isNotEmpty) {
                ref.read(savedControllerControllerProvider.notifier).renameController(
                  controller.controllerId,
                  textController.text,
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
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
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
```

- [ ] **Step 2: Create placeholder detail screens so imports compile**

Create `lib/screens/powerhub_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';

class PowerHubDetailScreen extends StatelessWidget {
  final String controllerId;
  const PowerHubDetailScreen({super.key, required this.controllerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PowerHub')),
      body: const Center(child: Text('PowerHub Detail')),
    );
  }
}
```

Create `lib/screens/switchhub_detail_screen.dart`:
```dart
import 'package:flutter/material.dart';

class SwitchHubDetailScreen extends StatelessWidget {
  final String controllerId;
  const SwitchHubDetailScreen({super.key, required this.controllerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SwitchHub')),
      body: const Center(child: Text('SwitchHub Detail')),
    );
  }
}
```

- [ ] **Step 3: Run analysis**

Run: `dart analyze lib/screens/device_list_screen.dart lib/screens/powerhub_detail_screen.dart lib/screens/switchhub_detail_screen.dart`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/device_list_screen.dart lib/screens/powerhub_detail_screen.dart lib/screens/switchhub_detail_screen.dart
git commit -m "feat: add DeviceListScreen with unified device list and placeholder detail screens"
```

---

### Task 3: Build PowerHubDetailScreen

**Files:**
- Modify: `lib/screens/powerhub_detail_screen.dart`

Migrates content from `DeviceControlScreen` (PWM channel control + telemetry) and `PowerManagementScreen` (voltage/temperature thresholds + force sleep/wake) into a single detail page. Auto-loads device config and power management config on entry. Receives `controllerId`, auto-selects the controller, and reads all config.

- [ ] **Step 1: Implement PowerHubDetailScreen**

Replace `lib/screens/powerhub_detail_screen.dart` with the full implementation that combines:
- Channel control UI from `DeviceControlScreen` (sliders, quick actions, telemetry chips)
- Power management UI from `PowerManagementScreen` (voltage thresholds, temperature thresholds, force sleep/wake)
- Auto-selects the controller via `deviceControlControllerProvider` on `initState`
- Auto-reads power config via `powerManagementControllerProvider` on `initState`
- No device selector dropdown — the device is already determined by `controllerId`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/device_control_controller.dart';
import 'package:app/controllers/power_management_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/models/power_management.dart';

class PowerHubDetailScreen extends ConsumerStatefulWidget {
  final String controllerId;
  const PowerHubDetailScreen({super.key, required this.controllerId});

  @override
  ConsumerState<PowerHubDetailScreen> createState() => _PowerHubDetailScreenState();
}

class _PowerHubDetailScreenState extends ConsumerState<PowerHubDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Auto-select controller and load config
        ref.read(deviceControlControllerProvider.notifier).selectController(widget.controllerId);
        ref.read(powerManagementControllerProvider.notifier).refreshConfig();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceControlState = ref.watch(deviceControlControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final powerState = ref.watch(powerManagementControllerProvider);
    final monitoringState = ref.watch(monitoringControllerProvider);
    final isConnected = connectionState.isConnected;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAlias() ?? 'PowerHub'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection status
            if (!isConnected)
              _buildDisconnectedView()
            else ...[
              // Error display
              if (deviceControlState.errorMessage != null)
                _buildErrorCard(deviceControlState.errorMessage!, () {
                  ref.read(deviceControlControllerProvider.notifier).clearError();
                }),
              if (powerState.error != null)
                _buildErrorCard(powerState.error!, () {
                  ref.read(powerManagementControllerProvider.notifier).clearError();
                }),

              // Quick actions
              if (deviceControlState.channels.isNotEmpty) ...[
                _buildQuickActions(deviceControlState),
                const SizedBox(height: 16),
              ],

              // Channel controls
              if (deviceControlState.channels.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('通道控制', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        ...List.generate(deviceControlState.channels.length, (index) {
                          final channel = deviceControlState.channels[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _buildChannelControl(channel, deviceControlState),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Telemetry
              if (monitoringState is AsyncData && monitoringState.value != null) ...[
                _buildTelemetrySection(monitoringState.value!),
                const SizedBox(height: 16),
              ],

              // Power management
              if (powerState.config != null) ...[
                _buildPowerManagementSection(powerState),
              ] else if (powerState.isLoading)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 16),
                        Text('加载电源配置...'),
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

  String? _getAlias() {
    final savedState = ref.read(savedControllerControllerProvider);
    try {
      final controller = savedState.controllers.firstWhere(
        (c) => c.controllerId == widget.controllerId,
      );
      return controller.alias;
    } catch (_) {
      return null;
    }
  }

  // ---- Channel Control (from DeviceControlScreen) ----

  Widget _buildQuickActions(DeviceControlState deviceControlState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('快捷操作', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(0),
                  icon: const Icon(Icons.power_off, size: 16),
                  label: const Text('全部关闭'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(255),
                  icon: const Icon(Icons.brightness_high, size: 16),
                  label: const Text('全部开启'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _setAllChannels(128),
                  icon: const Icon(Icons.brightness_medium, size: 16),
                  label: const Text('全部50%'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _randomizeChannels(),
                  icon: const Icon(Icons.shuffle, size: 16),
                  label: const Text('随机'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelControl(channel, DeviceControlState deviceControlState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text('通道 ${channel.id}', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (deviceControlState.isChannelBusy(channel.id))
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(channel.value > 0 ? Icons.power : Icons.power_off, color: channel.value > 0 ? Colors.green : Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('值: ${channel.value}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('${(channel.value / 255 * 100).toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            Slider(
              value: channel.value.toDouble(),
              min: 0,
              max: 255,
              divisions: 255,
              activeColor: _getSliderColor(channel.value),
              onChanged: deviceControlState.isChannelBusy(channel.id)
                  ? null
                  : (value) {
                      ref.read(deviceControlControllerProvider.notifier).handleSetValue(channel.id, value.round());
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: deviceControlState.isChannelBusy(channel.id) ? null : () {
                      ref.read(deviceControlControllerProvider.notifier).handleSetValue(channel.id, 0);
                    },
                    icon: const Icon(Icons.power_off, size: 16),
                    label: const Text('OFF'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: deviceControlState.isChannelBusy(channel.id) ? null : () {
                      ref.read(deviceControlControllerProvider.notifier).handleSetValue(channel.id, 128);
                    },
                    icon: const Icon(Icons.brightness_medium, size: 16),
                    label: const Text('50%'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: deviceControlState.isChannelBusy(channel.id) ? null : () {
                      ref.read(deviceControlControllerProvider.notifier).handleSetValue(channel.id, 255);
                    },
                    icon: const Icon(Icons.brightness_high, size: 16),
                    label: const Text('MAX'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getSliderColor(int value) {
    if (value == 0) return Colors.grey;
    if (value <= 85) return Colors.green;
    if (value <= 170) return Colors.orange;
    return Colors.red;
  }

  void _setAllChannels(int value) {
    final deviceControlState = ref.read(deviceControlControllerProvider);
    for (final channel in deviceControlState.channels) {
      if (!deviceControlState.isChannelBusy(channel.id)) {
        ref.read(deviceControlControllerProvider.notifier).handleSetValue(channel.id, value);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('所有通道设为 $value (${(value / 255 * 100).toStringAsFixed(1)}%)'), duration: const Duration(seconds: 2)),
    );
  }

  void _randomizeChannels() {
    final deviceControlState = ref.read(deviceControlControllerProvider);
    for (final channel in deviceControlState.channels) {
      if (!deviceControlState.isChannelBusy(channel.id)) {
        final randomValue = (DateTime.now().millisecond + channel.id) % 256;
        ref.read(deviceControlControllerProvider.notifier).handleSetValue(channel.id, randomValue);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通道已随机设置'), duration: Duration(seconds: 2)),
    );
  }

  // ---- Telemetry (from DeviceControlScreen) ----

  Widget _buildTelemetrySection(monitoringData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('遥测数据', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text('电压: ${monitoringData.inputVoltageVolts.toStringAsFixed(1)}V'),
                  backgroundColor: Colors.blue.shade100,
                ),
                if (monitoringData.controlZoneTempCelsius != null)
                  Chip(
                    label: Text('温度: ${monitoringData.controlZoneTempCelsius!.toStringAsFixed(1)}°C'),
                    backgroundColor: Colors.orange.shade100,
                  ),
                Chip(
                  label: Text('总电流: ${monitoringData.calculatedTotalCurrent.toStringAsFixed(2)}A'),
                  backgroundColor: Colors.green.shade100,
                ),
                if (monitoringData.isThermalProtectionActive)
                  Chip(
                    label: const Text('热保护已激活'),
                    backgroundColor: Colors.red.shade100,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---- Power Management (from PowerManagementScreen) ----

  Widget _buildPowerManagementSection(powerState) {
    final config = powerState.config as PowerManagementConfig;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    Text('电压阈值', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('休眠电压'),
                  subtitle: const Text('低于此电压设备将进入休眠'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${config.sleepVoltage.toStringAsFixed(1)}V', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showVoltageDialog('休眠电压', config.sleepVoltage, (v) {
                        ref.read(powerManagementControllerProvider.notifier).setSleepVoltageThreshold(v);
                      })),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('唤醒电压'),
                  subtitle: const Text('高于此电压设备将被唤醒'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${config.wakeVoltage.toStringAsFixed(1)}V', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showVoltageDialog('唤醒电压', config.wakeVoltage, (v) {
                        ref.read(powerManagementControllerProvider.notifier).setWakeVoltageThreshold(v);
                      })),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.thermostat, color: Colors.red),
                    const SizedBox(width: 8),
                    Text('温度阈值', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('高温阈值'),
                  subtitle: const Text('超过此温度将触发热保护'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${config.highTempCelsius.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showTempDialog('高温阈值', config.highTempCelsius, (v) {
                        ref.read(powerManagementControllerProvider.notifier).setHighTemperatureThreshold(v);
                      })),
                    ],
                  ),
                ),
                const Divider(),
                ListTile(
                  title: const Text('恢复温度'),
                  subtitle: const Text('低于此温度热保护将关闭'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${config.recoveryCelsius.toStringAsFixed(1)}°C', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showTempDialog('恢复温度', config.recoveryCelsius, (v) {
                        ref.read(powerManagementControllerProvider.notifier).setRecoveryThreshold(v);
                      })),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.power_settings_new, color: Colors.green),
                    const SizedBox(width: 8),
                    Text('电源控制', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showConfirmDialog('强制休眠', '确认强制设备进入休眠模式？', () {
                          ref.read(powerManagementControllerProvider.notifier).forceSleep();
                          Navigator.of(context).pop();
                        }),
                        icon: const Icon(Icons.bedtime),
                        label: const Text('强制休眠'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showConfirmDialog('强制唤醒', '确认强制设备从休眠模式唤醒？', () {
                          ref.read(powerManagementControllerProvider.notifier).forceWake();
                          Navigator.of(context).pop();
                        }),
                        icon: const Icon(Icons.wb_sunny),
                        label: const Text('强制唤醒'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (powerState.isLoading) ...[
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 16),
                  Text('更新配置中...'),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showVoltageDialog(String title, double currentValue, Function(double) onSet) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置$title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '电压 (V)',
                hintText: '输入 8.0 ~ 15.0 之间的值',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('有效范围: 8.0V - 15.0V', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 8.0 && value <= 15.0) {
                onSet(value);
                Navigator.pop(context);
              }
            },
            child: const Text('设置'),
          ),
        ],
      ),
    );
  }

  void _showTempDialog(String title, double currentValue, Function(double) onSet) {
    final controller = TextEditingController(text: currentValue.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置$title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '温度 (°C)',
                hintText: '输入 0.0 ~ 150.0 之间的值',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('有效范围: 0.0°C - 150.0°C', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0.0 && value <= 150.0) {
                onSet(value);
                Navigator.pop(context);
              }
            },
            child: const Text('设置'),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(onPressed: onConfirm, child: Text(title)),
        ],
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_getAlias() ?? '设备未连接', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('请先连接设备以查看和控制'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(String error, VoidCallback onDismiss) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(error, style: const TextStyle(color: Colors.red))),
            IconButton(icon: const Icon(Icons.close), onPressed: onDismiss),
          ],
        ),
      ),
    );
  }
}
```

Note: This file needs `import 'package:app/controllers/saved_controller_controller.dart';` added at the top for `_getAlias()` to work.

- [ ] **Step 2: Run analysis**

Run: `dart analyze lib/screens/powerhub_detail_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/powerhub_detail_screen.dart
git commit -m "feat: add PowerHubDetailScreen with PWM control and power management"
```

---

### Task 4: Build SwitchHubDetailScreen

**Files:**
- Modify: `lib/screens/switchhub_detail_screen.dart`

Migrates the configuration portion of `SwitchHubMonitoringScreen` — voltage threshold configuration via `VoltageThresholdWidget`. No device selector, no manual read buttons. Auto-loads voltage thresholds when entering the screen.

- [ ] **Step 1: Implement SwitchHubDetailScreen**

Replace `lib/screens/switchhub_detail_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:app/controllers/switch_hub_controller.dart';
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
    // Find matching device by remote ID matching controllerId
    final match = state.discoveredDevices.where(
      (d) => d.remoteId.str == widget.controllerId,
    );
    if (match.isNotEmpty) {
      setState(() {
        _device = match.first;
        _initialized = true;
      });
      // Auto-read thresholds
      await controller.readVoltageThresholds(_device!);
      await controller.readConfigWithChunks(_device!);
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

              if (state.errorMessage != null)
                const SizedBox(height: 16),

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
                          child: Text(
                            state.statusMessage!,
                            style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                          ),
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
```

Note: Add `import 'package:app/controllers/saved_controller_controller.dart';` at the top for `_getAlias()`.

- [ ] **Step 2: Run analysis**

Run: `dart analyze lib/screens/switchhub_detail_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/switchhub_detail_screen.dart
git commit -m "feat: add SwitchHubDetailScreen with voltage threshold configuration"
```

---

### Task 5: Build UnifiedMonitoringScreen

**Files:**
- Modify: `lib/screens/unified_monitoring_screen.dart`

Merges PowerHub monitoring data (from `monitoringControllerProvider`) and SwitchHub monitoring data (from `switchHubControllerProvider`) into a single page. Shows all connected devices' real-time data without manual selection.

- [ ] **Step 1: Implement UnifiedMonitoringScreen**

Replace `lib/screens/unified_monitoring_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/controllers/switch_hub_controller.dart';
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
              // No devices connected
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

  Widget _buildPowerHubMonitoring(BuildContext context, monitoringData) {
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
                    _buildInfoChip(
                      '${monitoringData.inputVoltageVolts.toStringAsFixed(1)} V',
                      Icons.bolt, Colors.blue,
                    ),
                    if (monitoringData.controlZoneTempCelsius != null)
                      _buildInfoChip(
                        '${monitoringData.controlZoneTempCelsius!.toStringAsFixed(1)} °C',
                        Icons.thermostat, Colors.orange,
                      ),
                    _buildInfoChip(
                      '${monitoringData.calculatedTotalCurrent.toStringAsFixed(2)} A',
                      Icons.electrical_services, Colors.green,
                    ),
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
        // Status cards
        Row(
          children: [
            Expanded(
              child: VoltageMonitorWidget(
                monitoringData: state.monitoringData,
                size: VoltageMonitorSize.small,
              ),
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
                          Icon(state.isMonitoring ? Icons.sensors : Icons.sensors_off,
                            color: state.isMonitoring ? Colors.green : Colors.grey),
                          const SizedBox(width: 8),
                          const Text('监测状态', style: TextStyle(fontWeight: FontWeight.bold)),
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
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Detailed voltage monitor
        if (state.monitoringData != null)
          VoltageMonitorWidget(
            monitoringData: state.monitoringData,
            size: VoltageMonitorSize.medium,
          ),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Chip(
      label: Text(label),
      avatar: Icon(icon, size: 16, color: color),
      backgroundColor: color.withOpacity(0.1),
    );
  }

  Widget _buildCurrentBar(BuildContext context, String label, double current, Color color) {
    final maxCurrent = 5.0;
    final percentage = (current / maxCurrent).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('${current.toStringAsFixed(2)} A', style: const TextStyle(fontWeight: FontWeight.w500)),
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
            widthFactor: percentage,
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

  Color _getChannelColor(int index) {
    final colors = [Colors.red, Colors.green, Colors.blue, Colors.orange, Colors.purple, Colors.teal];
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
```

- [ ] **Step 2: Run analysis**

Run: `dart analyze lib/screens/unified_monitoring_screen.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/unified_monitoring_screen.dart
git commit -m "feat: add UnifiedMonitoringScreen merging PowerHub and SwitchHub data"
```

---

### Task 6: Clean up old screens

**Files:**
- Remove: `lib/screens/saved_controller_management_screen.dart`
- Remove: `lib/screens/device_control_screen.dart`
- Remove: `lib/screens/power_management_screen.dart`
- Remove: `lib/screens/switchhub_monitoring_screen.dart`
- Remove: `lib/screens/monitoring_screen.dart`

These files are no longer referenced from `main.dart` or any new screen. Remove them.

- [ ] **Step 1: Check for remaining references**

Run: `grep -r "saved_controller_management_screen\|device_control_screen\|power_management_screen\|switchhub_monitoring_screen\|monitoring_screen" lib/`
Expected: No imports referencing these files (they were only imported in main.dart, which was updated in Task 1).

- [ ] **Step 2: Remove old screen files**

```bash
rm lib/screens/saved_controller_management_screen.dart
rm lib/screens/device_control_screen.dart
rm lib/screens/power_management_screen.dart
rm lib/screens/switchhub_monitoring_screen.dart
rm lib/screens/monitoring_screen.dart
```

- [ ] **Step 3: Run full project analysis**

Run: `dart analyze`
Expected: No errors.

- [ ] **Step 4: Commit**

```bash
git add -A lib/screens/
git commit -m "refactor: remove old screens replaced by new navigation structure"
```

---

## Self-Review Checklist

**1. Spec coverage:**
- 3-tab navigation → Task 1
- Device list with PowerHub + SwitchHub → Task 2
- PowerHub detail with PWM + power management → Task 3
- SwitchHub detail with voltage thresholds → Task 4
- Unified monitoring → Task 5
- Remove old screens → Task 6
- Auto-load on detail entry → Tasks 3 & 4 (initState callbacks)
- No device selector in detail pages → Tasks 3 & 4 confirmed

**2. Placeholder scan:** No TBD, TODO, or incomplete steps found.

**3. Type consistency:** All controller/provider names match their definitions. `PowerManagementConfig` used consistently. `SwitchHubState` used consistently.
