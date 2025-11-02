import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/models/power_management.dart';
import 'package:app/providers/app_state_provider.dart';

class PowerManagementScreen extends StatefulWidget {
  const PowerManagementScreen({super.key});

  @override
  State<PowerManagementScreen> createState() => _PowerManagementScreenState();
}

class _PowerManagementScreenState extends State<PowerManagementScreen> {
  PowerManagementConfig? _config;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPowerConfig();
  }

  Future<void> _loadPowerConfig() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<AppStateProvider>();
      final config = await provider.readPowerManagementConfig();
      if (mounted) {
        setState(() {
          _config = config;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load power config: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateThreshold(String type, double value) async {
    try {
      final provider = context.read<AppStateProvider>();
      int intValue;
      PowerCommand command;

      switch (type) {
        case 'highTemp':
          intValue = (value * 100).round();
          command = PowerCommand(
            type: PowerCommandType.setHighTempThreshold,
            parameter: intValue,
          );
          break;
        case 'recovery':
          intValue = (value * 100).round();
          command = PowerCommand(
            type: PowerCommandType.setRecoveryThreshold,
            parameter: intValue,
          );
          break;
        case 'sleepVoltage':
          intValue = (value * 1000).round();
          command = PowerCommand(
            type: PowerCommandType.setSleepThreshold,
            parameter: intValue,
          );
          break;
        case 'wakeVoltage':
          intValue = (value * 1000).round();
          command = PowerCommand(
            type: PowerCommandType.setWakeThreshold,
            parameter: intValue,
          );
          break;
        default:
          return;
      }

      await provider.sendPowerCommand(command);
      await _loadPowerConfig(); // Refresh the config

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Threshold updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update threshold: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendCommand(PowerCommandType type) async {
    try {
      final provider = context.read<AppStateProvider>();
      final command = PowerCommand(type: type);
      await provider.sendPowerCommand(command);

      if (mounted) {
        String message;
        switch (type) {
          case PowerCommandType.forceSleep:
            message = 'System sent to sleep mode';
            break;
          case PowerCommandType.forceWake:
            message = 'System awakened';
            break;
          default:
            message = 'Command sent successfully';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send command: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPowerConfig,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _config != null
              ? _buildConfigContent()
              : _buildNoContent(),
    );
  }

  Widget _buildConfigContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Temperature Thresholds',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildThresholdSlider(
                    'High Temperature',
                    _config!.highTempCelsius,
                    20.0,
                    80.0,
                    '°C',
                    (value) => _updateThreshold('highTemp', value),
                  ),
                  const SizedBox(height: 16),
                  _buildThresholdSlider(
                    'Recovery Temperature',
                    _config!.recoveryCelsius,
                    15.0,
                    75.0,
                    '°C',
                    (value) => _updateThreshold('recovery', value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voltage Thresholds',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  _buildThresholdSlider(
                    'Sleep Voltage',
                    _config!.sleepVoltage,
                    10.0,
                    15.0,
                    'V',
                    (value) => _updateThreshold('sleepVoltage', value),
                  ),
                  const SizedBox(height: 16),
                  _buildThresholdSlider(
                    'Wake Voltage',
                    _config!.wakeVoltage,
                    11.0,
                    16.0,
                    'V',
                    (value) => _updateThreshold('wakeVoltage', value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Control',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sendCommand(PowerCommandType.forceSleep),
                          icon: const Icon(Icons.bedtime),
                          label: const Text('Force Sleep'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _sendCommand(PowerCommandType.forceWake),
                          icon: const Icon(Icons.wb_sunny),
                          label: const Text('Force Wake'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSlider(
    String label,
    double currentValue,
    double min,
    double max,
    String unit,
    Function(double) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '${currentValue.toStringAsFixed(1)}$unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: currentValue.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          onChanged: (value) {
            // Show preview but don't update until user releases
          },
          onChangeEnd: onChanged,
        ),
      ],
    );
  }

  Widget _buildNoContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.power_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Power management configuration not available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadPowerConfig,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}