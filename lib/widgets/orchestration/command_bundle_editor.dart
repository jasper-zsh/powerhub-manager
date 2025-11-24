import 'package:flutter/material.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

class CommandBundleEditor extends StatelessWidget {
  const CommandBundleEditor({
    super.key,
    required this.bundle,
    this.onRemove,
    this.onActionTap,
    this.controllerAliases = const <String, String>{},
    this.missingControllers = const <String>{},
  });

  final CommandBundle bundle;
  final VoidCallback? onRemove;
  final void Function(CommandAction action)? onActionTap;
  final Map<String, String> controllerAliases;
  final Set<String> missingControllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(bundle.label, style: theme.textTheme.titleMedium),
                Row(
                  children: [
                    Text(
                      bundle.isEnabled ? 'Enabled' : 'Disabled',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (onRemove != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove bundle',
                        onPressed: onRemove,
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            if (bundle.actions.isEmpty)
              const Text('No actions configured.'),
            ...bundle.actions.map((action) {
              final subtitle = _actionDescription(action);
              final alias = controllerAliases[action.controllerId];
              final controllerLabel = alias != null
                  ? '${action.controllerId} ($alias)'
                  : action.controllerId;
              final isMissing =
                  missingControllers.contains(action.controllerId);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Controller $controllerLabel'),
                subtitle: Text(
                  subtitle,
                  style:
                      isMissing ? const TextStyle(color: Colors.orange) : null,
                ),
                onTap: onActionTap != null ? () => onActionTap!(action) : null,
              );
            }),
          ],
        ),
      ),
    );
  }

  String _actionDescription(CommandAction action) {
    switch (action.type) {
      case CommandActionType.channelValue:
        return 'Set channel ${action.channel} to ${action.value}';
      case CommandActionType.presetTrigger:
        return 'Trigger preset ${action.presetId}';
    }
  }
}
