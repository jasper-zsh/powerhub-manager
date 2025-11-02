import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:app/models/monitoring_data.dart';
import 'package:app/providers/app_state_provider.dart';

enum MonitoringStatus {
  disconnected,
  connecting,
  connected,
  subscribing,
  live,
  error,
}

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  MonitoringData? _currentData;
  MonitoringStatus _status = MonitoringStatus.disconnected;
  String? _errorMessage;
  DateTime? _lastUpdateTime;
  StreamSubscription<MonitoringData>? _subscription;
  StreamSubscription? _connectionSubscription;
  Timer? _reconnectTimer;
  int _updateCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeMonitoring();
    _setupConnectionListener();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionSubscription?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _setupConnectionListener() {
    // Use periodic timer to check connection status
    _connectionSubscription = Stream.periodic(const Duration(seconds: 2), (_) {
      return Provider.of<AppStateProvider>(context, listen: false).isConnected;
    }).listen((isConnected) {
      if (mounted) {
        if (isConnected && (_status == MonitoringStatus.disconnected || _status == MonitoringStatus.error)) {
          _startMonitoring();
        } else if (!isConnected && _status != MonitoringStatus.disconnected) {
          _stopMonitoring();
          setState(() {
            _status = MonitoringStatus.disconnected;
            _errorMessage = 'Device disconnected';
          });
        }
      }
    });
  }

  Future<void> _initializeMonitoring() async {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    if (provider.isConnected) {
      await _startMonitoring();
    } else {
      setState(() {
        _status = MonitoringStatus.disconnected;
        _errorMessage = 'No device connected';
      });
    }
  }

  Future<void> _startMonitoring() async {
    if (!mounted) return;

    setState(() {
      _status = MonitoringStatus.connecting;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<AppStateProvider>(context, listen: false);

      // Try to read current data first
      try {
        setState(() => _status = MonitoringStatus.connected);
        final data = await provider.readMonitoringData();
        if (mounted) {
          setState(() {
            _currentData = data;
            _lastUpdateTime = DateTime.now();
            _status = MonitoringStatus.subscribing;
          });
        }
      } catch (e) {
        debugPrint('Initial monitoring read failed: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to read initial data: $e';
            _status = MonitoringStatus.error;
          });
        }
        return;
      }

      // Enable notifications for real-time updates
      try {
        setState(() => _status = MonitoringStatus.subscribing);
        final stream = await provider.enableMonitoringNotifications();
        _subscription = stream.listen(
          (data) {
            if (mounted) {
              setState(() {
                _currentData = data;
                _lastUpdateTime = DateTime.now();
                _status = MonitoringStatus.live;
                _updateCount++;
                _errorMessage = null;
              });
            }
          },
          onError: (error) {
            debugPrint('Monitoring stream error: $error');
            if (mounted) {
              setState(() {
                _errorMessage = 'Monitoring error: $error';
                _status = MonitoringStatus.error;
              });
            }
            _scheduleReconnect();
          },
          onDone: () {
            debugPrint('Monitoring stream done');
            if (mounted) {
              setState(() {
                _status = MonitoringStatus.connected;
                _errorMessage = 'Real-time updates ended';
              });
            }
          },
        );

        if (mounted) {
          setState(() {
            _status = MonitoringStatus.live;
          });
        }
      } catch (e) {
        debugPrint('Failed to enable monitoring notifications: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Real-time monitoring not available: $e';
            _status = MonitoringStatus.connected;
          });
          _showMessage('Real-time monitoring not available: $e', Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize monitoring: $e';
          _status = MonitoringStatus.error;
        });
        _showMessage('Failed to initialize monitoring: $e', Colors.red);
      }
    }
  }

  void _stopMonitoring() {
    _subscription?.cancel();
    _reconnectTimer?.cancel();
    if (mounted) {
      setState(() {
        _status = MonitoringStatus.disconnected;
        _currentData = null;
        _lastUpdateTime = null;
        _updateCount = 0;
      });
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _status == MonitoringStatus.error) {
        debugPrint('Attempting to reconnect monitoring...');
        _startMonitoring();
      }
    });
  }

  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;

    try {
      setState(() => _status = MonitoringStatus.connecting);
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      final data = await provider.readMonitoringData();
      if (mounted) {
        setState(() {
          _currentData = data;
          _lastUpdateTime = DateTime.now();
          _status = MonitoringStatus.connected;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = MonitoringStatus.error;
          _errorMessage = 'Failed to refresh data: $e';
        });
        _showMessage('Failed to refresh data: $e', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('System Monitoring'),
            const SizedBox(width: 8),
            _buildStatusIndicator(),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh data',
          ),
          if (_status == MonitoringStatus.live)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_updateCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildStatusIndicator() {
    IconData icon;
    Color color;
    String tooltip;

    switch (_status) {
      case MonitoringStatus.disconnected:
        icon = Icons.bluetooth_disabled;
        color = Colors.grey;
        tooltip = 'Disconnected';
        break;
      case MonitoringStatus.connecting:
        icon = Icons.bluetooth_searching;
        color = Colors.orange;
        tooltip = 'Connecting...';
        break;
      case MonitoringStatus.connected:
        icon = Icons.bluetooth_connected;
        color = Colors.blue;
        tooltip = 'Connected';
        break;
      case MonitoringStatus.subscribing:
        icon = Icons.sync;
        color = Colors.orange;
        tooltip = 'Subscribing...';
        break;
      case MonitoringStatus.live:
        icon = Icons.sensors;
        color = Colors.green;
        tooltip = 'Live monitoring';
        break;
      case MonitoringStatus.error:
        icon = Icons.error;
        color = Colors.red;
        tooltip = 'Error';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case MonitoringStatus.disconnected:
        return _buildDisconnectedView();
      case MonitoringStatus.connecting:
      case MonitoringStatus.subscribing:
        return _buildLoadingView();
      case MonitoringStatus.connected:
      case MonitoringStatus.live:
        return _currentData != null
            ? _buildMonitoringContent()
            : _buildNoContentView();
      case MonitoringStatus.error:
        return _buildErrorView();
    }
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing monitoring...'),
        ],
      ),
    );
  }

  Widget _buildDisconnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_disabled,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No device connected',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to a PowerHub device to enable monitoring',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Monitoring Error',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.red,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.red,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoContentView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.monitor_heart,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No monitoring data available',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringContent() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpdateInfo(),
            const SizedBox(height: 16),
            _buildVoltageCard(),
            const SizedBox(height: 16),
            _buildTemperatureCard(),
            const SizedBox(height: 16),
            _buildCurrentCard(),
            const SizedBox(height: 16),
            _buildStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateInfo() {
    if (_lastUpdateTime == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = now.difference(_lastUpdateTime!);

    String timeText;
    if (diff.inSeconds < 60) {
      timeText = '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      timeText = '${diff.inMinutes}m ago';
    } else {
      timeText = '${diff.inHours}h ago';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(
            Icons.update,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            'Last update: $timeText',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          if (_status == MonitoringStatus.live) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'Updates: $_updateCount',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVoltageCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.electric_bolt,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Input Voltage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_currentData!.inputVoltageVolts.toStringAsFixed(2)}V',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _getVoltageColor(_currentData!.inputVoltageVolts),
                  ),
                ),
                Text(
                  _getVoltageStatus(_currentData!.inputVoltageVolts),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _getVoltageColor(_currentData!.inputVoltageVolts),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_currentData!.inputVoltageVolts - 10.0) / 10.0,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getVoltageColor(_currentData!.inputVoltageVolts),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.thermostat,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Temperature Monitoring',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTemperatureRow(
              'Power Zone',
              _currentData!.powerZoneTempCelsius,
              'Power-related components',
            ),
            const SizedBox(height: 12),
            _buildTemperatureRow(
              'Control Zone',
              _currentData!.controlZoneTempCelsius,
              'Control circuit',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureRow(String label, double? temperature, String description) {
    final hasValidData = temperature != null;
    final temp = temperature ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            Text(
              hasValidData ? '${temp.toStringAsFixed(1)}°C' : 'Invalid',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasValidData ? _getTemperatureColor(temp) : Colors.red,
              ),
            ),
          ],
        ),
        if (hasValidData) ...[
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (temp - 20.0) / 60.0,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getTemperatureColor(temp),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.electrical_services,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Monitoring',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Current',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '${_currentData!.totalInputCurrent.toStringAsFixed(3)}A',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Channel Currents',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ..._currentData!.channelCurrents.asMap().entries.map((entry) {
              final channel = entry.key;
              final current = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Channel $channel'),
                    Text(
                      '${current.toStringAsFixed(3)}A',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: current > 5.0 ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final flags = _currentData!.statusFlags;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info,
                  color: Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusFlag('Thermal Protection', flags.thermalProtectionActive),
            _buildStatusFlag('Temperature Data Valid', flags.temperatureDataValid),
            _buildStatusFlag('Current Data Valid', flags.currentDataValid),
            _buildStatusFlag('System Calibrated', flags.calibrationStatus),
            _buildStatusFlag('Peripheral Power On', flags.peripheralPowerOn),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFlag(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            size: 20,
            color: isActive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isActive ? null : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  
  Color _getVoltageColor(double voltage) {
    if (voltage < 11.0) return Colors.red;
    if (voltage < 12.0) return Colors.orange;
    return Colors.green;
  }

  String _getVoltageStatus(double voltage) {
    if (voltage < 11.0) return 'Critical';
    if (voltage < 12.0) return 'Low';
    if (voltage > 15.0) return 'High';
    return 'Normal';
  }

  Color _getTemperatureColor(double temperature) {
    if (temperature > 70.0) return Colors.red;
    if (temperature > 50.0) return Colors.orange;
    return Colors.green;
  }
}