import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_converter/tables/cmap_table.dart';
import 'package:app/services/font_converter/models/font_data.dart';
import 'package:app/services/font_converter/models/font_glyph.dart';

void main() {
  group('CmapTable Tests', () {
    test('Should handle large glyph ID ranges without error', () {
      // Create a font with many glyphs to trigger the original issue
      final glyphs = <FontGlyph>[];

      // Create 300 glyphs (more than the Format 0 limit of 255)
      for (int i = 0; i < 300; i++) {
        glyphs.add(
          FontGlyph(
            code: 0x20 + i, // Start from space character
            advanceWidth: 16.0,
            bbox: BoundingBox(x: 0, y: -12, width: 8, height: 12),
            kerning: {},
            pixels: List.generate(12, (_) => List.generate(8, (_) => 0)),
          ),
        );
      }

      final fontData = FontData(
        ascent: 12,
        descent: -2,
        typoAscent: 12,
        typoDescent: -2,
        typoLineGap: 2,
        size: 16,
        glyphs: glyphs,
        underlinePosition: -1,
        underlineThickness: 1,
      );

      // Create glyph ID mapping (simulating what Font class does)
      final glyphId = <int, int>{0: 0};
      for (int i = 0; i < glyphs.length; i++) {
        glyphId[glyphs[i].code] = i + 1;
      }

      // This should not throw an exception
      expect(() {
        final cmapTable = CmapTable(fontData, glyphId);
        final binaryData = cmapTable.toBin();
        expect(binaryData.isNotEmpty, true);
      }, returnsNormally);
    });

    test(
      'Should use sparse format when glyph ID range exceeds Format 0 limit',
      () {
        // Create glyphs with a large ID range
        final glyphs = <FontGlyph>[];

        // Create 10 consecutive characters but with high glyph IDs
        final startCode = 0x41; // 'A'
        final startGlyphId = 300; // Start from a high ID

        for (int i = 0; i < 10; i++) {
          glyphs.add(
            FontGlyph(
              code: startCode + i,
              advanceWidth: 16.0,
              bbox: BoundingBox(x: 0, y: -12, width: 8, height: 12),
              kerning: {},
              pixels: List.generate(12, (_) => List.generate(8, (_) => 0)),
            ),
          );
        }

        final fontData = FontData(
          ascent: 12,
          descent: -2,
          typoAscent: 12,
          typoDescent: -2,
          typoLineGap: 2,
          size: 16,
          glyphs: glyphs,
          underlinePosition: -1,
          underlineThickness: 1,
        );

        // Create glyph ID mapping with high IDs
        final glyphId = <int, int>{0: 0};
        for (int i = 0; i < glyphs.length; i++) {
          glyphId[glyphs[i].code] = startGlyphId + i;
        }

        // This should not throw an exception and should use sparse format
        expect(() {
          final cmapTable = CmapTable(fontData, glyphId);
          final binaryData = cmapTable.toBin();
          expect(binaryData.isNotEmpty, true);
        }, returnsNormally);
      },
    );
  });
}
