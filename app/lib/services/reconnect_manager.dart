import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app/models/saved_controller.dart';
import 'package:app/providers/app_state_provider.dart';

/// 重连策略枚举
enum ReconnectStrategy {
  immediate,    // 立即重连
  exponential,  // 指数退避
  linear,       // 线性增长
  fixed,        // 固定间隔
}

/// 重连状态
enum ReconnectStatus {
  idle,         // 空闲
  running,      // 运行中
  paused,       // 暂停
  stopped,      // 停止
}

/// 重连尝试记录
class ReconnectAttempt {
  final String controllerId;
  final DateTime timestamp;
  final bool success;
  final String? error;
  final int attemptNumber;
  final Duration delay;

  ReconnectAttempt({
    required this.controllerId,
    required this.timestamp,
    required this.success,
    this.error,
    required this.attemptNumber,
    required this.delay,
  });
}

/// 重连配置
class ReconnectConfig {
  final ReconnectStrategy strategy;
  final Duration initialDelay;
  final Duration maxDelay;
  final Duration timeout;
  final int maxAttempts;
  final double backoffMultiplier;

  const ReconnectConfig({
    this.strategy = ReconnectStrategy.exponential,
    this.initialDelay = const Duration(seconds: 5),
    this.maxDelay = const Duration(minutes: 10),
    this.timeout = const Duration(seconds: 10),
    this.maxAttempts = 5,
    this.backoffMultiplier = 2.0,
  });
}

/// 自动重连管理器
class ReconnectManager {
  ReconnectManager({
    required this.appStateProvider,
    this.config = const ReconnectConfig(),
  });

  final AppStateProvider appStateProvider;
  final ReconnectConfig config;

  ReconnectStatus _status = ReconnectStatus.idle;
  Timer? _timer;
  final List<ReconnectAttempt> _attempts = [];
  final Map<String, int> _attemptCounters = {};
  DateTime? _lastSuccessfulReconnect;

  /// 获取重连状态
  ReconnectStatus get status => _status;

  /// 获取所有重连尝试记录
  List<ReconnectAttempt> get attempts => List.unmodifiable(_attempts);

  /// 获取特定设备的重连尝试次数
  int getAttemptCount(String controllerId) => _attemptCounters[controllerId] ?? 0;

  /// 开始自动重连
  void start() {
    if (_status == ReconnectStatus.running) return;

    debugPrint('ReconnectManager: Starting auto reconnect');
    _status = ReconnectStatus.running;
    _scheduleNextCycle( Duration.zero);
  }

  /// 停止自动重连
  void stop() {
    debugPrint('ReconnectManager: Stopping auto reconnect');
    _status = ReconnectStatus.stopped;
    _timer?.cancel();
    _timer = null;
  }

  /// 暂停自动重连
  void pause() {
    debugPrint('ReconnectManager: Pausing auto reconnect');
    _status = ReconnectStatus.paused;
    _timer?.cancel();
    _timer = null;
  }

  /// 恢复自动重连
  void resume() {
    if (_status == ReconnectStatus.paused) {
      debugPrint('ReconnectManager: Resuming auto reconnect');
      _status = ReconnectStatus.running;
      _scheduleNextCycle(const Duration(seconds: 1));
    }
  }

  /// 重置重连计数器
  void resetCounters() {
    _attemptCounters.clear();
    _attempts.clear();
    debugPrint('ReconnectManager: Reset all counters');
  }

  /// 重置特定设备的重连计数器
  void resetCounter(String controllerId) {
    _attemptCounters.remove(controllerId);
    debugPrint('ReconnectManager: Reset counter for $controllerId');
  }

  /// 手动触发重连
  Future<void> triggerReconnect() async {
    if (_status != ReconnectStatus.running) {
      start();
    } else {
      await _performReconnectCycle();
    }
  }

  /// 重置特定设备的重连计数器（当用户手动连接成功时调用）
  void resetReconnectForController(String controllerId) {
    _attemptCounters.remove(controllerId);
    _attempts.removeWhere((attempt) => attempt.controllerId == controllerId);
    debugPrint('ReconnectManager: Reset reconnect counter for $controllerId');
  }

