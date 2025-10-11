import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app/models/telemetry.dart';
import 'package:app/providers/app_state_provider.dart';

class TelemetrySettingsScreen extends StatefulWidget {
  const TelemetrySettingsScreen({super.key});

  @override
  State<TelemetrySettingsScreen> createState() =>
      _TelemetrySettingsScreenState();
}

class _TelemetrySettingsScreenState extends State<TelemetrySettingsScreen> {
  final TextEditingController _sleepVoltageController = TextEditingController();
  final TextEditingController _wakeVoltageController = TextEditingController();
  final TextEditingController _highTempController = TextEditingController();
  final TextEditingController _recoverTempController = TextEditingController();

  bool _isApplyingSleep = false;
  bool _isApplyingWake = false;
  bool _isApplyingHighTemp = false;
  bool _isApplyingRecoverTemp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    _prefillFromTelemetry(appState.telemetry);
  }

  @override
  void dispose() {
    _sleepVoltageController.dispose();
    _wakeVoltageController.dispose();
    _highTempController.dispose();
    _recoverTempController.dispose();
    super.dispose();
  }

  void _prefillFromTelemetry(TelemetryData? telemetry) {
    if (telemetry == null) {
      return;
    }

    _sleepVoltageController.text = telemetry.sleepThresholdMilliVolts
        .toString();
    _wakeVoltageController.text = telemetry.wakeThresholdMilliVolts.toString();
    _highTempController.text = telemetry.highThresholdCelsius.toStringAsFixed(
      2,
    );
    _recoverTempController.text = telemetry.recoverThresholdCelsius
        .toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, appState, _) {
        if (!appState.isConnected) {
          return Scaffold(
            appBar: AppBar(title: const Text('设备阈值设置')),
            body: const Center(child: Text('请先连接设备后再调整阈值。')),
          );
        }

        final telemetry = appState.telemetry;

        return Scaffold(
          appBar: AppBar(
            title: const Text('设备阈值设置'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: '刷新遥测',
                onPressed: () async {
                  await appState.refreshTelemetry();
                  if (mounted) {
                    _prefillFromTelemetry(appState.telemetry);
                    _showSnack('已刷新设备遥测');
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (telemetry != null) ...[
                  _TelemetrySummary(telemetry: telemetry),
                  const SizedBox(height: 16),
                ],
                if (appState.telemetryError.isNotEmpty) ...[
                  Text(
                    appState.telemetryError,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildVoltageSection(appState),
                const SizedBox(height: 24),
                _buildTemperatureSection(appState),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVoltageSection(AppStateProvider appState) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '电压阈值 (mV)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildVoltageRow(
              label: '睡眠阈值',
              controller: _sleepVoltageController,
              hintText: '例如 11400',
              isBusy: _isApplyingSleep,
              onSubmit: () => _applyVoltageThreshold(appState, isSleep: true),
            ),
            const SizedBox(height: 12),
            _buildVoltageRow(
              label: '唤醒阈值',
              controller: _wakeVoltageController,
              hintText: '例如 12000',
              isBusy: _isApplyingWake,
              onSubmit: () => _applyVoltageThreshold(appState, isSleep: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoltageRow({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isBusy,
    required VoidCallback onSubmit,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: false,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              suffixText: 'mV',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isBusy ? null : onSubmit,
          child: isBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('应用'),
        ),
      ],
    );
  }

  Widget _buildTemperatureSection(AppStateProvider appState) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '温度阈值 (°C)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTemperatureRow(
              label: '高温阈值',
              controller: _highTempController,
              hintText: '例如 65.0',
              isBusy: _isApplyingHighTemp,
              onSubmit: () =>
                  _applyTemperatureThreshold(appState, isHigh: true),
            ),
            const SizedBox(height: 12),
            _buildTemperatureRow(
              label: '恢复阈值',
              controller: _recoverTempController,
              hintText: '例如 55.0',
              isBusy: _isApplyingRecoverTemp,
              onSubmit: () =>
                  _applyTemperatureThreshold(appState, isHigh: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureRow({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isBusy,
    required VoidCallback onSubmit,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              signed: false,
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: label,
              hintText: hintText,
              suffixText: '°C',
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: isBusy ? null : onSubmit,
          child: isBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('应用'),
        ),
      ],
    );
  }

  Future<void> _applyVoltageThreshold(
    AppStateProvider appState, {
    required bool isSleep,
  }) async {
    final controller = isSleep
        ? _sleepVoltageController
        : _wakeVoltageController;
    final rawValue = controller.text.trim();

    final value = int.tryParse(rawValue);
    if (value == null) {
      _showError('请输入有效的${isSleep ? '睡眠' : '唤醒'}阈值（mV）');
      return;
    }

    setState(() {
      if (isSleep) {
        _isApplyingSleep = true;
      } else {
        _isApplyingWake = true;
      }
    });

    try {
      if (isSleep) {
        await appState.setSleepThreshold(value);
        _showSnack('睡眠电压阈值已更新');
      } else {
        await appState.setWakeThreshold(value);
        _showSnack('唤醒电压阈值已更新');
      }

      await appState.refreshTelemetry();
      if (mounted) {
        _prefillFromTelemetry(appState.telemetry);
      }
    } on ArgumentError catch (e) {
      _showError(e.message?.toString() ?? '参数不合法');
    } catch (e) {
      _showError('更新失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (isSleep) {
            _isApplyingSleep = false;
          } else {
            _isApplyingWake = false;
          }
        });
      }
    }
  }

  Future<void> _applyTemperatureThreshold(
    AppStateProvider appState, {
    required bool isHigh,
  }) async {
    final controller = isHigh ? _highTempController : _recoverTempController;
    final rawValue = controller.text.trim();

    final value = double.tryParse(rawValue);
    if (value == null) {
      _showError('请输入有效的${isHigh ? '高温' : '恢复'}阈值（°C）');
      return;
    }

    final centiDegrees = (value * 100).round();

    setState(() {
      if (isHigh) {
        _isApplyingHighTemp = true;
      } else {
        _isApplyingRecoverTemp = true;
      }
    });

    try {
      if (isHigh) {
        await appState.setHighTemperatureThreshold(centiDegrees);
        _showSnack('高温阈值已更新');
      } else {
        await appState.setRecoverTemperatureThreshold(centiDegrees);
        _showSnack('恢复阈值已更新');
      }

      await appState.refreshTelemetry();
      if (mounted) {
        _prefillFromTelemetry(appState.telemetry);
      }
    } on ArgumentError catch (e) {
      _showError(e.message?.toString() ?? '参数不合法');
    } catch (e) {
      _showError('更新失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          if (isHigh) {
            _isApplyingHighTemp = false;
          } else {
            _isApplyingRecoverTemp = false;
          }
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }
}

class _TelemetrySummary extends StatelessWidget {
  final TelemetryData telemetry;

  const _TelemetrySummary({required this.telemetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '当前遥测',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _TelemetryRow(
              label: 'Vin',
              value:
                  '${(telemetry.vinMillivolts / 1000.0).toStringAsFixed(2)} V',
            ),
            _TelemetryRow(
              label: '温度',
              value: '${telemetry.temperatureCelsius.toStringAsFixed(2)} °C',
            ),
            _TelemetryRow(
              label: '高温阈值',
              value: '${telemetry.highThresholdCelsius.toStringAsFixed(2)} °C',
            ),
            _TelemetryRow(
              label: '恢复阈值',
              value:
                  '${telemetry.recoverThresholdCelsius.toStringAsFixed(2)} °C',
            ),
            _TelemetryRow(
              label: '睡眠阈值',
              value:
                  '${telemetry.sleepThresholdMilliVolts} mV (${telemetry.sleepThresholdVolts.toStringAsFixed(2)} V)',
            ),
            _TelemetryRow(
              label: '唤醒阈值',
              value:
                  '${telemetry.wakeThresholdMilliVolts} mV (${telemetry.wakeThresholdVolts.toStringAsFixed(2)} V)',
            ),
            _TelemetryRow(
              label: '热保护',
              value: telemetry.isThermalProtectionActive ? '已激活' : '未激活',
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final String label;
  final String value;

  const _TelemetryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
