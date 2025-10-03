import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';

class ConnectionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          color: appState.selectedDevice?.isConnected ?? false
              ? Colors.green[100]
              : Colors.red[100],
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                appState.selectedDevice?.isConnected ?? false
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: appState.selectedDevice?.isConnected ?? false
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(
                appState.selectedDevice?.isConnected ?? false
                    ? 'Connected to ${appState.selectedDevice?.name ?? "device"}'
                    : 'Not connected',
                style: TextStyle(
                  color: appState.selectedDevice?.isConnected ?? false
                      ? Colors.green
                      : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}