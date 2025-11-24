import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/pwm_controller.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/screens/channel_control_screen.dart';
import 'package:app/screens/telemetry_settings_screen.dart';
import 'package:app/screens/switch_hub_screen.dart';
import 'package:app/widgets/connection_status.dart';
import 'package:app/widgets/saved_controller_list.dart';
import 'package:app/controllers/discovery_controller.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/device_control_controller.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveryState = ref.watch(discoveryControllerProvider);
    final savedControllersState = ref.watch(savedControllerControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);
    final deviceControlState = ref.watch(deviceControlControllerProvider);
    
    // 检查是否有已连接的设备
    final isConnected = connectionState.isConnected;
    final selectedDevice = connectionState.controllerId != null && isConnected
        ? PWMController(
            id: connectionState.controllerId!,
            name: 'Connected Device',
            rssi: 0,
            channels: deviceControlState.channels,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: discoveryState.isScanning
                ? null
                : () => ref
                    .read(discoveryControllerProvider.notifier)
                    .startScan(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: isConnected
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TelemetrySettingsScreen(),
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Connection status
          const ConnectionStatus(),

          // Device selection or connection button
          if (selectedDevice == null)
            _buildDeviceSelectionSection(
              context,
              ref,
              discoveryState,
            )
          else
            _buildConnectedDeviceSection(
              context,
              ref,
              selectedDevice,
              savedControllersState.controllers,
            ),

          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildSavedControllersSection(
                    context,
                    ref,
                    savedControllersState.controllers,
                  ),
                ),
                _buildNavigationSection(context, isConnected),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceSelectionSection(
    BuildContext context,
    WidgetRef ref,
    DiscoveryState discoveryState,
  ) {
    debugPrint(
      'Building device selection section. Discovered devices: ${discoveryState.devices.length}',
    );

    final devices = discoveryState.devices;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Select a device to connect',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (discoveryState.hasError)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Scan error: ${discoveryState.error}',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (discoveryState.isScanning)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                debugPrint('Scan button pressed');
                ref.read(discoveryControllerProvider.notifier).startScan();
              },
              child: const Text('Scan for Devices'),
            ),
          ),
        if (devices.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                debugPrint('Displaying device: ${device.name} (${device.id})');
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text('RSSI: ${device.rssi}'),
                  onTap: () {
                    debugPrint(
                      'User tapped on device: ${device.name} (${device.id})',
                    );
                    ref.read(connectionSessionControllerProvider.notifier)
                        .connect(device.id);
                  },
                );
              },
            ),
          )
        else if (!discoveryState.isScanning)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No devices found. Tap "Scan for Devices" to search.'),
          ),
      ],
    );
  }

  Widget _buildSavedControllersSection(
    BuildContext context,
    WidgetRef ref,
    List<SavedController> controllers,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              title: Text('Saved Controllers'),
              subtitle: Text('Reconnect quickly using saved aliases'),
            ),
            const Divider(height: 1),
            Expanded(
              child: SavedControllerList(
                controllers: controllers,
                emptyState: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No saved controllers yet. Save a device to reuse it later.',
                  ),
                ),
                onRename: (controller) => _promptRenameSavedController(
                  context,
                  ref,
                  controller,
                ),
                onRemove: (controller) => _confirmRemoveSavedController(
                  context,
                  ref,
                  controller,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationSection(
    BuildContext context,
    bool isConnected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: isConnected
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ChannelControlScreen(),
                        ),
                      );
                    }
                  : null,
              child: const Text('Channel Control'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SwitchHubScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.settings_remote),
              label: const Text('SwitchHub 管理'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedDeviceSection(
    BuildContext context,
    WidgetRef ref,
    PWMController selectedDevice,
    List<SavedController> savedControllers,
  ) {
    final isAlreadySaved = savedControllers.any(
      (saved) => saved.controllerId == selectedDevice.id,
    );

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Connected Device',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                selectedDevice.name,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  debugPrint('Disconnect button pressed');
                  ref.read(connectionSessionControllerProvider.notifier).disconnect();
                },
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isAlreadySaved
                  ? null
                  : () => _promptSaveController(context, ref, selectedDevice),
              icon: const Icon(Icons.save_alt),
              label: Text(
                isAlreadySaved ? 'Device Saved' : 'Save Device',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _promptSaveController(
    BuildContext context,
    WidgetRef ref,
    PWMController pwm,
  ) async {
    final aliasController = TextEditingController(text: pwm.name);

    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Save Controller'),
          content: TextField(
            controller: aliasController,
            decoration: const InputDecoration(
              labelText: 'Alias',
              hintText: 'e.g. Living Room',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(aliasController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    aliasController.dispose();

    if (alias == null || alias.isEmpty) {
      return;
    }

    try {
      await ref
          .read(savedControllerControllerProvider.notifier)
          .createController(controllerId: pwm.id, alias: alias);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved controller "$alias".')),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ?? 'Alias already exists. Try another.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save controller: $error')),
      );
    }
  }

  Future<void> _promptRenameSavedController(
    BuildContext context,
    WidgetRef ref,
    SavedController controller,
  ) async {
    final aliasController = TextEditingController(text: controller.alias);

    final alias = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Controller'),
          content: TextField(
            controller: aliasController,
            decoration: const InputDecoration(
              labelText: 'New alias',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(aliasController.text.trim());
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    aliasController.dispose();

    if (alias == null || alias.isEmpty || alias == controller.alias) {
      return;
    }

    try {
      await ref
          .read(savedControllerControllerProvider.notifier)
          .renameController(controller.controllerId, alias);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed controller to "$alias".')),
      );
    } on ArgumentError catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message?.toString() ?? 'Alias already exists.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename controller: $error')),
      );
    }
  }

  Future<void> _confirmRemoveSavedController(
    BuildContext context,
    WidgetRef ref,
    SavedController controller,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove Controller'),
          content: Text(
            'Are you sure you want to remove "${controller.alias}" from saved controllers?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    try {
      await ref
          .read(savedControllerControllerProvider.notifier)
          .removeController(controller.controllerId);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed controller "${controller.alias}".'),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove controller: $error')),
      );
    }
  }
}
