import 'dart:convert';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/models/switch_hub/state_context.dart';
import 'package:app/models/switch_hub/command_packet.dart';

/// Manages conditional logic operations for ToggleState
class ConditionalLogicManager {
  const ConditionalLogicManager();

  /// Resolves bundle references in conditional logic nodes
  /// This handles the temporary storage of bundle IDs in targetMac fields
  SwitchHubLogicNode resolveBundleReferences(
    SwitchHubLogicNode node,
    List<CommandBundle> availableBundles,
  ) {
    print('DEBUG ConditionalLogicManager.resolveBundleReferences: Input node type=${node.runtimeType}');

    if (node is SwitchHubLeafNode) {
      print('DEBUG ConditionalLogicManager: Input sequence has ${node.sequence.length} items');
      for (int i = 0; i < node.sequence.length; i++) {
        final item = node.sequence[i];
        print('  Item $i: targetMac="${item.targetMac}"');
      }
    }

    final result = _resolveNode(node, availableBundles);

    if (result is SwitchHubLeafNode) {
      print('DEBUG ConditionalLogicManager: Output sequence has ${result.sequence.length} items');
      for (int i = 0; i < result.sequence.length; i++) {
        final item = result.sequence[i];
        print('  Output Item $i: targetMac="${item.targetMac}"');
      }
    }

    return result;
  }

  SwitchHubLogicNode _resolveNode(
    SwitchHubLogicNode node,
    List<CommandBundle> availableBundles,
  ) {
    if (node is SwitchHubLeafNode) {
      return SwitchHubLeafNode(
        sequence: _resolveSequenceItems(node.sequence, availableBundles),
      );
    } else if (node is SwitchHubIfNode) {
      return SwitchHubIfNode(
        condition: node.condition,
        thenNode: _resolveNode(node.thenNode, availableBundles),
        elseNode: node.elseNode != null
            ? _resolveNode(node.elseNode!, availableBundles)
            : null,
      );
    }
    return node;
  }

  List<SwitchHubSequenceItem> _resolveSequenceItems(
    List<SwitchHubSequenceItem> items,
    List<CommandBundle> availableBundles,
  ) {
    final result = <SwitchHubSequenceItem>[];
    for (final item in items) {
      result.addAll(_resolveSequenceItem(item, availableBundles));
    }
    return result;
  }

  // Returns multiple sequence items from a single bundle reference
  List<SwitchHubSequenceItem> _resolveSequenceItem(
    SwitchHubSequenceItem item,
    List<CommandBundle> availableBundles,
  ) {
    // Check if targetMac contains a bundle reference
    if (item.targetMac.startsWith('bundle:')) {
      final bundleId = item.targetMac.substring(7); // Remove 'bundle:' prefix
      final bundle = availableBundles.where((b) => b.id == bundleId).firstOrNull;

      if (bundle != null) {
        // Group bundle actions by controllerId like in _sequenceFromBundle
        final grouped = <String, List<CommandAction>>{};
        for (final action in bundle.actions) {
          grouped
              .putIfAbsent(action.controllerId, () => <CommandAction>[])
              .add(action);
        }

        // Create sequence items for each controller
        final result = <SwitchHubSequenceItem>[];
        for (final entry in grouped.entries) {
          final controllerId = entry.key;
          final actions = entry.value;
          final packets = <SwitchHubCommandPacket>[];

          for (final action in actions) {
            if (action.channel == null) continue;
            final packet = action.buildPacketFromAction();
            if (packet != null) {
              packets.add(packet);
            }
          }

          // Only create sequence item if we have valid packets
          if (packets.isNotEmpty) {
            result.add(SwitchHubSequenceItem(
              targetMac: controllerId, // Use controller ID as MAC address (will be resolved)
              commandPackets: packets,
              delayMs: item.delayMs,
            ));
          }
        }

        return result;
      }
    }

    // Return original item as single-item list if no bundle reference
    return [item];
  }

  List<SwitchHubCommandPacket> _buildPacketsFromBundle(CommandBundle bundle) {
    // Use the same logic as _sequenceFromBundle in toggle_scene.dart
    // Group actions by controllerId to create proper sequence items
    final packets = <SwitchHubCommandPacket>[];
    for (final action in bundle.actions) {
      if (action.channel == null) continue;

      final packet = action.buildPacketFromAction();
      if (packet != null) {
        packets.add(packet);
      }
    }
    return packets;
  }

