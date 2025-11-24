import 'package:flutter/material.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

typedef RuleChangedCallback = void Function(ConditionalRule rule);

typedef RuleRemovedCallback = void Function(String ruleId);

class ConditionalRuleEditor extends StatelessWidget {
  const ConditionalRuleEditor({
    super.key,
    required this.rule,
    this.onChanged,
    this.onRemoved,
  });

  final ConditionalRule rule;
  final RuleChangedCallback? onChanged;
  final RuleRemovedCallback? onRemoved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium;

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
                Text('Rule ${rule.id}', style: theme.textTheme.titleMedium),
                if (onRemoved != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove rule',
                    onPressed: () => onRemoved!(rule.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('If toggle "${rule.toggleId}" equals "${rule.expectedStateId}"', style: style),
            Text('→ Run bundle ${rule.trueBundleId}', style: style),
            if (rule.falseBundleId != null)
              Text(
                'Else run bundle ${rule.falseBundleId}',
                style: style,
              ),
            if (rule.description != null) ...[
              const SizedBox(height: 8),
              Text(rule.description!, style: theme.textTheme.bodySmall),
            ],
            if (onChanged != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onChanged!(rule),
                  child: const Text('Edit rule'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
