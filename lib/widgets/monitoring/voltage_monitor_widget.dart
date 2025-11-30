import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/switch_hub/monitoring_data.dart';
import 'package:app/providers/switch_hub_provider_riverpod.dart';

/// Widget for displaying real-time voltage monitoring data
class VoltageMonitorWidget extends ConsumerWidget {
  const VoltageMonitorWidget({
    super.key,
    this.monitoringData,
    this.showDetails = true,
    this.size = VoltageMonitorSize.medium,
  });

  final SwitchHubMonitoringData? monitoringData;
  final bool showDetails;
  final VoltageMonitorSize size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(switchHubControllerProvider);
    final data = monitoringData ?? controller.monitoringData;

    return Card(
      elevation: 2,
      child: Padding(
        padding: _getPadding(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            const SizedBox(height: 8),
            _buildVoltageGauge(data),
            if (showDetails) ...[
              const SizedBox(height: 12),
              _buildDetails(data),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.battery_charging_full,
          size: size.iconSize,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          '电压监测',
          style: TextStyle(
            fontSize: size.titleFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Consumer(
          builder: (context, ref, _) {
            final controller = ref.watch(switchHubControllerProvider);
            return Icon(
              controller.isMonitoring ? Icons.sensors : Icons.sensors_off,
              size: size.iconSize * 0.8,
              color: controller.isMonitoring ? Colors.green : Colors.grey,
            );
          },
        ),
      ],
    );
  }

  Widget _buildVoltageGauge(SwitchHubMonitoringData? data) {
    if (data == null) {
      return _buildEmptyGauge();
    }

    final percentage = data.batteryPercentage;
    final color = _getVoltageColor(data);

    return Column(
      children: [
        SizedBox(
          height: size.gaugeHeight,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: size.gaugeHeight,
                height: size.gaugeHeight,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
              ),
              // Progress arc
              SizedBox(
                width: size.gaugeHeight,
                height: size.gaugeHeight,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  strokeWidth: size.gaugeStrokeWidth,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              // Voltage text
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${data.inputVoltageMv}',
                    style: TextStyle(
                      fontSize: size.voltageFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'mV',
                    style: TextStyle(
                      fontSize: size.unitFontSize,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: size.percentageFontSize,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyGauge() {
    return SizedBox(
      height: size.gaugeHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.battery_unknown,
            size: size.iconSize,
            color: Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            '无数据',
            style: TextStyle(
              fontSize: size.voltageFontSize,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(SwitchHubMonitoringData? data) {
    if (data == null) {
      return const Text(
        '暂无监测数据',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('状态', _getVoltageStatusText(data), _getVoltageColor(data)),
        _buildDetailRow('温度传感器', data.hasTemperatureSensor ? '可用' : '不可用',
                       data.hasTemperatureSensor ? Colors.green : Colors.grey),
        if (showDetails) ...[
          _buildDetailRow('状态标志', '0x${data.statusFlags.toRadixString(16).padLeft(2, '0')}', Colors.grey.shade600),
          _buildDetailRow('更新时间', DateTime.now().toString().substring(11, 19), Colors.grey.shade600),
        ],
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: size.detailFontSize,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: size.detailFontSize,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getVoltageColor(SwitchHubMonitoringData data) {
    if (data.isVoltageCritical) return Colors.red;
    if (data.isVoltageLow) return Colors.orange;
    if (data.isVoltageHigh) return Colors.purple;
    return Colors.green;
  }

  String _getVoltageStatusText(SwitchHubMonitoringData data) {
    if (data.isVoltageCritical) return '电压严重偏低';
    if (data.isVoltageLow) return '电压偏低';
    if (data.isVoltageHigh) return '电压偏高';
    return '电压正常';
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case VoltageMonitorSize.small:
        return const EdgeInsets.all(12);
      case VoltageMonitorSize.medium:
        return const EdgeInsets.all(16);
      case VoltageMonitorSize.large:
        return const EdgeInsets.all(20);
    }
  }
}

enum VoltageMonitorSize {
  small,
  medium,
  large;

  double get titleFontSize {
    switch (this) {
      case VoltageMonitorSize.small: return 14;
      case VoltageMonitorSize.medium: return 16;
      case VoltageMonitorSize.large: return 18;
    }
  }

  double get voltageFontSize {
    switch (this) {
      case VoltageMonitorSize.small: return 16;
      case VoltageMonitorSize.medium: return 20;
      case VoltageMonitorSize.large: return 24;
    }
  }

  double get unitFontSize {
    switch (this) {
      case VoltageMonitorSize.small: return 10;
      case VoltageMonitorSize.medium: return 12;
      case VoltageMonitorSize.large: return 14;
    }
  }

  double get percentageFontSize {
    switch (this) {
      case VoltageMonitorSize.small: return 12;
      case VoltageMonitorSize.medium: return 14;
      case VoltageMonitorSize.large: return 16;
    }
  }

  double get detailFontSize {
    switch (this) {
      case VoltageMonitorSize.small: return 11;
      case VoltageMonitorSize.medium: return 12;
      case VoltageMonitorSize.large: return 14;
    }
  }

  double get gaugeHeight {
    switch (this) {
      case VoltageMonitorSize.small: return 80;
      case VoltageMonitorSize.medium: return 100;
      case VoltageMonitorSize.large: return 120;
    }
  }

  double get gaugeStrokeWidth {
    switch (this) {
      case VoltageMonitorSize.small: return 4;
      case VoltageMonitorSize.medium: return 6;
      case VoltageMonitorSize.large: return 8;
    }
  }

  double get iconSize {
    switch (this) {
      case VoltageMonitorSize.small: return 16;
      case VoltageMonitorSize.medium: return 20;
      case VoltageMonitorSize.large: return 24;
    }
  }
}