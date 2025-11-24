import 'condition_evaluator.dart';
import 'sequence_item.dart';
import 'state_context.dart';

/// Base type for SwitchHub logic tree nodes.
abstract class SwitchHubLogicNode {
  const SwitchHubLogicNode();

  List<SwitchHubSequenceItem> evaluate(SwitchHubStateContext context);

  Map<String, dynamic> toJson();

  void collectReferences(Set<String> references);

  factory SwitchHubLogicNode.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'leaf';
    if (type == 'if') {
      return SwitchHubIfNode.fromJson(json);
    }
    return SwitchHubLeafNode.fromJson(json);
  }
}

class SwitchHubIfNode extends SwitchHubLogicNode {
  const SwitchHubIfNode({
    required this.condition,
    required this.thenNode,
    this.elseNode,
  });

  final String condition;
  final SwitchHubLogicNode thenNode;
  final SwitchHubLogicNode? elseNode;

  @override
  List<SwitchHubSequenceItem> evaluate(SwitchHubStateContext context) {
    final evaluator = SwitchHubConditionEvaluator(context);
    final matches = evaluator.evaluate(condition);
    if (matches) {
      return thenNode.evaluate(context);
    }
    return elseNode?.evaluate(context) ?? const <SwitchHubSequenceItem>[];
  }

  @override
  void collectReferences(Set<String> references) {
    references.add(condition);
    thenNode.collectReferences(references);
    elseNode?.collectReferences(references);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'if',
      'condition': condition,
      'then': thenNode.toJson(),
      if (elseNode != null) 'else': elseNode!.toJson(),
    };
  }

  factory SwitchHubIfNode.fromJson(Map<String, dynamic> json) {
    final thenNode = SwitchHubLogicNode.fromJson(
      Map<String, dynamic>.from(json['then'] as Map),
    );
    final elseJson = json['else'];
    return SwitchHubIfNode(
      condition: json['condition'] as String? ?? '',
      thenNode: thenNode,
      elseNode: elseJson == null
          ? null
          : SwitchHubLogicNode.fromJson(
              Map<String, dynamic>.from(elseJson as Map),
            ),
    );
  }
}

class SwitchHubLeafNode extends SwitchHubLogicNode {
  const SwitchHubLeafNode({
    required this.sequence,
  });

  final List<SwitchHubSequenceItem> sequence;

  @override
  List<SwitchHubSequenceItem> evaluate(SwitchHubStateContext context) {
    return List<SwitchHubSequenceItem>.from(sequence);
  }

  @override
  void collectReferences(Set<String> references) {}

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'leaf',
      'sequence': sequence.map((item) => item.toJson()).toList(),
    };
  }

  factory SwitchHubLeafNode.fromJson(Map<String, dynamic> json) {
    final seq = (json['sequence'] as List<dynamic>? ?? [])
        .map(
          (entry) =>
              SwitchHubSequenceItem.fromJson(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    return SwitchHubLeafNode(sequence: seq);
  }
}
