import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/widgets/orchestration/condition_builder.dart';
import 'package:app/widgets/orchestration/if_node_rule_editor.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';

void main() {
  group('Condition Loading Tests', () {
    testWidgets('ConditionBuilder should load initial condition correctly', (tester) async {
      const testCondition = 'SW1.ON AND SW2.OFF';
      String? loadedCondition;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ConditionBuilder(
                initialCondition: testCondition,
                availableToggles: ['SW1', 'SW2'],
                aliases: {},
                onConditionChanged: (condition) {
                  loadedCondition = condition;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the condition display text
      expect(find.text(testCondition), findsOneWidget);
      expect(loadedCondition, equals(testCondition));
    });

    testWidgets('IfNodeRuleEditor should load existing condition for editing', (tester) async {
      // Create a test if-node with a condition
      const testCondition = 'SW1.ON OR SW3.OFF';
      final testIfNode = SwitchHubIfNode(
        condition: testCondition,
        thenNode: const SwitchHubLeafNode(sequence: []),
        elseNode: const SwitchHubLeafNode(sequence: []),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IfNodeRuleEditorDialog(
                ifNode: testIfNode,
                availableBundles: [],
                availableToggles: ['SW1', 'SW2', 'SW3'],
                aliases: {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the condition display text in the condition builder
      expect(find.text(testCondition), findsOneWidget);
    });

    testWidgets('IfNodeRuleEditor should handle empty condition for new rule', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: IfNodeRuleEditorDialog(
                ifNode: null, // New rule - no existing condition
                availableBundles: [],
                availableToggles: ['SW1', 'SW2'],
                aliases: {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show the placeholder text for empty condition
      expect(find.text('Tap buttons below to build condition'), findsOneWidget);
    });

    testWidgets('ConditionBuilder should preserve condition during widget updates', (tester) async {
      const initialCondition = 'SW1.ON';
      const updatedCondition = 'SW2.OFF';
      String? currentCondition;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      ConditionBuilder(
                        initialCondition: currentCondition ?? initialCondition,
                        availableToggles: ['SW1', 'SW2'],
                        aliases: {},
                        onConditionChanged: (condition) {
                          currentCondition = condition;
                        },
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            currentCondition = updatedCondition;
                          });
                        },
                        child: const Text('Update Condition'),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show initial condition (might appear multiple times - buttons + display)
      expect(find.text(initialCondition), findsAtLeastNWidgets(1));

      // Tap the button to update condition
      await tester.tap(find.text('Update Condition'));
      await tester.pumpAndSettle();

      // Should show updated condition
      expect(find.text(updatedCondition), findsAtLeastNWidgets(1));
    });
  });
}