import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/status_slot_configuration.dart';
import 'package:app/widgets/status/status_slot_widget.dart';
import 'package:app/providers/status_orchestration_provider.dart';

typedef ToggleStateChanged = void Function(String stateId);
typedef ToggleActionPressed = void Function(CommandBundle bundle);
typedef ToggleConditionalRulePressed = void Function(ToggleState state);

class ToggleCard extends StatelessWidget {
  const ToggleCard({
    super.key,
    required this.toggleId,
    required this.states,
    required this.selectedStateId,
    required this.onStateChanged,
    this.onAddCommandBundle,
    this.onEditBundle,
    this.onAddConditionalRule,
    this.controllerAliases = const <String, String>{},
    this.missingControllers = const <String>{},
    this.switchSlot,
    this.statusConfiguration,
  });

  final String toggleId;
  final List<ToggleState> states;
  final String selectedStateId;
  final ToggleStateChanged onStateChanged;
  final VoidCallback? onAddCommandBundle;
  final ToggleActionPressed? onEditBundle;
  final ToggleConditionalRulePressed? onAddConditionalRule;
  final Map<String, String> controllerAliases;
  final Set<String> missingControllers;
  final int? switchSlot;
  final StatusSlotConfiguration? statusConfiguration;

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
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                    ),
                    children: [
                      TextSpan(text: '${states.length} 状态 · '),
                      TextSpan(text: '${currentState.commandBundles.length} 个命令组合'),
                      if (currentState.hasConditionalLogic) ...[
                        const WidgetSpan(child: SizedBox(width: 4)),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.code,
                            size: 14,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        TextSpan(text: ' 条件逻辑'),
                      ],
                      const WidgetSpan(child: SizedBox(width: 4)),
                      TextSpan(text: '· 位号: ${switchSlot ?? '自动'}'),
                    ],
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
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      if (onAddConditionalRule != null)
                        OutlinedButton.icon(
                          onPressed: () => onAddConditionalRule!(currentState),
                          icon: Icon(
                            currentState.hasConditionalLogic ? Icons.edit : Icons.code,
                            size: 18,
                          ),
                          label: Text(currentState.hasConditionalLogic ? '编辑条件' : '添加条件'),
                        ),
                      if (onAddCommandBundle != null)
                        OutlinedButton.icon(
                          onPressed: onAddCommandBundle,
                          icon: const Icon(Icons.add),
                          label: const Text('新增命令组合'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (statusConfiguration != null)
            Consumer(
              builder: (context, ref, child) {
                final remoteDataSources = ref.watch(remoteDataSourcesProvider);
                final isRefreshing = ref.watch(isStatusDataRefreshingProvider);

                final slot1 = statusConfiguration!.slot1;
                final slot2 = statusConfiguration!.slot2;

                final dataSource1 = slot1 != null && slot1.requiresRemoteConnection
                    ? remoteDataSources[slot1.sourceMac]
                    : null;
                final dataSource2 = slot2 != null && slot2.requiresRemoteConnection
                    ? remoteDataSources[slot2.sourceMac]
                    : null;

                return Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '状态监控',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.textTheme.titleSmall?.color?.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          StatusDisplayRow(
                            slot1: slot1,
                            slot2: slot2,
                            dataSource1: dataSource1,
                            dataSource2: dataSource2,
                            isLoading1: slot1 != null && isRefreshing,
                            isLoading2: slot2 != null && isRefreshing,
                            onError: () {
                              // Handle retry logic
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
            final description = action.chineseDescription;
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
