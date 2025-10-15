import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/models/connection_status_record.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/providers/device_control_provider.dart';
import 'package:app/widgets/channel_control_card.dart';

class DeviceControlScreen extends StatelessWidget {
  const DeviceControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeviceControlProvider, AppStateProvider>(
      builder: (context, provider, appState, child) {
        if (provider.savedControllers.isEmpty) {
          return const Center(child: Text('No saved controllers available.'));
        }

        final saved = provider.selectedSavedController;
        if (saved == null) {
          return const Center(child: Text('Select a controller to begin.'));
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButton<String>(
                value: saved.controllerId,
                isExpanded: true,
                onChanged: (value) {
                  if (value != null) {
                    provider.selectController(value);
                  }
                },
                items: provider.savedControllers
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item.controllerId,
                        child: Text(
                          '${item.alias}${item.connectionStatus == SavedControllerConnectionStatus.connected ? '' : ' (offline)'}',
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _ConnectionMonitor(provider: provider, appState: appState),
                    const SizedBox(height: 12),
                    if (!provider.isSelectedControllerConnected)
                      _OfflineNotice(name: saved.alias)
                    else ...[
                      _ChannelSection(provider: provider, appState: appState),
                      const SizedBox(height: 24),
                      _PresetSection(provider: provider),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ConnectionMonitor extends StatelessWidget {
  const _ConnectionMonitor({required this.provider, required this.appState});

  final DeviceControlProvider provider;
  final AppStateProvider appState;

  @override
  Widget build(BuildContext context) {
    final selectedId = provider.selectedControllerId;
    final saved = provider.selectedSavedController;
    final activeDevice = provider.activeDevice;

    ConnectionStatusRecord? record;
    if (selectedId != null) {
      try {
        record = appState.connectionStatusRecords.firstWhere(
          (item) => item.controller.controllerId == selectedId,
        );
      } catch (_) {
        record = null;
      }
    }

    final connectionStatus =
        record?.controller.connectionStatus ??
        saved?.connectionStatus ??
        SavedControllerConnectionStatus.disconnected;
    final isConnected =
        activeDevice?.isConnected ??
        connectionStatus == SavedControllerConnectionStatus.connected;

    final statusLabel = switch (connectionStatus) {
      SavedControllerConnectionStatus.connected => '已连接',
      SavedControllerConnectionStatus.connecting => '正在连接…',
      SavedControllerConnectionStatus.unavailable => '不可用',
      SavedControllerConnectionStatus.disconnected => '未连接',
    };

    final Color statusColor = switch (connectionStatus) {
      SavedControllerConnectionStatus.connected => Colors.green,
      SavedControllerConnectionStatus.connecting => Colors.indigo,
      SavedControllerConnectionStatus.unavailable => Colors.orange,
      SavedControllerConnectionStatus.disconnected => Colors.redAccent,
    };

    final aliasMap = {
      for (final savedController in appState.savedControllers)
        savedController.controllerId: savedController.alias,
    };

    final telemetry = (appState.selectedDevice?.id == selectedId)
        ? appState.telemetry
        : activeDevice?.telemetry;
    final telemetryError = (appState.selectedDevice?.id == selectedId)
        ? appState.telemetryError
        : '';

    final scanningMessage = switch (record?.scanState) {
      ScanState.scanning => '正在扫描此设备…',
      ScanState.waitingRetry =>
        record?.nextRetryAt != null ? '等待重试 ${record!.nextRetryAt}' : '等待重试…',
      _ => null,
    };

    final rssiText = activeDevice != null
        ? 'RSSI: ${activeDevice.rssi} dBm'
        : null;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isConnected ? Colors.green[50] : Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aliasMap[selectedId] ??
                            activeDevice?.name ??
                            selectedId ??
                            '未命名设备',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _StatusPill(label: statusLabel, color: statusColor),
                          if (rssiText != null)
                            _StatusPill(
                              label: rssiText,
                              color: Colors.blueGrey,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (scanningMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                scanningMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (telemetry != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _TelemetryChip(
                    label: '电压',
                    value:
                        '${(telemetry.vinMillivolts / 1000.0).toStringAsFixed(2)} V',
                  ),
                  _TelemetryChip(
                    label: '温度',
                    value:
                        '${telemetry.temperatureCelsius.toStringAsFixed(1)} °C',
                  ),
                  _TelemetryChip(
                    label: '高温阈值',
                    value:
                        '${telemetry.highThresholdCelsius.toStringAsFixed(1)} °C',
                  ),
                  _TelemetryChip(
                    label: '恢复阈值',
                    value:
                        '${telemetry.recoverThresholdCelsius.toStringAsFixed(1)} °C',
                  ),
                  _TelemetryChip(
                    label: '睡眠阈值',
                    value:
                        '${telemetry.sleepThresholdVolts.toStringAsFixed(2)} V',
                  ),
                  _TelemetryChip(
                    label: '唤醒阈值',
                    value:
                        '${telemetry.wakeThresholdVolts.toStringAsFixed(2)} V',
                  ),
                  if (telemetry.isThermalProtectionActive)
                    const _TelemetryChip(
                      label: '热保护',
                      value: '激活',
                      emphasize: true,
                    ),
                ],
              ),
            ] else if (telemetryError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                telemetryError,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 11,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name is offline',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.orange),
            ),
            const SizedBox(height: 8),
            const Text(
              'Controller is offline. Please reconnect to make adjustments.',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelSection extends StatelessWidget {
  const _ChannelSection({required this.provider, required this.appState});

  final DeviceControlProvider provider;
  final AppStateProvider appState;

  @override
  Widget build(BuildContext context) {
    final channels = provider.channels;
    if (channels.isEmpty) {
      return const Text(
        'No channel data available yet. Adjust after connecting.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('控制每个通道的执行方式', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          '支持即时设置、渐变、闪烁与爆闪命令。设置参数后发送至控制器。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (appState.errorMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              appState.errorMessage,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...channels.map(
          (channel) => ChannelControlCard(
            channelId: channel.id,
            channelName: channel.name.isNotEmpty
                ? channel.name
                : 'Channel ${channel.id + 1}',
            value: channel.value,
            onSetValue: (value) => provider.handleSetValue(channel.id, value),
            onFadeCommand: (targetValue, duration) =>
                provider.sendFadeCommand(channel.id, targetValue, duration),
            onBlinkCommand: (period) =>
                provider.sendBlinkCommand(channel.id, period),
            onStrobeCommand: (flashCount, totalDuration, pauseDuration) =>
                provider.sendStrobeCommand(
                  channel.id,
                  flashCount,
                  totalDuration,
                  pauseDuration,
                ),
          ),
        ),
      ],
    );
  }
}

class _PresetSection extends StatelessWidget {
  const _PresetSection({required this.provider});

  final DeviceControlProvider provider;

  @override
  Widget build(BuildContext context) {
    final presets = provider.presets;
    if (presets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Presets', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: presets
              .map(
                (preset) => ElevatedButton(
                  onPressed: provider.isBusy
                      ? null
                      : () => provider.triggerPreset(preset.id),
                  child: Text(preset.name),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
