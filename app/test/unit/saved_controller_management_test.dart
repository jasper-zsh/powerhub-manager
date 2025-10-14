import 'package:app/providers/app_state_provider.dart';
import 'package:app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/shared_preferences_stub.dart';

void main() {
  group('Saved controller management', () {
    late StorageService storageService;
    late AppStateProvider provider;

    setUp(() async {
      await resetSharedPreferences();
      storageService = StorageService();
      await storageService.init();
      provider = AppStateProvider(storageService: storageService);
      await provider.init();
    });

    test('rename updates alias and persists across reload', () async {
      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );

      final renamed = await provider.renameSavedController(
        'controller-001',
        'Studio',
      );

      expect(renamed.alias, 'Studio');
      expect(provider.savedControllers.first.alias, 'Studio');

      final reloadProvider = AppStateProvider(storageService: storageService);
      await reloadProvider.init();

      expect(reloadProvider.savedControllers.first.alias, 'Studio');
    });

    test('remove deletes controller and cancels reconnection tracking', () async {
      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );
      await provider.saveController(
        controllerId: 'controller-002',
        alias: 'Workshop',
      );

      expect(provider.savedControllers.length, 2);
      expect(provider.connectionStatusRecords.length, 2);

      await provider.removeSavedController('controller-001');

      expect(
        provider.savedControllers.any(
          (controller) => controller.controllerId == 'controller-001',
        ),
        isFalse,
      );
      expect(
        provider.connectionStatusRecords.any(
          (record) => record.controller.controllerId == 'controller-001',
        ),
        isFalse,
      );

      final reloadProvider = AppStateProvider(storageService: storageService);
      await reloadProvider.init();

      expect(
        reloadProvider.savedControllers.any(
          (controller) => controller.controllerId == 'controller-001',
        ),
        isFalse,
      );
    });
  });
}
