/// Represents a single glyph in a font
class FontGlyph {
  /// Unicode code point of the glyph
  final int code;

  /// Advance width of the glyph
  final double advanceWidth;

  /// Bounding box of the glyph
  final BoundingBox bbox;

  /// Kerning information for this glyph
  final Map<int, double> kerning;

  /// Pixel data of the glyph (2D array)
  final List<List<int>> pixels;

  const FontGlyph({
    required this.code,
    required this.advanceWidth,
    required this.bbox,
    required this.kerning,
    required this.pixels,
  });

  /// Creates a copy of this glyph with modified properties
  FontGlyph copyWith({
    int? code,
    double? advanceWidth,
    BoundingBox? bbox,
    Map<int, double>? kerning,
    List<List<int>>? pixels,
  }) {
    return FontGlyph(
      code: code ?? this.code,
      advanceWidth: advanceWidth ?? this.advanceWidth,
      bbox: bbox ?? this.bbox,
      kerning: kerning ?? this.kerning,
      pixels: pixels ?? this.pixels,
    );
  }

  @override
  String toString() {
    return 'FontGlyph{code: ${code.toRadixString(16)}, advanceWidth: $advanceWidth, bbox: $bbox}';
  }
}

/// Represents the bounding box of a glyph
class BoundingBox {
  /// X coordinate of the bottom-left corner
  final int x;

  /// Y coordinate of the bottom-left corner
  final int y;

  /// Width of the bounding box
  final int width;

  /// Height of the bounding box
  final int height;

  const BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  @override
  String toString() {
    return 'BoundingBox{x: $x, y: $y, width: $width, height: $height}';
  }
}
