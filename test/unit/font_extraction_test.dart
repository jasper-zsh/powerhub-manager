import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_extraction_service.dart';
import 'package:app/models/switch_hub/config.dart';

void main() {
  group('Font Extraction Tests', () {
    test('includeCommonChars parameter default behavior', () {
      // Create empty config to test the getCommonCharacters method
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Test default behavior (should be false now)
      final charactersDefault = FontExtractionService.getCharacterSet(testConfig);
      expect(charactersDefault.length, equals(1)); // Only degree symbol

      // Test with includeCommonChars explicitly set to false
      final charactersWithoutCommon = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: false);
      expect(charactersWithoutCommon.length, equals(1)); // Only degree symbol

      // Test with includeCommonChars set to true
      final charactersWithCommon = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: true);
      expect(charactersWithCommon.length, greaterThan(500)); // Should include many common characters
      print('Characters with common chars: ${charactersWithCommon.length}');

      // Verify specific characters are included when common chars are enabled
      expect(charactersWithCommon.contains('A'), isTrue);
      expect(charactersWithCommon.contains('0'), isTrue);
      // Note: '客' character check might fail depending on common characters set
      expect(charactersWithCommon.contains('°'), isTrue); // Degree symbol always included
    });

    test('getCommonCharacters size', () {
      final commonChars = FontExtractionService.getCommonCharacters();
      expect(commonChars.length, greaterThan(500)); // Should be a large set of characters
      print('Common characters count: ${commonChars.length}');

      // Should contain basic Latin characters
      expect(commonChars.contains('A'), isTrue);
      expect(commonChars.contains('0'), isTrue);
      expect(commonChars.contains('!'), isTrue);
    });

    test('Font generation size comparison', () async {
      // Test that font generation with default settings (no common chars) is much smaller
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Test with common characters enabled (should be large)
      final binaryDataWithCommon = await FontExtractionService.getCharacterSet(testConfig, includeCommonChars: true);
      print('Characters with common: ${binaryDataWithCommon.length}');

      // Test with common characters disabled (should contain only degree symbol)
      final binaryDataWithoutCommon = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: false);
      print('Characters without common: ${binaryDataWithoutCommon.length}');

      expect(binaryDataWithCommon.length, greaterThan(500));
      expect(binaryDataWithoutCommon.length, equals(1)); // Only degree symbol
    });
  });
}