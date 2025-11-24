import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/font_extraction_service.dart';
import '../../lib/services/font_converter/simple_ttf_parser.dart';

void main() {
  group('Simple Font Tests', () {
    test('extract common characters', () {
      final commonChars = FontExtractionService.getCommonCharacters();

      // Should contain basic Latin characters
      expect(commonChars.contains('A'), isTrue);
      expect(commonChars.contains('B'), isTrue);
      expect(commonChars.contains('C'), isTrue);
      expect(commonChars.contains('0'), isTrue);
      expect(commonChars.contains('1'), isTrue);
      expect(commonChars.contains('2'), isTrue);

      // Should contain common Chinese characters
      expect(commonChars.contains('的'), isTrue);
      expect(commonChars.contains('是'), isTrue);
      expect(commonChars.contains('在'), isTrue);

      print('Common characters count: ${commonChars.length}');
    });

    test('generate font data for specific characters', () async {
      final characters = ['A', 'B', 'C', '你', '好', '世', '界'];

      final fontData = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        characters,
        fontSize: 16,
        bpp: 2,
      );

      expect(fontData.glyphs.length, equals(7));
      expect(fontData.size, equals(16));

      // Check that we have glyphs for all requested characters
      final charCodes = fontData.glyphs.map((g) => g.code).toSet();
      for (final char in characters) {
        expect(
          charCodes.contains(char.codeUnitAt(0)),
          isTrue,
          reason: 'Missing glyph for character: $char',
        );
      }

      print('Generated font for ${characters.length} specific characters');
      print('Font size: ${fontData.size}px');
      print('Glyph count: ${fontData.glyphs.length}');
    });

    test('generate minimal font for single character', () async {
      final fontData = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        ['测'],
        fontSize: 20,
        bpp: 4,
      );

      expect(fontData.glyphs.length, equals(1));
      expect(fontData.glyphs[0].code, equals('测'.codeUnitAt(0)));
      expect(fontData.size, equals(20));

      print('Generated minimal font for single character');
      print('Character code: 0x${fontData.glyphs[0].code.toRadixString(16)}');
    });

    test('font caching mechanism', () async {
      final characters = ['A', 'B', 'C'];

      // First generation
      final startTime1 = DateTime.now();
      final fontData1 = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        characters,
        fontSize: 16,
        bpp: 2,
      );
      final endTime1 = DateTime.now();
      final duration1 = endTime1.difference(startTime1);

      // Second generation (should use cache)
      final startTime2 = DateTime.now();
      final fontData2 = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        characters,
        fontSize: 16,
        bpp: 2,
      );
      final endTime2 = DateTime.now();
      final duration2 = endTime2.difference(startTime2);

      // Verify both results are same
      expect(fontData1.glyphs.length, equals(fontData2.glyphs.length));
      expect(fontData1.size, equals(fontData2.size));

      // Second generation should be faster (from cache)
      expect(duration2.inMilliseconds, lessThan(duration1.inMilliseconds));

      print('First generation: ${duration1.inMilliseconds}ms');
      print('Second generation (cached): ${duration2.inMilliseconds}ms');
      print(
        'Speedup: ${(duration1.inMilliseconds / duration2.inMilliseconds).toStringAsFixed(2)}x',
      );
    });

    test('font compression effectiveness', () async {
      final characters = ['A', 'B', 'C', 'D', 'E', 'F'];

      // Generate font with compression
      final compressedData = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        characters,
        fontSize: 16,
        bpp: 4,
      );

      // Generate font without compression
      final uncompressedData = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        characters,
        fontSize: 16,
        bpp: 4,
      );

      // Compressed data should be smaller
      expect(compressedData.length, lessThan(uncompressedData.length));

      final compressionRatio = compressedData.length / uncompressedData.length;
      final spaceSaved = (1 - compressionRatio) * 100;

      print('Compressed size: ${compressedData.length} bytes');
      print('Uncompressed size: ${uncompressedData.length} bytes');
      print(
        'Compression ratio: ${(compressionRatio * 100).toStringAsFixed(2)}%',
      );
      print('Space saved: ${spaceSaved.toStringAsFixed(2)}%');

      // Should save at least 5% space
      expect(spaceSaved, greaterThan(5));
    });

    test('performance with Chinese characters', () async {
      final chineseChars = ['你', '好', '世', '界', '中', '国', '文', '字'];

      final startTime = DateTime.now();
      final fontData = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        chineseChars,
        fontSize: 16,
        bpp: 2,
      );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      expect(fontData.glyphs.length, equals(8));

      print(
        'Generated font for 8 Chinese characters in ${duration.inMilliseconds}ms',
      );
      print('Average time per character: ${duration.inMilliseconds / 8}ms');
      print('Total font size: ${fontData.glyphs.length} glyphs');
    });

    test('performance with mixed characters', () async {
      final mixedChars = ['A', 'B', 'C', '你', '好', '1', '2', '3'];

      final startTime = DateTime.now();
      final fontData = await SimpleTtfParser.parseTtfFile(
        'assets/NotoSansSC-Regular.ttf',
        mixedChars,
        fontSize: 14,
        bpp: 2,
      );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      expect(fontData.glyphs.length, equals(8));

      print(
        'Generated font for 8 mixed characters in ${duration.inMilliseconds}ms',
      );
      print('Average time per character: ${duration.inMilliseconds / 8}ms');

      // Verify we have both Latin and Chinese characters
      final charCodes = fontData.glyphs.map((g) => g.code).toSet();
      expect(charCodes.contains('A'.codeUnitAt(0)), isTrue);
      expect(charCodes.contains('你'.codeUnitAt(0)), isTrue);
      expect(charCodes.contains('1'.codeUnitAt(0)), isTrue);
    });
  });
}
