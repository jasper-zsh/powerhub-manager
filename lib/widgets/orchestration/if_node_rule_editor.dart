import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/orchestration/conditional_logic_manager.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/command_packet.dart';
import 'package:app/widgets/orchestration/condition_builder.dart';

/// Dialog for creating and editing if-node conditional rules
class IfNodeRuleEditorDialog extends ConsumerStatefulWidget {
  const IfNodeRuleEditorDialog({
    super.key,
    this.ifNode,
    this.availableBundles = const [],
    this.availableToggles = const [],
    this.aliases = const {},
  });

  final SwitchHubIfNode? ifNode;
  final List<CommandBundle> availableBundles;
  final List<String> availableToggles;
  final Map<String, String> aliases;

  @override
  ConsumerState<IfNodeRuleEditorDialog> createState() => _IfNodeRuleEditorDialogState();
}

class _IfNodeRuleEditorDialogState extends ConsumerState<IfNodeRuleEditorDialog> {
  late String _condition;
  String? _selectedThenBundle;
  String? _selectedElseBundle;
  bool _showElseBranch = false;
  bool _conditionValid = true;

  // For nested rule creation
  SwitchHubLogicNode? _editingNode;
  String _editingBranch = 'then'; // 'then' or 'else'

  // Bundle resolution logic
  final ConditionalLogicManager _logicManager = const ConditionalLogicManager();

