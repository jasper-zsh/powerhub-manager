import 'package:flutter/material.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

typedef ToggleStateChanged = void Function(String stateId);
typedef ToggleActionPressed = void Function(CommandBundle bundle);

class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.toggleId,
    required this.states,
    required this.selectedStateId,
    required this.onStateChanged,
    this.onAddCommandBundle,
    this.onEditBundle,
    this.controllerAliases = const <String, String>{},
    this.missingControllers = const <String>{},
    this.switchSlot,
  });

  final String toggleId;
  final List<ToggleState> states;
  final String selectedStateId;
  final ToggleStateChanged onStateChanged;
  final VoidCallback? onAddCommandBundle;
  final ToggleActionPressed? onEditBundle;
  final Map<String, String> controllerAliases;
  final Set<String> missingControllers;
  final int? switchSlot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentState = states.firstWhere(
      (state) => state.stateId == selectedStateId,
      orElse: () => states.first,
    );

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toggleId, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '${states.length} 状态 · '
                  '${currentState.commandBundles.length} 个命令组合 · '
                  '位号: ${switchSlot ?? '自动'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 12),
                _StateSelector(
                  states: states,
                  selectedStateId: currentState.stateId,
                  onStateChanged: onStateChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CommandBundleList(
                  bundles: currentState.commandBundles,
                  onEdit: onEditBundle,
                  controllerAliases: controllerAliases,
                  missingControllers: missingControllers,
                ),
                if (onAddCommandBundle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: onAddCommandBundle,
                        icon: const Icon(Icons.add),
                        label: const Text('新增命令组合'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateSelector extends StatelessWidget {
  const _StateSelector({
    required this.states,
    required this.selectedStateId,
    required this.onStateChanged,
  });

  final List<ToggleState> states;
  final String selectedStateId;
  final ToggleStateChanged onStateChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: states
          .map((state) {
            final isSelected = state.stateId == selectedStateId;
            return ChoiceChip(
              label: Text(state.label),
              selected: isSelected,
              onSelected: (_) => onStateChanged(state.stateId),
            );
          })
          .toList(growable: false),
    );
  }
}

class _CommandBundleList extends StatelessWidget {
  const _CommandBundleList({
    required this.bundles,
    this.onEdit,
    this.controllerAliases = const <String, String>{},
    this.missingControllers = const <String>{},
  });

  final List<CommandBundle> bundles;
  final ToggleActionPressed? onEdit;
  final Map<String, String> controllerAliases;
  final Set<String> missingControllers;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) {
      return const Text('No command bundles configured.');
    }

    return Column(
      children: bundles.map((bundle) {
        final subtitle = <Widget>[
          Text(
            '${bundle.actions.length} 个动作 · '
            '状态: ${bundle.isEnabled ? '启用' : '停用'}',
          ),
          ...bundle.actions.take(2).map((action) {
            final alias = controllerAliases[action.controllerId];
            final controllerLabel = alias != null
                ? '${action.controllerId} ($alias)'
                : action.controllerId;
            final description = action.type == CommandActionType.channelValue
                ? '通道 ${action.channel} → ${action.value}'
                : '触发预设 ${action.presetId}';
            final isMissing = missingControllers.contains(action.controllerId);
            return Text(
              '$controllerLabel · $description',
              style: isMissing ? const TextStyle(color: Colors.orange) : null,
            );
          }).toList(),
          if (bundle.actions.length > 2)
            Text('… 另有 ${bundle.actions.length - 2} 个动作'),
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bundle.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    ...subtitle,
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => onEdit!(bundle),
                  tooltip: '编辑命令组合',
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
