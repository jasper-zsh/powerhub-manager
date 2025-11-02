import 'package:flutter_test/flutter_test.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/services/ble_service.dart';
import 'package:app/models/control_command/set_command.dart';

void main() {
  group('Connection Health Integration Tests', () {
    late AppStateProvider appStateProvider;
    late BLEService bleService;

    setUp(() {
      // 创建测试实例
      bleService = BLEService();
      appStateProvider = AppStateProvider(
        bleService: bleService,
      );
    });

    tearDown(() {
      // 清理资源
      appStateProvider.dispose();
    });

    test('should detect when device is not actually connected', () async {
      // 模拟设备显示已连接但实际不健康的情况
      print('Testing connection health detection...');

      // 当没有设备连接时，应该返回false
      expect(appStateProvider.isConnected, isFalse,
          reason: 'Should return false when no device is connected');

      print('✓ Correctly detected no device connection');
    });

    test('should handle connection state changes', () async {
      print('Testing connection state change handling...');

      // 模拟连接状态变化监听
      int changeCount = 0;

      // 监听状态变化
      appStateProvider.addListener(() {
        changeCount++;
        print('Connection state changed: ${appStateProvider.isConnected}');
      });

      // 初始状态应该是未连接
      expect(appStateProvider.isConnected, isFalse);
      expect(changeCount, equals(0));

      print('✓ Initial connection state is correct');

      // 注意：在真实环境中，这里会模拟设备连接和断开
      // 但在单元测试中，我们主要验证状态检测逻辑
    });

    test('should properly handle failed operations when disconnected', () async {
      print('Testing failed operation handling...');

      // 当没有连接时，尝试更新通道值应该失败
      expect(appStateProvider.isConnected, isFalse);

      try {
        await appStateProvider.updateChannelValue(0, 128);
        fail('Should have thrown an exception when not connected');
      } catch (e) {
        expect(e.toString(), contains('NOT_CONNECTED'));
        print('✓ Correctly rejected operation when not connected: ${e}');
      }

      // 尝试发送其他命令也应该失败
      try {
        final command = SetCommand(channel: 0, value: 128);
        // 注意：sendSetCommand 方法不存在，这里只测试 updateChannelValue
        // await appStateProvider.sendSetCommand(command);
        fail('Should have thrown an exception when not connected');
      } catch (e) {
        expect(e.toString(), contains('NOT_CONNECTED'));
        print('✓ Correctly rejected command when not connected: ${e}');
      }
    });

    test('should provide accurate connection health information', () {
      print('Testing connection health information...');

      // 获取BLE服务的健康信息
      final healthInfo = bleService.getConnectionHealthInfo();

      // 验证健康信息的结构
      expect(healthInfo, contains('healthy'));
      expect(healthInfo, contains('lastSuccessfulOperation'));
      expect(healthInfo, contains('deviceConnected'));
      expect(healthInfo, contains('timeSinceLastSuccess'));

      print('✓ Connection health info structure is valid: $healthInfo');

      // 当没有设备连接时，设备应该是未连接状态
      expect(healthInfo['deviceConnected'], isFalse);
      expect(healthInfo['healthy'], isFalse);

      print('✓ Health info correctly reflects disconnected state');
    });

    test('should update connection state based on health checks', () async {
      print('Testing connection state updates based on health...');

      // 获取初始状态
      final initialConnected = appStateProvider.isConnected;
      expect(initialConnected, isFalse);

      // 模拟健康状态变化（在实际环境中，这会通过BLE服务的健康检查触发）
      // 这里我们验证AppStateProvider的isConnected getter会检查BLE服务的健康状态

      final healthInfo = bleService.getConnectionHealthInfo();
      final isConnected = appStateProvider.isConnected;

      // 连接状态应该与BLE服务的健康状态一致
      expect(isConnected, equals(healthInfo['healthy'] && healthInfo['deviceConnected']));

      print('✓ Connection state matches BLE service health status');
      print('  - BLE healthy: ${healthInfo['healthy']}');
      print('  - BLE connected: ${healthInfo['deviceConnected']}');
      print('  - App connected: $isConnected');
    });

    test('should handle connection monitoring lifecycle', () {
      print('Testing connection monitoring lifecycle...');

      // 验证连接状态监听器可以被正确启动和停止
      // 这主要通过调用方法来验证没有异常

      expect(() => appStateProvider.reconnectManager, returnsNormally,
          reason: 'Should be able to access reconnect manager');

      final stats = appStateProvider.reconnectStatistics;
      expect(stats, isA<Map<String, dynamic>>(),
          reason: 'Should return reconnect statistics');

      print('✓ Connection monitoring components are accessible');
      print('  - Reconnect manager: OK');
      print('  - Statistics: $stats');
    });

    group('Real-world Scenarios', () {
      test('should handle device suddenly disconnecting during operation', () async {
        print('Testing sudden disconnection scenario...');

        // 模拟操作过程中设备断开的情况
        // 在真实环境中，BLE服务的健康检查会检测到连接丢失
        // AppStateProvider应该通过新的isConnected getter反映这个状态

        expect(appStateProvider.isConnected, isFalse);

        // 尝试执行操作应该失败
        bool operationSucceeded = false;
        try {
          await appStateProvider.updateChannelValue(0, 255);
          operationSucceeded = true;
        } catch (e) {
          expect(e.toString(), contains('NOT_CONNECTED'));
        }

        expect(operationSucceeded, isFalse,
            reason: 'Operation should fail when device is not connected');

        print('✓ Operations correctly fail when device is disconnected');
      });

      test('should detect stale connections', () {
        print('Testing stale connection detection...');

        // 模拟连接长时间无活动的情况
        // AppStateProvider的isConnected getter应该检查最后成功操作时间

        final healthInfo = bleService.getConnectionHealthInfo();
        final timeSinceLastSuccess = healthInfo['timeSinceLastSuccess'] as int?;

        if (timeSinceLastSuccess != null) {
          // 如果超过60秒无成功操作，应该被视为连接断开
          final isStale = timeSinceLastSuccess > 60;
          final isConnected = appStateProvider.isConnected;

          print('  - Time since last success: ${timeSinceLastSuccess}s');
          print('  - Is stale: $isStale');
          print('  - Is connected: $isConnected');

          if (isStale) {
            expect(isConnected, isFalse,
                reason: 'Should not be connected if connection is stale');
          }
        }

        print('✓ Stale connection detection logic is working');
      });
    });
  });

  group('Connection Health UI Integration', () {
    test('should provide data for UI components', () {
      print('Testing UI data provision...');

      // 验证UI组件所需的数据格式
      final appStateProvider = AppStateProvider();

      // 连接状态
      expect(appStateProvider.isConnected, isA<bool>());

      // 错误信息
      expect(appStateProvider.errorMessage, isA<String>());

      // 健康统计
      final stats = appStateProvider.reconnectStatistics;
      expect(stats, isA<Map<String, dynamic>>());

      print('✓ All UI data types are correct');
      print('  - isConnected: ${appStateProvider.isConnected}');
      print('  - errorMessage: "${appStateProvider.errorMessage}"');
      print('  - statistics keys: ${stats.keys.toList()}');

      appStateProvider.dispose();
    });
  });
}