import 'package:app/models/saved_controller.dart';
import 'package:app/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/saved_controller_fixtures.dart';
import '../test_utils/shared_preferences_stub.dart';

void main() {
  group('SavedController storage', () {
    late StorageService storageService;

    setUp(() async {
      await resetSharedPreferences();
      storageService = StorageService();
      await storageService.init();
    });

    test('persists saved controller with alias', () async {
      final controller = buildSavedControllerFixture(alias: 'Living Room');

      final saved = await storageService.addSavedController(controller);
      final controllers = await storageService.loadSavedControllers();

      expect(controllers, isNotEmpty);
      expect(saved.alias, 'Living Room');
      expect(controllers.first.controllerId, saved.controllerId);
    });

    test('throws when alias duplicates existing saved controller', () async {
      final existing = buildSavedControllerFixture(alias: 'Workshop');
      await storageService.addSavedController(existing);

      final duplicate = buildSavedControllerFixture(
        controllerId: 'controller-dup',
        alias: ' workshop ',
      );

      expect(
        () => storageService.addSavedController(duplicate),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