  @override
  void initState() {
    super.initState();
    _condition = widget.ifNode?.condition ?? '';
    _showElseBranch = widget.ifNode?.elseNode != null;
    _extractBundleIds();
    // Validation will be called after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _validateCondition();
      }
    });
  }

  void _extractBundleIds() {
    if (widget.ifNode != null) {
      _selectedThenBundle = _extractBundleIdFromNode(widget.ifNode!.thenNode, widget.availableBundles);
      _selectedElseBundle = widget.ifNode?.elseNode != null
          ? _extractBundleIdFromNode(widget.ifNode!.elseNode!, widget.availableBundles)
          : null;
    }
  }

  String? _extractBundleIdFromNode(SwitchHubLogicNode node, List<CommandBundle> availableBundles) {
    if (node is SwitchHubLeafNode && node.sequence.isNotEmpty) {
      final targetMac = node.sequence.first.targetMac;

      // Check if it's a bundle reference (old format)
      if (targetMac.startsWith('bundle:')) {
        return targetMac.substring(7); // Remove 'bundle:' prefix
      }

      // Match using both MAC address and packet contents
      for (final bundle in availableBundles) {
        if (_matchesBundleWithNode(bundle, node)) {
          return bundle.id;
        }
      }
    }
    return null;
  }

  /// Matches a bundle with a node by comparing MAC addresses and packet contents
  bool _matchesBundleWithNode(CommandBundle bundle, SwitchHubLeafNode node) {
    for (final sequenceItem in node.sequence) {
      final targetMac = sequenceItem.targetMac;
      final nodePackets = sequenceItem.commandPackets;

      // Find actions in bundle that match this MAC address
      final matchingActions = bundle.actions
          .where((action) => action.controllerId == targetMac)
          .toList();

      if (matchingActions.isEmpty) continue;

      // Build expected packets from these actions
      final expectedPackets = <String>[];
      for (final action in matchingActions) {
        final packet = action.buildPacketFromAction();
        if (packet != null) {
          expectedPackets.add('${packet.mode}_${packet.channel}_${packet.payload}');
        }
      }

      // Compare with actual packets in node
      final actualPackets = nodePackets
          .map((packet) => '${packet.mode}_${packet.channel}_${packet.payload}')
          .toList();

      // Check if packets match (allowing for reordering)
      if (_packetListsMatch(expectedPackets, actualPackets)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if two packet lists contain the same elements (order doesn't matter)
  bool _packetListsMatch(List<String> expected, List<String> actual) {
    if (expected.length != actual.length) return false;

    final expectedSet = expected.toSet();
    final actualSet = actual.toSet();

    return expectedSet.difference(actualSet).isEmpty &&
           actualSet.difference(expectedSet).isEmpty;
  }

  void _validateCondition() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _conditionValid = _condition.isNotEmpty;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.ifNode == null ? 'Create Conditional Rule' : 'Edit Conditional Rule',
                      style: theme.textTheme.headlineSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Condition Builder Section
                      _buildConditionSection(),
                      const SizedBox(height: 24),

                      // Branch Configuration Section
                      _buildBranchConfigurationSection(),
                      const SizedBox(height: 24),

                      // Preview Section
                      _buildPreviewSection(),
                    ],
                  ),
                ),
              ),

              // Actions
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConditionSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condition',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ConditionBuilder(
          initialCondition: _condition,
          onConditionChanged: (condition) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _condition = condition;
                  _conditionValid = condition.isNotEmpty;
                });
              }
            });
          },
          availableToggles: widget.availableToggles,
          aliases: widget.aliases,
        ),
        if (!_conditionValid) ...[
          const SizedBox(height: 8),
          Text(
            'Please enter a valid condition',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBranchConfigurationSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actions',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 16),

        // Then Branch
        _buildBranchCard(
          title: 'THEN (when condition is true)',
          icon: Icons.check_circle,
          iconColor: theme.colorScheme.primary,
          selectedBundle: _selectedThenBundle,
          onBundleSelected: (bundleId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedThenBundle = bundleId;
                });
              }
            });
          },
          onNestedRule: () => _createNestedRule('then'),
        ),

        const SizedBox(height: 16),

        // Else Branch Toggle
        Row(
          children: [
            Checkbox(
              value: _showElseBranch,
              onChanged: (value) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _showElseBranch = value ?? false;
                      if (!_showElseBranch) {
                        _selectedElseBundle = null;
                      }
                    });
                  }
                });
              },
            ),
            Expanded(
              child: Text(
                'Add ELSE branch (when condition is false)',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),

        if (_showElseBranch) ...[
          const SizedBox(height: 16),
          _buildBranchCard(
            title: 'ELSE (when condition is false)',
            icon: Icons.not_interested,
            iconColor: theme.colorScheme.secondary,
            selectedBundle: _selectedElseBundle,
            onBundleSelected: (bundleId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _selectedElseBundle = bundleId;
                  });
                }
              });
            },
            onNestedRule: () => _createNestedRule('else'),
          ),
        ],
      ],
    );
  }

  Widget _buildBranchCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String? selectedBundle,
    required Function(String?) onBundleSelected,
    required VoidCallback onNestedRule,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bundle Selection
            DropdownButtonFormField<String?>(
              value: selectedBundle,
              decoration: const InputDecoration(
                labelText: 'Select Command Bundle',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No action'),
                ),
                ...widget.availableBundles.map((bundle) => DropdownMenuItem(
                  value: bundle.id,
                  child: Text(bundle.label),
                )),
              ],
              onChanged: onBundleSelected,
            ),

            const SizedBox(height: 12),

            // Nested Rule Option
            OutlinedButton.icon(
              onPressed: onNestedRule,
              icon: const Icon(Icons.account_tree),
              label: const Text('Create Nested Rule'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Card(
          color: theme.colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IF $_condition',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'THEN ${_selectedThenBundle != null ? "Run bundle: ${_getBundleName(_selectedThenBundle!)}" : "No action"}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontFamily: 'monospace',
                  ),
                ),
                if (_showElseBranch) ...[
                  const SizedBox(height: 4),
                  Text(
                    'ELSE ${_selectedElseBundle != null ? "Run bundle: ${_getBundleName(_selectedElseBundle!)}" : "No action"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _conditionValid ? _saveRule : null,
          child: const Text('Save Rule'),
        ),
      ],
    );
  }

  String _getBundleName(String bundleId) {
    final bundle = widget.availableBundles.where((b) => b.id == bundleId).firstOrNull;
    return bundle?.label ?? bundleId;
  }

  void _createNestedRule(String branch) {
    // TODO: Implement nested rule creation
    // This would open another instance of this dialog for nested logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nested rules will be implemented in the next iteration')),
    );
  }

  void _saveRule() {
    // Create the leaf nodes for then and else branches
    final thenNode = _createLeafNode(_selectedThenBundle);
    final elseNode = _showElseBranch ? _createLeafNode(_selectedElseBundle) : null;

    final ifNode = SwitchHubIfNode(
      condition: _condition,
      thenNode: thenNode,
      elseNode: elseNode,
    );

    Navigator.of(context).pop(ifNode);
  }

  SwitchHubLogicNode _createLeafNode(String? bundleId) {
    if (bundleId == null) {
      // Empty leaf node
      return const SwitchHubLeafNode(sequence: []);
    }

    // Create a bundle reference sequence item
    final bundleRefItem = SwitchHubSequenceItem(
      targetMac: 'bundle:$bundleId',
      commandPackets: [], // Empty - will be filled by bundle resolution
      delayMs: 0,
    );

    // Create a temporary leaf node with the bundle reference
    final bundleRefNode = SwitchHubLeafNode(sequence: [bundleRefItem]);

    // Resolve the bundle reference immediately to get real controller commands
    final resolvedNode = _logicManager.resolveBundleReferences(bundleRefNode, widget.availableBundles);

    return resolvedNode;
  }
}

