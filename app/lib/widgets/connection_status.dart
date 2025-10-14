import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';

class ConnectionStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, child) {
        return Container(
          color: _resolveBackgroundColor(appState),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
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
              if (appState.telemetry != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _TelemetryChip(
                      label: 'Vin',
                      value:
                          '${(appState.telemetry!.vinMillivolts / 1000.0).toStringAsFixed(2)} V',
                    ),
                    _TelemetryChip(
                      label: '温度',
                      value:
                          '${appState.telemetry!.temperatureCelsius.toStringAsFixed(2)} °C',
                    ),
                    _TelemetryChip(
                      label: '高温阈值',
                      value:
                          '${appState.telemetry!.highThresholdCelsius.toStringAsFixed(2)} °C',
                    ),
                    _TelemetryChip(
                      label: '恢复阈值',
                      value:
                          '${appState.telemetry!.recoverThresholdCelsius.toStringAsFixed(2)} °C',
                    ),
                    _TelemetryChip(
                      label: '睡眠阈值',
                      value:
                          '${appState.telemetry!.sleepThresholdVolts.toStringAsFixed(2)} V',
                    ),
                    _TelemetryChip(
                      label: '唤醒阈值',
                      value:
                          '${appState.telemetry!.wakeThresholdVolts.toStringAsFixed(2)} V',
                    ),
                    if (appState.isThermalProtectionActive)
                      const _TelemetryChip(
                        label: '状态',
                        value: '热保护激活',
                        emphasize: true,
                      ),
                  ],
                ),
              ] else if (appState.telemetryError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  appState.telemetryError,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
              if (appState.savedControllers.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SavedControllersSummary(appState: appState),
              ],
            ],
          ),
        );
      },
    );
  }

  Color? _resolveBackgroundColor(AppStateProvider appState) {
    final hasActiveConnections = appState.connectionStatusRecords.any(
      (record) =>
          record.controller.connectionStatus ==
          SavedControllerConnectionStatus.connected,
    );

    final hasAlerts = appState.connectionStatusRecords.any(
      (record) => record.controller.connectionStatus ==
          SavedControllerConnectionStatus.unavailable,
    );

    if (hasAlerts) {
      return Colors.orange[100];
    }

    if (hasActiveConnections || (appState.selectedDevice?.isConnected ?? false)) {
      return Colors.green[100];
    }

    return Colors.red[100];
  }
}

class _SavedControllersSummary extends StatelessWidget {
  const _SavedControllersSummary({required this.appState});

  final AppStateProvider appState;

  @override
  Widget build(BuildContext context) {
    final summary = appState.connectionDashboardSummary;
    final records = appState.connectionStatusRecords;
    final scanningCount = records
        .where((record) => record.scanState == ScanState.scanning)
        .length;
    final waitingCount = records
        .where((record) => record.scanState == ScanState.waitingRetry)
        .length;
    final unavailableAliases = records
        .where((record) =>
            record.controller.connectionStatus ==
            SavedControllerConnectionStatus.unavailable)
        .map((record) => record.controller.alias)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            _StatusChip(
              label: 'Saved',
              value: summary.totalSaved.toString(),
              color: Colors.blueGrey,
            ),
            _StatusChip(
              label: 'Connected',
              value: summary.connectedCount.toString(),
              color: Colors.green,
            ),
            if (scanningCount > 0)
              _StatusChip(
                label: 'Scanning',
                value: scanningCount.toString(),
                color: Colors.indigo,
              ),
            if (waitingCount > 0)
              _StatusChip(
                label: 'Retrying',
                value: waitingCount.toString(),
                color: Colors.orange,
              ),
            if (summary.unavailableCount > 0)
              _StatusChip(
                label: 'Unavailable',
                value: summary.unavailableCount.toString(),
                color: Colors.red,
              ),
          ],
        ),
        if (scanningCount > 0)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Scanning saved controllers…',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (waitingCount > 0)
          const Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Text(
              'Retrying connections shortly.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        if (unavailableAliases.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              'Unreachable: ${unavailableAliases.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: RichText(
        text: TextSpan(
          style: TextStyle(color: color, fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _TelemetryChip({
    Key? key,
    required this.label,
    required this.value,
    this.emphasize = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = emphasize
        ? colorScheme.error.withOpacity(0.1)
        : colorScheme.primary.withOpacity(0.05);
    final textColor = emphasize ? colorScheme.error : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(color: textColor, fontSize: 12),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