  /// Validates conditional logic in a ToggleState
  ConditionalValidationResult validateLogic(
    ToggleState state,
    List<String> availableToggles,
    Map<String, String> aliases,
  ) {
    final errors = <String>[];
    final warnings = <String>[];

    if (state.logic == null) {
      return ConditionalValidationResult(
        isValid: true,
        errors: errors,
        warnings: warnings,
      );
    }

    final logic = state.logic!;
    final references = <String>{};
    logic.collectReferences(references);

    // Validate toggle references
    for (final reference in references) {
      if (!_isValidToggleReference(reference, availableToggles, aliases)) {
        errors.add('Unknown toggle reference: $reference');
      }
    }

    // Check for potential circular dependencies
    if (_hasCircularDependency(logic)) {
      errors.add('Potential circular dependency detected in conditional logic');
    }

    // Check complexity
    final complexity = _calculateComplexity(logic);
    if (complexity > 50) {
      warnings.add('Complex conditional logic may impact performance');
    }

    return ConditionalValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      complexity: complexity,
    );
  }

  bool _isValidToggleReference(
    String reference,
    List<String> availableToggles,
    Map<String, String> aliases,
  ) {
    // Check if it's a direct toggle reference (e.g., SW1.ON)
    final toggleRegex = RegExp(r'^SW\d+\.(ON|OFF)$', caseSensitive: false);
    if (toggleRegex.hasMatch(reference)) {
      final toggleId = reference.split('.')[0];
      return availableToggles.contains(toggleId);
    }

    // Check if it's an alias reference
    if (aliases.containsKey(reference)) {
      return availableToggles.contains(aliases[reference]!);
    }

    return false;
  }

  bool _hasCircularDependency(SwitchHubLogicNode node, {Set<SwitchHubLogicNode>? visited}) {
    visited ??= <SwitchHubLogicNode>{};

    if (visited.contains(node)) {
      return true;
    }

    visited.add(node);

    if (node is SwitchHubIfNode) {
      return _hasCircularDependency(node.thenNode, visited: visited) ||
             (node.elseNode != null && _hasCircularDependency(node.elseNode!, visited: visited));
    }

    visited.remove(node);
    return false;
  }

  int _calculateComplexity(SwitchHubLogicNode node) {
    if (node is SwitchHubIfNode) {
      // Count condition complexity + branch complexity
      final conditionComplexity = node.condition.split(' ').length;
      final thenComplexity = _calculateComplexity(node.thenNode);
      final elseComplexity = node.elseNode != null ? _calculateComplexity(node.elseNode!) : 0;
      return conditionComplexity + thenComplexity + elseComplexity;
    } else if (node is SwitchHubLeafNode) {
      return node.sequence.length;
    }
    return 0;
  }

  /// Creates a conditional logic node from a bundle reference
  SwitchHubIfNode createConditionalFromBundle(
    String bundleId,
    List<CommandBundle> availableBundles,
    String condition,
  ) {
    final bundle = availableBundles.where((b) => b.id == bundleId).firstOrNull;
    if (bundle == null) {
      throw ArgumentError('Bundle with ID $bundleId not found');
    }

    final leafNode = SwitchHubLeafNode(
      sequence: _resolveSequenceItems(
        [SwitchHubSequenceItem(
          targetMac: 'bundle:$bundleId',
          commandPackets: [],
        )],
        availableBundles,
      ),
    );

    return SwitchHubIfNode(
      condition: condition,
      thenNode: leafNode,
    );
  }

  /// Merges multiple conditional rules into a single logic tree
  SwitchHubLogicNode mergeConditionalRules(List<SwitchHubIfNode> rules) {
    if (rules.isEmpty) {
      return const SwitchHubLeafNode(sequence: []);
    }

    if (rules.length == 1) {
      return rules.first;
    }

    // Create a nested if-else chain
    SwitchHubLogicNode result = rules.first;
    for (int i = 1; i < rules.length; i++) {
      result = SwitchHubIfNode(
        condition: rules[i].condition,
        thenNode: rules[i].thenNode,
        elseNode: result,
      );
    }

    return result;
  }

  /// Extracts bundle references from conditional logic
  Set<String> extractBundleReferences(SwitchHubLogicNode node) {
    final bundleIds = <String>{};
    _collectBundleIds(node, bundleIds);
    return bundleIds;
  }

  void _collectBundleIds(SwitchHubLogicNode node, Set<String> bundleIds) {
    if (node is SwitchHubLeafNode) {
      for (final item in node.sequence) {
        if (item.targetMac.startsWith('bundle:')) {
          final bundleId = item.targetMac.substring(7);
          bundleIds.add(bundleId);
        }
      }
    } else if (node is SwitchHubIfNode) {
      _collectBundleIds(node.thenNode, bundleIds);
      if (node.elseNode != null) {
        _collectBundleIds(node.elseNode!, bundleIds);
      }
    }
  }
}

/// Validation result for conditional logic
class ConditionalValidationResult {
  const ConditionalValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.complexity = 0,
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final int complexity;

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}

/// Performance metrics for conditional logic evaluation
class ConditionalEvaluationMetrics {
  const ConditionalEvaluationMetrics({
    required this.evaluationTimeMs,
    required this.nodesEvaluated,
    required this.conditionsChecked,
    required this.bundlesExecuted,
  });

  final int evaluationTimeMs;
  final int nodesEvaluated;
  final int conditionsChecked;
  final int bundlesExecuted;

  @override
  String toString() {
    return 'ConditionalEvaluationMetrics('
        'time: ${evaluationTimeMs}ms, '
        'nodes: $nodesEvaluated, '
        'conditions: $conditionsChecked, '
        'bundles: $bundlesExecuted)';
  }
}