/// Widget for displaying and managing if-node rules in a list
class IfNodeRuleListItem extends StatelessWidget {
  const IfNodeRuleListItem({
    super.key,
    required this.index,
    required this.ifNode,
    required this.availableBundles,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
  });

  final int index;
  final SwitchHubIfNode ifNode;
  final List<CommandBundle> availableBundles;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

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
            // Header with index and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rule ${index + 1}',
                  style: theme.textTheme.titleMedium,
                ),
                Row(
                  children: [
                    if (onDuplicate != null)
                      IconButton(
                        icon: const Icon(Icons.content_copy),
                        tooltip: 'Duplicate rule',
                        onPressed: onDuplicate,
                      ),
                    if (onEdit != null)
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit rule',
                        onPressed: onEdit,
                      ),
                    if (onDelete != null)
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete rule',
                        onPressed: onDelete,
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Rule content
            _buildRuleContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleContent(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Condition
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
          ),
          child: Text(
            ifNode.condition,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Then branch
        _buildBranchContent(
          context,
          title: 'THEN',
          icon: Icons.check_circle,
          color: theme.colorScheme.primary,
          node: ifNode.thenNode,
          availableBundles: availableBundles,
        ),

        // Else branch (if exists)
        if (ifNode.elseNode != null) ...[
          const SizedBox(height: 8),
          _buildBranchContent(
            context,
            title: 'ELSE',
            icon: Icons.not_interested,
            color: theme.colorScheme.secondary,
            node: ifNode.elseNode!,
            availableBundles: availableBundles,
          ),
        ],
      ],
    );
  }

  Widget _buildBranchContent(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required SwitchHubLogicNode node,
    required List<CommandBundle> availableBundles,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getNodeDescription(node, availableBundles),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  String _getNodeDescription(SwitchHubLogicNode node, List<CommandBundle> availableBundles) {
    if (node is SwitchHubLeafNode) {
      if (node.sequence.isEmpty) {
        return 'No action';
      }

      // Extract bundle ID from targetMac (temporary storage)
      final targetMac = node.sequence.first.targetMac;
      if (targetMac.startsWith('bundle:')) {
        final bundleId = targetMac.substring(7); // Remove 'bundle:' prefix
        final bundle = availableBundles.where((b) => b.id == bundleId).firstOrNull;
        return 'Run: ${bundle?.label ?? bundleId}';
      }
      return '${node.sequence.length} commands';
    } else if (node is SwitchHubIfNode) {
      return 'Nested rule: ${node.condition}';
    }
    return 'Unknown node type';
  }
}