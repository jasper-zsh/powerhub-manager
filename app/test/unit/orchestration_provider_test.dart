import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;
  late OrchestrationProvider provider;
  late ToggleScene scene;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.init();
    scene = ToggleScene(
      id: 'scene-1',
      name: 'Morning Routine',
      states: [
        ToggleState(
          toggleId: 'toggle-main',
          stateId: 'on',
          label: 'On',
          commandBundles: [
            CommandBundle(
              id: 'bundle-on',
              label: 'On bundle',
              actions: [
                CommandAction(
                  controllerId: 'controller-a',
                  type: CommandActionType.channelValue,
                  channel: 1,
                  value: 255,
                ),
              ],
            ),
          ],
        ),
        ToggleState(
          toggleId: 'toggle-main',
          stateId: 'off',
          label: 'Off',
          commandBundles: [
            CommandBundle(
              id: 'bundle-off',
              label: 'Off bundle',
              actions: [
                CommandAction(
                  controllerId: 'controller-a',
                  type: CommandActionType.channelValue,
                  channel: 1,
                  value: 0,
                ),
              ],
            ),
          ],
        ),
      ],
      rules: [
        ConditionalRule(
          id: 'rule-1',
          toggleId: 'toggle-main',
          expectedStateId: 'on',
          trueBundleId: 'bundle-on',
          falseBundleId: 'bundle-off',
        ),
      ],
    );
    await storage.persistToggleScenes([scene]);
    provider = OrchestrationProvider(storage: storage);
    await provider.init();
  });

  test('init loads scenes and execution logs', () {
    expect(provider.isLoading, isFalse);
    expect(provider.scenes.length, 1);
    expect(provider.activeScene?.id, equals('scene-1'));
    expect(provider.executionLogs, isEmpty);
  });

  test('previewScene merges bundles and flags missing references', () async {
    final preview = provider.previewScene(
      'scene-1',
      toggleId: 'toggle-main',
      stateId: 'on',
    );
    expect(preview.actions.length, 1);
    expect(preview.bundleOrder, contains('bundle-on'));
    expect(preview.hasWarnings, isFalse);

    // Introduce rule pointing to missing bundle and verify warning surface.
    final updatedScene = scene.copyWith(
      rules: [
        ...scene.rules,
        ConditionalRule(
          id: 'rule-missing',
          toggleId: 'toggle-main',
          expectedStateId: 'on',
          trueBundleId: 'missing-bundle',
        ),
      ],
    );
    await provider.saveScene(updatedScene);

    final previewWithMissing = provider.previewScene(
      'scene-1',
      toggleId: 'toggle-main',
      stateId: 'on',
    );
    expect(previewWithMissing.missingBundles, contains('missing-bundle'));
    expect(previewWithMissing.hasWarnings, isTrue);
  });

  test('recordExecution appends capped execution logs', () async {
    final preview = provider.previewScene(
      'scene-1',
      toggleId: 'toggle-main',
      stateId: 'on',
    );

    for (var i = 0; i < 105; i++) {
      await provider.recordExecution(
        sceneId: 'scene-1',
        triggerSource: 'toggle-main',
        preview: preview,
      );
    }

    expect(provider.executionLogs.length, lessThanOrEqualTo(100));
    expect(provider.executionLogs.first.sceneId, equals('scene-1'));
  });

  test('controllerDependencies returns scene ids keyed by controller', () {
    final deps = provider.controllerDependencies;
    expect(deps.containsKey('controller-a'), isTrue);
    expect(deps['controller-a'], contains('scene-1'));
  });

  test('renameToggle updates toggle ID and related references', () async {
    // Rename the toggle from 'toggle-main' to 'toggle-renamed'
    final success = await provider.renameToggle('toggle-main', 'toggle-renamed');
    expect(success, isTrue);

    // Verify the scene was updated
    final updatedScene = provider.activeScene!;
    expect(updatedScene.states.every((state) => state.toggleId == 'toggle-renamed'), isTrue);
    
    // Verify state IDs were updated (only if they follow the pattern 'toggleId-stateId')
    final onState = updatedScene.states.firstWhere((state) => state.stateId == 'on');
    final offState = updatedScene.states.firstWhere((state) => state.stateId == 'off');
    expect(onState.toggleId, equals('toggle-renamed'));
    expect(offState.toggleId, equals('toggle-renamed'));

    // Verify rules were updated
    final rule = updatedScene.rules.first;
    expect(rule.toggleId, equals('toggle-renamed'));
    expect(rule.expectedStateId, equals('on'));
  });

  test('renameToggle returns false for duplicate names', () async {
    // Create a scene with multiple toggles
    final multiToggleScene = ToggleScene(
      id: 'scene-multi',
      name: 'Multi Toggle Scene',
      states: [
        ToggleState(toggleId: 'toggle-1', stateId: 'toggle-1-on', label: 'On'),
        ToggleState(toggleId: 'toggle-2', stateId: 'toggle-2-on', label: 'On'),
      ],
      rules: [],
    );
    await provider.saveScene(multiToggleScene);
    provider.selectScene('scene-multi');

    // Try to rename toggle-1 to toggle-2 (should fail)
    final success = await provider.renameToggle('toggle-1', 'toggle-2');
    expect(success, isFalse);
  });

  test('renameToggle returns false for empty names', () async {
    final success = await provider.renameToggle('toggle-main', '');
    expect(success, isFalse);
  });

  test('updateStateLabel updates state label correctly', () async {
    // Update the state label from 'On' to 'Enabled'
    await provider.updateStateLabel('toggle-main', 'on', 'Enabled');
    
    // Verify the label was updated
    final updatedScene = provider.activeScene!;
    final onState = updatedScene.states.firstWhere((state) => state.stateId == 'on');
    expect(onState.label, equals('Enabled'));
  });

  test('updateStateLabel does nothing for empty label', () async {
    final originalLabel = 'On';
    
    // Try to update with empty label
    await provider.updateStateLabel('toggle-main', 'on', '');
    
    // Verify the label remains unchanged
    final updatedScene = provider.activeScene!;
    final onState = updatedScene.states.firstWhere((state) => state.stateId == 'on');
    expect(onState.label, equals(originalLabel));
  });

  test('command action preserves controller ID when editing', () {
    // Create a command action with specific controller ID
    final action = CommandAction(
      controllerId: 'controller-a',
      type: CommandActionType.channelValue,
      channel: 1,
      value: 255,
    );

    // Verify the controller ID is preserved
    expect(action.controllerId, equals('controller-a'));
    expect(action.type, equals(CommandActionType.channelValue));
    expect(action.channel, equals(1));
    expect(action.value, equals(255));
  });

  test('command action with preset trigger preserves controller ID', () {
    // Create a preset trigger action
    final action = CommandAction(
      controllerId: 'controller-b',
      type: CommandActionType.presetTrigger,
      presetId: 5,
    );

    // Verify the controller ID is preserved
    expect(action.controllerId, equals('controller-b'));
    expect(action.type, equals(CommandActionType.presetTrigger));
    expect(action.presetId, equals(5));
  });
}
