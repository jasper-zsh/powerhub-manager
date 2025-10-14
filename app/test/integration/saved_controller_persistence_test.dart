import 'package:app/providers/app_state_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_utils/shared_preferences_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Saved controller persistence', () {
    setUp(() async {
      await resetSharedPreferences();
    });

    test('saved controllers reload after provider reinitialization', () async {
      final provider = AppStateProvider();
      await provider.init();

      await provider.saveController(
        controllerId: 'controller-001',
        alias: 'Living Room',
      );

      expect(provider.savedControllers.length, 1);
      expect(provider.savedControllers.first.alias, 'Living Room');

      final reloadProvider = AppStateProvider();
      await reloadProvider.init();

      expect(reloadProvider.savedControllers.length, 1);
      expect(reloadProvider.savedControllers.first.alias, 'Living Room');
    });
  });
}
