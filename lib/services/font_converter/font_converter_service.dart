import 'dart:typed_data';
import 'dart:io';
import 'models/font_data.dart';
import 'models/font_options.dart';
import 'models/font_glyph.dart';
import 'font.dart';

/// Font converter service for converting TTF/OTF fonts to binary format
class FontConverterService {
  /// Convert font data to binary format
  ///
  /// [fontData] - The font data containing glyphs and metrics
  /// [options] - Conversion options
  ///
  /// Returns binary font data in the specified format
  static Uint8List convertToBinary(FontData fontData, FontOptions options) {
    final font = Font(fontData, options);
    return font.toBin();
  }

  /// Save binary font data to file
  ///
  /// [fontData] - The font data containing glyphs and metrics
  /// [options] - Conversion options
  /// [outputPath] - Path to save the binary font file
  ///
  /// Returns [Future<void>] when complete
  static Future<void> saveBinaryFont(
    FontData fontData,
    FontOptions options,
    String outputPath,
  ) async {
    final binaryData = convertToBinary(fontData, options);
    final file = File(outputPath);
    await file.writeAsBytes(binaryData);
  }

  /// Create a simple font data from basic parameters
  ///
  /// This is a helper method for creating basic font data for testing or simple use cases
  ///
  /// [size] - Font size in pixels
  /// [glyphs] - List of glyphs to include
  /// [ascent] - Maximum Y coordinate of any glyph
  /// [descent] - Minimum Y coordinate of any glyph (negative value)
  /// [typoAscent] - Typographic ascent
  /// [typoDescent] - Typographic descent (negative value)
  /// [typoLineGap] - Typographic line gap
  /// [underlinePosition] - Underline position
  /// [underlineThickness] - Underline thickness
  static FontData createBasicFontData({
    required int size,
    required List<FontGlyph> glyphs,
    int ascent = 0,
    int descent = 0,
    int typoAscent = 0,
    int typoDescent = 0,
    int typoLineGap = 0,
    int underlinePosition = 0,
    int underlineThickness = 0,
  }) {
    // Calculate ascent and descent if not provided
    if (ascent == 0 && glyphs.isNotEmpty) {
      ascent = glyphs
          .map((g) => g.bbox.y + g.bbox.height)
          .reduce((a, b) => a > b ? a : b);
    }
    if (descent == 0 && glyphs.isNotEmpty) {
      descent = glyphs.map((g) => g.bbox.y).reduce((a, b) => a < b ? a : b);
    }

    return FontData(
      ascent: ascent,
      descent: descent,
      typoAscent: typoAscent > 0 ? typoAscent : ascent,
      typoDescent: typoDescent < 0 ? typoDescent : descent,
      typoLineGap: typoLineGap,
      size: size,
      glyphs: glyphs,
      underlinePosition: underlinePosition,
      underlineThickness: underlineThickness,
    );
  }

  /// Create a simple glyph from bitmap data
  ///
  /// This is a helper method for creating basic glyphs for testing or simple use cases
  ///
  /// [code] - Unicode code point of the glyph
  /// [pixels] - 2D array of pixel values (0-255)
  /// [advanceWidth] - Advance width of the glyph
  /// [x] - X coordinate of the bounding box
  /// [y] - Y coordinate of the bounding box
  static FontGlyph createBasicGlyph({
    required int code,
    required List<List<int>> pixels,
    double advanceWidth = 0.0,
    int x = 0,
    int y = 0,
  }) {
    // Calculate bounding box if not provided
    if (pixels.isNotEmpty) {
      final height = pixels.length;
      final width = pixels.first.length;

      return FontGlyph(
        code: code,
        advanceWidth: advanceWidth > 0 ? advanceWidth : width.toDouble(),
        bbox: BoundingBox(x: x, y: y - height, width: width, height: height),
        kerning: {},
        pixels: pixels,
      );
    }

    // Empty glyph
    return FontGlyph(
      code: code,
      advanceWidth: advanceWidth,
      bbox: BoundingBox(x: x, y: y, width: 0, height: 0),
      kerning: {},
      pixels: [],
    );
  }

  /// Create font options with common defaults
  ///
  /// [bpp] - Bits per pixel (1, 2, 3, 4, or 8)
  /// [size] - Font size in pixels
  /// [noCompress] - Disable RLE compression
  /// [noKerning] - Drop kerning info to reduce size
  static FontOptions createOptions({
    required int bpp,
    required int size,
    bool noCompress = false,
    bool noKerning = false,
  }) {
    return FontOptions(
      bpp: bpp,
      size: size,
      noCompress: noCompress,
      noKerning: noKerning,
    );
  }
}
