import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../lib/services/font_converter/models/font_data.dart';
import '../../lib/services/font_converter/models/font_options.dart';
import '../../lib/services/font_converter/models/font_glyph.dart';
import '../../lib/services/font_converter/font_converter_service.dart';
import '../../lib/services/font_converter/ttf_parser.dart';

void main() {
  group('FontConverterService', () {
    test('createBasicGlyph creates glyph with correct properties', () {
      final pixels = [
        [0, 1, 1, 0],
        [1, 1, 1, 1],
        [0, 1, 1, 0],
      ];

      final glyph = FontConverterService.createBasicGlyph(
        code: 0x41, // 'A'
        pixels: pixels,
        advanceWidth: 4.0,
        x: 1,
        y: 3,
      );

      expect(glyph.code, equals(0x41));
      expect(glyph.advanceWidth, equals(4.0));
      expect(glyph.bbox.x, equals(1));
      expect(glyph.bbox.y, equals(0)); // y - height = 3 - 3 = 0
      expect(glyph.bbox.width, equals(4));
      expect(glyph.bbox.height, equals(3));
      expect(glyph.pixels, equals(pixels));
    });

    test('createBasicFontData creates font with correct properties', () {
      final glyphs = [
        FontConverterService.createBasicGlyph(
          code: 0x41, // 'A'
          pixels: [
            [0, 1, 1, 0],
            [1, 1, 1, 1],
            [0, 1, 1, 0],
          ],
          advanceWidth: 4.0,
        ),
      ];

      final fontData = FontConverterService.createBasicFontData(
        size: 16,
        glyphs: glyphs,
        ascent: 12,
        descent: -2,
        typoAscent: 10,
        typoDescent: -3,
        typoLineGap: 2,
        underlinePosition: -1,
        underlineThickness: 1,
      );

      expect(fontData.size, equals(16));
      expect(fontData.glyphs.length, equals(1));
      expect(fontData.ascent, equals(12));
      expect(fontData.descent, equals(-2));
      expect(fontData.typoAscent, equals(10));
      expect(fontData.typoDescent, equals(-3));
      expect(fontData.typoLineGap, equals(2));
      expect(fontData.underlinePosition, equals(-1));
      expect(fontData.underlineThickness, equals(1));
    });

    test('createOptions creates font options with correct properties', () {
      final options = FontConverterService.createOptions(
        bpp: 4,
        size: 16,
        noCompress: true,
        noKerning: true,
      );

      expect(options.bpp, equals(4));
      expect(options.size, equals(16));
      expect(options.noCompress, isTrue);
      expect(options.noKerning, isTrue);
      expect(options.lcd, isFalse);
      expect(options.lcdV, isFalse);
      expect(options.useColorInfo, isFalse);
      expect(options.noPrefilter, isFalse);
      expect(options.byteAlign, isFalse);
      expect(options.stride, equals(0));
      expect(options.align, equals(1));
    });

    test('convertToBinary returns non-empty data for simple font', () {
      final glyphs = [
        FontConverterService.createBasicGlyph(
          code: 0x41, // 'A'
          pixels: [
            [0, 1, 1, 0],
            [1, 1, 1, 1],
            [0, 1, 1, 0],
          ],
          advanceWidth: 4.0,
        ),
      ];

      final fontData = FontConverterService.createBasicFontData(
        size: 16,
        glyphs: glyphs,
      );

      final options = FontConverterService.createOptions(
        bpp: 2,
        size: 16,
        noCompress: true,
        noKerning: true,
      );

      final binaryData = FontConverterService.convertToBinary(
        fontData,
        options,
      );

      expect(binaryData.isNotEmpty, isTrue);
      expect(
        binaryData.length,
        greaterThan(100),
      ); // Should have reasonable size
    });

    test('empty glyph handling', () {
      final emptyGlyph = FontConverterService.createBasicGlyph(
        code: 0x20, // Space
        pixels: [], // Empty pixel data
        advanceWidth: 4.0,
        x: 0,
        y: 0,
      );

      expect(emptyGlyph.code, equals(0x20));
      expect(emptyGlyph.advanceWidth, equals(4.0));
      expect(emptyGlyph.bbox.x, equals(0));
      expect(emptyGlyph.bbox.y, equals(0));
      expect(emptyGlyph.bbox.width, equals(0));
      expect(emptyGlyph.bbox.height, equals(0));
      expect(emptyGlyph.pixels.isEmpty, isTrue);
    });

    test('font with multiple glyphs', () {
      final glyphs = [
        FontConverterService.createBasicGlyph(
          code: 0x41, // 'A'
          pixels: [
            [0, 1, 1, 0],
            [1, 1, 1, 1],
            [0, 1, 1, 0],
          ],
          advanceWidth: 4.0,
        ),
        FontConverterService.createBasicGlyph(
          code: 0x42, // 'B'
          pixels: [
            [1, 1, 1, 0],
            [1, 1, 1, 1],
            [1, 1, 1, 0],
          ],
          advanceWidth: 4.0,
        ),
      ];

      final fontData = FontConverterService.createBasicFontData(
        size: 16,
        glyphs: glyphs,
      );

      expect(fontData.glyphs.length, equals(2));
      expect(fontData.glyphs[0].code, equals(0x41));
      expect(fontData.glyphs[1].code, equals(0x42));
    });

    test('font options with different bpp values', () {
      for (final bpp in [1, 2, 3, 4, 8]) {
        final options = FontConverterService.createOptions(bpp: bpp, size: 16);

        expect(options.bpp, equals(bpp));
      }
    });

    test('create Chinese font with common characters', () {
      // Create simplified Chinese glyphs for common characters
      final glyphs = [
        // 你 (nǐ) - simplified 8x8 bitmap
        FontConverterService.createBasicGlyph(
          code: 0x4F60, // Unicode for '你'
          pixels: [
            [0, 1, 1, 1, 1, 1, 0, 0],
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 1, 1, 1, 1, 1, 0, 0],
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 1, 1, 1, 1, 1, 0, 0],
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
          ],
          advanceWidth: 8.0,
          x: 0,
          y: 8,
        ),
        // 好 (hǎo) - simplified 8x8 bitmap
        FontConverterService.createBasicGlyph(
          code: 0x597D, // Unicode for '好'
          pixels: [
            [1, 1, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [1, 1, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [1, 1, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [1, 1, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
          ],
          advanceWidth: 8.0,
          x: 0,
          y: 8,
        ),
        // 世 (shì) - simplified 8x8 bitmap
        FontConverterService.createBasicGlyph(
          code: 0x4E16, // Unicode for '世'
          pixels: [
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
            [0, 0, 1, 1, 1, 1, 0, 0],
          ],
          advanceWidth: 8.0,
          x: 0,
          y: 8,
        ),
        // 界 (jiè) - simplified 8x8 bitmap
        FontConverterService.createBasicGlyph(
          code: 0x754C, // Unicode for '界'
          pixels: [
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [0, 1, 1, 1, 1, 0, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [1, 1, 1, 1, 1, 1, 1, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
            [0, 1, 1, 1, 1, 0, 0, 0],
            [0, 0, 1, 1, 0, 0, 0, 0],
          ],
          advanceWidth: 8.0,
          x: 0,
          y: 8,
        ),
      ];

      // Create font data with Chinese characters
      final fontData = FontConverterService.createBasicFontData(
        size: 16,
        glyphs: glyphs,
        ascent: 8,
        descent: 0,
        typoAscent: 8,
        typoDescent: 0,
        typoLineGap: 2,
        underlinePosition: -1,
        underlineThickness: 1,
      );

      // Create options optimized for Chinese characters
      final options = FontConverterService.createOptions(
        bpp: 4, // Higher bpp for better Chinese character rendering
        size: 16,
        noCompress: false, // Enable compression for efficiency
        noKerning: true, // Chinese typically doesn't use kerning
      );

      // Convert to binary format
      final binaryData = FontConverterService.convertToBinary(
        fontData,
        options,
      );

      // Verify the Chinese font was created successfully
      expect(binaryData.isNotEmpty, isTrue);
      expect(
        binaryData.length,
        greaterThan(200),
      ); // Should be larger for Chinese characters
      expect(
        fontData.glyphs.length,
        equals(4),
      ); // Should have 4 Chinese characters

      // Verify specific Chinese character codes
      expect(fontData.glyphs[0].code, equals(0x4F60)); // 你
      expect(fontData.glyphs[1].code, equals(0x597D)); // 好
      expect(fontData.glyphs[2].code, equals(0x4E16)); // 世
      expect(fontData.glyphs[3].code, equals(0x754C)); // 界
    });

    test('parse TTF file and generate Chinese font library', () async {
      // Define Chinese characters to extract from TTF
      final chineseCharacters = ['你', '好', '世', '界', '中', '国', '文', '字'];

      // Load the actual TTF file from assets
      final ttfPath = 'assets/NotoSansSC-Regular.ttf';
      final fontData = await TtfParser.parseTtfFile(
        ttfPath,
        chineseCharacters,
        size: 16,
        bpp: 4,
      );

      // Verify font data was created correctly
      expect(fontData.glyphs.length, equals(chineseCharacters.length));
      expect(fontData.size, equals(16));

      // Verify each character has a corresponding glyph
      for (int i = 0; i < chineseCharacters.length; i++) {
        final charCode = chineseCharacters[i].codeUnitAt(0);
        expect(fontData.glyphs[i].code, equals(charCode));
        expect(fontData.glyphs[i].pixels.isNotEmpty, isTrue);
        expect(fontData.glyphs[i].advanceWidth, greaterThan(0));
      }

      // Create options optimized for Chinese characters
      final options = FontConverterService.createOptions(
        bpp: 4, // Higher bpp for better Chinese character rendering
        size: 16,
        noCompress: false, // Enable compression for efficiency
        noKerning: true, // Chinese typically doesn't use kerning
      );

      // Convert to binary format
      final binaryData = FontConverterService.convertToBinary(
        fontData,
        options,
      );

      // Verify Chinese font was created successfully
      expect(binaryData.isNotEmpty, isTrue);
      expect(
        binaryData.length,
        greaterThan(300),
      ); // Should be larger for more characters
    });

    test('parse TTF file with mixed characters', () async {
      // Define a mix of Latin and Chinese characters
      final mixedCharacters = ['A', 'B', 'C', '你', '好', '1', '2', '3'];

      // Load the actual TTF file from assets
      final ttfPath = 'assets/NotoSansSC-Regular.ttf';
      final fontData = await TtfParser.parseTtfFile(
        ttfPath,
        mixedCharacters,
        size: 14,
        bpp: 2,
      );

      // Verify font data was created correctly
      expect(fontData.glyphs.length, equals(mixedCharacters.length));
      expect(fontData.size, equals(14));

      // Verify each character has a corresponding glyph
      for (int i = 0; i < mixedCharacters.length; i++) {
        final charCode = mixedCharacters[i].codeUnitAt(0);
        expect(fontData.glyphs[i].code, equals(charCode));
        expect(fontData.glyphs[i].pixels.isNotEmpty, isTrue);
      }

      // Create options
      final options = FontConverterService.createOptions(
        bpp: 2,
        size: 14,
        noCompress: true, // No compression for this test
        noKerning: true,
      );

      // Convert to binary format
      final binaryData = FontConverterService.convertToBinary(
        fontData,
        options,
      );

      // Verify mixed font was created successfully
      expect(binaryData.isNotEmpty, isTrue);
      expect(binaryData.length, greaterThan(200));
    });
  });
}
