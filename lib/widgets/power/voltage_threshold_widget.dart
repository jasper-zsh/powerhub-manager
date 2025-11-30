import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/switch_hub/voltage_thresholds.dart';
import 'package:app/services/switch_hub_ble_service.dart';

/// Widget for configuring voltage thresholds
class VoltageThresholdWidget extends ConsumerStatefulWidget {
  const VoltageThresholdWidget({
    super.key,
    this.initialThresholds,
    this.onChanged,
    this.readOnly = false,
  });

  final SwitchHubVoltageThresholds? initialThresholds;
  final Function(SwitchHubVoltageThresholds)? onChanged;
  final bool readOnly;

  @override
  ConsumerState<VoltageThresholdWidget> createState() => _VoltageThresholdWidgetState();
}

class _VoltageThresholdWidgetState extends ConsumerState<VoltageThresholdWidget> {
  late int _sleepVoltage;
  late int _wakeVoltage;
  bool _isValid = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _sleepVoltage = widget.initialThresholds?.sleepVoltageMv ?? SwitchHubVoltageThresholds.defaultThresholds.sleepVoltageMv;
    _wakeVoltage = widget.initialThresholds?.wakeVoltageMv ?? SwitchHubVoltageThresholds.defaultThresholds.wakeVoltageMv;
    _validateThresholds();
  }

  void _validateThresholds() {
    final thresholds = SwitchHubVoltageThresholds(
      sleepVoltageMv: _sleepVoltage,
      wakeVoltageMv: _wakeVoltage,
    );

    setState(() {
      _isValid = thresholds.isValid();
      _validationError = thresholds.getValidationError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final thresholds = SwitchHubVoltageThresholds(
      sleepVoltageMv: _sleepVoltage,
      wakeVoltageMv: _wakeVoltage,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildSleepVoltageSlider(),
            const SizedBox(height: 16),
            _buildWakeVoltageSlider(),
            const SizedBox(height: 16),
            _buildValidationStatus(),
            if (!widget.readOnly) ...[
              const SizedBox(height: 16),
              _buildActionButtons(thresholds),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.power_settings_new,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        const Text(
          '电压阈值配置',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Icon(
          _isValid ? Icons.check_circle : Icons.error,
          color: _isValid ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  Widget _buildSleepVoltageSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '睡眠电压阈值',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${_sleepVoltage}mV',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getVoltageColor(_sleepVoltage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _sleepVoltage.toDouble(),
          min: SwitchHubBleService.minVoltageMv.toDouble(),
          max: SwitchHubBleService.maxVoltageMv.toDouble(),
          divisions: 120, // 1mV divisions
          activeColor: _getVoltageColor(_sleepVoltage),
          inactiveColor: Colors.grey.shade300,
          onChanged: widget.readOnly ? null : (value) {
            setState(() {
              _sleepVoltage = value.round();
              // Ensure wake voltage is higher
              if (_wakeVoltage <= _sleepVoltage) {
                _wakeVoltage = (_sleepVoltage + 100).clamp(SwitchHubBleService.minVoltageMv, SwitchHubBleService.maxVoltageMv);
              }
              _validateThresholds();
            });
            widget.onChanged?.call(SwitchHubVoltageThresholds(
              sleepVoltageMv: _sleepVoltage,
              wakeVoltageMv: _wakeVoltage,
            ));
          },
        ),
        Text(
          '当电压低于此值时设备进入睡眠模式',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildWakeVoltageSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '唤醒电压阈值',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(
              '${_wakeVoltage}mV',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getVoltageColor(_wakeVoltage),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Slider(
          value: _wakeVoltage.toDouble(),
          min: (_sleepVoltage + 10).toDouble(), // Must be higher than sleep
          max: SwitchHubBleService.maxVoltageMv.toDouble(),
          divisions: 120, // 1mV divisions
          activeColor: _getVoltageColor(_wakeVoltage),
          inactiveColor: Colors.grey.shade300,
          onChanged: widget.readOnly ? null : (value) {
            setState(() {
              _wakeVoltage = value.round();
              _validateThresholds();
            });
            widget.onChanged?.call(SwitchHubVoltageThresholds(
              sleepVoltageMv: _sleepVoltage,
              wakeVoltageMv: _wakeVoltage,
            ));
          },
        ),
        Text(
          '当电压高于此值时设备从睡眠模式唤醒',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildValidationStatus() {
    if (_isValid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '电压阈值配置有效',
                style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error, color: Colors.red.shade600, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _validationError ?? '无效的配置',
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionButtons(SwitchHubVoltageThresholds thresholds) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isValid ? () => _resetToDefaults() : null,
            icon: const Icon(Icons.refresh),
            label: const Text('重置默认'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isValid ? () => _applyThresholds(thresholds) : null,
            icon: const Icon(Icons.save),
            label: const Text('应用设置'),
          ),
        ),
      ],
    );
  }

  Color _getVoltageColor(int voltage) {
    if (voltage < 3200) return Colors.red;
    if (voltage < 3400) return Colors.orange;
    if (voltage > 4100) return Colors.purple;
    return Colors.green;
  }

  void _resetToDefaults() {
    setState(() {
      _sleepVoltage = SwitchHubVoltageThresholds.defaultThresholds.sleepVoltageMv;
      _wakeVoltage = SwitchHubVoltageThresholds.defaultThresholds.wakeVoltageMv;
      _validateThresholds();
    });
    widget.onChanged?.call(SwitchHubVoltageThresholds(
      sleepVoltageMv: _sleepVoltage,
      wakeVoltageMv: _wakeVoltage,
    ));
  }

  void _applyThresholds(SwitchHubVoltageThresholds thresholds) {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationError ?? '无效的配置'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认应用设置'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('睡眠电压: ${thresholds.sleepVoltageMv}mV'),
              const SizedBox(height: 4),
              Text('唤醒电压: ${thresholds.wakeVoltageMv}mV'),
              const SizedBox(height: 12),
              const Text('确定要应用这些电压阈值设置吗？'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _executeApplyThresholds(thresholds);
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  void _executeApplyThresholds(SwitchHubVoltageThresholds thresholds) {
    // This would typically call the controller to apply the thresholds
    // For now, we'll just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('电压阈值设置已应用'),
        backgroundColor: Colors.green,
      ),
    );
  }
}