import 'package:app/providers/app_state_provider.dart';
import 'package:app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/shared_preferences_stub.dart';

void main() {
  group('Saved controller management integration', () {
    late StorageService storageService;
    late AppStateProvider provider;

    setUp(() async {
      await resetSharedPreferences();
      storageService = StorageService();
      await storageService.init();
      provider = AppStateProvider(storageService: storageService);
      await provider.init();
    });

    test('rename propagates to connection records', () async {
      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );

      await provider.renameSavedController('controller-001', 'Studio');

      expect(provider.connectionStatusRecords.first.controller.alias, 'Studio');

      final reloadProvider = AppStateProvider(storageService: storageService);
      await reloadProvider.init();

      expect(
        reloadProvider.connectionStatusRecords.first.controller.alias,
        'Studio',
      );
    });

    test('remove updates saved list and connection records immediately', () async {
      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );
      await provider.saveController(
        controllerId: 'controller-002',
        alias: 'Workshop',
      );

      await provider.removeSavedController('controller-002');

      expect(provider.savedControllers.length, 1);
      expect(provider.connectionStatusRecords.length, 1);
      expect(
        provider.savedControllers.first.controllerId,
        'controller-001',
      );
    });
  });
}
