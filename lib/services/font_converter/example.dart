import 'dart:typed_data';
import 'models/font_data.dart';
import 'models/font_options.dart';
import 'models/font_glyph.dart';
import 'font_converter_service.dart';

/// Example usage of the font converter service
class FontConverterExample {
  /// Create a simple example font with basic ASCII characters
  static Future<void> createExampleFont() async {
    // Create font options
    final options = FontConverterService.createOptions(
      bpp: 4, // 4 bits per pixel for anti-aliasing
      size: 16, // 16px font size
      noCompress: false, // Enable compression
      noKerning: true, // No kerning for simplicity
    );

    // Create some basic glyphs (simplified examples)
    final glyphs = <FontGlyph>[];

    // Add a simple 'A' glyph (5x7 pixel pattern)
    glyphs.add(
      FontConverterService.createBasicGlyph(
        code: 0x41, // 'A'
        pixels: [
          [0, 0, 1, 1, 1, 1, 1, 1], // Row 0
          [0, 1, 1, 1, 1, 1, 1, 0], // Row 1
          [1, 1, 1, 1, 1, 1, 1, 1], // Row 2
          [1, 1, 1, 1, 1, 1, 1, 1], // Row 3
          [1, 1, 1, 1, 1, 1, 1, 1], // Row 4
          [1, 1, 1, 1, 1, 1, 1, 1], // Row 5
          [0, 1, 1, 1, 1, 1, 1, 0], // Row 6
        ],
        advanceWidth: 8.0,
        x: 0,
        y: 7,
      ),
    );

    // Add a simple 'B' glyph
    glyphs.add(
      FontConverterService.createBasicGlyph(
        code: 0x42, // 'B'
        pixels: [
          [1, 1, 1, 1, 1, 1, 0, 0], // Row 0
          [1, 1, 1, 1, 1, 1, 1, 0], // Row 1
          [1, 1, 1, 1, 1, 1, 1, 0], // Row 2
          [1, 1, 1, 1, 1, 1, 1, 1], // Row 3
          [1, 1, 1, 1, 1, 1, 1, 0], // Row 4
          [1, 1, 1, 1, 1, 1, 1, 0], // Row 5
          [0, 1, 1, 1, 1, 1, 0, 0], // Row 6
        ],
        advanceWidth: 8.0,
        x: 0,
        y: 7,
      ),
    );

    // Create font data
    final fontData = FontConverterService.createBasicFontData(
      size: options.size,
      glyphs: glyphs,
      ascent: 7,
      descent: 0,
      typoAscent: 7,
      typoDescent: 0,
      typoLineGap: 2,
      underlinePosition: -1,
      underlineThickness: 1,
    );

    // Convert to binary format
    final binaryData = FontConverterService.convertToBinary(fontData, options);

    // Save to file
    await FontConverterService.saveBinaryFont(
      fontData,
      options,
      'example_font.bin',
    );

    print('Example font created: example_font.bin');
    print('Font size: ${binaryData.length} bytes');
    print('Glyph count: ${glyphs.length}');
  }

  /// Create a more complex example with kerning
  static Future<void> createKerningExample() async {
    // Create font options with kerning enabled
    final options = FontConverterService.createOptions(
      bpp: 2, // 2 bits per pixel
      size: 12, // 12px font size
      noCompress: false,
      noKerning: false, // Enable kerning
    );

    // Create glyphs with kerning
    final glyphs = <FontGlyph>[];

    // Add 'A' glyph
    final glyphA = FontConverterService.createBasicGlyph(
      code: 0x41, // 'A'
      pixels: [
        [0, 0, 3, 3, 3, 3], // Row 0
        [0, 3, 3, 3, 3, 3], // Row 1
        [3, 3, 3, 3, 3, 3], // Row 2
        [3, 3, 3, 3, 3, 3], // Row 3
        [3, 3, 3, 3, 3, 3], // Row 4
        [0, 3, 3, 3, 3, 0], // Row 5
      ],
      advanceWidth: 6.0,
      x: 0,
      y: 5,
    );

    // Add 'V' glyph with kerning to 'A'
    final glyphV = FontConverterService.createBasicGlyph(
      code: 0x56, // 'V'
      pixels: [
        [3, 3, 3, 3, 3, 3], // Row 0
        [3, 3, 3, 3, 3, 3], // Row 1
        [3, 3, 3, 3, 3, 3], // Row 2
        [3, 3, 3, 3, 3, 3], // Row 3
        [1, 3, 3, 3, 3, 1], // Row 4
        [0, 1, 1, 1, 1, 0], // Row 5
      ],
      advanceWidth: 6.0,
      x: 0,
      y: 5,
    );

    // Add kerning: when 'V' follows 'A', move closer by 1 pixel
    glyphA.kerning[0x56] = -1.0; // 'A' -> 'V'

    glyphs.add(glyphA);
    glyphs.add(glyphV);

    // Create font data
    final fontData = FontConverterService.createBasicFontData(
      size: options.size,
      glyphs: glyphs,
      ascent: 5,
      descent: 0,
      typoAscent: 5,
      typoDescent: 0,
      typoLineGap: 2,
      underlinePosition: -1,
      underlineThickness: 1,
    );

    // Convert to binary format
    final binaryData = FontConverterService.convertToBinary(fontData, options);

    // Save to file
    await FontConverterService.saveBinaryFont(
      fontData,
      options,
      'kerning_font.bin',
    );

    print('Kerning font created: kerning_font.bin');
    print('Font size: ${binaryData.length} bytes');
    print('Glyph count: ${glyphs.length}');
    print('Kerning pairs: ${glyphs.where((g) => g.kerning.isNotEmpty).length}');
  }
}
