import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/orchestration/toggle_scene.dart';
import 'package:app/providers/orchestration_provider.dart';
import 'package:app/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Orchestration integration flow', () {
    late StorageService storage;
    late OrchestrationProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = StorageService();
      await storage.init();

      final scene = ToggleScene(
        id: 'scene-multi',
        name: 'Multi Controller Scene',
        states: [
          ToggleState(
            toggleId: 'toggle-main',
            stateId: 'on',
            label: 'On',
            commandBundles: [
              CommandBundle(
                id: 'bundle-switch-on',
                label: 'Switch On',
                actions: [
                  CommandAction(
                    controllerId: 'controller-a',
                    type: CommandActionType.channelValue,
                    channel: 1,
                    value: 200,
                  ),
                  CommandAction(
                    controllerId: 'controller-b',
                    type: CommandActionType.presetTrigger,
                    presetId: 4,
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
                id: 'bundle-switch-off',
                label: 'Switch Off',
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
            id: 'rule-balanced',
            toggleId: 'toggle-main',
            expectedStateId: 'off',
            trueBundleId: 'bundle-switch-off',
            falseBundleId: 'bundle-switch-on',
          ),
        ],
      );

      await storage.persistToggleScenes([scene]);
      provider = OrchestrationProvider(storage: storage);
      await provider.init();
    });

    test('preview returns correct bundles for alternate state', () {
      final offPreview = provider.previewScene(
        'scene-multi',
        toggleId: 'toggle-main',
        stateId: 'off',
      );

      expect(offPreview.bundleOrder.first, equals('bundle-switch-off'));
      expect(offPreview.actions.single.value, equals(0));

      final onPreview = provider.previewScene(
        'scene-multi',
        toggleId: 'toggle-main',
        stateId: 'on',
      );

      expect(onPreview.bundleOrder, contains('bundle-switch-on'));
      expect(onPreview.actions.length, 2);
      expect(
        onPreview.actions.where((action) => action.controllerId == 'controller-b').length,
        equals(1),
      );
    });

    test('recordExecution stores logs and respects controller dependencies', () async {
      final preview = provider.previewScene(
        'scene-multi',
        toggleId: 'toggle-main',
        stateId: 'on',
      );

      await provider.recordExecution(
        sceneId: 'scene-multi',
        triggerSource: 'toggle-main',
        preview: preview,
      );

      expect(provider.executionLogs.length, 1);
      final log = provider.executionLogs.first;
      expect(log.executedBundleIds, contains('bundle-switch-on'));

      final dependencies = provider.controllerDependencies;
      expect(dependencies['controller-a'], contains('scene-multi'));
      expect(dependencies['controller-b'], contains('scene-multi'));
    });
  });
}
