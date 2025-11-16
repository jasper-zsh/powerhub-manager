import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/controllers/discovery_controller.dart';
import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/models/pwm_controller.dart';

class SavedControllerManagementScreen extends ConsumerWidget {
  const SavedControllerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(savedControllerControllerProvider);
    final connectionState = ref.watch(connectionSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Controllers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(savedControllerControllerProvider.notifier).loadControllers();
            },
          ),
        ],
      ),
      body: state.controllers.isEmpty
          ? _buildEmptyState(context, ref, state)
          : _buildControllerList(context, ref, state),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddControllerDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, SavedControllerState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.storage_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No saved controllers',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first controller to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddControllerDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add Controller'),
          ),
        ],
      ),
    );
  }

  Widget _buildControllerList(
    BuildContext context,
    WidgetRef ref,
    SavedControllerState state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.controllers.length,
      itemBuilder: (context, index) {
        final controller = state.controllers[index];
        final connectionState = ref.watch(connectionSessionControllerProvider);
        final isConnected = connectionState.isConnected &&
                           connectionState.controllerId == controller.controllerId;
        final isConnecting = connectionState.lifecycle == ConnectionLifecycle.connecting &&
                            connectionState.controllerId == controller.controllerId;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isConnected
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              child: Icon(
                Icons.bluetooth,
                color: isConnected ? Colors.green : Colors.grey,
              ),
            ),
            title: Text(
              controller.alias,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isConnected ? Colors.green : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.controllerId),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Connection status indicator
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
                      isConnecting
                          ? 'Connecting...'
                          : isConnected
                              ? 'Connected'
                              : 'Disconnected',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConnecting
                            ? Colors.orange
                            : isConnected
                                ? Colors.green
                                : Colors.grey,
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
                // Connect/Disconnect button
                if (!isConnected && !isConnecting)
                  IconButton(
                    icon: const Icon(Icons.bluetooth_connected, size: 20),
                    onPressed: () => _connectToDevice(context, ref, controller.controllerId),
                    tooltip: 'Connect',
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
                    tooltip: 'Disconnect',
                  ),
                // More options menu
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'connect',
                      child: ListTile(
                        leading: Icon(Icons.bluetooth_connected),
                        title: Text('Connect'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: ListTile(
                        leading: Icon(Icons.bluetooth_disabled),
                        title: Text('Disconnect'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        leading: Icon(Icons.edit),
                        title: Text('Rename'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete),
                        title: Text('Delete'),
                      ),
                    ),
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
              if (isConnected) {
                _showControllerDetails(context, controller);
              } else {
                _showControllerDetails(context, controller);
              }
            },
          ),
        );
      },
    );
  }

  void _showAddControllerDialog(BuildContext context, WidgetRef ref) {
    final aliasController = TextEditingController();
    final notesController = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Controller'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'First, scan for available devices, then select one to add.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: aliasController,
                  decoration: const InputDecoration(
                    labelText: 'Controller Alias',
                    hintText: 'Enter a name for this controller',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    hintText: 'Enter any notes about this controller',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Choice between real device and sample
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showDeviceSelectionDialog(context, ref, aliasController.text),
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Select Real Device'),
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
                        label: const Text('Add Sample'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Choose: Scan for real PowerHub devices, or add a sample controller for testing.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
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
            title: const Text('Select Device'),
            content: SizedBox(
              width: double.maxFinite,
              height: 450,
              child: Column(
                children: [
                  // Scanning status indicator
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
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Scanning for devices...',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  'Found ${discoveryState.devices.length} device${discoveryState.devices.length == 1 ? '' : 's'}',
                                  style: TextStyle(
                                    color: Colors.blue.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Device list or empty state
                  if (discoveryState.devices.isEmpty && !discoveryState.isScanning)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No devices found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try scanning again or check if your device is powered on',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (discoveryState.devices.isEmpty && discoveryState.isScanning)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_searching, size: 48, color: Colors.blue),
                            const SizedBox(height: 16),
                            const Text('Searching for PowerHub devices...'),
                            const SizedBox(height: 8),
                            const Text(
                              'Make sure your device is turned on and nearby',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Devices (${discoveryState.devices.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: discoveryState.devices.length,
                              itemBuilder: (context, index) {
                                final device = discoveryState.devices[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                      child: Icon(
                                        Icons.bluetooth,
                                        color: Theme.of(context).primaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      device.name.isNotEmpty ? device.name : 'Unknown Device',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('ID: ${device.id}'),
                                        if (device.isConnected) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'Connected',
                                              style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      Navigator.of(context).pop(); // Close both dialogs
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
                child: const Text('Cancel'),
              ),
              if (!discoveryState.isScanning)
                ElevatedButton.icon(
                  onPressed: () {
                    ref.read(discoveryControllerProvider.notifier).startScan();
                  },
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text('Scan for Devices'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    // Just show a message that scanning will stop automatically
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Scanning will stop automatically when devices are found or timeout'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Auto-Scan'),
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

      final controller = SavedController(
        controllerId: device.id,
        alias: controllerAlias,
        notes: 'Added from device discovery on ${DateTime.now().toString().substring(0, 19)}\n'
                'Device: $deviceName\n'
                'ID: ${device.id}',
        deviceCapabilities: const DeviceCapabilities(
          channels: 6,
          supportsPresets: false,
        ),
      );

      await ref.read(savedControllerControllerProvider.notifier).createController(
        controllerId: controller.controllerId,
        alias: controller.alias,
        notes: controller.notes,
        deviceCapabilities: controller.deviceCapabilities,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$controllerAlias added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add controller: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _addSampleController(BuildContext context, WidgetRef ref, String alias, String notes) async {
    if (alias.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a controller alias'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final controller = SavedController(
        controllerId: 'sample_${DateTime.now().millisecondsSinceEpoch}',
        alias: alias.trim(),
        notes: notes.trim().isEmpty ? null : notes.trim(),
        deviceCapabilities: const DeviceCapabilities(
          channels: 6,
          supportsPresets: false,
        ),
      );

      await ref.read(savedControllerControllerProvider.notifier).createController(
        controllerId: controller.controllerId,
        alias: controller.alias,
        notes: controller.notes,
        deviceCapabilities: controller.deviceCapabilities,
      );

      Navigator.of(context).pop(); // Close the add dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${controller.alias} added successfully (Sample)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add sample controller: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    SavedController controller,
  ) {
    final textController = TextEditingController(text: controller.alias);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Controller'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Controller Name',
            hintText: 'Enter a name for this controller',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
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
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    String controllerId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Controller'),
        content: const Text('Are you sure you want to delete this saved controller?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(savedControllerControllerProvider.notifier).removeController(controllerId);
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showControllerDetails(BuildContext context, SavedController controller) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) {
          final connectionState = ref.watch(connectionSessionControllerProvider);
          final isConnected = connectionState.isConnected &&
                             connectionState.controllerId == controller.controllerId;
          final isConnecting = connectionState.lifecycle == ConnectionLifecycle.connecting &&
                              connectionState.controllerId == controller.controllerId;

          return AlertDialog(
            title: Text(controller.alias),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Controller ID: ${controller.controllerId}'),
                const SizedBox(height: 8),

                // Connection status
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
                    const SizedBox(width: 8),
                    Text(
                      isConnecting
                          ? 'Connecting...'
                          : isConnected
                              ? 'Connected'
                              : 'Disconnected',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: isConnecting
                            ? Colors.orange
                            : isConnected
                                ? Colors.green
                                : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (controller.deviceCapabilities != null) ...[
                  Text(
                    'Device Capabilities:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('Channels: ${controller.deviceCapabilities!.channels}'),
                  Text('Presets: ${controller.deviceCapabilities!.supportsPresets == true ? "Yes" : "No"}'),
                  const SizedBox(height: 8),
                ],

                if (controller.notes != null && controller.notes!.isNotEmpty) ...[
                  Text(
                    'Notes:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(controller.notes!),
                  const SizedBox(height: 8),
                ],

                if (isConnected) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Device is ready for control',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (!isConnected && !isConnecting)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _connectToDevice(context, ref, controller.controllerId);
                  },
                  icon: const Icon(Icons.bluetooth_connected, size: 16),
                  label: const Text('Connect'),
                )
              else if (isConnecting)
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: const Text('Connecting...'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _disconnectDevice(context, ref);
                  },
                  icon: const Icon(Icons.bluetooth_disabled, size: 16),
                  label: const Text('Disconnect'),
                ),

              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _connectToDevice(BuildContext context, WidgetRef ref, String controllerId) async {
    try {
      await ref.read(connectionSessionControllerProvider.notifier).connect(controllerId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to $controllerId'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _disconnectDevice(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(connectionSessionControllerProvider.notifier).disconnect();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from device'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}