import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/services/reconnect_manager.dart';
import 'package:app/models/saved_controller.dart';

class ReconnectStatusScreen extends StatefulWidget {
  const ReconnectStatusScreen({super.key});

  @override
  State<ReconnectStatusScreen> createState() => _ReconnectStatusScreenState();
}

class _ReconnectStatusScreenState extends State<ReconnectStatusScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reconnect Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final provider = context.read<AppStateProvider>();
              provider.triggerReconnect();
            },
            tooltip: 'Trigger Reconnect',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final provider = context.read<AppStateProvider>();
              switch (value) {
                case 'reset_counters':
                  provider.resetReconnectCounters();
                  _showMessage('All reconnect counters reset');
                  break;
                case 'trigger_reconnect':
                  provider.triggerReconnect();
                  _showMessage('Manual reconnect triggered');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'trigger_reconnect',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Trigger Reconnect'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_counters',
                child: Row(
                  children: [
                    Icon(Icons.reset_tv),
                    SizedBox(width: 8),
                    Text('Reset Counters'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, provider, child) {
          final reconnectManager = provider.reconnectManager;
          final statistics = provider.reconnectStatistics;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(reconnectManager, statistics),
                const SizedBox(height: 16),
                _buildStatisticsCard(statistics),
                const SizedBox(height: 16),
                _buildRecentAttemptsCard(reconnectManager),
                const SizedBox(height: 16),
                _buildControllersCard(provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(ReconnectManager manager, Map<String, dynamic> stats) {
    final status = manager.status;
    final lastSuccess = stats['lastSuccessfulReconnect'] as DateTime?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Reconnect Status',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                if (status == ReconnectStatus.running)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: _pulseAnimation.value),
                          shape: BoxShape.circle,
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  _getStatusText(status),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (lastSuccess != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Last Success',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _formatTime(lastSuccess),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(Map<String, dynamic> stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Statistics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2,
              children: [
                _buildStatItem('Total Attempts', '${stats['totalAttempts']}', Icons.sync),
                _buildStatItem('Successful', '${stats['successfulAttempts']}', Icons.check_circle, Colors.green),
                _buildStatItem('Failed', '${stats['failedAttempts']}', Icons.error, Colors.red),
                _buildStatItem('Success Rate', '${(stats['successRate'] * 100).toStringAsFixed(1)}%', Icons.percent, Colors.blue),
                _buildStatItem('Recent (24h)', '${stats['recentAttempts']}', Icons.history),
                _buildStatItem('Active', '${stats['activeControllers']}', Icons.bluetooth, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, [Color? color]) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: color ?? Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color ?? Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentAttemptsCard(ReconnectManager manager) {
    final attempts = manager.attempts.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: Colors.purple,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Recent Attempts',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${attempts.length} shown',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (attempts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No reconnection attempts yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: attempts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final attempt = attempts[index];
                  return _buildAttemptItem(attempt);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttemptItem(ReconnectAttempt attempt) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            attempt.success ? Icons.check_circle : Icons.error,
            color: attempt.success ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attempt ${attempt.attemptNumber}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  attempt.success ? 'Successful' : (attempt.error ?? 'Failed'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: attempt.success ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(attempt.timestamp),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Delay: ${attempt.delay.inSeconds}s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControllersCard(AppStateProvider provider) {
    final controllers = provider.savedControllers;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: Colors.blue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Controllers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controllers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No saved controllers',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: controllers.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final controller = controllers[index];
                  final attemptCount = provider.reconnectManager.getAttemptCount(controller.controllerId);
                  return _buildControllerItem(controller, attemptCount);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControllerItem(SavedController controller, int attemptCount) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getConnectionStatusColor(controller.connectionStatus),
        child: Icon(
          _getConnectionStatusIcon(controller.connectionStatus),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(controller.controllerId),
      subtitle: Text(
        'Attempts: $attemptCount',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Text(
        _getConnectionStatusText(controller.connectionStatus),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _getConnectionStatusColor(controller.connectionStatus),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  IconData _getStatusIcon(ReconnectStatus status) {
    switch (status) {
      case ReconnectStatus.idle:
        return Icons.bluetooth_disabled;
      case ReconnectStatus.running:
        return Icons.sync;
      case ReconnectStatus.paused:
        return Icons.pause_circle;
      case ReconnectStatus.stopped:
        return Icons.stop_circle;
    }
  }

  Color _getStatusColor(ReconnectStatus status) {
    switch (status) {
      case ReconnectStatus.idle:
        return Colors.grey;
      case ReconnectStatus.running:
        return Colors.green;
      case ReconnectStatus.paused:
        return Colors.orange;
      case ReconnectStatus.stopped:
        return Colors.red;
    }
  }

  String _getStatusText(ReconnectStatus status) {
    switch (status) {
      case ReconnectStatus.idle:
        return 'Idle';
      case ReconnectStatus.running:
        return 'Running';
      case ReconnectStatus.paused:
        return 'Paused';
      case ReconnectStatus.stopped:
        return 'Stopped';
    }
  }

  IconData _getConnectionStatusIcon(SavedControllerConnectionStatus status) {
    switch (status) {
      case SavedControllerConnectionStatus.connected:
        return Icons.bluetooth_connected;
      case SavedControllerConnectionStatus.connecting:
        return Icons.bluetooth_searching;
      case SavedControllerConnectionStatus.disconnected:
        return Icons.bluetooth_disabled;
      case SavedControllerConnectionStatus.unavailable:
        return Icons.error;
    }
  }

  Color _getConnectionStatusColor(SavedControllerConnectionStatus status) {
    switch (status) {
      case SavedControllerConnectionStatus.connected:
        return Colors.green;
      case SavedControllerConnectionStatus.connecting:
        return Colors.orange;
      case SavedControllerConnectionStatus.disconnected:
        return Colors.grey;
      case SavedControllerConnectionStatus.unavailable:
        return Colors.red;
    }
  }

  String _getConnectionStatusText(SavedControllerConnectionStatus status) {
    switch (status) {
      case SavedControllerConnectionStatus.connected:
        return 'Connected';
      case SavedControllerConnectionStatus.connecting:
        return 'Connecting';
      case SavedControllerConnectionStatus.disconnected:
        return 'Disconnected';
      case SavedControllerConnectionStatus.unavailable:
        return 'Unavailable';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}