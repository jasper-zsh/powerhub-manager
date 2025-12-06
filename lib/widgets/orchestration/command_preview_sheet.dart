import 'package:flutter/material.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/widgets/orchestration/dynamic_action_preview.dart';

class CommandPreviewSheet extends StatelessWidget {
  const CommandPreviewSheet({
    super.key,
    required this.preview,
    required this.toggleId,
    required this.stateId,
    required this.onExecute,
    this.controllerAliases = const <String, String>{},
    this.missingControllers = const <String>{},
  });

  final CommandPreviewResult preview;
  final String toggleId;
  final String stateId;
  final VoidCallback onExecute;
  final Map<String, String> controllerAliases;
  final Set<String> missingControllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preview for "$toggleId" · "$stateId"',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (preview.actions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('No actions configured for this state.'),
              )
            else
                ...preview.actions.map((action) {
                  final alias = controllerAliases[action.controllerId];
                  final controllerLabel = alias != null
                      ? '${action.controllerId} ($alias)'
                      : action.controllerId;
                  final isMissing =
                      missingControllers.contains(action.controllerId);
                  final isDynamicAction = _isDynamicAction(action);

                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Controller $controllerLabel'),
                        subtitle: Text(
                          _describeAction(action),
                          style: isMissing
                              ? const TextStyle(color: Colors.orange)
                              : null,
                        ),
                      ),
                      if (isDynamicAction)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                          child: DynamicActionPreview(
                            action: action,
                            width: double.infinity,
                            height: 40,
                          ),
                        ),
                    ],
                  );
                }),
            if (preview.hasWarnings) const Divider(),
            if (preview.hasWarnings)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warnings',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: Colors.orange),
                  ),
                  ...preview.missingBundles
                      .map((bundle) => Text('Missing bundle $bundle')),
                  ...preview.warnings.map(Text.new),
                ],
              ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: onExecute,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Log execution'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isDynamicAction(CommandAction action) {
    return action.type == CommandActionType.gradientMode ||
        action.type == CommandActionType.blinkMode ||
        action.type == CommandActionType.strobeMode;
  }

  String _describeAction(CommandAction action) {
    switch (action.type) {
      case CommandActionType.channelValue:
        return 'Set channel ${action.channel} to ${action.value}';
      case CommandActionType.presetTrigger:
        return 'Trigger preset ${action.presetId}';
      case CommandActionType.gradientMode:
        return 'Gradient channel ${action.channel} to ${action.value} over ${action.duration}ms';
      case CommandActionType.blinkMode:
        return 'Blink channel ${action.channel} with ${action.period}ms period';
      case CommandActionType.strobeMode:
        return 'Strobe channel ${action.channel}: ${action.count} flashes in ${action.totalTime}ms with ${action.pauseTime}ms pause';
    }
  }
}
