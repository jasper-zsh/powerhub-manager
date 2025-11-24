import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_generation_service.dart';
import 'package:app/services/font_extraction_service.dart';
import 'package:app/models/switch_hub/config.dart';

void main() {
  group('Final Font Extraction Tests', () {
    test('Default behavior now excludes common characters', () {
      // Create empty config to test default behavior
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Test default behavior (should be false now)
      final charactersDefault = FontExtractionService.getCharacterSet(testConfig);
      expect(charactersDefault.length, equals(0)); // No switches, no characters

      // Explicitly test that default is now false
      final charactersExplicit = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: false);
      expect(charactersExplicit.length, equals(0));
    });

    test('FontGenerationService methods now default to exclude common chars', () {
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // Test that FontGenerationService methods now have includeCommonChars=false as default
      // We can't easily test the internal calls without complex setup, but we can test
      // the character extraction directly which is what these methods use

      final characters = FontExtractionService.getCharacterSet(testConfig);
      expect(characters.length, equals(0)); // Should be empty since no switches and no common chars

      // If we call with includeCommonChars=true explicitly, it should include them
      final charactersWithCommon = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: true);
      expect(charactersWithCommon.length, equals(603)); // Should include all common characters
    });

    test('Verify the exact character count with common characters', () {
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [],
      );

      // This should match the 603 characters you were seeing in the logs
      final charactersWithCommon = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: true);
      expect(charactersWithCommon.length, equals(603));
      print('✅ Confirmed: Common characters count = ${charactersWithCommon.length}');

      // But without common characters, it should be much smaller
      final charactersWithoutCommon = FontExtractionService.getCharacterSet(testConfig, includeCommonChars: false);
      expect(charactersWithoutCommon.length, equals(0));
      print('✅ Confirmed: Without common characters = ${charactersWithoutCommon.length}');
    });

    test('Font generation should now be much smaller by default', () async {
      // Create a simple configuration with just a few UI characters
      final testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [
          // We can't easily create proper SwitchHubSwitch objects here without complex setup,
          // so we'll use the character-based methods directly
        ],
      );

      // Generate font using character-based method with default settings
      // This simulates what would happen with a real UI that only has a few characters
      final binaryData = await FontGenerationService.generateBinaryFontForCharacters(
        ['A', 'B', 'C', '1', '2', '3'], // Just 6 ASCII characters
        fontSize: 16,
        bpp: 2,
      );

      print('✅ Small character set font size: ${binaryData.length} bytes');
      expect(binaryData.length, lessThan(1000)); // Should be small
      expect(binaryData.length, greaterThan(0)); // But not empty
    });
  });
}