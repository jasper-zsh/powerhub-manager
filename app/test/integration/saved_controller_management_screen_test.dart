import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/providers/app_state_provider.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/services/storage_service.dart';
import 'package:app/screens/saved_controller_management_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppStateProvider appState;
  late OrchestrationProvider orchestrationProvider;
  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    appState = AppStateProvider();
    await appState.init();
    await appState.saveController(
      controllerId: 'controller-1',
      alias: 'Living Room',
    );
    await appState.saveController(
      controllerId: 'controller-2',
      alias: 'Workshop',
    );

    orchestrationProvider = OrchestrationProvider(storage: storage);
    await orchestrationProvider.init();
    await orchestrationProvider.saveScene(
      ToggleScene(
        id: 'scene-test',
        name: 'Test Scene',
        states: [
          ToggleState(
            toggleId: 'toggle-1',
            stateId: 'on',
            label: 'On',
            commandBundles: [
              CommandBundle(
                id: 'bundle-1',
                label: 'Bundle',
                actions: [
                  CommandAction(
                    controllerId: 'controller-1',
                    type: CommandActionType.channelValue,
                    channel: 1,
                    value: 120,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  });

  Future<void> _pumpManagementScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppStateProvider>.value(value: appState),
          ChangeNotifierProvider<OrchestrationProvider>.value(
            value: orchestrationProvider,
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SavedControllerManagementScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('rename controller updates alias and persists', (tester) async {
    await _pumpManagementScreen(tester);

    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Studio');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Studio'), findsOneWidget);
    expect(appState.savedControllers.first.alias, equals('Studio'));
  });

  testWidgets('remove controller updates list and provider state', (tester) async {
    await _pumpManagementScreen(tester);

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();

    // Confirm removal in dialog.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Workshop'), findsNothing);
    expect(appState.savedControllers.length, equals(1));
  });

  testWidgets('dependencies indicator shows scenes using controller', (tester) async {
    await _pumpManagementScreen(tester);

    expect(find.textContaining('Used in: scene-test'), findsOneWidget);
  });
}
