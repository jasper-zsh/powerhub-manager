import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/font_generation_service.dart';
import '../../lib/services/font_extraction_service.dart';
import '../../lib/services/font_converter/font_converter_service.dart';
import '../../lib/services/font_converter/ttf_parser.dart';
import '../../lib/services/font_converter/models/font_data.dart';
import '../../lib/services/font_converter/models/font_options.dart';
import '../../lib/services/font_converter/models/font_glyph.dart';
import '../../lib/models/switch_hub/config.dart';
import '../../lib/models/switch_hub/switch_definition.dart';
import '../../lib/models/switch_hub/ui_config.dart';
import '../../lib/models/switch_hub/logic_node.dart';

void main() {
  group('Optimized Font Loading Tests', () {
    late SwitchHubConfig testConfig;

    setUp(() {
      // Create a test configuration with various characters
      testConfig = SwitchHubConfig(
        schemaVersion: 1,
        switches: [
          SwitchHubSwitch(
            switchId: 1,
            revision: 0,
            onLogic: SwitchHubLeafNode(sequence: []),
            offLogic: SwitchHubLeafNode(sequence: []),
            uiConfig: SwitchHubUiConfig(
              channelLabel: '通道1',
              onLabel: '开启',
              offLabel: '关闭',
              statusSlots: [],
            ),
          ),
          SwitchHubSwitch(
            switchId: 2,
            revision: 0,
            onLogic: SwitchHubLeafNode(sequence: []),
            offLogic: SwitchHubLeafNode(sequence: []),
            uiConfig: SwitchHubUiConfig(
              channelLabel: 'Channel2',
              onLabel: 'ON',
              offLabel: 'OFF',
              statusSlots: [],
            ),
          ),
        ],
      );
    });

    tearDown(() {
      // Clear caches after each test
      FontGenerationService.clearCache();
      TtfParser.clearCache();
    });

    test('extract unique characters from configuration', () {
      final characters = FontExtractionService.extractUniqueCharacters(
        testConfig,
      );

      // Should contain Chinese and Latin characters
      expect(characters.contains('测'), isTrue);
      expect(characters.contains('试'), isTrue);
      expect(characters.contains('通'), isTrue);
      expect(characters.contains('道'), isTrue);
      expect(characters.contains('开'), isTrue);
      expect(characters.contains('关'), isTrue);
      expect(characters.contains('C'), isTrue);
      expect(characters.contains('h'), isTrue);
      expect(characters.contains('a'), isTrue);
      expect(characters.contains('n'), isTrue);
      expect(characters.contains('e'), isTrue);
      expect(characters.contains('l'), isTrue);
      expect(characters.contains('O'), isTrue);
      expect(characters.contains('N'), isTrue);
      expect(characters.contains('F'), isTrue);

      print('Extracted characters: ${characters.length} unique chars');
      print('Characters: ${characters.toList()..sort()}');
    });

    test('get character set with common characters', () {
      final characterSet = FontExtractionService.getCharacterSet(testConfig);

      // Should contain both extracted and common characters
      expect(characterSet.length, greaterThan(20));
      expect(characterSet.contains('0'), isTrue);
      expect(characterSet.contains('1'), isTrue);
      expect(characterSet.contains('2'), isTrue);
      expect(characterSet.contains('A'), isTrue);
      expect(characterSet.contains('B'), isTrue);
      expect(characterSet.contains('a'), isTrue);
      expect(characterSet.contains('b'), isTrue);

      print('Total character set size: ${characterSet.length}');
    });

    test('generate font data for configuration', () async {
      final fontData = await FontGenerationService.generateFontData(
        testConfig,
        fontSize: 16,
        bpp: 2,
        includeCommonChars: true,
      );

      expect(fontData.glyphs.isNotEmpty, isTrue);
      expect(fontData.size, equals(16));
      expect(fontData.glyphs.length, greaterThan(10));

      // Check that we have glyphs for our test characters
      final charCodes = fontData.glyphs.map((g) => g.code).toSet();
      expect(charCodes.contains('测'.codeUnitAt(0)), isTrue);
      expect(charCodes.contains('试'.codeUnitAt(0)), isTrue);
      expect(charCodes.contains('C'.codeUnitAt(0)), isTrue);
      expect(charCodes.contains('h'.codeUnitAt(0)), isTrue);

      print('Generated font with ${fontData.glyphs.length} glyphs');
      print('Font ascent: ${fontData.ascent}, descent: ${fontData.descent}');
    });

    test('generate binary font for configuration', () async {
      final binaryData = await FontGenerationService.generateBinaryFont(
        testConfig,
        fontSize: 16,
        bpp: 2,
        includeCommonChars: true,
        noCompress: false,
        noKerning: true,
      );

      expect(binaryData.isNotEmpty, isTrue);
      expect(binaryData.length, greaterThan(100));

      print('Generated binary font: ${binaryData.length} bytes');
    });

    test('generate font data for specific characters', () async {
      final characters = ['A', 'B', 'C', '你', '好', '世', '界'];

      final fontData =
          await FontGenerationService.generateFontDataForCharacters(
            characters,
            fontSize: 14,
            bpp: 4,
          );

      expect(fontData.glyphs.length, equals(7));
      expect(fontData.size, equals(14));

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
    });

    test('generate minimal font for single character', () async {
      final fontData = await FontGenerationService.generateMinimalFontData(
        '测',
        fontSize: 20,
        bpp: 4,
      );

      expect(fontData.glyphs.length, equals(1));
      expect(fontData.glyphs[0].code, equals('测'.codeUnitAt(0)));
      expect(fontData.size, equals(20));

      print('Generated minimal font for single character');
    });

    test('font caching mechanism', () async {
      // First generation
      final startTime1 = DateTime.now();
      final fontData1 = await FontGenerationService.generateFontData(
        testConfig,
        fontSize: 16,
        bpp: 2,
        includeCommonChars: true,
      );
      final endTime1 = DateTime.now();
      final duration1 = endTime1.difference(startTime1);

      // Second generation (should use cache)
      final startTime2 = DateTime.now();
      final fontData2 = await FontGenerationService.generateFontData(
        testConfig,
        fontSize: 16,
        bpp: 2,
        includeCommonChars: true,
      );
      final endTime2 = DateTime.now();
      final duration2 = endTime2.difference(startTime2);

      // Verify both results are the same
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

    test('binary font caching mechanism', () async {
      // First generation
      final startTime1 = DateTime.now();
      final binaryData1 = await FontGenerationService.generateBinaryFont(
        testConfig,
        fontSize: 16,
        bpp: 2,
        includeCommonChars: true,
        noCompress: false,
        noKerning: true,
      );
      final endTime1 = DateTime.now();
      final duration1 = endTime1.difference(startTime1);

      // Second generation (should use cache)
      final startTime2 = DateTime.now();
      final binaryData2 = await FontGenerationService.generateBinaryFont(
        testConfig,
        fontSize: 16,
        bpp: 2,
        includeCommonChars: true,
        noCompress: false,
        noKerning: true,
      );
      final endTime2 = DateTime.now();
      final duration2 = endTime2.difference(startTime2);

      // Verify both results are the same
      expect(binaryData1.length, equals(binaryData2.length));

      // Second generation should be faster (from cache)
      expect(duration2.inMilliseconds, lessThan(duration1.inMilliseconds));

      print('First binary generation: ${duration1.inMilliseconds}ms');
      print('Second binary generation (cached): ${duration2.inMilliseconds}ms');
      print('Binary font size: ${binaryData1.length} bytes');
    });

    test('font compression effectiveness', () async {
      // Generate font with compression
      final compressedData = await FontGenerationService.generateBinaryFont(
        testConfig,
        fontSize: 16,
        bpp: 4,
        includeCommonChars: true,
        noCompress: false,
        noKerning: true,
      );

      // Generate font without compression
      final uncompressedData = await FontGenerationService.generateBinaryFont(
        testConfig,
        fontSize: 16,
        bpp: 4,
        includeCommonChars: true,
        noCompress: true,
        noKerning: true,
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

      // Should save at least 10% space
      expect(spaceSaved, greaterThan(10));
    });

    test('font size comparison with different bpp values', () async {
      final bppValues = [1, 2, 4, 8];
      final results = <int, Map<String, dynamic>>{};

      for (final bpp in bppValues) {
        final fontInfo = await FontGenerationService.getFontInfo(
          testConfig,
          fontSize: 16,
          bpp: bpp,
          includeCommonChars: true,
        );

        results[bpp] = fontInfo;
        print(
          'BPP $bpp: ${fontInfo['binarySize']} bytes, ${fontInfo['characterCount']} chars',
        );
      }

      // Higher bpp should result in larger files
      expect(results[1]!['binarySize'], lessThan(results[2]!['binarySize']));
      expect(results[2]!['binarySize'], lessThan(results[4]!['binarySize']));
      expect(results[4]!['binarySize'], lessThan(results[8]!['binarySize']));

      // All should have the same number of characters
      for (int i = 1; i < bppValues.length; i++) {
        expect(
          results[bppValues[i - 1]]!['characterCount'],
          equals(results[bppValues[i]]!['characterCount']),
        );
      }
    });

    test('cache statistics', () {
      final stats = FontGenerationService.getCacheStats();

      expect(stats.containsKey('fontDataCacheSize'), isTrue);
      expect(stats.containsKey('binaryFontCacheSize'), isTrue);
      expect(stats.containsKey('maxCacheSize'), isTrue);

      print('Font data cache size: ${stats['fontDataCacheSize']}');
      print('Binary font cache size: ${stats['binaryFontCacheSize']}');
      print('Max cache size: ${stats['maxCacheSize']}');
    });

    test('performance comparison with large character set', () async {
      // Create a large character set
      final largeCharSet = List.generate(
        100,
        (i) => String.fromCharCode(0x4E00 + i),
      ); // Chinese characters

      final startTime = DateTime.now();
      final fontData =
          await FontGenerationService.generateFontDataForCharacters(
            largeCharSet,
            fontSize: 16,
            bpp: 2,
          );
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      expect(fontData.glyphs.length, equals(100));

      print(
        'Generated font for 100 Chinese characters in ${duration.inMilliseconds}ms',
      );
      print('Average time per character: ${duration.inMilliseconds / 100}ms');
      print('Total font size: ${fontData.glyphs.length} glyphs');
    });
  });
}
