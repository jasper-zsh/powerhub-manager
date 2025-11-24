import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_generation_service.dart';

void main() {
  group('Font Size Comparison Tests', () {
    test('Font generation size with minimal characters', () async {
      // Generate binary font for just a few characters
      final binaryData = await FontGenerationService.generateBinaryFontForCharacters(
        ['开', '关', '灯'], // Simple Chinese characters
        fontSize: 16,
        bpp: 2,
      );

      print('Minimal character set binary font size: ${binaryData.length} bytes');
      expect(binaryData.length, greaterThan(0));
      expect(binaryData.length, lessThan(1000)); // Should be relatively small
    });

    test('Font generation size with more characters', () async {
      // Generate binary font for more characters
      final binaryData = await FontGenerationService.generateBinaryFontForCharacters(
        ['客厅灯', '开启', '关闭', '明亮', '昏暗'], // More Chinese text
        fontSize: 16,
        bpp: 2,
      );

      print('Larger character set binary font size: ${binaryData.length} bytes');
      expect(binaryData.length, greaterThan(0));
      expect(binaryData.length, lessThan(5000)); // Should still be reasonable
    });

    test('Compare with ASCII characters', () async {
      // Generate binary font for ASCII characters only
      final binaryData = await FontGenerationService.generateBinaryFontForCharacters(
        ['A', 'B', 'C', '1', '2', '3', 'ON', 'OFF'],
        fontSize: 16,
        bpp: 2,
      );

      print('ASCII character set binary font size: ${binaryData.length} bytes');
      expect(binaryData.length, greaterThan(0));
      expect(binaryData.length, lessThan(1000)); // Should be small
    });
  });
}