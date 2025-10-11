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
            ],
          ),
        );
      },
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
