import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/action_validator.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/providers/orchestration_provider_riverpod.dart';
import 'package:app/providers/status_orchestration_provider.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/widgets/orchestration/command_preview_sheet.dart';
import 'package:app/widgets/orchestration/switch_hub_sync_sheet.dart';
import 'package:app/widgets/orchestration/toggle_card.dart';
import 'package:app/widgets/status/status_slot_editor_sheet.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/ui_config.dart';

class OrchestrationScreen extends ConsumerStatefulWidget {
  const OrchestrationScreen({super.key});

  @override
  ConsumerState<OrchestrationScreen> createState() =>
      _OrchestrationScreenState();
}

class _OrchestrationScreenState extends ConsumerState<OrchestrationScreen> {
  bool _didLoad = false;
  final Map<String, String> _selectedStates = <String, String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_didLoad) {
        _didLoad = true;
        ref.read(orchestrationProviderProvider).init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(orchestrationProviderProvider);
    final scene = provider.activeScene;
    _syncSelection(scene);

    // TODO: Initialize status orchestration when SwitchHub config is available
    // This would typically happen after SwitchHub sync is completed

    return Scaffold(
      appBar: AppBar(
        title: const Text('SwitchHub 编排'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建场景',
            onPressed: () => _showCreateSceneDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            tooltip: '导出/推送到 SwitchHub',
            onPressed: scene == null
                ? null
                : () => _openSyncSheet(scene, provider),
          ),
        ],
      ),
      floatingActionButton: scene == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddToggleDialog(),
              icon: const Icon(Icons.toggle_on),
              label: const Text('新增开关'),
            ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : scene == null
          ? _buildEmptyState()
          : _buildSceneBody(provider, scene),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.toggle_on_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('尚未创建任何编排场景'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _showCreateSceneDialog(),
            icon: const Icon(Icons.add),
            label: const Text('创建场景'),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneBody(OrchestrationProvider provider, ToggleScene scene) {
    final grouped = _groupStates(scene);
    final children = <Widget>[
      _buildSceneHeader(provider, scene),
      const SizedBox(height: 16),
      if (grouped.isEmpty)
        _buildNoToggleBanner()
      else
        ...grouped.map(
          (entry) =>
              _buildToggleSection(provider, scene, entry.key, entry.value),
        ),
      const SizedBox(height: 16),
      _buildExecutionLogCard(provider),
      const SizedBox(height: 32),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: children,
    );
  }

  Widget _buildSceneHeader(OrchestrationProvider provider, ToggleScene scene) {
    final scenes = provider.scenes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: scene.id,
                    decoration: const InputDecoration(labelText: '当前场景'),
                    items: scenes
                        .map(
                          (entry) => DropdownMenuItem<String>(
                            value: entry.id,
                            child: Text(entry.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        provider.selectScene(value);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline),
                  tooltip: '重命名场景',
                  onPressed: () => _showRenameSceneDialog(scene),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除场景',
                  onPressed: () => _confirmDeleteScene(scene),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('开关数量：${provider.activeToggleOrder.length}'),
            Text('最近更新：${_formatTimestamp(scene.updatedAt)}'),
            if (scene.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  scene.description!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: scene.isPublished,
              title: const Text('标记为已发布'),
              onChanged: (value) async {
                try {
                  await provider.publishScene(scene.id, isPublished: value);
                } catch (error) {
                  _showSnack('更新发布状态失败: $error');
                }
              },
            ),
            if (provider.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoToggleBanner() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('尚未添加任何开关'),
            SizedBox(height: 4),
            Text(
              '点击右下角的“新增开关”按钮即可创建新的开关和状态。',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Iterable<MapEntry<String, List<ToggleState>>> _groupStates(
    ToggleScene scene,
  ) {
    final order = <String>[];
    final grouped = <String, List<ToggleState>>{};
    for (final state in scene.states) {
      if (!grouped.containsKey(state.toggleId)) {
        order.add(state.toggleId);
      }
      grouped.putIfAbsent(state.toggleId, () => <ToggleState>[]).add(state);
    }
    return order.map((toggleId) => MapEntry(toggleId, grouped[toggleId]!));
  }

  Widget _buildToggleSection(
    OrchestrationProvider provider,
    ToggleScene scene,
    String toggleId,
    List<ToggleState> states,
  ) {
    final selectedStateId = _selectedStates[toggleId]!;
    final theme = Theme.of(context);
    final currentState = states.firstWhere(
      (state) => state.stateId == selectedStateId,
      orElse: () => states.first,
    );
    final switchSlot = scene.switchSlots[toggleId];

    // Get status configuration from the orchestration provider
    final statusConfigurations = ref.watch(statusConfigurationsProvider);
    final statusConfiguration =
        statusConfigurations[int.tryParse(toggleId) ?? 0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            ToggleCard(
              toggleId: toggleId,
              states: states,
              selectedStateId: selectedStateId,
              onStateChanged: (stateId) {
                setState(() {
                  _selectedStates[toggleId] = stateId;
                });
              },
              onAddCommandBundle: () => _showBundleEditor(
                _stateForId(states, _selectedStates[toggleId]!),
              ),
              onEditBundle: (bundle) => _showBundleEditor(
                _stateForId(states, _selectedStates[toggleId]!),
                existing: bundle,
              ),
              controllerAliases: const <String, String>{},
              missingControllers: provider.missingControllers,
              switchSlot: switchSlot,
              statusConfiguration: statusConfiguration,
            ),
            Positioned(
              right: 24,
              top: 12,
              child: PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'rename':
                      _renameToggle(toggleId);
                      break;
                    case 'slot':
                      _editToggleSlot(toggleId);
                      break;
                    case 'status':
                      _editStatusSlots(toggleId);
                      break;
                    case 'delete':
                      _removeToggle(toggleId);
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      leading: Icon(Icons.drive_file_rename_outline),
                      title: Text('重命名'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'slot',
                    child: ListTile(
                      leading: Icon(Icons.confirmation_number_outlined),
                      title: Text('设置开关位号'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: ListTile(
                      leading: Icon(Icons.tune),
                      title: Text('配置状态显示'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('删除'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: states
                .map(
                  (state) => InputChip(
                    label: Text('${state.label} (${state.stateId})'),
                    onPressed: () => _renameStateLabel(toggleId, state),
                  ),
                )
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () =>
                  _previewState(toggleId, _selectedStates[toggleId]!),
              icon: const Icon(Icons.visibility),
              label: const Text('预览当前状态序列'),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }

  ToggleState _stateForId(List<ToggleState> states, String stateId) {
    return states.firstWhere(
      (state) => state.stateId == stateId,
      orElse: () => states.first,
    );
  }

  Widget _buildExecutionLogCard(OrchestrationProvider provider) {
    final logs = provider.executionLogs;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Text('执行日志', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: '清空日志',
                  onPressed: logs.isEmpty
                      ? null
                      : () async {
                          await provider.clearLogs();
                          if (mounted) {
                            _showSnack('执行日志已清空');
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text('暂无执行记录。')
            else
              ...logs
                  .take(5)
                  .map(
                    (log) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        log.isSuccess ? Icons.check_circle : Icons.error,
                        color: log.isSuccess ? Colors.green : Colors.orange,
                      ),
                      title: Text(log.sceneId),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('触发源：${log.triggerSource}'),
                          Text('结果：${log.result}'),
                          if (log.notes != null)
                            Text(
                              log.notes!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                      trailing: Text(_formatTimestamp(log.triggeredAt)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _syncSelection(ToggleScene? scene) {
    if (scene == null) {
      _selectedStates.clear();
      return;
    }
    final grouped = _groupStates(scene);
    final existing = grouped.map((entry) => entry.key).toSet();
    _selectedStates.removeWhere((key, _) => !existing.contains(key));
    for (final entry in grouped) {
      _selectedStates.putIfAbsent(entry.key, () {
        final defaultState = entry.value.firstWhere(
          (state) => state.isDefault,
          orElse: () => entry.value.first,
        );
        return defaultState.stateId;
      });
    }
  }

  Future<void> _showCreateSceneDialog() async {
    final provider = ref.read(orchestrationProviderProvider);
    String name = '';
    String description = '';
    await showDialog<void>(
      context: context,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('创建新场景'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  autofocus: true,
                  initialValue: name,
                  decoration: const InputDecoration(labelText: '场景名称'),
                  onChanged: (value) => name = value,
                ),
                TextFormField(
                  initialValue: description,
                  decoration: const InputDecoration(labelText: '描述 (可选)'),
                  onChanged: (value) => description = value,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final trimmedName = name.trim();
                        if (trimmedName.isEmpty) {
                          _showSnack('请填写场景名称');
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        final toggleId =
                            'toggle-${DateTime.now().microsecondsSinceEpoch}';
                        final sceneId =
                            'scene-${DateTime.now().microsecondsSinceEpoch}';
                        final states = <ToggleState>[
                          ToggleState(
                            toggleId: toggleId,
                            stateId: '$toggleId-on',
                            label: '$trimmedName · 开',
                            isDefault: true,
                          ),
                          ToggleState(
                            toggleId: toggleId,
                            stateId: '$toggleId-off',
                            label: '$trimmedName · 关',
                          ),
                        ];
                        final newScene = ToggleScene(
                          id: sceneId,
                          name: trimmedName,
                          states: states,
                          description: description.trim().isEmpty
                              ? null
                              : description.trim(),
                        );
                        await provider.saveScene(newScene);
                        if (mounted) {
                          Navigator.of(context).pop();
                          _showSnack('场景已创建');
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('保存'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRenameSceneDialog(ToggleScene scene) async {
    final provider = ref.read(orchestrationProviderProvider);
    String name = scene.name;
    String description = scene.description ?? '';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑场景'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: name,
              decoration: const InputDecoration(labelText: '场景名称'),
              onChanged: (value) => name = value,
            ),
            TextFormField(
              initialValue: description,
              decoration: const InputDecoration(labelText: '描述'),
              onChanged: (value) => description = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result == true) {
      try {
        final updated = scene.copyWith(
          name: name.trim().isEmpty ? scene.name : name.trim(),
          description: description.trim(),
        );
        await provider.saveScene(updated);
        _showSnack('场景已更新');
      } catch (error) {
        _showSnack('更新场景失败: $error');
      }
    }
  }

  Future<void> _confirmDeleteScene(ToggleScene scene) async {
    final provider = ref.read(orchestrationProviderProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除场景'),
        content: Text('确定删除场景 "${scene.name}" 吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.deleteScene(scene.id);
      _showSnack('场景已删除');
    }
  }

  Future<void> _showAddToggleDialog() async {
    final provider = ref.read(orchestrationProviderProvider);
    String label = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增开关'),
        content: TextFormField(
          initialValue: label,
          decoration: const InputDecoration(labelText: '显示名称 (可选)'),
          onChanged: (value) => label = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (result == true) {
      final trimmed = label.trim();
      await provider.addToggle(baseLabel: trimmed.isEmpty ? null : trimmed);
      _showSnack('开关已创建');
    }
  }

  Future<void> _renameToggle(String toggleId) async {
    final provider = ref.read(orchestrationProviderProvider);
    String nextId = toggleId;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名开关'),
        content: TextFormField(
          initialValue: nextId,
          decoration: const InputDecoration(labelText: '新的开关标识'),
          onChanged: (value) => nextId = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(nextId.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final success = await provider.renameToggle(toggleId, result);
      if (success) {
        setState(() {
          final oldStateId = _selectedStates.remove(toggleId);
          if (oldStateId != null) {
            final nextStateId = oldStateId.startsWith('$toggleId-')
                ? oldStateId.replaceFirst('$toggleId-', '$result-')
                : oldStateId;
            _selectedStates[result] = nextStateId;
          }
        });
        _showSnack('开关已重命名');
      } else {
        _showSnack('名称已存在或无效');
      }
    }
  }

  Future<void> _editToggleSlot(String toggleId) async {
    final provider = ref.read(orchestrationProviderProvider);
    final currentSlot = provider.activeScene?.switchSlots[toggleId];
    String slotInput = currentSlot?.toString() ?? '';
    bool isSaving = false;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('设置开关位号'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                initialValue: slotInput,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Switch 位号',
                  helperText: '留空表示自动分配，正整数可跳号指定',
                  errorText: errorText,
                ),
                onChanged: (value) {
                  slotInput = value;
                  setDialogState(() => errorText = null);
                },
              ),
              const SizedBox(height: 8),
              const Text(
                '位号对应 SwitchHub 上的物理位置。',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final raw = slotInput.trim();
                      int? slot;
                      if (raw.isNotEmpty) {
                        final parsed = int.tryParse(raw);
                        if (parsed == null || parsed <= 0) {
                          setDialogState(() => errorText = '请输入大于 0 的整数');
                          return;
                        }
                        slot = parsed;
                      }
                      setDialogState(() => isSaving = true);
                      final success = await provider.updateToggleSlot(
                        toggleId,
                        slot,
                      );
                      if (!success) {
                        setDialogState(() {
                          isSaving = false;
                          errorText = '该位号已被其他开关使用';
                        });
                        return;
                      }
                      if (mounted) {
                        Navigator.of(context).pop(true);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      _showSnack('开关位号已更新');
    }
  }

  Future<void> _removeToggle(String toggleId) async {
    final provider = ref.read(orchestrationProviderProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除开关'),
        content: Text('确定删除开关 "$toggleId" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await provider.removeToggle(toggleId);
      setState(() {
        _selectedStates.remove(toggleId);
      });
      _showSnack('开关已删除');
    }
  }

  Future<void> _renameStateLabel(String toggleId, ToggleState state) async {
    final provider = ref.read(orchestrationProviderProvider);
    String label = state.label;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重命名 ${state.stateId}'),
        content: TextFormField(
          initialValue: label,
          decoration: const InputDecoration(labelText: '显示名称'),
          onChanged: (value) => label = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(label.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await provider.updateStateLabel(toggleId, state.stateId, result);
      _showSnack('状态标签已更新');
    }
  }

  Future<void> _showBundleEditor(
    ToggleState state, {
    CommandBundle? existing,
  }) async {
    final provider = ref.read(orchestrationProviderProvider);
    String bundleLabel =
        existing?.label ?? 'Bundle ${state.commandBundles.length + 1}';
    bool isEnabled = existing?.isEnabled ?? true;
    final bundleId =
        existing?.id ?? 'bundle-${DateTime.now().microsecondsSinceEpoch}';
    final actions = List<CommandAction>.from(
      existing?.actions ?? <CommandAction>[],
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    existing == null ? '新增命令组合' : '编辑命令组合',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: bundleLabel,
                    decoration: const InputDecoration(labelText: '组合名称'),
                    onChanged: (value) => bundleLabel = value,
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: isEnabled,
                    title: const Text('启用'),
                    onChanged: (value) =>
                        setSheetState(() => isEnabled = value),
                  ),
                  const SizedBox(height: 12),
                  if (actions.isEmpty)
                    const Text('尚未添加动作。')
                  else
                    ...actions.asMap().entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(entry.value.controllerId),
                        subtitle: Text(entry.value.chineseDescription),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () async {
                                final updated = await _showActionEditor(
                                  existing: entry.value,
                                );
                                if (updated != null) {
                                  setSheetState(() {
                                    actions[entry.key] = updated;
                                  });
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => setSheetState(
                                () => actions.removeAt(entry.key),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final action = await _showActionEditor();
                        if (action != null) {
                          setSheetState(() => actions.add(action));
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('添加动作'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      if (existing != null)
                        TextButton(
                          onPressed: () async {
                            await provider.removeCommandBundle(
                              state.toggleId,
                              state.stateId,
                              bundleId,
                            );
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              _showSnack('命令组合已删除');
                            }
                          },
                          child: const Text('删除'),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: bundleLabel.trim().isEmpty || actions.isEmpty
                            ? null
                            : () async {
                                final bundle = CommandBundle(
                                  id: bundleId,
                                  label: bundleLabel.trim(),
                                  actions: actions,
                                  isEnabled: isEnabled,
                                );
                                await provider.upsertCommandBundle(
                                  state.toggleId,
                                  state.stateId,
                                  bundle,
                                );
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  _showSnack('命令组合已保存');
                                }
                              },
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<CommandAction?> _showActionEditor({CommandAction? existing}) async {
    final savedControllers = ref
        .read(savedControllerControllerProvider)
        .controllers;

    // Initialize form values
    CommandActionType selectedType =
        existing?.type ?? CommandActionType.channelValue;
    String controllerId = existing?.controllerId ?? '';
    String channelText = existing?.channel?.toString() ?? '';
    String valueText = existing?.value?.toString() ?? '';
    String durationText = existing?.duration?.toString() ?? '';
    String periodText = existing?.period?.toString() ?? '';
    String countText = existing?.count?.toString() ?? '';
    String totalTimeText = existing?.totalTime?.toString() ?? '';
    String pauseTimeText = existing?.pauseTime?.toString() ?? '';
    String presetIdText = existing?.presetId?.toString() ?? '';

    String? selectedSavedControllerId =
        savedControllers.any(
          (controller) => controller.controllerId == controllerId,
        )
        ? controllerId
        : null;

    CommandAction? result;

    // Show the dialog
    await showDialog<void>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(existing == null ? '新增动作' : '编辑动作'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Controller selection
                  TextFormField(
                    initialValue: controllerId,
                    decoration: const InputDecoration(
                      labelText: '目标控制器 MAC',
                      helperText: '控制器的蓝牙MAC地址',
                    ),
                    onChanged: (value) => controllerId = value,
                  ),
                  if (savedControllers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedSavedControllerId,
                      decoration: const InputDecoration(labelText: '从已保存设备选择'),
                      items: savedControllers
                          .map(
                            (controller) => DropdownMenuItem<String>(
                              value: controller.controllerId,
                              child: Text(
                                controller.alias.isEmpty
                                    ? controller.controllerId
                                    : '${controller.alias} (${controller.controllerId})',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSavedControllerId = value;
                          controllerId = value ?? controllerId;
                        });
                      },
                    ),
                  const SizedBox(height: 16),

                  // Action type selector
                  DropdownButtonFormField<CommandActionType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: '动作类型',
                      helperText: '选择要执行的动作类型',
                    ),
                    items: CommandActionType.values.map((type) {
                      String label;
                      String description;

                      switch (type) {
                        case CommandActionType.channelValue:
                          label = '设置通道值';
                          description = '立即设置通道为指定值 (0-255)';
                          break;
                        case CommandActionType.presetTrigger:
                          label = '触发预设';
                          description = '激活预设配置';
                          break;
                        case CommandActionType.gradientMode:
                          label = '渐变模式';
                          description = '平滑过渡到目标值';
                          break;
                        case CommandActionType.blinkMode:
                          label = '闪烁模式';
                          description = '周期性开关闪烁';
                          break;
                        case CommandActionType.strobeMode:
                          label = '频闪模式';
                          description = '快速闪烁效果';
                          break;
                      }

                      return DropdownMenuItem<CommandActionType>(
                        value: type,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedType = value;
                          errorMessage = null; // Clear error when type changes
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Channel field (common to most types)
                  if (selectedType != CommandActionType.presetTrigger)
                    TextFormField(
                      initialValue: channelText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '通道',
                        helperText: '目标通道 (0-5)',
                        errorText:
                            channelText.isNotEmpty &&
                                (int.tryParse(channelText) == null ||
                                    int.parse(channelText) < 0 ||
                                    int.parse(channelText) > 5)
                            ? '通道必须在 0-5 之间'
                            : null,
                      ),
                      onChanged: (value) {
                        channelText = value;
                        setDialogState(() {}); // Rebuild to show validation
                      },
                    ),

                  // Dynamic mode specific fields
                  if (selectedType == CommandActionType.channelValue) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: valueText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '目标值',
                        helperText: 'PWM 值 (0-255)',
                        errorText:
                            valueText.isNotEmpty &&
                                (int.tryParse(valueText) == null ||
                                    int.parse(valueText) < 0 ||
                                    int.parse(valueText) > 255)
                            ? '值必须在 0-255 之间'
                            : null,
                      ),
                      onChanged: (value) {
                        valueText = value;
                        setDialogState(() {});
                      },
                    ),
                  ] else if (selectedType ==
                      CommandActionType.gradientMode) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: valueText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '目标值',
                        helperText: '渐变目标值 (0-255)',
                        errorText:
                            valueText.isNotEmpty &&
                                (int.tryParse(valueText) == null ||
                                    int.parse(valueText) < 0 ||
                                    int.parse(valueText) > 255)
                            ? '值必须在 0-255 之间'
                            : null,
                      ),
                      onChanged: (value) {
                        valueText = value;
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: durationText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '渐变时间',
                        helperText: '渐变持续时间，单位毫秒 (1000-60000)',
                        errorText:
                            durationText.isNotEmpty &&
                                (int.tryParse(durationText) == null ||
                                    int.parse(durationText) < 1 ||
                                    int.parse(durationText) > 60000)
                            ? '渐变时间必须在 1-60000 毫秒之间'
                            : null,
                      ),
                      onChanged: (value) {
                        durationText = value;
                        setDialogState(() {});
                      },
                    ),
                    // Helper examples
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '常用设置:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• 快速渐变: 500-2000ms',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '• 中等渐变: 3000-5000ms',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '• 慢速渐变: 8000-15000ms',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ] else if (selectedType == CommandActionType.blinkMode) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: periodText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '闪烁周期',
                        helperText: '闪烁周期，单位毫秒 (50-10000)',
                        errorText:
                            periodText.isNotEmpty &&
                                (int.tryParse(periodText) == null ||
                                    int.parse(periodText) < 50 ||
                                    int.parse(periodText) > 10000)
                            ? '闪烁周期必须在 50-10000 毫秒之间'
                            : null,
                      ),
                      onChanged: (value) {
                        periodText = value;
                        setDialogState(() {});
                      },
                    ),
                    if (periodText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '闪烁频率: ${(1000 / int.parse(periodText)).toStringAsFixed(1)} Hz',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    // Helper examples
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '常用设置:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• 快速闪烁: 250-500ms (2-4Hz)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '• 中等闪烁: 1000-2000ms (0.5-1Hz)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '• 慢速闪烁: 3000-5000ms (0.2-0.33Hz)',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ] else if (selectedType == CommandActionType.strobeMode) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: countText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '闪烁次数',
                        helperText: '闪烁次数 (1-255)',
                        errorText:
                            countText.isNotEmpty &&
                                (int.tryParse(countText) == null ||
                                    int.parse(countText) < 1 ||
                                    int.parse(countText) > 255)
                            ? '闪烁次数必须在 1-255 之间'
                            : null,
                      ),
                      onChanged: (value) {
                        countText = value;
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: totalTimeText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '总时间',
                        helperText: '总执行时间，单位毫秒 (10-60000)',
                        errorText:
                            totalTimeText.isNotEmpty &&
                                (int.tryParse(totalTimeText) == null ||
                                    int.parse(totalTimeText) < 10 ||
                                    int.parse(totalTimeText) > 60000)
                            ? '总时间必须在 10-60000 毫秒之间'
                            : null,
                      ),
                      onChanged: (value) {
                        totalTimeText = value;
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: pauseTimeText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '暂停时间',
                        helperText: '暂停时间，单位毫秒',
                        errorText:
                            pauseTimeText.isNotEmpty &&
                                totalTimeText.isNotEmpty &&
                                int.parse(pauseTimeText) >=
                                    int.parse(totalTimeText)
                            ? '暂停时间必须小于总时间'
                            : null,
                      ),
                      onChanged: (value) {
                        pauseTimeText = value;
                        setDialogState(() {});
                      },
                    ),
                    if (countText.isNotEmpty && totalTimeText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '闪烁频率: ${(int.parse(countText) * 1000 / int.parse(totalTimeText)).toStringAsFixed(1)} Hz',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    // Helper examples
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '常用设置:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• 提醒闪烁: 3次，2秒总时长，500ms暂停',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '• 警告频闪: 5次，3秒总时长，200ms暂停',
                            style: const TextStyle(fontSize: 11),
                          ),
                          Text(
                            '• 紧急闪烁: 10次，1秒总时长，50ms暂停',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ] else if (selectedType ==
                      CommandActionType.presetTrigger) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: presetIdText,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '预设ID',
                        helperText: '要触发的预设配置ID (>= 0)',
                        errorText:
                            presetIdText.isNotEmpty &&
                                (int.tryParse(presetIdText) == null ||
                                    int.parse(presetIdText) < 0)
                            ? '预设ID必须大于等于0'
                            : null,
                      ),
                      onChanged: (value) {
                        presetIdText = value;
                        setDialogState(() {});
                      },
                    ),
                  ],

                  // Error message display
                  if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Validate and create action
                  final trimmedId = controllerId.trim();
                  if (trimmedId.isEmpty) {
                    setDialogState(() => errorMessage = '请输入控制器ID');
                    return;
                  }

                  // Create action based on type
                  CommandAction? newAction;

                  try {
                    switch (selectedType) {
                      case CommandActionType.channelValue:
                        final channel = _parseIntField(channelText, '通道');
                        final value = _parseIntField(valueText, '值');
                        if (channel != null && value != null) {
                          newAction = CommandAction(
                            controllerId: trimmedId,
                            type: selectedType,
                            channel: channel,
                            value: value,
                          );
                        }
                        break;

                      case CommandActionType.gradientMode:
                        final channel = _parseIntField(channelText, '通道');
                        final targetValue = _parseIntField(valueText, '目标值');
                        final duration = _parseIntField(durationText, '渐变时间');
                        if (channel != null &&
                            targetValue != null &&
                            duration != null) {
                          newAction = CommandAction(
                            controllerId: trimmedId,
                            type: selectedType,
                            channel: channel,
                            value: targetValue,
                            duration: duration,
                          );
                        }
                        break;

                      case CommandActionType.blinkMode:
                        final channel = _parseIntField(channelText, '通道');
                        final period = _parseIntField(periodText, '闪烁周期');
                        if (channel != null && period != null) {
                          newAction = CommandAction(
                            controllerId: trimmedId,
                            type: selectedType,
                            channel: channel,
                            period: period,
                          );
                        }
                        break;

                      case CommandActionType.strobeMode:
                        final channel = _parseIntField(channelText, '通道');
                        final count = _parseIntField(countText, '闪烁次数');
                        final totalTime = _parseIntField(totalTimeText, '总时间');
                        final pauseTime = _parseIntField(pauseTimeText, '暂停时间');
                        if (channel != null &&
                            count != null &&
                            totalTime != null &&
                            pauseTime != null) {
                          newAction = CommandAction(
                            controllerId: trimmedId,
                            type: selectedType,
                            channel: channel,
                            count: count,
                            totalTime: totalTime,
                            pauseTime: pauseTime,
                          );
                        }
                        break;

                      case CommandActionType.presetTrigger:
                        final presetId = _parseIntField(presetIdText, '预设ID');
                        if (presetId != null) {
                          newAction = CommandAction(
                            controllerId: trimmedId,
                            type: selectedType,
                            presetId: presetId,
                          );
                        }
                        break;
                    }
                  } catch (e) {
                    setDialogState(
                      () => errorMessage = '参数格式错误: ${e.toString()}',
                    );
                    return;
                  }

                  if (newAction == null) {
                    setDialogState(() => errorMessage = '请填写完整的参数信息');
                    return;
                  }

                  // Validate using ActionValidator
                  final validationResult = ActionValidator.validate(newAction);
                  if (validationResult != null) {
                    setDialogState(() => errorMessage = validationResult);
                    return;
                  }

                  result = newAction;
                  Navigator.of(context).pop();
                },
                child: const Text('保存'),
              ),
            ],
          ),
        );
      },
    );

    return result;
  }

  // Helper method to parse integer field with error handling
  int? _parseIntField(String text, String fieldName) {
    final parsed = int.tryParse(text.trim());
    if (parsed == null) {
      throw Exception('$fieldName 必须是有效的整数');
    }
    return parsed;
  }

  Future<void> _previewState(String toggleId, String stateId) async {
    final provider = ref.read(orchestrationProviderProvider);
    final scene = provider.activeScene;
    if (scene == null) {
      return;
    }
    try {
      final preview = provider.previewScene(
        scene.id,
        toggleId: toggleId,
        stateId: stateId,
      );
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => CommandPreviewSheet(
          preview: preview,
          toggleId: toggleId,
          stateId: stateId,
          controllerAliases: const <String, String>{},
          missingControllers: provider.missingControllers,
          onExecute: () async {
            await provider.recordExecution(
              sceneId: scene.id,
              triggerSource: 'preview',
              preview: preview,
              success: true,
              notes: 'Manual preview execution',
            );
            if (context.mounted) {
              Navigator.of(context).pop();
              _showSnack('执行记录已保存');
            }
          },
        ),
      );
    } catch (error) {
      _showSnack('预览失败: $error');
    }
  }

  void _openSyncSheet(ToggleScene scene, OrchestrationProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          SwitchHubSyncSheet(scene: scene, provider: provider),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _editStatusSlots(String toggleId) async {
    final provider = ref.read(orchestrationProviderProvider);
    final scene = provider.activeScene;

    if (scene == null) {
      _showSnack('没有活跃的场景');
      return;
    }

    // Build SwitchHub config from the current scene
    final switchHubConfig = provider.buildSwitchHubConfig(scene.id);

    // Find the switch config by matching the channelLabel (which should equal toggleId)
    final switchConfig = switchHubConfig.switches
        .where((s) => s.uiConfig?.channelLabel == toggleId)
        .firstOrNull;

    if (switchConfig == null) {
      _showSnack('未找到开关配置');
      return;
    }

    // Extract current status slots from the config
    final statusSlots = <StatusSlot?>[];
    final uiConfig = switchConfig.uiConfig;

    if (uiConfig != null && uiConfig.newStatusSlots.isNotEmpty) {
      statusSlots.addAll(uiConfig.newStatusSlots);
    }

    // Ensure we have exactly 2 slots
    while (statusSlots.length < 2) {
      statusSlots.add(null);
    }

    // Show the status slot editor
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatusSlotEditorSheet(
        initialSlots: statusSlots,
        onSaved: (newSlots) async {
          try {
            // Save the status slot configuration to the active scene
            await provider.updateStatusSlots(toggleId, newSlots);

            // Reinitialize status orchestration with the updated scene
            final statusProvider = ref.read(
              statusOrchestrationProvider.notifier,
            );
            final updatedSwitchHubConfig = provider.buildSwitchHubConfig(
              scene.id,
            );
            await statusProvider.initialize(updatedSwitchHubConfig);

            _showSnack('状态显示配置已保存');
          } catch (e) {
            _showSnack('保存配置失败: $e');
          }
        },
      ),
    );
  }
}
