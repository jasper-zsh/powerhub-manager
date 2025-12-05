import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/switch_hub/status_slot_config.dart';
import 'package:app/models/switch_hub/status_data_type.dart';
import 'package:app/controllers/saved_controller_controller.dart';
import 'package:app/models/saved_controller.dart';

class StatusSlotEditorSheet extends ConsumerStatefulWidget {
  const StatusSlotEditorSheet({
    super.key,
    required this.initialSlots,
    this.onSaved,
    this.onCancel,
  });

  final List<StatusSlot?> initialSlots;
  final Function(List<StatusSlot?>)? onSaved;
  final VoidCallback? onCancel;

  @override
  ConsumerState<StatusSlotEditorSheet> createState() => _StatusSlotEditorSheetState();
}

class _StatusSlotEditorSheetState extends ConsumerState<StatusSlotEditorSheet> {
  late List<StatusSlot?> _slots;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _slots = List.from(widget.initialSlots);
    // Ensure we have exactly 2 slots (can be null)
    while (_slots.length < 2) {
      _slots.add(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.tune,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '状态显示配置',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Slot 1
                    _buildStatusSlotEditor(
                      context,
                      title: '状态显示位置 1',
                      slotIndex: 0,
                    ),
                    const SizedBox(height: 24),
                    // Status Slot 2
                    _buildStatusSlotEditor(
                      context,
                      title: '状态显示位置 2',
                      slotIndex: 1,
                    ),
                    const SizedBox(height: 24),
                    // Instructions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '配置说明',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '每个开关可以配置最多两个状态显示位置，用于实时监控数据：',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• 本地电压：显示SwitchHub自身电压\n'
                            '• 远程设备：显示PowerHub的电压、电流或温度\n'
                            '• 数据格式：选择数据类型和参数\n'
                            '• 连接状态：自动检测设备连接状态',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Preview
                    _buildConfigurationPreview(),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : widget.onCancel ?? () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveConfiguration,
                      child: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存配置'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSlotEditor(BuildContext context, {
    required String title,
    required int slotIndex,
  }) {
    final theme = Theme.of(context);
    final slot = _slots[slotIndex];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  slot != null ? Icons.visibility : Icons.visibility_off,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (slot != null)
                  IconButton(
                    onPressed: () => _clearSlot(slotIndex),
                    icon: const Icon(Icons.clear),
                    tooltip: '清除配置',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (slot == null)
              ElevatedButton.icon(
                onPressed: () => _showSlotConfigurationDialog(context, slotIndex),
                icon: const Icon(Icons.add),
                label: const Text('配置状态显示'),
              )
            else
              _buildSlotDetails(slot),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotDetails(StatusSlot slot) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDetailRow('数据源', _getSourceDisplay(slot.sourceMac)),
        _buildDetailRow('数据类型', slot.dataType.jsonValue),
        if (slot.params != null)
          _buildDetailRow('参数', slot.params!),
        if (slot.label != null)
          _buildDetailRow('标签', slot.label!),
        if (slot.value != null)
          _buildDetailRow('当前值', '${slot.value}${slot.displayUnit}'),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showSlotConfigurationDialog(context, _slots.indexOf(slot)),
          icon: const Icon(Icons.edit),
          label: const Text('编辑'),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const Text(' : '),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _getSourceDisplay(String mac) {
    if (mac == 'LOCAL') return '本地设备';
    return mac; // Could enhance with device name lookup
  }

  Widget _buildConfigurationPreview() {
    final theme = Theme.of(context);
    final hasSlots = _slots.any((slot) => slot != null);

    if (!hasSlots) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.device_unknown,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 8),
              Text(
                '未配置状态显示',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                '添加状态显示配置以实时监控数据',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.preview,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '配置预览',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._slots.asMap().entries.where((entry) => entry.value != null).map((entry) {
              final index = entry.key;
              final slot = entry.value!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildSlotPreview(index, slot),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotPreview(int index, StatusSlot slot) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getDataIcon(slot.dataType),
            color: _getDataColor(slot.dataType, theme),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.label ?? '未命名',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      slot.dataType.jsonValue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    if (slot.params != null) ...[
                      Text(' (${slot.params})'),
                    ],
                    if (slot.sourceMac != 'LOCAL') ...[
                      Text(' • ${_getSourceDisplay(slot.sourceMac)}'),
                    ],
                  ],
                ),
                if (slot.value != null)
                  Text(
                    '${slot.value}${slot.displayUnit}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _getDataColor(slot.dataType, theme),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getDataIcon(StatusDataType dataType) {
    switch (dataType) {
      case StatusDataType.voltage:
        return dataType == StatusDataType.voltage ? Icons.battery_full : Icons.electrical_services;
      case StatusDataType.channelCurrent:
      case StatusDataType.totalCurrent:
        return Icons.electric_bolt;
      case StatusDataType.temperature:
        return Icons.thermostat;
    }
  }

  Color _getDataColor(StatusDataType dataType, ThemeData theme) {
    switch (dataType) {
      case StatusDataType.voltage:
        return Colors.green;
      case StatusDataType.channelCurrent:
        return theme.colorScheme.primary;
      case StatusDataType.totalCurrent:
        return theme.colorScheme.secondary;
      case StatusDataType.temperature:
        return theme.colorScheme.tertiary;
    }
  }

  void _clearSlot(int slotIndex) {
    setState(() {
      _slots[slotIndex] = null;
    });
  }

  void _showSlotConfigurationDialog(BuildContext context, int slotIndex) {
    showDialog(
      context: context,
      builder: (context) => StatusSlotConfigDialog(
        initialSlot: _slots[slotIndex],
        onSaved: (slot) {
          setState(() {
            _slots[slotIndex] = slot;
          });
        },
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSaved?.call(_slots);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class StatusSlotConfigDialog extends ConsumerWidget {
  const StatusSlotConfigDialog({
    super.key,
    this.initialSlot,
    required this.onSaved,
  });

  final StatusSlot? initialSlot;
  final Function(StatusSlot) onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _StatusSlotConfigDialogContent(
      initialSlot: initialSlot,
      onSaved: onSaved,
      savedControllers: ref.watch(savedControllerControllerProvider).controllers,
    );
  }
}

class _StatusSlotConfigDialogContent extends StatefulWidget {
  const _StatusSlotConfigDialogContent({
    required this.initialSlot,
    required this.onSaved,
    required this.savedControllers,
  });

  final StatusSlot? initialSlot;
  final Function(StatusSlot) onSaved;
  final List<SavedController> savedControllers;

  @override
  State<_StatusSlotConfigDialogContent> createState() => _StatusSlotConfigDialogState();
}

class _StatusSlotConfigDialogState extends State<_StatusSlotConfigDialogContent> {
  late TextEditingController _labelController;
  late TextEditingController _paramsController;
  late StatusDataType _selectedDataType;
  String? _selectedMacAddress;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _selectedMacAddress = widget.initialSlot?.sourceMac ?? 'LOCAL';
    _labelController = TextEditingController(text: widget.initialSlot?.label ?? '');
    _paramsController = TextEditingController(text: widget.initialSlot?.params ?? '');
    _selectedDataType = widget.initialSlot?.dataType ?? StatusDataType.voltage;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _paramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '状态显示配置',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data Source
                    DropdownButtonFormField<StatusDataType>(
                      value: _selectedDataType,
                      decoration: InputDecoration(
                        labelText: '数据类型',
                        border: OutlineInputBorder(),
                      ),
                      items: StatusDataType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_getDataTypeDisplayName(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDataType = value!;
                          _errorText = null;
                          // Clear params when type changes
                          if (!_requiresParameters(value)) {
                            _paramsController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Data Type description
                    Text(
                      _getDataTypeDescription(_selectedDataType),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),

                    if (_requiresParameters(_selectedDataType)) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _paramsController,
                        decoration: InputDecoration(
                          labelText: _getParamLabel(_selectedDataType),
                          border: OutlineInputBorder(),
                          helperText: _getParamHelper(_selectedDataType),
                          errorText: _getParamError(_selectedDataType, _paramsController.text),
                        ),
                        onChanged: (_) => setState(() => _errorText = null),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Device Source (dropdown for LOCAL and saved PowerHub devices)
                    DropdownButtonFormField<String>(
                      value: _selectedMacAddress,
                      decoration: InputDecoration(
                        labelText: '数据源设备',
                        border: OutlineInputBorder(),
                        helperText: '选择本地设备或已保存的 PowerHub 设备',
                        prefixIcon: Icon(
                          _selectedMacAddress == 'LOCAL' ? Icons.devices : Icons.bluetooth,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      items: _buildDeviceSourceItems(),
                      onChanged: (value) {
                        if (value != 'NO_DEVICES') {
                          setState(() {
                            _selectedMacAddress = value;
                            _errorText = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getDataSourceDescription(_selectedDataType, _selectedMacAddress ?? 'LOCAL'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Label
                    TextField(
                      controller: _labelController,
                      decoration: InputDecoration(
                        labelText: '显示标签',
                        border: OutlineInputBorder(),
                        helperText: '在界面中显示的名称，留空使用默认名称',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Error message
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Actions
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _validateAndSave,
                    child: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _requiresParameters(StatusDataType dataType) {
    return dataType.requiresParameters;
  }

  List<DropdownMenuItem<String>> _buildDeviceSourceItems() {
    final items = <DropdownMenuItem<String>>[];

    // Add LOCAL option
    items.add(DropdownMenuItem(
      value: 'LOCAL',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          const Flexible(
            child: Text('本地设备 (SwitchHub)'),
          ),
        ],
      ),
    ));

    // Add saved PowerHub devices
    if (widget.savedControllers.isEmpty) {
      items.add(DropdownMenuItem(
        value: 'NO_DEVICES',
        enabled: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '暂无已保存的 PowerHub 设备',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ));
    } else {
      for (final controller in widget.savedControllers) {
        items.add(DropdownMenuItem(
          value: controller.controllerId,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth, size: 20, color: Theme.of(context).colorScheme.secondary),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      controller.alias.isEmpty ? controller.controllerId : controller.alias,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      controller.controllerId,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (controller.connectionStatus == SavedControllerConnectionStatus.connected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '已连接',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '离线',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ));
      }
    }

    return items;
  }

  String _getDataTypeDisplayName(StatusDataType dataType) {
    switch (dataType) {
      case StatusDataType.voltage:
        return '电压';
      case StatusDataType.channelCurrent:
        return '通道电流';
      case StatusDataType.totalCurrent:
        return '总电流';
      case StatusDataType.temperature:
        return '温度';
    }
  }

  String _getDataTypeDescription(StatusDataType dataType) {
    switch (dataType) {
      case StatusDataType.voltage:
        return '监测设备输入电压，适用于所有支持电压测量的设备';
      case StatusDataType.channelCurrent:
        return '监测指定通道的输出电流，需要提供通道号参数';
      case StatusDataType.totalCurrent:
        return '监测所有通道的总电流，无需额外参数';
      case StatusDataType.temperature:
        return '监测设备温度，需要提供温度区域参数';
    }
  }

  String _getDataSourceDescription(StatusDataType dataType, String sourceMac) {
    final isLocal = sourceMac == 'LOCAL';
    switch (dataType) {
      case StatusDataType.voltage:
        return isLocal
          ? '监测 SwitchHub 本身的输入电压'
          : '监测远程 PowerHub 设备的输入电压';
      case StatusDataType.channelCurrent:
        return isLocal
          ? '电流监测需要远程 PowerHub 设备，请输入 MAC 地址'
          : '监测指定 PowerHub 通道的输出电流';
      case StatusDataType.totalCurrent:
        return isLocal
          ? '电流监测需要远程 PowerHub 设备，请输入 MAC 地址'
          : '监测 PowerHub 所有通道的总电流';
      case StatusDataType.temperature:
        return isLocal
          ? '温度监测需要远程 PowerHub 设备，请输入 MAC 地址'
          : '监测 PowerHub 设备的温度传感器';
    }
  }

  String _getParamLabel(StatusDataType dataType) {
    switch (dataType) {
      case StatusDataType.channelCurrent:
        return '通道号';
      case StatusDataType.temperature:
        return '温度区域';
      default:
        return '参数';
    }
  }

  String _getParamHelper(StatusDataType dataType) {
    switch (dataType) {
      case StatusDataType.channelCurrent:
        return '输入通道编号 (0-15)';
      case StatusDataType.temperature:
        return '输入温度区域: POWER 或 CONTROL';
      default:
        return '';
    }
  }

  String? _getParamError(StatusDataType dataType, String value) {
    return dataType.validateParameters(value);
  }

  String? _getMacError(String mac) {
    if (mac == 'LOCAL') return null;
    if (mac.isEmpty) return 'MAC地址不能为空';
    if (!RegExp(r'^([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}$').hasMatch(mac)) {
      return 'MAC地址格式不正确，应为: AA:BB:CC:DD:EE:FF';
    }
    return null;
  }

  void _validateAndSave() {
    final mac = _selectedMacAddress ?? 'LOCAL';
    final label = _labelController.text.trim();
    final params = _paramsController.text.trim();

    // Validate MAC address selection
    if (mac == 'NO_DEVICES') {
      setState(() => _errorText = '请先在设备管理中添加 PowerHub 设备');
      return;
    }

    if (mac == 'LOCAL' && _selectedDataType != StatusDataType.voltage) {
      setState(() => _errorText = '电流和温度监测需要远程 PowerHub 设备，请选择已保存的设备');
      return;
    }

    // Validate parameters
    final paramError = _getParamError(_selectedDataType, params);
    if (paramError != null) {
      setState(() => _errorText = paramError);
      return;
    }

    // Create status slot
    final slot = StatusSlot(
      sourceMac: mac,
      dataType: _selectedDataType,
      params: params.isEmpty ? null : params,
      label: label.isEmpty ? null : label,
    );

    widget.onSaved(slot);
    Navigator.of(context).pop();
  }
}