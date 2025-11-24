/// Configuration options for font conversion
class FontOptions {
  /// Bits per pixel for antialiasing (1, 2, 3, 4, or 8)
  final int bpp;

  /// Output font size in pixels
  final int size;

  /// Enable horizontal subpixel rendering (3x horizontal resolution)
  final bool lcd;

  /// Enable vertical subpixel rendering (3x vertical resolution)
  final bool lcdV;

  /// Use color info from font to create grayscale icons
  final bool useColorInfo;

  /// Disable RLE compression
  final bool noCompress;

  /// Disable bitmap lines filter (XOR) used to improve compression ratio
  final bool noPrefilter;

  /// Pad bitmap line endings to whole bytes
  final bool byteAlign;

  /// Align each glyph's stride to the specified number of bytes
  final int stride;

  /// Align each glyph address to the specified number of bytes
  final int align;

  /// Drop kerning info to reduce size
  final bool noKerning;

  const FontOptions({
    required this.bpp,
    required this.size,
    this.lcd = false,
    this.lcdV = false,
    this.useColorInfo = false,
    this.noCompress = false,
    this.noPrefilter = false,
    this.byteAlign = false,
    this.stride = 0,
    this.align = 1,
    this.noKerning = false,
  });

  /// Creates a copy of this FontOptions with modified properties
  FontOptions copyWith({
    int? bpp,
    int? size,
    bool? lcd,
    bool? lcdV,
    bool? useColorInfo,
    bool? noCompress,
    bool? noPrefilter,
    bool? byteAlign,
    int? stride,
    int? align,
    bool? noKerning,
  }) {
    return FontOptions(
      bpp: bpp ?? this.bpp,
      size: size ?? this.size,
      lcd: lcd ?? this.lcd,
      lcdV: lcdV ?? this.lcdV,
      useColorInfo: useColorInfo ?? this.useColorInfo,
      noCompress: noCompress ?? this.noCompress,
      noPrefilter: noPrefilter ?? this.noPrefilter,
      byteAlign: byteAlign ?? this.byteAlign,
      stride: stride ?? this.stride,
      align: align ?? this.align,
      noKerning: noKerning ?? this.noKerning,
    );
  }

  @override
  String toString() {
    return 'FontOptions{bpp: $bpp, size: $size, lcd: $lcd, lcdV: $lcdV, noCompress: $noCompress}';
  }
}
