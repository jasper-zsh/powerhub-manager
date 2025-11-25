import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/providers/orchestration_provider_riverpod.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:app/controllers/switch_hub_controller.dart';
import 'package:app/screens/orchestration_screen.dart';

class SwitchHubScreen extends ConsumerStatefulWidget {
  const SwitchHubScreen({super.key});

  @override
  ConsumerState<SwitchHubScreen> createState() => _SwitchHubScreenState();
}

class _SwitchHubScreenState extends ConsumerState<SwitchHubScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(switchHubControllerProvider.notifier).initialize();
    });
    ref.listen<SwitchHubState>(switchHubControllerProvider, (previous, next) {
      if (!mounted) {
        return;
      }
      final controller = ref.read(switchHubControllerProvider.notifier);
      if (next.statusMessage != null && next.statusMessage != previous?.statusMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.statusMessage!),
            backgroundColor: Colors.green,
          ),
        );
        controller.clearStatusMessage();
      }
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Colors.red,
          ),
        );
        controller.clearError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orchestrationProvider = ref.watch(orchestrationProviderProvider);
    final switchHubState = ref.watch(switchHubControllerProvider);
    final controller = ref.read(switchHubControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SwitchHub 编排管理'),
        actions: [
          IconButton(
            icon: switchHubState.isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth_searching),
            onPressed: switchHubState.isScanning ? null : controller.startScan,
            tooltip: '扫描 SwitchHub',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwitchHubDiscoveryCard(switchHubState, controller.startScan),
            const SizedBox(height: 16),
            _buildCurrentSceneCard(orchestrationProvider),
            const SizedBox(height: 16),
            _buildConfigPushCard(orchestrationProvider, switchHubState),
            const SizedBox(height: 16),
            _buildExecutionLogsCard(orchestrationProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchHubDiscoveryCard(
    SwitchHubState state,
    Future<void> Function() onScan,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'SwitchHub 设备',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.isScanning)
              const Center(child: CircularProgressIndicator())
            else if (state.discoveredDevices.isEmpty)
              const Text('暂未发现 SwitchHub 设备')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.discoveredDevices.length,
                itemBuilder: (context, index) {
                  final device = state.discoveredDevices[index];
                  return ListTile(
                    leading: const Icon(Icons.devices),
                    title: Text(device.platformName.isNotEmpty
                        ? device.platformName
                        : 'SwitchHub (${device.remoteId.str.substring(device.remoteId.str.length - 6)})'),
                    subtitle: Text(device.remoteId.str),
                    trailing: ElevatedButton(
                      onPressed: () => _pushConfigToDevice(device),
                      child: const Text('推送配置'),
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: state.isScanning ? null : onScan,
                icon: const Icon(Icons.refresh),
                label: Text(state.isScanning ? '扫描中...' : '扫描 SwitchHub'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentSceneCard(OrchestrationProvider provider) {
    final activeScene = provider.activeScene;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.playlist_play, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '当前编排场景',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeScene != null) ...[
              Text(
                '场景名称: ${activeScene.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('开关数量: ${provider.activeToggleOrder.length}'),
              const SizedBox(height: 4),
              Text('是否已发布: ${activeScene.isPublished ? '是' : '否'}'),
              if (activeScene.description?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text('描述: ${activeScene.description}'),
              ],
            ] else
              const Text('未选择活跃场景'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const OrchestrationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('管理场景'),
                  ),
                ),
                const SizedBox(width: 12),
                if (activeScene != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _previewSceneConfig(activeScene.id),
                      icon: const Icon(Icons.preview),
                      label: const Text('预览配置'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPushCard(
    OrchestrationProvider provider,
    SwitchHubState state,
  ) {
    final activeScene = provider.activeScene;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.upload_file, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '配置推送',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeScene != null) ...[
              Text('场景: ${activeScene.name}'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('配置信息:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('目标设备数: ${activeScene.referencedControllers.length}'),
                    Text('开关数量: ${provider.activeToggleOrder.length}'),
                    Text('配置版本: v1'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.isPushing)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: activeScene.isPublished && state.discoveredDevices.isNotEmpty
                        ? () => _pushToAllSwitchHubs(state)
                        : null,
                    icon: const Icon(Icons.send),
                    label: const Text('推送到所有 SwitchHub'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ] else
              const Text('请先创建并选择一个编排场景'),
          ],
        ),
      ),
    );
  }

  Widget _buildExecutionLogsCard(OrchestrationProvider provider) {
    final logs = provider.executionLogs.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  '执行日志',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.clear_all),
                  onPressed: () => provider.clearLogs(),
                  tooltip: '清空日志',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              const Text('暂无执行记录')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return ListTile(
                    leading: Icon(
                      log.result == 'success' ? Icons.check_circle : Icons.error,
                      color: log.result == 'success' ? Colors.green : Colors.red,
                    ),
                    title: Text('场景: ${log.sceneId}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('触发源: ${log.triggerSource}'),
                        Text('结果: ${log.result}'),
                        if (log.notes != null)
                          Text('备注: ${log.notes}',
                               style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Text(
                      '${log.triggeredAt.hour.toString().padLeft(2, '0')}:'
                      '${log.triggeredAt.minute.toString().padLeft(2, '0')}:'
                      '${log.triggeredAt.second.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pushConfigToDevice(BluetoothDevice device) async {
    final provider = ref.read(orchestrationProviderProvider);
    final activeScene = provider.activeScene;
    final switchHubController = ref.read(switchHubControllerProvider.notifier);

    if (activeScene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择一个场景')),
      );
      return;
    }

    try {
      final config = provider.buildSwitchHubConfig(activeScene.id);
      final success = await switchHubController.pushConfigToDevice(device, config);
      if (!success) {
        return;
      }

      // 记录执行日志
      await provider.recordExecution(
        sceneId: activeScene.id,
        triggerSource: 'Manual Push',
        preview: provider.previewScene(
          activeScene.id,
          toggleId: 'manual',
          stateId: 'push',
        ),
        success: true,
        notes: '推送到设备: ${device.remoteId.str}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('配置推送成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pushToAllSwitchHubs(SwitchHubState state) async {
    final provider = ref.read(orchestrationProviderProvider);
    final activeScene = provider.activeScene;
    final controller = ref.read(switchHubControllerProvider.notifier);

    if (activeScene == null || state.discoveredDevices.isEmpty) {
      return;
    }

    try {
      final config = provider.buildSwitchHubConfig(activeScene.id);
      final successCount = await controller.pushConfigToAll(
        state.discoveredDevices,
        config,
      );
      await provider.recordExecution(
        sceneId: activeScene.id,
        triggerSource: 'Batch Push',
        preview: provider.previewScene(
          activeScene.id,
          toggleId: 'manual',
          stateId: 'batch_push',
        ),
        success: successCount == state.discoveredDevices.length,
        notes: '推送到 $successCount/${state.discoveredDevices.length} 个设备',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('配置推送完成: $successCount/${state.discoveredDevices.length} 个设备'),
            backgroundColor: successCount == state.discoveredDevices.length
                ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('推送失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _previewSceneConfig(String sceneId) {
    final provider = ref.read(orchestrationProviderProvider);

    try {
      final config = provider.buildSwitchHubConfig(sceneId);
      final configJson = config.toJson();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('配置预览'),
          content: SingleChildScrollView(
            child: Text(
              '开关数量: ${config.switches.length}\n\n'
              '完整配置:\n${const JsonEncoder.withIndent('  ').convert(configJson)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('生成配置预览失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
