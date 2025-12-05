import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_extraction_service.dart';
import 'package:app/models/switch_hub/config.dart';

void main() {
  group('Degree Celsius Font Test', () {
    test('Degree symbol should be included in extracted characters', () {
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Test that degree symbol is always included in extraction
      final extractedChars = FontExtractionService.extractUniqueCharacters(testConfig);
      expect(extractedChars.contains('°'), isTrue,
             reason: 'Degree symbol (°) should always be included in character extraction');

      // Verify letter C is included (should already be there from Latin alphabet)
      final commonChars = FontExtractionService.getCommonCharacters();
      expect(commonChars.contains('C'), isTrue,
             reason: 'Letter C should be included for Celsius display');

      print('✅ Degree symbol (°) included in extraction: ${extractedChars.contains('°')}');
      print('✅ Letter C included in common characters: ${commonChars.contains('C')}');
      print('✅ Total extracted characters: ${extractedChars.length}');
    });

    test('Temperature string should be extractable', () {
      // Test that we can extract temperature-related text
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Get characters - degree symbol is always included, letter C is in common chars
      final characters = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: true);

      // Verify temperature string characters are all available
      final temperatureString = '25°C';
      final tempChars = temperatureString.split('');

      for (final char in tempChars) {
        expect(characters.contains(char), isTrue,
               reason: 'Character "$char" from "$temperatureString" should be available');
      }

      print('✅ All temperature string characters are available: $temperatureString');
    });
  });
}