import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/widgets/orchestration/command_preview_sheet.dart';

class OrchestrationScreen extends StatefulWidget {
  const OrchestrationScreen({super.key});

  @override
  State<OrchestrationScreen> createState() => _OrchestrationScreenState();
}

class _OrchestrationScreenState extends State<OrchestrationScreen> {
  final Map<String, String> _selectedStates = <String, String>{};
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // 延迟初始化以避免构建期间的通知冲突
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OrchestrationProvider>().init();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OrchestrationProvider, AppStateProvider>(
      builder: (context, provider, appState, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage != null) {
          return _ErrorState(
            message: provider.errorMessage!,
            onRetry: provider.init,
          );
        }

        if (provider.scenes.isEmpty) {
          return _EmptyState(onCreate: () => _createExampleScene(provider));
        }

        final scene = provider.activeScene ?? provider.scenes.first;
        final groupedStates = _groupStates(scene);

        _selectedStates.removeWhere(
          (key, value) => !groupedStates.containsKey(key),
        );
        groupedStates.forEach((toggleId, states) {
          _selectedStates.putIfAbsent(toggleId, () {
            final defaultState = states.firstWhere(
              (state) => state.isDefault,
              orElse: () => states.first,
            );
            return defaultState.stateId;
          });
        });

        final aliasMap = {
          for (final saved in appState.savedControllers)
            saved.controllerId: saved.alias,
        };

        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                icon: const Icon(Icons.history),
                tooltip: 'View execution logs',
                onPressed: () => _showExecutionLogs(context, provider),
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit),
                tooltip: _isEditing ? 'Exit edit mode' : 'Edit toggles',
                onPressed: () {
                  setState(() {
                    _isEditing = !_isEditing;
                  });
                },
              ),
            ],
          ),
          body: _isEditing
              ? _buildEditMode(context, provider, groupedStates)
              : _buildViewMode(
                  context,
                  provider,
                  scene,
                  groupedStates,
                  aliasMap,
                ),
          floatingActionButton: _isEditing
              ? FloatingActionButton(
                  onPressed: () async {
                    await provider.addToggle();
                    setState(() {});
                  },
                  tooltip: 'Add toggle',
                  child: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget _buildViewMode(
    BuildContext context,
    OrchestrationProvider provider,
    ToggleScene scene,
    Map<String, List<ToggleState>> groupedStates,
    Map<String, String> aliasMap,
  ) {
    // 使用ResponsiveBuilder来处理不同屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360; // 小屏幕阈值

    // 如果开关数量很多，使用网格布局以更好地利用空间
    final toggleCount = groupedStates.length;
    final useGridLayout = toggleCount > 4 && screenWidth > 400;

    if (useGridLayout) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: screenWidth > 600
                ? 4
                : screenWidth > 400
                ? 3
                : 2,
            childAspectRatio: isSmallScreen ? 1.2 : 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: groupedStates.length,
          itemBuilder: (context, index) {
            final entry = groupedStates.entries.elementAt(index);
            final toggleId = entry.key;
            final states = entry.value;
            final selectedStateId = _selectedStates[toggleId]!;
            return _VerticalToggleControl(
              toggleId: toggleId,
              states: states,
              selectedStateId: selectedStateId,
              onChanged: (stateId) async {
                setState(() {
                  _selectedStates[toggleId] = stateId;
                });
                
                final preview = provider.previewScene(
                  scene.id,
                  toggleId: toggleId,
                  stateId: stateId,
                );
                
                if (preview.actions.isEmpty) {
                  return;
                }
                
                bool executionSuccess = false;
                try {
                  executionSuccess = await provider.executeCommands(preview);
                } catch (e) {
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('执行失败: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                
                await provider.recordExecution(
                  sceneId: scene.id,
                  triggerSource: toggleId,
                  preview: preview,
                  success: executionSuccess,
                  notes:
                      executionSuccess ? null : 'Some commands failed to execute',
                );
              },
              onPreview: () => _previewState(
                context,
                provider,
                scene,
                toggleId,
                selectedStateId,
                aliasMap,
              ),
            );
          },
        ),
      );
    }

    // 对于较少的开关或较小屏幕，使用横向滚动的列表
    return SizedBox(
      height: 150, // 给横向滚动容器一个固定高度
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, // 避免垂直拉伸问题
          children: groupedStates.entries.map((entry) {
            final toggleId = entry.key;
            final states = entry.value;
            final selectedStateId = _selectedStates[toggleId]!;
            return Padding(
              padding: const EdgeInsets.only(
                left: 6,
                right: 6,
                bottom: 6,
              ), // 减少padding
              child: _VerticalToggleControl(
                toggleId: toggleId,
                states: states,
                selectedStateId: selectedStateId,
                onChanged: (stateId) async {
                  setState(() {
                    _selectedStates[toggleId] = stateId;
                  });

                  final preview = provider.previewScene(
                    scene.id,
                    toggleId: toggleId,
                    stateId: stateId,
                  );

                  bool executionSuccess = false;
                  if (preview.actions.isNotEmpty) {
                    try {
                      executionSuccess = await provider.executeCommands(preview);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('执行失败: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }

                  await provider.recordExecution(
                    sceneId: scene.id,
                    triggerSource: toggleId,
                    preview: preview,
                    success: preview.actions.isNotEmpty ? executionSuccess : false,
                    notes: preview.actions.isEmpty
                        ? '无可执行指令'
                        : (executionSuccess ? null : '部分或全部指令执行失败'),
                  );
                },
                onPreview: () => _previewState(
                  context,
                  provider,
                  scene,
                  toggleId,
                  selectedStateId,
                  aliasMap,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEditMode(
    BuildContext context,
    OrchestrationProvider provider,
    Map<String, List<ToggleState>> groupedStates,
  ) {
    final toggleIds = groupedStates.keys.toList();
    if (toggleIds.isEmpty) {
      return const Center(child: Text('No toggles configured yet.'));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: toggleIds.length,
      onReorder: (oldIndex, newIndex) async {
        await provider.reorderToggles(oldIndex, newIndex);
        setState(() {});
      },
      itemBuilder: (context, index) {
        final toggleId = toggleIds[index];
        final states = groupedStates[toggleId]!;
        final stateLabels = states.map((state) => state.label).join(' / ');
        return ListTile(
          key: ValueKey(toggleId),
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_indicator),
          ),
          title: Text(toggleId),
          subtitle: Text(stateLabels),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Rename toggle',
                onPressed: () => _renameToggle(context, provider, toggleId),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Remove toggle',
                onPressed: () =>
                    _confirmRemoveToggle(context, provider, toggleId),
              ),
            ],
          ),
          onTap: () => _showToggleEditor(context, provider, toggleId, states),
        );
      },
    );
  }

  Map<String, List<ToggleState>> _groupStates(ToggleScene scene) {
    final map = LinkedHashMap<String, List<ToggleState>>();
    for (final state in scene.states) {
      map.putIfAbsent(state.toggleId, () => <ToggleState>[]).add(state);
    }
    return map;
  }

  void _previewState(
    BuildContext context,
    OrchestrationProvider provider,
    ToggleScene scene,
    String toggleId,
    String stateId,
    Map<String, String> aliasMap,
  ) {
    final preview = provider.previewScene(
      scene.id,
      toggleId: toggleId,
      stateId: stateId,
    );

    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return CommandPreviewSheet(
          preview: preview,
          toggleId: toggleId,
          stateId: stateId,
          onExecute: () {
            provider.recordExecution(
              sceneId: scene.id,
              triggerSource: toggleId,
              preview: preview,
            );
            Navigator.of(context).pop();
          },
          controllerAliases: aliasMap,
          missingControllers: provider.missingControllers,
        );
      },
    );
  }

  void _showExecutionLogs(
    BuildContext context,
    OrchestrationProvider provider,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final logs = provider.executionLogs;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Execution history',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    TextButton(
                      onPressed: provider.clearLogs,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
                if (logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No executions recorded yet.'),
                  )
                else
                  ...logs.map(
                    (log) => ListTile(
                      title: Text(log.triggerSource),
                      subtitle: Text(
                        '${log.result} • ${log.triggeredAt.toLocal()}\nBundles: ${log.executedBundleIds.join(', ')}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showToggleEditor(
    BuildContext context,
    OrchestrationProvider provider,
    String toggleId,
    List<ToggleState> states,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final theme = Theme.of(context);
        final currentStates = provider.statesForToggle(toggleId);

        // Create controllers outside of StatefulBuilder to preserve them during rebuilds
        final labelControllers = <String, TextEditingController>{};
        for (final state in currentStates) {
          labelControllers[state.stateId] = TextEditingController(
            text: state.label,
          );
        }

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final aliasMap = {
              for (final saved
                  in context.read<AppStateProvider>().savedControllers)
                saved.controllerId: saved.alias,
            };

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '编辑 $toggleId',
                          style: theme.textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: currentStates.length,
                        itemBuilder: (context, index) {
                          final state = currentStates[index];
                          final labelController =
                              labelControllers[state.stateId]!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: labelController,
                                      decoration: const InputDecoration(
                                        labelText: '状态名称',
                                      ),
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (value) async {
                                        await provider.updateStateLabel(
                                          state.toggleId,
                                          state.stateId,
                                          value.trim(),
                                        );
                                        // Update the controller text to reflect the saved value
                                        final updatedStates = provider
                                            .statesForToggle(toggleId);
                                        final updatedState = updatedStates
                                            .firstWhere(
                                              (s) => s.stateId == state.stateId,
                                            );
                                        labelController.text =
                                            updatedState.label;
                                        setSheetState(() {});
                                      },
                                      onEditingComplete: () async {
                                        await provider.updateStateLabel(
                                          state.toggleId,
                                          state.stateId,
                                          labelController.text.trim(),
                                        );
                                        // Update the controller text to reflect the saved value
                                        final updatedStates = provider
                                            .statesForToggle(toggleId);
                                        final updatedState = updatedStates
                                            .firstWhere(
                                              (s) => s.stateId == state.stateId,
                                            );
                                        labelController.text =
                                            updatedState.label;
                                        setSheetState(() {});
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    if (state.commandBundles.isEmpty)
                                      const Text('尚未配置任何编排命令。')
                                    else
                                      ...state.commandBundles.map(
                                        (bundle) => ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(bundle.label),
                                          subtitle: Text(
                                            '${bundle.actions.length} 条指令 • ${bundle.isEnabled ? '已启用' : '已停用'}',
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                tooltip: '编辑指令组',
                                                onPressed: () =>
                                                    _openBundleEditor(
                                                      context,
                                                      provider,
                                                      toggleId,
                                                      state.stateId,
                                                      bundle,
                                                      aliasMap,
                                                      setSheetState,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                tooltip: '删除指令组',
                                                onPressed: () =>
                                                    _confirmRemoveBundle(
                                                      context,
                                                      provider,
                                                      toggleId,
                                                      state.stateId,
                                                      bundle.id,
                                                      setSheetState,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () => _promptAddBundle(
                                          context,
                                          provider,
                                          toggleId,
                                          state,
                                          setSheetState,
                                        ),
                                        icon: const Icon(Icons.add),
                                        label: const Text('添加指令组'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveToggle(
    BuildContext context,
    OrchestrationProvider provider,
    String toggleId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('移除开关'),
          content: Text('确定要删除 $toggleId 吗？此操作无法撤销。'),
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
        );
      },
    );

    if (confirmed == true) {
      await provider.removeToggle(toggleId);
      setState(() {
        _selectedStates.remove(toggleId);
      });
    }
  }

  Future<void> _renameToggle(
    BuildContext context,
    OrchestrationProvider provider,
    String toggleId,
  ) async {
    final nameController = TextEditingController(text: toggleId);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('重命名开关'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: '开关名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(nameController.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty || result == toggleId) {
      return;
    }

    try {
      final success = await provider.renameToggle(toggleId, result);
      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已重命名为 "$result"')));
          setState(() {
            final oldSelectedState = _selectedStates[toggleId];
            if (oldSelectedState != null) {
              _selectedStates.remove(toggleId);
              _selectedStates[result] = oldSelectedState;
            }
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('重命名失败：开关名称已存在')));
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('重命名失败: $error')));
      }
    }
  }

  Future<void> _promptAddBundle(
    BuildContext context,
    OrchestrationProvider provider,
    String toggleId,
    ToggleState state,
    void Function(void Function()) setSheetState,
  ) async {
    final controller = TextEditingController(
      text: 'Bundle ${state.commandBundles.length + 1}',
    );
    final label = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建指令组'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('创建'),
            ),
          ],
        );
      },
    );

    if (label == null || label.isEmpty) {
      return;
    }

    final bundleId = 'bundle-${DateTime.now().microsecondsSinceEpoch}';
    await provider.upsertCommandBundle(
      toggleId,
      state.stateId,
      CommandBundle(id: bundleId, label: label),
    );
    setSheetState(() {});
  }

  Future<void> _confirmRemoveBundle(
    BuildContext context,
    OrchestrationProvider provider,
    String toggleId,
    String stateId,
    String bundleId,
    void Function(void Function()) setSheetState,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('移除指令组'),
          content: const Text('删除该指令组后其命令将不可恢复。确认删除？'),
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
        );
      },
    );

    if (confirmed == true) {
      await provider.removeCommandBundle(toggleId, stateId, bundleId);
      setSheetState(() {});
    }
  }

  void _openBundleEditor(
    BuildContext context,
    OrchestrationProvider provider,
    String toggleId,
    String stateId,
    CommandBundle bundle,
    Map<String, String> aliasMap,
    void Function(void Function()) parentSetState,
  ) {
    final labelController = TextEditingController(text: bundle.label);
    bool isEnabled = bundle.isEnabled;
    List<CommandAction> actions = List<CommandAction>.from(bundle.actions);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('编辑指令组', style: theme.textTheme.titleMedium),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    TextField(
                      controller: labelController,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    SwitchListTile(
                      value: isEnabled,
                      onChanged: (value) => setModalState(() {
                        isEnabled = value;
                      }),
                      title: const Text('启用此指令组'),
                    ),
                    const Divider(),
                    if (actions.isEmpty)
                      const Text('尚未添加任何指令。')
                    else
                      ...actions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final action = entry.value;
                        final alias = aliasMap[action.controllerId];
                        final controllerLabel = alias != null
                            ? '${action.controllerId} ($alias)'
                            : action.controllerId;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(controllerLabel),
                          subtitle: Text(_describeAction(action)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () async {
                                  final updated = await _showActionEditor(
                                    context,
                                    action,
                                  );
                                  if (updated != null) {
                                    setModalState(() {
                                      actions[index] = updated;
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  setModalState(() {
                                    actions.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final action = await _showActionEditor(context, null);
                          if (action != null) {
                            setModalState(() {
                              actions.add(action);
                            });
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('添加指令'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final updatedBundle = bundle.copyWith(
                            label: labelController.text.trim().isEmpty
                                ? bundle.label
                                : labelController.text.trim(),
                            actions: actions,
                            isEnabled: isEnabled,
                          );
                          await provider.upsertCommandBundle(
                            toggleId,
                            stateId,
                            updatedBundle,
                          );
                          parentSetState(() {});
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.save),
                        label: const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<CommandAction?> _showActionEditor(
    BuildContext context,
    CommandAction? initial,
  ) async {
    final appState = context.read<AppStateProvider>();
    final savedControllers = appState.savedControllers;
    
    CommandActionType selectedType =
        initial?.type ?? CommandActionType.channelValue;
    
    String? selectedControllerId = initial?.controllerId;
    final channelController = TextEditingController(
      text: initial?.channel?.toString() ?? '',
    );
    final valueController = TextEditingController(
      text: initial?.value?.toString() ?? '',
    );
    final presetController = TextEditingController(
      text: initial?.presetId?.toString() ?? '',
    );
    String? errorText;

    return showDialog<CommandAction?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(initial == null ? '添加指令' : '编辑指令'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<CommandActionType>(
                    value: selectedType,
                    decoration: const InputDecoration(labelText: '指令类型'),
                    items: CommandActionType.values
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type == CommandActionType.channelValue
                                  ? '设置通道值'
                                  : '触发预设',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() {
                        selectedType = value;
                      });
                    },
                  ),
                  if (savedControllers.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedControllerId,
                      decoration: const InputDecoration(labelText: '控制器'),
                      items: savedControllers
                          .map(
                            (controller) => DropdownMenuItem(
                              value: controller.controllerId,
                              child: Text(
                                controller.alias.isNotEmpty 
                                  ? '${controller.alias} (${controller.controllerId})'
                                  : controller.controllerId,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedControllerId = value;
                        });
                      },
                    )
                  else
                    const Text(
                      '暂无已保存的设备，请先在设备页面添加设备',
                      style: TextStyle(color: Colors.orange),
                    ),
                  if (selectedType == CommandActionType.channelValue) ...[
                    TextField(
                      controller: channelController,
                      decoration: const InputDecoration(labelText: '通道 (0-3)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: valueController,
                      decoration: const InputDecoration(
                        labelText: 'PWM 值 (0-255)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ] else ...[
                    TextField(
                      controller: presetController,
                      decoration: const InputDecoration(
                        labelText: '预设 ID (0-255)',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: savedControllers.isEmpty ? null : () {
                    if (selectedControllerId == null || selectedControllerId!.isEmpty) {
                      setDialogState(() {
                        errorText = '请选择控制器';
                      });
                      return;
                    }

                    if (selectedType == CommandActionType.channelValue) {
                      final channel = int.tryParse(channelController.text);
                      final value = int.tryParse(valueController.text);
                      if (channel == null || channel < 0 || channel > 3) {
                        setDialogState(() {
                          errorText = '通道必须是 0-3 的整数';
                        });
                        return;
                      }
                      if (value == null || value < 0 || value > 255) {
                        setDialogState(() {
                          errorText = 'PWM 值必须是 0-255 的整数';
                        });
                        return;
                      }
                      Navigator.of(context).pop(
                        CommandAction(
                          controllerId: selectedControllerId!,
                          type: CommandActionType.channelValue,
                          channel: channel,
                          value: value,
                        ),
                      );
                    } else {
                      final presetId = int.tryParse(presetController.text);
                      if (presetId == null || presetId < 0 || presetId > 255) {
                        setDialogState(() {
                          errorText = '预设 ID 必须是 0-255 的整数';
                        });
                        return;
                      }
                      Navigator.of(context).pop(
                        CommandAction(
                          controllerId: selectedControllerId!,
                          type: CommandActionType.presetTrigger,
                          presetId: presetId,
                        ),
                      );
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _describeAction(CommandAction action) {
    switch (action.type) {
      case CommandActionType.channelValue:
        return '通道 ${action.channel} → 值 ${action.value}';
      case CommandActionType.presetTrigger:
        return '触发预设 ${action.presetId}';
    }
  }

  Future<void> _createExampleScene(OrchestrationProvider provider) async {
    final scene = ToggleScene(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'New Scene',
      states: [
        ToggleState(
          toggleId: 'toggle-1',
          stateId: 'on',
          label: 'On',
          isDefault: true,
          commandBundles: [
            CommandBundle(
              id: 'bundle-on',
              label: 'On bundle',
              actions: [
                CommandAction(
                  controllerId: 'controller-1',
                  type: CommandActionType.channelValue,
                  channel: 1,
                  value: 255,
                ),
              ],
            ),
          ],
        ),
        ToggleState(
          toggleId: 'toggle-1',
          stateId: 'off',
          label: 'Off',
          commandBundles: [
            CommandBundle(
              id: 'bundle-off',
              label: 'Off bundle',
              actions: [
                CommandAction(
                  controllerId: 'controller-1',
                  type: CommandActionType.channelValue,
                  channel: 1,
                  value: 0,
                ),
              ],
            ),
          ],
        ),
      ],
      rules: [
        ConditionalRule(
          id: 'rule-default',
          toggleId: 'toggle-1',
          expectedStateId: 'on',
          trueBundleId: 'bundle-on',
          falseBundleId: 'bundle-off',
        ),
      ],
    );

    await provider.saveScene(scene);
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No switch scenes yet.'),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onCreate,
            child: const Text('Create a scene'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _VerticalToggleControl extends StatelessWidget {
  const _VerticalToggleControl({
    required this.toggleId,
    required this.states,
    required this.selectedStateId,
    required this.onChanged,
    required this.onPreview,
  });

  final String toggleId;
  final List<ToggleState> states;
  final String selectedStateId;
  final ValueChanged<String> onChanged;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (states.isEmpty) {
      return const SizedBox.shrink();
    }

    final selectedIndex = states.indexWhere(
      (state) => state.stateId == selectedStateId,
    );
    final currentIndex = selectedIndex >= 0 ? selectedIndex : 0;
    final bool hasMultipleStates = states.length > 1;

    Alignment knobAlignment;
    if (!hasMultipleStates) {
      knobAlignment = Alignment.center;
    } else {
      final maxIndex = states.length - 1;
      final fraction = currentIndex / maxIndex;
      final alignmentY = (fraction * 2) - 1; // map 0..1 -> -1..1
      knobAlignment = Alignment(0, alignmentY.clamp(-1.0, 1.0));
    }

    final bool isActive = currentIndex == 0;
    final Color activeColor = theme.colorScheme.primary;
    final Color trackFill = isActive
        ? activeColor.withOpacity(0.85)
        : theme.colorScheme.surface;
    final Color trackBorder = isActive
        ? activeColor
        : theme.colorScheme.outlineVariant ?? Colors.grey;
    final Color knobColor = isActive ? Colors.white : Colors.grey.shade600;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ), // 进一步减少padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min, // 使用最小尺寸
        children: [
          SizedBox(
            // 使用SizedBox而不是Flexible
            width: 60, // 固定宽度
            height: 140, // 固定高度
            child: GestureDetector(
              onTap: () {
                if (states.isEmpty) return;
                final nextIndex = (currentIndex + 1) % states.length;
                onChanged(states[nextIndex].stateId);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (states.isNotEmpty)
                    Text(
                      states.first.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ), // 进一步减小字体
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2), // 进一步减少间距
                  Container(
                    height: 70, // 从80减少到70
                    width: 42, // 从48减少到42
                    decoration: BoxDecoration(
                      color: trackFill,
                      border: Border.all(
                        color: trackBorder,
                        width: 1.5,
                      ), // 减少边框宽度
                      borderRadius: BorderRadius.circular(21), // 调整圆角
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: knobAlignment,
                      child: Container(
                        margin: const EdgeInsets.all(4), // 从6减少到4
                        height: 20, // 从24减少到20
                        width: 20, // 从24减少到20
                        decoration: BoxDecoration(
                          color: knobColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (isActive)
                              BoxShadow(
                                color: activeColor.withOpacity(0.25),
                                blurRadius: 3, // 从4减少到3
                                offset: const Offset(0, 1),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2), // 进一步减少间距
                  if (hasMultipleStates)
                    Text(
                      states.last.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                      ), // 进一步减小字体
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2), // 进一步减少间距
                  Text(
                    toggleId,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 12,
                    ), // 进一步减小字体
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
