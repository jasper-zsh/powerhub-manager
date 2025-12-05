import 'package:flutter/material.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_data_source.dart';
import 'package:app/models/switch_hub/status_data_type.dart';

/// Widget for displaying a single status slot
class StatusSlotWidget extends StatelessWidget {
  const StatusSlotWidget({
    super.key,
    required this.statusSlot,
    this.dataSource,
    this.isLoading = false,
    this.onError,
  });

  final StatusSlot statusSlot;
  final StatusDataSource? dataSource;
  final bool isLoading;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = statusSlot.value ?? '--';
    final displayLabel = statusSlot.label ?? _getDefaultLabel();

    // Determine color based on data type and status
    Color dataColor = _getDataColor(theme);
    IconData dataIcon = _getDataIcon();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with icon and label
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dataIcon,
                size: 16,
                color: dataColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  displayLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dataSource != null) ...[
                const SizedBox(width: 4),
                _buildConnectionIndicator(theme, dataSource!),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Value display
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(dataColor),
                  ),
                )
              else
                Text(
                  displayValue,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: dataColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (statusSlot.value != null && !isLoading) ...[
                const SizedBox(width: 2),
                Text(
                  statusSlot.displayUnit,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: dataColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ],
          ),
          // Error indicator
          if (dataSource?.connectionStatus == ConnectionStatus.connectionFailed ||
              dataSource?.connectionStatus == ConnectionStatus.connectionLost)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
                onTap: onError,
                child: Text(
                  '连接错误',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator(ThemeData theme, StatusDataSource dataSource) {
    Color indicatorColor;
    IconData indicatorIcon;

    switch (dataSource.connectionStatus) {
      case ConnectionStatus.connected:
        indicatorColor = Colors.green;
        indicatorIcon = Icons.bluetooth_connected;
        break;
      case ConnectionStatus.connecting:
        indicatorColor = Colors.orange;
        indicatorIcon = Icons.bluetooth_searching;
        break;
      case ConnectionStatus.disconnected:
        indicatorColor = Colors.grey;
        indicatorIcon = Icons.bluetooth_disabled;
        break;
      case ConnectionStatus.connectionFailed:
      case ConnectionStatus.connectionLost:
        indicatorColor = Colors.red;
        indicatorIcon = Icons.bluetooth_disabled;
        break;
    }

    return Icon(
      indicatorIcon,
      size: 12,
      color: indicatorColor,
    );
  }

  String _getDefaultLabel() {
    switch (statusSlot.dataType) {
      case StatusDataType.voltage:
        return statusSlot.isLocal ? '输入电压' : '远程电压';
      case StatusDataType.channelCurrent:
        return '通道${statusSlot.params ?? '0'}电流';
      case StatusDataType.totalCurrent:
        return '总电流';
      case StatusDataType.temperature:
        final zone = statusSlot.params ?? 'POWER';
        return zone == 'POWER' ? '电源区温度' : '控制区温度';
    }
  }

  IconData _getDataIcon() {
    switch (statusSlot.dataType) {
      case StatusDataType.voltage:
        return statusSlot.isLocal ? Icons.battery_full : Icons.electrical_services;
      case StatusDataType.channelCurrent:
        return Icons.electric_bolt;
      case StatusDataType.totalCurrent:
        return Icons.electric_bolt;
      case StatusDataType.temperature:
        return Icons.thermostat;
    }
  }

  Color _getDataColor(ThemeData theme) {
    // If there's a connection error, show error color
    if (dataSource?.connectionStatus == ConnectionStatus.connectionFailed ||
        dataSource?.connectionStatus == ConnectionStatus.connectionLost) {
      return theme.colorScheme.error;
    }

    // If loading, show neutral color
    if (isLoading) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Color based on data type and value
    switch (statusSlot.dataType) {
      case StatusDataType.voltage:
        return _getVoltageColor(theme);
      case StatusDataType.channelCurrent:
        return theme.colorScheme.primary;
      case StatusDataType.totalCurrent:
        return theme.colorScheme.secondary;
      case StatusDataType.temperature:
        return theme.colorScheme.tertiary;
    }
  }

  Color _getVoltageColor(ThemeData theme) {
    if (statusSlot.value == null) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Extract numeric value from voltage string (e.g., "12.5V" -> 12.5)
    final valueStr = statusSlot.value!.replaceAll('V', '');
    final voltage = double.tryParse(valueStr);

    if (voltage == null) {
      return theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Color coding for voltage levels
    if (voltage < 3.3) {
      return Colors.red; // Low voltage
    } else if (voltage < 3.6) {
      return Colors.orange; // Medium voltage
    } else {
      return Colors.green; // Good voltage
    }
  }
}

/// Row widget for displaying two status slots side by side
class StatusDisplayRow extends StatelessWidget {
  const StatusDisplayRow({
    super.key,
    this.slot1,
    this.slot2,
    this.dataSource1,
    this.dataSource2,
    this.isLoading1 = false,
    this.isLoading2 = false,
    this.onError,
  });

  final StatusSlot? slot1;
  final StatusSlot? slot2;
  final StatusDataSource? dataSource1;
  final StatusDataSource? dataSource2;
  final bool isLoading1;
  final bool isLoading2;
  final VoidCallback? onError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (slot1 != null) ...[
          StatusSlotWidget(
            statusSlot: slot1!,
            dataSource: dataSource1,
            isLoading: isLoading1,
            onError: onError,
          ),
          if (slot2 != null) const SizedBox(height: 8),
        ],
        if (slot2 != null)
          StatusSlotWidget(
            statusSlot: slot2!,
            dataSource: dataSource2,
            isLoading: isLoading2,
            onError: onError,
          ),
        if (slot1 == null && slot2 == null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '未配置状态显示',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}

/// Empty state widget for when no status slots are configured
class StatusDisplayEmptyState extends StatelessWidget {
  const StatusDisplayEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.info_outline,
            size: 24,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            '状态显示未配置',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '请在设备配置中添加状态插槽',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}