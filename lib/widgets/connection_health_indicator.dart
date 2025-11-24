import 'package:flutter/material.dart';

class ConnectionHealthIndicator extends StatefulWidget {
  const ConnectionHealthIndicator({super.key});

  @override
  State<ConnectionHealthIndicator> createState() => _ConnectionHealthIndicatorState();
}

class _ConnectionHealthIndicatorState extends State<ConnectionHealthIndicator>
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

    // 获取BLE服务实例
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 假设我们可以通过某种方式获取BLEService实例
      // 这里需要根据实际的应用架构来调整
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 这里应该通过Provider或其他方式获取BLEService实例
    // 暂时使用模拟数据
    final healthInfo = _getHealthInfo();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(healthInfo['healthy'] as bool),
                  color: _getStatusColor(healthInfo['healthy'] as bool),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Connection Health',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(healthInfo['healthy'] as bool)
                            .withValues(alpha: _pulseAnimation.value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildHealthDetails(healthInfo),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthDetails(Map<String, dynamic> healthInfo) {
    final isHealthy = healthInfo['healthy'] as bool;
    final lastSuccess = healthInfo['lastSuccessfulOperation'] as DateTime?;
    final timeSinceSuccess = healthInfo['timeSinceLastSuccess'] as int?;
    final deviceConnected = healthInfo['deviceConnected'] as bool;

    return Column(
      children: [
        Row(
          children: [
            Icon(
              deviceConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              size: 16,
              color: deviceConnected ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              deviceConnected ? 'Device Connected' : 'Device Disconnected',
              style: TextStyle(
                color: deviceConnected ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              isHealthy ? 'Healthy' : 'Unhealthy',
              style: TextStyle(
                color: isHealthy ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        if (lastSuccess != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                'Last successful operation:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(lastSuccess),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
        if (timeSinceSuccess != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.timer,
                size: 16,
                color: _getTimeAgoColor(timeSinceSuccess),
              ),
              const SizedBox(width: 8),
              Text(
                'Time since last success:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const Spacer(),
              Text(
                '${timeSinceSuccess}s',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _getTimeAgoColor(timeSinceSuccess),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Map<String, dynamic> _getHealthInfo() {
    // 这里应该从实际的BLEService获取数据
    // 暂时返回模拟数据
    return {
      'healthy': true,
      'lastSuccessfulOperation': DateTime.now().subtract(const Duration(seconds: 5)),
      'deviceConnected': true,
      'timeSinceLastSuccess': 5,
    };
  }

  IconData _getStatusIcon(bool healthy) {
    if (healthy) {
      return Icons.check_circle;
    } else {
      return Icons.error;
    }
  }

  Color _getStatusColor(bool healthy) {
    if (healthy) {
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  Color _getTimeAgoColor(int seconds) {
    if (seconds < 10) {
      return Colors.green;
    } else if (seconds < 30) {
      return Colors.orange;
    } else {
      return Colors.red;
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
}

/// 连接健康状态指示器（简化版）
class SimpleConnectionHealthIndicator extends StatelessWidget {
  final bool isConnected;
  final bool isHealthy;
  final DateTime? lastSuccess;
  final int? timeSinceSuccess;

  const SimpleConnectionHealthIndicator({
    super.key,
    required this.isConnected,
    required this.isHealthy,
    this.lastSuccess,
    this.timeSinceSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIcon(),
            size: 16,
            color: _getIconColor(),
          ),
          const SizedBox(width: 8),
          Text(
            _getText(),
            style: TextStyle(
              color: _getTextColor(),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (timeSinceSuccess != null) ...[
            const SizedBox(width: 8),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: _getTimeAgoColor(timeSinceSuccess!),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIcon() {
    if (!isConnected) {
      return Icons.bluetooth_disabled;
    } else if (isHealthy) {
      return Icons.bluetooth_connected;
    } else {
      return Icons.bluetooth_searching;
    }
  }

  Color _getIconColor() {
    if (!isConnected) {
      return Colors.grey;
    } else if (isHealthy) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }

  Color _getTextColor() {
    if (!isConnected) {
      return Colors.grey;
    } else if (isHealthy) {
      return Colors.green.shade700;
    } else {
      return Colors.orange.shade700;
    }
  }

  Color _getBackgroundColor() {
    if (!isConnected) {
      return Colors.grey.shade100;
    } else if (isHealthy) {
      return Colors.green.shade50;
    } else {
      return Colors.orange.shade50;
    }
  }

  Color _getBorderColor() {
    if (!isConnected) {
      return Colors.grey.shade300;
    } else if (isHealthy) {
      return Colors.green.shade300;
    } else {
      return Colors.orange.shade300;
    }
  }

  String _getText() {
    if (!isConnected) {
      return 'Disconnected';
    } else if (isHealthy) {
      return 'Connected';
    } else {
      return 'Checking...';
    }
  }

  Color _getTimeAgoColor(int seconds) {
    if (seconds < 10) {
      return Colors.green;
    } else if (seconds < 30) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}