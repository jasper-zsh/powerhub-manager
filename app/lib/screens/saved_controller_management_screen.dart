import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/models/pwm_controller.dart';
import 'package:app/models/telemetry.dart';

class SavedControllerManagementScreen extends StatefulWidget {
  const SavedControllerManagementScreen({super.key});

  @override
  State<SavedControllerManagementScreen> createState() =>
      _SavedControllerManagementScreenState();
}

class _SavedControllerManagementScreenState
    extends State<SavedControllerManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AppStateProvider, OrchestrationProvider>(
      builder: (context, appState, orchestration, child) {
        final controllers = appState.savedControllers;
        orchestration.updateControllerIndex(
          controllers.map((controller) => controller.controllerId),
        );
        final dependencies = orchestration.controllerDependencies;

        return Column(
          children: [
            _DiscoveryPanel(appState: appState, controllers: controllers),
            if (orchestration.missingControllers.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scenes reference controllers that are no longer saved: '
                        '${orchestration.missingControllers.join(', ')}',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: controllers.isEmpty
                  ? const Center(child: Text('No saved controllers yet.'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 24, top: 8),
                      itemCount: controllers.length,
                      onReorder: (oldIndex, newIndex) {
                        appState.reorderSavedControllers(oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final controller = controllers[index];
                        final scenes =
                            dependencies[controller.controllerId] ?? {};
                        PWMController? connectedDevice;
                        if (appState.selectedDevice?.id ==
                            controller.controllerId) {
                          connectedDevice = appState.selectedDevice;
                        } else {
                          try {
                            connectedDevice = appState.connectedControllers
                                .firstWhere(
                                  (device) =>
                                      device.id == controller.controllerId,
                                );
                          } catch (_) {
                            connectedDevice = null;
                          }
                        }

                        final telemetry =
                            appState.selectedDevice?.id ==
                                controller.controllerId
                            ? appState.telemetry ?? connectedDevice?.telemetry
                            : connectedDevice?.telemetry;
                        final isConnected =
                            connectedDevice?.isConnected ??
                            controller.connectionStatus ==
                                SavedControllerConnectionStatus.connected;
                        return ListTile(
                          key: ValueKey(controller.controllerId),
                          leading: const Icon(Icons.drag_handle),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(controller.alias),
                              if (isConnected && telemetry != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _MiniTelemetryChip(
                                        label: 'Vin',
                                        value:
                                            '${(telemetry.vinMillivolts / 1000).toStringAsFixed(1)}V',
                                      ),
                                      const SizedBox(width: 4),
                                      _MiniTelemetryChip(
                                        label: '温度',
                                        value:
                                            '${telemetry.temperatureCelsius.toStringAsFixed(1)}°C',
                                        color:
                                            telemetry.temperatureCelsius >=
                                                telemetry.highThresholdCelsius
                                            ? Colors.orange
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${controller.controllerId}'),
                              Text(
                                'Status: ${controller.connectionStatus.name}',
                              ),
                              if (scenes.isNotEmpty)
                                Text('Used in: ${scenes.join(', ')}'),
                            ],
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Rename',
                                onPressed: () =>
                                    _renameController(context, controller),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                tooltip: 'Remove',
                                onPressed: () => _removeController(
                                  context,
                                  appState,
                                  controller,
                                  scenes,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _renameController(
    BuildContext context,
    SavedController controller,
  ) async {
    final provider = context.read<AppStateProvider>();
    final aliasController = TextEditingController(text: controller.alias);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rename controller'),
          content: TextField(
            controller: aliasController,
            decoration: const InputDecoration(labelText: 'Alias'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(aliasController.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty || result == controller.alias) {
      return;
    }

    try {
      await provider.renameSavedController(controller.controllerId, result);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Renamed to "$result"')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rename failed: $error')));
      }
    }
  }

  Future<void> _removeController(
    BuildContext context,
    AppStateProvider provider,
    SavedController controller,
    Set<String> scenes,
  ) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove controller'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove "${controller.alias}" from saved controllers?'),
              if (scenes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Used in scenes: ${scenes.join(', ')}',
                  style: const TextStyle(color: Colors.orange),
                ),
                const Text('Those scenes will need to be updated.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
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
      await provider.removeSavedController(controller.controllerId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Removed ${controller.alias}')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to remove: $error')));
      }
    }
  }
}

class _DiscoveryPanel extends StatelessWidget {
  const _DiscoveryPanel({required this.appState, required this.controllers});

  final AppStateProvider appState;
  final List<SavedController> controllers;

  @override
  Widget build(BuildContext context) {
    final savedIds = controllers
        .map((controller) => controller.controllerId)
        .toSet();
    final candidates = appState.discoveredDevices
        .where((device) => !savedIds.contains(device.id))
        .toList();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Nearby Devices',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (appState.isScanning)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.search),
                  label: Text(appState.isScanning ? 'Scanning...' : 'Scan'),
                  onPressed: appState.isScanning
                      ? null
                      : () => appState.scanForDevices(),
                ),
              ],
            ),
            if (appState.errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  appState.errorMessage,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 12),
            if (appState.isScanning)
              const Text('Scanning for PowerHub controllers...')
            else if (candidates.isEmpty)
              Text(
                'No new devices found. Make sure your controller is powered on and in pairing range.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              )
            else
              ...candidates.map(
                (device) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    device.name.isNotEmpty ? device.name : 'PowerHub',
                  ),
                  subtitle: Text('ID: ${device.id} — RSSI ${device.rssi}'),
                  trailing: TextButton(
                    child: const Text('Save'),
                    onPressed: () => _promptSaveController(context, device),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptSaveController(
    BuildContext context,
    PWMController device,
  ) async {
    final appState = context.read<AppStateProvider>();
    final aliasController = TextEditingController(
      text: device.name.isNotEmpty ? device.name : 'PowerHub',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save controller'),
        content: TextField(
          controller: aliasController,
          decoration: const InputDecoration(labelText: 'Alias'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(aliasController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    try {
      await appState.saveController(controllerId: device.id, alias: result);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Saved "$result"')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save controller: $error')),
        );
      }
    }
  }
}

class _MiniTelemetryChip extends StatelessWidget {
  const _MiniTelemetryChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: resolvedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(fontSize: 11, color: resolvedColor),
      ),
    );
  }
}