  /// 停止特定设备的重连
  void stopReconnectForController(String controllerId) {
    _attemptCounters.remove(controllerId);
    debugPrint('ReconnectManager: Stopped reconnect attempts for $controllerId');
  }

  /// 安排下一个重连周期
  void _scheduleNextCycle(Duration delay) {
    if (_status != ReconnectStatus.running) return;

    _timer?.cancel();
    _timer = Timer(delay, () {
      if (_status == ReconnectStatus.running) {
        _performReconnectCycle().whenComplete(() {
          // 安排下一个周期
          final nextDelay = _calculateNextDelay();
          _scheduleNextCycle(nextDelay);
        });
      }
    });
  }

  /// 执行重连周期
  Future<void> _performReconnectCycle() async {
    try {
      debugPrint('ReconnectManager: Performing reconnect cycle');

      // 获取需要重连的设备
      final controllersToReconnect = _getControllersToReconnect();

      if (controllersToReconnect.isEmpty) {
        debugPrint('ReconnectManager: No controllers to reconnect, stopping auto-reconnect');
        _status = ReconnectStatus.idle;
        _timer?.cancel();
        _timer = null;
        return;
      }

      // 并行尝试重连所有设备
      final futures = controllersToReconnect.map(
        (controller) => _attemptReconnect(controller),
      );

      await Future.wait(futures);

    } catch (e) {
      debugPrint('ReconnectManager: Reconnect cycle error: $e');
    }
  }

  /// 获取需要重连的设备列表
  List<SavedController> _getControllersToReconnect() {
    final allControllers = appStateProvider.savedControllers;

    return allControllers.where((controller) {
      final connectionStatus = controller.connectionStatus;
      final attemptCount = getAttemptCount(controller.controllerId);
      final lastAttempt = controller.retryPolicy.lastAttemptAt;

      debugPrint('ReconnectManager: Evaluating controller ${controller.controllerId}: status=$connectionStatus, attempts=$attemptCount');

      // 优先检查实际的BLE连接状态
      final actualDevice = appStateProvider.getConnectedController(controller.controllerId);
      if (actualDevice != null && actualDevice.isConnected) {
        debugPrint('ReconnectManager: Controller ${controller.controllerId} is actually connected, skipping');
        return false;
      }

      // 检查应用整体连接状态
      if (appStateProvider.isConnected &&
          appStateProvider.selectedDevice?.id == controller.controllerId) {
        debugPrint('ReconnectManager: App reports ${controller.controllerId} as connected, skipping');
        return false;
      }

      // 只重连未连接且未达到最大尝试次数的设备
      if (connectionStatus == SavedControllerConnectionStatus.unavailable ||
          attemptCount >= config.maxAttempts) {
        debugPrint('ReconnectManager: Controller ${controller.controllerId} is unavailable or max attempts reached, skipping');
        return false;
      }

      // 如果保存的状态是connected但实际已断开，仍然尝试重连
      if (connectionStatus == SavedControllerConnectionStatus.connected) {
        debugPrint('ReconnectManager: Controller ${controller.controllerId} marked as connected but actually disconnected, will reconnect');
        // 强制更新状态为断开
        appStateProvider.markControllerDisconnected(controller.controllerId);
      }

      // 如果距离上次尝试时间太短，跳过这次重连（防止过于频繁）
      if (lastAttempt != null) {
        final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
        final minInterval = _calculateDelayForAttempt(attemptCount + 1);
        if (timeSinceLastAttempt < minInterval) {
          debugPrint('ReconnectManager: Controller ${controller.controllerId} tried too recently, skipping');
          return false;
        }
      }

      debugPrint('ReconnectManager: Controller ${controller.controllerId} needs reconnect');
      return true;
    }).toList();
  }

