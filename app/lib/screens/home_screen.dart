import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/screens/channel_control_screen.dart';
import 'package:app/screens/preset_management_screen.dart';
import 'package:app/screens/telemetry_settings_screen.dart';
import 'package:app/widgets/connection_status.dart';

// For debugging
import 'package:flutter/foundation.dart';

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

              // Navigation buttons
              Expanded(
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
                                    builder: (context) =>
                                        const ChannelControlScreen(),
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
                              builder: (context) =>
                                  const PresetManagementScreen(),
                            ),
                          );
                        },
                        child: const Text('Preset Management'),
                      ),
                    ),
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

  Widget _buildConnectedDeviceSection(
    BuildContext context,
    AppStateProvider appState,
  ) {
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
