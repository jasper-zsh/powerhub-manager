import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import 'package:app/providers/app_state_provider.dart';

class ConnectionStatus extends ConsumerWidget {
  const ConnectionStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = context.watch<AppStateProvider>();
    final session = ref.watch(connectionSessionControllerProvider);
    final telemetryState = ref.watch(monitoringControllerProvider);

    final telemetryData = telemetryState.value ?? appState.telemetry;
    final telemetryError = telemetryState.when<String?>(
      data: (_) => appState.telemetryError.isNotEmpty
          ? appState.telemetryError
          : null,
      loading: () => null,
      error: (error, _) => error.toString(),
    );

    final bool isConnected =
        session.isConnected || appState.selectedDevice?.isConnected == true;
    final statusText = _statusLabel(
      session,
      appState.selectedDevice?.name,
      appState.isConnected,
    );

    return Container(
      color: _resolveBackgroundColor(appState, session, isConnected),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(
                statusText,
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (telemetryData != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                _TelemetryChip(
                  label: 'Vin',
                  value:
                      '${(telemetryData.vinMillivolts / 1000.0).toStringAsFixed(2)} V',
                ),
                _TelemetryChip(
                  label: '温度',
                  value:
                      '${telemetryData.temperatureCelsius.toStringAsFixed(2)} °C',
                ),
                _TelemetryChip(
                  label: '高温阈值',
                  value:
                      '${telemetryData.highThresholdCelsius.toStringAsFixed(2)} °C',
                ),
                _TelemetryChip(
                  label: '恢复阈值',
                  value:
                      '${telemetryData.recoverThresholdCelsius.toStringAsFixed(2)} °C',
                ),
                _TelemetryChip(
                  label: '睡眠阈值',
                  value:
                      '${telemetryData.sleepThresholdVolts.toStringAsFixed(2)} V',
                ),
                _TelemetryChip(
                  label: '唤醒阈值',
                  value:
                      '${telemetryData.wakeThresholdVolts.toStringAsFixed(2)} V',
                ),
                if (appState.isThermalProtectionActive)
                  const _TelemetryChip(
                    label: '状态',
                    value: '热保护激活',
                    emphasize: true,
                  ),
              ],
            ),
          ] else if (telemetryError?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              telemetryError!,
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
  }

  String _statusLabel(
    ConnectionSessionState session,
    String? deviceName,
    bool appStateConnected,
  ) {
    final name = deviceName ?? 'device';
    return switch (session.lifecycle) {
      ConnectionLifecycle.connected => 'Connected to $name',
      ConnectionLifecycle.degraded => 'Connection degraded ($name)',
      ConnectionLifecycle.connecting => 'Connecting to $name…',
      ConnectionLifecycle.error => 'Connection error',
      ConnectionLifecycle.disconnected =>
          appStateConnected ? 'Connected to $name' : 'Not connected',
    };
  }

  Color? _resolveBackgroundColor(
    AppStateProvider appState,
    ConnectionSessionState session,
    bool resolvedConnection,
  ) {
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

    if (hasActiveConnections || resolvedConnection) {
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color.darken(),
                fontWeight: FontWeight.w600,
              ) ??
              TextStyle(color: color.darken()),
          children: [
            TextSpan(text: '$label '),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _TelemetryChip extends StatelessWidget {
  const _TelemetryChip({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final color = emphasize ? Colors.orange : Colors.blueGrey;
    return Chip(
      backgroundColor: color.withOpacity(0.1),
      label: Text('$label $value', style: TextStyle(color: color)),
    );
  }
}

extension _ColorBrightness on Color {
  Color darken([double amount = .2]) {
    final factor = 1 - amount;
    return Color.fromARGB(
      alpha,
      (red * factor).round(),
      (green * factor).round(),
      (blue * factor).round(),
    );
  }
}