  /// 尝试重连单个设备
  Future<void> _attemptReconnect(SavedController controller) async {
    final controllerId = controller.controllerId;
    final attemptNumber = (getAttemptCount(controllerId) + 1);

    // 更新尝试计数器
    _attemptCounters[controllerId] = attemptNumber;

    // 计算本次重连的延迟
    final delay = _calculateDelayForAttempt(attemptNumber);

    debugPrint('ReconnectManager: Attempting reconnect for $controllerId (attempt $attemptNumber/${config.maxAttempts})');

    
    try {
      // 等待延迟时间
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      // 执行重连逻辑
      await appStateProvider.connectToDevice(controllerId);

      // 重连成功
      _attemptCounters[controllerId] = 0; // 重置计数器
      _lastSuccessfulReconnect = DateTime.now();

      final successAttempt = ReconnectAttempt(
        controllerId: controllerId,
        timestamp: DateTime.now(),
        success: true,
        attemptNumber: attemptNumber,
        delay: delay,
      );

      _attempts.add(successAttempt);
      debugPrint('ReconnectManager: Successfully reconnected to $controllerId');

    } catch (e) {
      // 重连失败
      final failedAttempt = ReconnectAttempt(
        controllerId: controllerId,
        timestamp: DateTime.now(),
        success: false,
        error: e.toString(),
        attemptNumber: attemptNumber,
        delay: delay,
      );

      _attempts.add(failedAttempt);
      debugPrint('ReconnectManager: Failed to reconnect to $controllerId: $e');

      // 如果达到最大尝试次数，标记为不可用
      if (attemptNumber >= config.maxAttempts) {
        appStateProvider.markControllerUnavailable(controllerId);
        debugPrint('ReconnectManager: Marking $controllerId as unavailable after ${config.maxAttempts} attempts');
      }
    }
  }

  /// 计算重连延迟
  Duration _calculateDelayForAttempt(int attemptNumber) {
    switch (config.strategy) {
      case ReconnectStrategy.immediate:
        return Duration.zero;

      case ReconnectStrategy.fixed:
        return config.initialDelay;

      case ReconnectStrategy.linear:
        final delay = config.initialDelay.inSeconds * attemptNumber;
        return Duration(seconds: delay.clamp(0, config.maxDelay.inSeconds).toInt());

      case ReconnectStrategy.exponential:
        final delay = config.initialDelay.inSeconds *
                      (config.backoffMultiplier.pow(attemptNumber - 1));
        return Duration(seconds: delay.clamp(0, config.maxDelay.inSeconds).toInt());
    }
  }

  /// 计算下一个重连周期的延迟
  Duration _calculateNextDelay() {
    // 如果最近有成功的重连，使用较短的间隔
    if (_lastSuccessfulReconnect != null) {
      final timeSinceLastSuccess = DateTime.now().difference(_lastSuccessfulReconnect!);
      if (timeSinceLastSuccess.inMinutes < 5) {
        return const Duration(seconds: 10);
      }
    }

    // 根据失败的设备数量调整延迟
    final failedControllers = _getControllersToReconnect();
    if (failedControllers.isEmpty) {
      return const Duration(minutes: 2); // 增加到2分钟
    }

    // 设备越多，检查频率越高，但最小间隔增加
    final baseInterval = 15; // 增加基础间隔
    final interval = baseInterval ~/ (failedControllers.length.clamp(1, 3));
    return Duration(seconds: interval.clamp(10, 60).toInt()); // 最小10秒，最大1分钟
  }

  /// 获取重连统计信息
  Map<String, dynamic> getStatistics() {
    final totalAttempts = _attempts.length;
    final successfulAttempts = _attempts.where((a) => a.success).length;
    final failedAttempts = totalAttempts - successfulAttempts;

    final recentAttempts = _attempts.where((a) =>
      DateTime.now().difference(a.timestamp).inHours <= 24
    );

    return {
      'totalAttempts': totalAttempts,
      'successfulAttempts': successfulAttempts,
      'failedAttempts': failedAttempts,
      'successRate': totalAttempts > 0 ? successfulAttempts / totalAttempts : 0.0,
      'recentAttempts': recentAttempts.length,
      'activeControllers': _getControllersToReconnect().length,
      'lastSuccessfulReconnect': _lastSuccessfulReconnect,
      'status': _status.name,
    };
  }

  /// 销毁重连管理器
  void dispose() {
    debugPrint('ReconnectManager: Disposing');
    stop();
    _attempts.clear();
    _attemptCounters.clear();
  }
}

extension on num {
  double pow(int exponent) {
    if (exponent == 0) return 1.0;
    double result = toDouble();
    for (int i = 1; i < exponent; i++) {
      result *= toDouble();
    }
    return result;
  }
}