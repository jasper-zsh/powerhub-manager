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
  });

  final String toggleId;
  final List<ToggleState> states;
  final String selectedStateId;
  final ToggleStateChanged onStateChanged;
  final VoidCallback? onAddCommandBundle;
  final ToggleActionPressed? onEditBundle;
  final Map<String, String> controllerAliases;
  final Set<String> missingControllers;

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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Toggle: $toggleId',
                  style: theme.textTheme.titleMedium,
                ),
                SegmentedButton<String>(
                  segments: states
                      .map(
                        (state) => ButtonSegment<String>(
                          value: state.stateId,
                          label: Text(state.label),
                        ),
                      )
                      .toList(),
                  selected: <String>{currentState.stateId},
                  onSelectionChanged: (selection) {
                    if (selection.isNotEmpty) {
                      onStateChanged(selection.first);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CommandBundleList(
              bundles: currentState.commandBundles,
              onEdit: onEditBundle,
              controllerAliases: controllerAliases,
              missingControllers: missingControllers,
            ),
            if (onAddCommandBundle != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAddCommandBundle,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Command Bundle'),
                ),
              ),
          ],
        ),
      ),
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
      children: bundles
          .map(
            (bundle) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(bundle.label),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bundle.actions.length} action(s) • Enabled: ${bundle.isEnabled ? 'Yes' : 'No'}',
                  ),
                  ...bundle.actions.take(2).map((action) {
                    final alias = controllerAliases[action.controllerId];
                    final controllerLabel = alias != null
                        ? '${action.controllerId} ($alias)'
                        : action.controllerId;
                    final description = action.type ==
                            CommandActionType.channelValue
                        ? 'Set channel ${action.channel} to ${action.value}'
                        : 'Trigger preset ${action.presetId}';
                    final isMissing =
                        missingControllers.contains(action.controllerId);
                    return Text(
                      '$controllerLabel → $description',
                      style: isMissing
                          ? const TextStyle(color: Colors.orange)
                          : null,
                    );
                  }),
                  if (bundle.actions.length > 2)
                    Text('… +${bundle.actions.length - 2} more'),
                ],
              ),
              trailing: onEdit != null
                  ? IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => onEdit!(bundle),
                    )
                  : null,
            ),
          )
          .toList(),
    );
  }
}
