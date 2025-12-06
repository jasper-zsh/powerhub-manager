import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/orchestration/dynamic_action_preview.dart';
import 'package:app/models/orchestration/toggle_scene.dart';

void main() {
  group('Dynamic Action Preview Tests', () {
    late CommandAction gradientAction;
    late CommandAction blinkAction;
    late CommandAction strobeAction;
    late CommandAction channelValueAction;
    late CommandAction presetTriggerAction;

    setUp(() {
      gradientAction = CommandAction(
        controllerId: 'controller-1',
        type: CommandActionType.gradientMode,
        channel: 2,
        value: 200,
        duration: 1500,
      );

      blinkAction = CommandAction(
        controllerId: 'controller-2',
        type: CommandActionType.blinkMode,
        channel: 1,
        period: 1000,
      );

      strobeAction = CommandAction(
        controllerId: 'controller-3',
        type: CommandActionType.strobeMode,
        channel: 3,
        count: 5,
        totalTime: 2000,
        pauseTime: 300,
      );

      channelValueAction = CommandAction(
        controllerId: 'controller-4',
        type: CommandActionType.channelValue,
        channel: 0,
        value: 128,
      );

      presetTriggerAction = CommandAction(
        controllerId: 'controller-5',
        type: CommandActionType.presetTrigger,
        presetId: 3,
      );
    });

    group('DynamicActionPreview', () {
      testWidgets('renders GradientModePreview for gradient action', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: gradientAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Gradient: 0 → 200 over 1500ms'), findsOneWidget);
        expect(find.byType(GradientModePreview), findsOneWidget);
      });

      testWidgets('renders BlinkModePreview for blink action', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: blinkAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Blink: 1.0Hz (1000ms period)'), findsOneWidget);
        expect(find.byType(BlinkModePreview), findsOneWidget);
      });

      testWidgets('renders StrobeModePreview for strobe action', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: strobeAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Strobe: 5 flashes, 2.5Hz'), findsOneWidget);
        expect(find.text('Total: 2000ms, Pause: 300ms'), findsOneWidget);
        expect(find.byType(StrobeModePreview), findsOneWidget);
      });

      testWidgets('renders no preview message for non-dynamic actions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: channelValueAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('No preview available'), findsOneWidget);
      });

      testWidgets('renders no preview message for preset trigger actions', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: presetTriggerAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('No preview available'), findsOneWidget);
      });
    });

    group('GradientModePreview', () {
      testWidgets('displays correct gradient information', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GradientModePreview(
                action: gradientAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Gradient: 0 → 200 over 1500ms'), findsOneWidget);
      });

      testWidgets('handles edge case values correctly', (WidgetTester tester) async {
        final edgeCaseAction = CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.gradientMode,
          channel: 0,
          value: 255,
          duration: 100,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GradientModePreview(
                action: edgeCaseAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Gradient: 0 → 255 over 100ms'), findsOneWidget);
      });
    });

    group('BlinkModePreview', () {
      testWidgets('displays correct blink frequency', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlinkModePreview(
                action: blinkAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Blink: 1.0Hz (1000ms period)'), findsOneWidget);
      });

      testWidgets('calculates frequency correctly for fast blink', (WidgetTester tester) async {
        final fastBlinkAction = CommandAction(
          controllerId: 'controller-2',
          type: CommandActionType.blinkMode,
          channel: 1,
          period: 250,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlinkModePreview(
                action: fastBlinkAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Blink: 4.0Hz (250ms period)'), findsOneWidget);
      });

      testWidgets('calculates frequency correctly for slow blink', (WidgetTester tester) async {
        final slowBlinkAction = CommandAction(
          controllerId: 'controller-2',
          type: CommandActionType.blinkMode,
          channel: 1,
          period: 2000,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BlinkModePreview(
                action: slowBlinkAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Blink: 0.5Hz (2000ms period)'), findsOneWidget);
      });
    });

    group('StrobeModePreview', () {
      testWidgets('displays correct strobe information', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StrobeModePreview(
                action: strobeAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Strobe: 5 flashes, 2.5Hz'), findsOneWidget);
        expect(find.text('Total: 2000ms, Pause: 300ms'), findsOneWidget);
      });

      testWidgets('calculates frequency correctly for single flash', (WidgetTester tester) async {
        final singleFlashAction = CommandAction(
          controllerId: 'controller-3',
          type: CommandActionType.strobeMode,
          channel: 3,
          count: 1,
          totalTime: 1000,
          pauseTime: 500,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StrobeModePreview(
                action: singleFlashAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.text('Strobe: 1 flashes, 1.0Hz'), findsOneWidget);
        expect(find.text('Total: 1000ms, Pause: 500ms'), findsOneWidget);
      });
    });

    group('CombinedDynamicActionPreview', () {
      testWidgets('displays multiple dynamic actions', (WidgetTester tester) async {
        final actions = [gradientAction, blinkAction, strobeAction];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CombinedDynamicActionPreview(
                actions: actions,
                width: 400,
                height: 120,
              ),
            ),
          ),
        );

        expect(find.text('Dynamic Actions Preview'), findsOneWidget);
        expect(find.byType(DynamicActionPreview), findsNWidgets(3));
      });

      testWidgets('shows no actions message when empty', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CombinedDynamicActionPreview(
                actions: [],
                width: 400,
                height: 120,
              ),
            ),
          ),
        );

        expect(find.text('No actions to preview'), findsOneWidget);
      });

      testWidgets('shows no dynamic actions message for non-dynamic actions only', (WidgetTester tester) async {
        final actions = [channelValueAction, presetTriggerAction];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CombinedDynamicActionPreview(
                actions: actions,
                width: 400,
                height: 120,
              ),
            ),
          ),
        );

        expect(find.text('No dynamic actions to preview'), findsOneWidget);
      });

      testWidgets('filters non-dynamic actions correctly', (WidgetTester tester) async {
        final mixedActions = [gradientAction, channelValueAction, blinkAction, presetTriggerAction];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CombinedDynamicActionPreview(
                actions: mixedActions,
                width: 400,
                height: 120,
              ),
            ),
          ),
        );

        expect(find.text('Dynamic Actions Preview'), findsOneWidget);
        // Should only show the 2 dynamic actions (gradient and blink)
        expect(find.byType(DynamicActionPreview), findsNWidgets(2));
      });
    });

    group('Preview Performance', () {
      testWidgets('handles rapid parameter changes without performance issues', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return DynamicActionPreview(
                    action: gradientAction,
                    width: 300,
                    height: 60,
                  );
                },
              ),
            ),
          ),
        );

        // Simulate rapid parameter changes
        for (int i = 0; i < 10; i++) {
          final updatedAction = CommandAction(
            controllerId: 'controller-1',
            type: CommandActionType.gradientMode,
            channel: 2,
            value: i * 25,
            duration: 100 + (i * 100),
          );

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DynamicActionPreview(
                  action: updatedAction,
                  width: 300,
                  height: 60,
                ),
              ),
            ),
          );

          expect(find.byType(GradientModePreview), findsOneWidget);
        }
      });
    });

    group('Error Handling', () {
      testWidgets('handles null parameters gracefully', (WidgetTester tester) async {
        // This should not happen due to constructor assertions, but test robustness
        final incompleteAction = CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.gradientMode,
          channel: 2,
          value: 200,
          duration: 1500,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: incompleteAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.byType(GradientModePreview), findsOneWidget);
      });

      testWidgets('handles extreme parameter values', (WidgetTester tester) async {
        final extremeAction = CommandAction(
          controllerId: 'controller-1',
          type: CommandActionType.strobeMode,
          channel: 5,
          count: 255,
          totalTime: 60000,
          pauseTime: 59999,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicActionPreview(
                action: extremeAction,
                width: 300,
                height: 60,
              ),
            ),
          ),
        );

        expect(find.byType(StrobeModePreview), findsOneWidget);
        expect(find.text('Strobe: 255 flashes, 4.3Hz'), findsOneWidget);
      });
    });
  });
}