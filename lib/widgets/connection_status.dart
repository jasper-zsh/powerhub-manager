import 'package:app/controllers/connection_session_controller.dart';
import 'package:app/controllers/monitoring_controller.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionStatus extends ConsumerWidget {
  const ConnectionStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(connectionSessionControllerProvider);
    final monitoringState = ref.watch(monitoringControllerProvider);
    final savedControllersState = ref.watch(savedControllerControllerProvider);

    final monitoringData = monitoringState.value;
    final monitoringError = monitoringState.when<String?>(
      data: (_) => null,
      loading: () => null,
      error: (error, _) => error.toString(),
    );

    SavedController? selectedController;
    if (session.controllerId != null) {
      try {
        selectedController = savedControllersState.controllers.firstWhere(
          (controller) => controller.controllerId == session.controllerId,
        );
      } catch (_) {}
    }

    final bool isConnected = session.isConnected;
    final statusText = _statusLabel(
      session,
      selectedController?.alias ?? session.controllerId,
    );

    return Container(
      color: _resolveBackgroundColor(
        savedControllersState.controllers,
        isConnected,
      ),
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
          if (monitoringData != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 4,
              children: [
                _TelemetryChip(
                  label: 'Vin',
                  value: '${monitoringData.inputVoltageVolts.toStringAsFixed(2)} V',
                ),
                if (monitoringData.powerZoneTempCelsius != null)
                  _TelemetryChip(
                    label: '功率区温度',
                    value:
                        '${monitoringData.powerZoneTempCelsius!.toStringAsFixed(1)} °C',
                  ),
                if (monitoringData.controlZoneTempCelsius != null)
                  _TelemetryChip(
                    label: '控制区温度',
                    value:
                        '${monitoringData.controlZoneTempCelsius!.toStringAsFixed(1)} °C',
                  ),
                _TelemetryChip(
                  label: '总电流 (calc)',
                  value:
                      '${monitoringData.calculatedTotalCurrent.toStringAsFixed(2)} A',
                ),
                if (monitoringData.isThermalProtectionActive)
                  const _TelemetryChip(
                    label: '状态',
                    value: '热保护激活',
                    emphasize: true,
                  ),
              ],
            ),
          ] else if (monitoringError?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              monitoringError!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
          if (savedControllersState.controllers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SavedControllersSummary(
              controllers: savedControllersState.controllers,
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(
    ConnectionSessionState session,
    String? deviceName,
  ) {
    final name = deviceName ?? 'device';
    return switch (session.lifecycle) {
      ConnectionLifecycle.connected => 'Connected to $name',
      ConnectionLifecycle.degraded => 'Connection degraded ($name)',
      ConnectionLifecycle.connecting => 'Connecting to $name…',
      ConnectionLifecycle.error => 'Connection error',
      ConnectionLifecycle.disconnected => 'Not connected',
    };
  }

  Color? _resolveBackgroundColor(
    List<SavedController> controllers,
    bool resolvedConnection,
  ) {
    final summary = ConnectionDashboardSummary.fromControllers(controllers);
    final hasAlerts = summary.unavailableCount > 0;
    final hasActiveConnections =
        summary.connectedCount > 0 || summary.recoveringCount > 0;

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
  const _SavedControllersSummary({required this.controllers});

  final List<SavedController> controllers;

  @override
  Widget build(BuildContext context) {
    final summary = ConnectionDashboardSummary.fromControllers(controllers);
    final unavailableAliases = controllers
        .where(
          (controller) =>
              controller.connectionStatus ==
              SavedControllerConnectionStatus.unavailable,
        )
        .map((controller) => controller.alias)
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
            if (summary.recoveringCount > 0)
              _StatusChip(
                label: 'Recovering',
                value: summary.recoveringCount.toString(),
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
