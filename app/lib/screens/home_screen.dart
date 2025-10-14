import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/screens/channel_control_screen.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/screens/preset_management_screen.dart';
import 'package:app/screens/telemetry_settings_screen.dart';
import 'package:app/widgets/connection_status.dart';
import 'package:app/widgets/saved_controller_list.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('PowerHub Manager'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: appState.isScanning
                    ? null
                    : () => appState.scanForDevices(),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: appState.isConnected
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const TelemetrySettingsScreen(),
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
              ConnectionStatus(),

              // Device selection or connection button
              if (appState.selectedDevice == null)
                _buildDeviceSelectionSection(context, appState)
              else
                _buildConnectedDeviceSection(context, appState),

              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildSavedControllersSection(
                        context,
                        appState,
                      ),
                    ),
                    _buildNavigationSection(context, appState),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceSelectionSection(
    BuildContext context,
    AppStateProvider appState,
  ) {
    debugPrint(
      'Building device selection section. Discovered devices: ${appState.discoveredDevices.length}',
    );

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Select a device to connect',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (appState.errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              appState.errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        if (appState.isScanning)
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
                appState.scanForDevices();
              },
              child: const Text('Scan for Devices'),
            ),
          ),
        if (appState.discoveredDevices.isNotEmpty)
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemCount: appState.discoveredDevices.length,
              itemBuilder: (context, index) {
                final device = appState.discoveredDevices[index];
                debugPrint('Displaying device: ${device.name} (${device.id})');
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text('RSSI: ${device.rssi}'),
                  onTap: () {
                    debugPrint(
                      'User tapped on device: ${device.name} (${device.id})',
                    );
                    appState.connectToDevice(device.id);
                  },
                );
              },
            ),
          )
        else if (!appState.isScanning)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No devices found. Tap "Scan for Devices" to search.'),
          ),
      ],
    );
  }

  Widget _buildSavedControllersSection(
    BuildContext context,
    AppStateProvider appState,
  ) {
    final statusRecords = {
      for (final record in appState.connectionStatusRecords)
        record.controller.controllerId: record,
    };

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
                controllers: appState.savedControllers,
                emptyState: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No saved controllers yet. Save a device to reuse it later.',
                  ),
                ),
                statusRecords: statusRecords,
                onRename: (controller) => _promptRenameSavedController(
                  context,
                  appState,
                  controller,
                ),
                onRemove: (controller) => _confirmRemoveSavedController(
                  context,
                  appState,
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
    AppStateProvider appState,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: appState.selectedDevice != null
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
          const SizedBox(height: 20),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PresetManagementScreen(),
                  ),
                );
              },
              child: const Text('Preset Management'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _promptSaveController(
    BuildContext context,
    AppStateProvider appState,
  ) async {
    final pwm = appState.selectedDevice;
    if (pwm == null) {
      return;
    }

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
      await appState.saveController(
        controllerId: pwm.id,
        alias: alias,
      );

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
    AppStateProvider appState,
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
      await appState.renameSavedController(controller.controllerId, alias);

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
    AppStateProvider appState,
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
      await appState.removeSavedController(controller.controllerId);

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

  Widget _buildConnectedDeviceSection(
    BuildContext context,
    AppStateProvider appState,
  ) {
    final isAlreadySaved = appState.savedControllers.any(
      (saved) => saved.controllerId == appState.selectedDevice?.id,
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
                appState.selectedDevice!.name,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  debugPrint('Disconnect button pressed');
                  appState.disconnectFromDevice();
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
                  : () => _promptSaveController(context, appState),
              icon: const Icon(Icons.save_alt),
              label: Text(
                isAlreadySaved ? 'Device Saved' : 'Save Device',
              ),
            ),
          ),
        ),
        if (appState.errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              appState.errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }
}
