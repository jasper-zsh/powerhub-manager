import 'font_glyph.dart';

/// Complete font data containing all glyphs and metrics
class FontData {
  /// Maximum Y coordinate of any glyph
  final int ascent;

  /// Minimum Y coordinate of any glyph (negative value)
  final int descent;

  /// Typographic ascent
  final int typoAscent;

  /// Typographic descent (negative value)
  final int typoDescent;

  /// Typographic line gap
  final int typoLineGap;

  /// Font size in pixels
  final int size;

  /// List of all glyphs in the font
  final List<FontGlyph> glyphs;

  /// Underline position
  final int underlinePosition;

  /// Underline thickness
  final int underlineThickness;

  const FontData({
    required this.ascent,
    required this.descent,
    required this.typoAscent,
    required this.typoDescent,
    required this.typoLineGap,
    required this.size,
    required this.glyphs,
    required this.underlinePosition,
    required this.underlineThickness,
  });

  /// Gets the maximum Y coordinate of any glyph
  int get maxY => ascent;

  /// Gets the minimum Y coordinate of any glyph
  int get minY => descent;

  @override
  String toString() {
    return 'FontData{size: $size, glyphCount: ${glyphs.length}, ascent: $ascent, descent: $descent}';
  }
}
