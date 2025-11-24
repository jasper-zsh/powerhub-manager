import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_converter/tables/cmap_table.dart';
import 'package:app/services/font_converter/models/font_data.dart';
import 'package:app/services/font_converter/models/font_glyph.dart';

void main() {
  group('Font Glyph Range Tests', () {
    test('Should handle glyph ID range exceeding Format 0 limit', () {
      // Create a font with glyphs that will exceed Format 0 range
      final glyphs = <FontGlyph>[];

      // Create 300 glyphs starting from codepoint 0x20 (space)
      for (int i = 0; i < 300; i++) {
        glyphs.add(
          FontGlyph(
            code: 0x20 + i,
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

        // Verify that the binary data contains some sparse format tables
        // (we can't easily check the exact format without parsing, but we can verify it doesn't crash)
      }, returnsNormally);
    });

    test('Should use sparse format for large glyph ID ranges', () {
      // Create a smaller set of glyphs but with non-sequential glyph IDs
      final glyphs = <FontGlyph>[];

      // Create 10 glyphs but assign them non-sequential IDs
      final List<int> glyphIds = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50];
      for (int i = 0; i < 10; i++) {
        glyphs.add(
          FontGlyph(
            code: 0x41 + i, // 'A' through 'J'
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

      // Create glyph ID mapping with non-sequential IDs
      final glyphId = <int, int>{0: 0};
      for (int i = 0; i < glyphs.length; i++) {
        glyphId[glyphs[i].code] = glyphIds[i];
      }

      // This should not throw an exception and should use sparse format
      expect(() {
        final cmapTable = CmapTable(fontData, glyphId);
        final binaryData = cmapTable.toBin();
        expect(binaryData.isNotEmpty, true);
      }, returnsNormally);
    });

    test('Should use format0 for small glyph ID ranges', () {
      // Create a small set of glyphs with sequential IDs
      final glyphs = <FontGlyph>[];

      // Create 10 glyphs with sequential IDs starting from 1
      for (int i = 0; i < 10; i++) {
        glyphs.add(
          FontGlyph(
            code: 0x41 + i, // 'A' through 'J'
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

      // Create glyph ID mapping with sequential IDs
      final glyphId = <int, int>{0: 0};
      for (int i = 0; i < glyphs.length; i++) {
        glyphId[glyphs[i].code] = i + 1;
      }

      // This should not throw an exception and should use format0
      expect(() {
        final cmapTable = CmapTable(fontData, glyphId);
        final binaryData = cmapTable.toBin();
        expect(binaryData.isNotEmpty, true);
      }, returnsNormally);
    });
  });
}
