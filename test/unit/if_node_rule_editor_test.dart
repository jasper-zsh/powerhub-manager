import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/models/switch_hub/logic_node.dart';
import 'package:app/models/switch_hub/command_packet.dart';
import 'package:app/models/switch_hub/sequence_item.dart';
import 'package:app/widgets/orchestration/if_node_rule_editor.dart';

void main() {
  group('IfNodeRuleEditorDialog Widget Tests', () {
    late List<CommandBundle> testBundles;
    late List<String> testToggles;
    late Map<String, String> testAliases;

    setUp(() {
      testBundles = [
        CommandBundle(
          id: 'bundle1',
          label: 'Light On',
          actions: [
            CommandAction(
              controllerId: '1',
              type: CommandActionType.channelValue,
              channel: 1,
              value: 255,
            ),
          ],
        ),
        CommandBundle(
          id: 'bundle2',
          label: 'Light Off',
          actions: [
            CommandAction(
              controllerId: '1',
              type: CommandActionType.channelValue,
              channel: 1,
              value: 0,
            ),
          ],
        ),
      ];
      testToggles = ['SW1', 'SW2', 'SW3'];
      testAliases = {'LIGHT': 'SW1', 'FAN': 'SW2'};
    });

    Widget createTestWidget({SwitchHubIfNode? ifNode}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: IfNodeRuleEditorDialog(
              ifNode: ifNode,
              availableBundles: testBundles,
              availableToggles: testToggles,
              aliases: testAliases,
            ),
          ),
        ),
      );
    }

    testWidgets('renders dialog with correct title for new rule', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Create Conditional Rule'), findsOneWidget);
      expect(find.text('Condition'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
    });

    testWidgets('renders dialog with correct title for existing rule', (WidgetTester tester) async {
      final ifNode = SwitchHubIfNode(
        condition: 'SW1.ON',
        thenNode: SwitchHubLeafNode(sequence: []),
      );

      await tester.pumpWidget(createTestWidget(ifNode: ifNode));

      expect(find.text('Edit Conditional Rule'), findsOneWidget);
      expect(find.text('SW1.ON'), findsOneWidget);
    });

    testWidgets('displays condition builder with initial condition', (WidgetTester tester) async {
      final ifNode = SwitchHubIfNode(
        condition: 'SW1.ON AND SW2.OFF',
        thenNode: SwitchHubLeafNode(sequence: []),
      );

      await tester.pumpWidget(createTestWidget(ifNode: ifNode));

      expect(find.text('SW1.ON AND SW2.OFF'), findsOneWidget);
    });

    testWidgets('shows then and else branch configuration', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('THEN (when condition is true)'), findsOneWidget);
      expect(find.text('Select Command Bundle'), findsOneWidget);
      expect(find.text('Create Nested Rule'), findsOneWidget);
    });

    testWidgets('can toggle else branch visibility', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initially, else branch should not be visible
      expect(find.text('ELSE (when condition is false)'), findsNothing);

      // Click the checkbox to show else branch
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      expect(find.text('ELSE (when condition is false)'), findsOneWidget);
      expect(find.text('Select Command Bundle'), findsNWidgets(2)); // One for then, one for else
    });

    testWidgets('populates bundle dropdown with available bundles', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Open the dropdown for then branch
      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await tester.pump();

      expect(find.text('No action'), findsOneWidget);
      expect(find.text('Light On'), findsOneWidget);
      expect(find.text('Light Off'), findsOneWidget);
    });

    testWidgets('updates preview when condition and bundles are selected', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Set condition
      await tester.tap(find.text('SW1.ON'));
      await tester.pump();

      // Select bundle for then branch
      await tester.tap(find.byType(DropdownButtonFormField<String?>).first);
      await tester.pump();
      await tester.tap(find.text('Light On'));
      await tester.pump();

      // Check preview
      expect(find.text('IF SW1.ON'), findsOneWidget);
      expect(find.textContaining('Run bundle: Light On'), findsOneWidget);
    });

    testWidgets('validates condition before saving', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Initially, save button should be disabled (empty condition)
      expect(find.byType(ElevatedButton), findsNothing);

      // Set condition
      await tester.tap(find.text('SW1.ON'));
      await tester.pump();

      // Now save button should be enabled
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('can edit existing rule with else branch', (WidgetTester tester) async {
      final elseNode = SwitchHubLeafNode(sequence: [
        SwitchHubSequenceItem(
          targetMac: 'bundle:bundle2',
          commandPackets: [
            SwitchHubCommandPacket(
              mode: 1,
              channel: 1,
              payload: 'AA==',
            ),
          ],
        ),
      ]);

      final ifNode = SwitchHubIfNode(
        condition: 'SW1.ON',
        thenNode: SwitchHubLeafNode(sequence: []),
        elseNode: elseNode,
      );

      await tester.pumpWidget(createTestWidget(ifNode: ifNode));

      expect(find.text('SW1.ON'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);
      // Checkbox should be checked since else node exists
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
      expect(find.text('ELSE (when condition is false)'), findsOneWidget);
    });

    testWidgets('displays nested rule button for each branch', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Should have nested rule button for then branch
      expect(find.text('Create Nested Rule'), findsOneWidget);

      // Toggle else branch
      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      // Should now have two nested rule buttons
      expect(find.text('Create Nested Rule'), findsNWidgets(2));
    });

    testWidgets('shows snackbar for nested rule creation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Create Nested Rule'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Nested rules will be implemented in the next iteration'), findsOneWidget);
    });
  });

  group('IfNodeRuleListItem Widget Tests', () {
    late List<CommandBundle> testBundles;
    late SwitchHubIfNode testIfNode;

    setUp(() {
      testBundles = [
        CommandBundle(
          id: 'bundle1',
          label: 'Morning Scene',
          actions: [],
        ),
        CommandBundle(
          id: 'bundle2',
          label: 'Evening Scene',
          actions: [],
        ),
      ];

      // Create a simple if-node without bundle references for testing
      testIfNode = SwitchHubIfNode(
        condition: '(SW1.ON AND SW2.OFF) OR SW3.ON',
        thenNode: SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle1',
            commandPackets: [
              const SwitchHubCommandPacket(
                mode: 1,
                channel: 1,
                payload: 'AQ==', // Base64 for simple packet
              ),
            ],
          ),
        ]),
        elseNode: SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:bundle2',
            commandPackets: [
              const SwitchHubCommandPacket(
                mode: 1,
                channel: 1,
                payload: 'AA==', // Base64 for empty packet
              ),
            ],
          ),
        ]),
      );
    });

    Widget createTestListItem({
      required SwitchHubIfNode ifNode,
      VoidCallback? onEdit,
      VoidCallback? onDelete,
      VoidCallback? onDuplicate,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: IfNodeRuleListItem(
              index: 0,
              ifNode: ifNode,
              availableBundles: testBundles,
              onEdit: onEdit,
              onDelete: onDelete,
              onDuplicate: onDuplicate,
            ),
          ),
        ),
      );
    }

    testWidgets('displays rule number and condition correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestListItem(ifNode: testIfNode));

      expect(find.text('Rule 1'), findsOneWidget);
      expect(find.text('(SW1.ON AND SW2.OFF) OR SW3.ON'), findsOneWidget);
    });

    testWidgets('shows then and else branches with bundle names', (WidgetTester tester) async {
      await tester.pumpWidget(createTestListItem(ifNode: testIfNode));

      expect(find.text('THEN'), findsOneWidget);
      expect(find.text('ELSE'), findsOneWidget);
      expect(find.text('Run: Morning Scene'), findsOneWidget);
      expect(find.text('Run: Evening Scene'), findsOneWidget);
    });

    testWidgets('shows action buttons when callbacks provided', (WidgetTester tester) async {
      bool editClicked = false;
      bool deleteClicked = false;
      bool duplicateClicked = false;

      await tester.pumpWidget(createTestListItem(
        ifNode: testIfNode,
        onEdit: () => editClicked = true,
        onDelete: () => deleteClicked = true,
        onDuplicate: () => duplicateClicked = true,
      ));

      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit));
      expect(editClicked, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleteClicked, isTrue);

      await tester.tap(find.byIcon(Icons.content_copy));
      expect(duplicateClicked, isTrue);
    });

    testWidgets('hides action buttons when callbacks not provided', (WidgetTester tester) async {
      await tester.pumpWidget(createTestListItem(ifNode: testIfNode));

      expect(find.byIcon(Icons.content_copy), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('handles empty leaf node correctly', (WidgetTester tester) async {
      final emptyIfNode = SwitchHubIfNode(
        condition: 'SW1.ON',
        thenNode: SwitchHubLeafNode(sequence: []),
      );

      await tester.pumpWidget(createTestListItem(ifNode: emptyIfNode));

      expect(find.text('THEN'), findsOneWidget);
      expect(find.text('No action'), findsOneWidget);
      expect(find.text('ELSE'), findsNothing);
    });

    testWidgets('displays correct rule index', (WidgetTester tester) async {
      await tester.pumpWidget(createTestListItem(ifNode: testIfNode));

      expect(find.text('Rule 1'), findsOneWidget);
    });

    testWidgets('handles bundle not found gracefully', (WidgetTester tester) async {
      final unknownBundleIfNode = SwitchHubIfNode(
        condition: 'SW1.ON',
        thenNode: SwitchHubLeafNode(sequence: [
          SwitchHubSequenceItem(
            targetMac: 'bundle:unknown_bundle',
            commandPackets: [
              const SwitchHubCommandPacket(
                mode: 1,
                channel: 1,
                payload: 'AA==',
              ),
            ],
          ),
        ]),
      );

      await tester.pumpWidget(createTestListItem(ifNode: unknownBundleIfNode));

      expect(find.text('Run: unknown_bundle'), findsOneWidget);
    });

    testWidgets('displays node description for non-leaf nodes', (WidgetTester tester) async {
      final nestedIfNode = SwitchHubIfNode(
        condition: 'SW1.ON',
        thenNode: testIfNode, // Nested if node
      );

      await tester.pumpWidget(createTestListItem(ifNode: nestedIfNode));

      expect(find.text('Nested rule: (SW1.ON AND SW2.OFF) OR SW3.ON'), findsOneWidget);
    });
  });

  group('IfNodeRuleEditor Helper Methods Tests', () {
    test('extracts bundle ID from targetMac correctly', () {
      final item = SwitchHubSequenceItem(
        targetMac: 'bundle:test_bundle_id',
        commandPackets: [
          const SwitchHubCommandPacket(
            mode: 1,
            channel: 1,
            payload: 'AA==',
          ),
        ],
      );

      final targetMac = item.targetMac;
      expect(targetMac.startsWith('bundle:'), isTrue);

      final bundleId = targetMac.substring(7); // Remove 'bundle:' prefix
      expect(bundleId, equals('test_bundle_id'));
    });

    test('creates empty leaf node when no bundle selected', () {
      final leafNode = SwitchHubLeafNode(sequence: []);
      expect(leafNode.sequence, isEmpty);
    });

    test('creates leaf node with bundle reference', () {
      final item = SwitchHubSequenceItem(
        targetMac: 'bundle:test_bundle',
        commandPackets: [
          const SwitchHubCommandPacket(
            mode: 1,
            channel: 1,
            payload: 'AA==',
          ),
        ],
      );

      final leafNode = SwitchHubLeafNode(sequence: [item]);
      expect(leafNode.sequence.length, equals(1));
      expect(leafNode.sequence.first.targetMac, equals('bundle:test_bundle'));
    });
  });
}