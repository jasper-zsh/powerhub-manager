import 'dart:typed_data';
import '../models/font_data.dart';
import '../models/font_options.dart';
import '../utils/font_utils.dart';

/// Head table containing font header information
class HeadTable {
  static const String label = 'head';
  static const int headLength = 64; // 4x aligned

  final FontData _fontData;
  final FontOptions _options;
  final Map<int, int> _glyphId;
  final int _glyphIdFormat;
  final int _advanceWidthFormat;
  final int _xyBits;
  final int _whBits;
  final int _advanceWidthBits;
  final int _compressionCode;
  final int _subpixelsMode;
  final double _kerningScale;
  final bool _monospaced;
  final int _indexToLocFormat;

  HeadTable(
    this._fontData,
    this._options,
    this._glyphId,
    this._glyphIdFormat,
    this._advanceWidthFormat,
    this._xyBits,
    this._whBits,
    this._advanceWidthBits,
    this._compressionCode,
    this._subpixelsMode,
    this._kerningScale,
    this._monospaced,
    this._indexToLocFormat,
  );

  /// Convert the head table to binary format
  Uint8List toBin() {
    final buffer = Uint8List(headLength);
    final byteData = buffer.buffer.asByteData();

    int offset = 0;

    // Record size (4 bytes)
    byteData.setUint32(offset, headLength, Endian.little);
    offset += 4;

    // Table marker (4 bytes)
    offset += 4; // Will be set later

    // Version (4 bytes, reserved)
    offset += 4;

    // Number of additional tables (2 bytes)
    byteData.setUint16(
      offset,
      4,
      Endian.little,
    ); // head, cmap, loca, glyf, kern
    offset += 2;

    // Font size (2 bytes)
    byteData.setUint16(offset, _fontData.size, Endian.little);
    offset += 2;

    // Ascent (2 bytes)
    byteData.setUint16(offset, _fontData.ascent, Endian.little);
    offset += 2;

    // Descent (2 bytes, negative)
    byteData.setInt16(offset, _fontData.descent, Endian.little);
    offset += 2;

    // typoAscent (2 bytes)
    byteData.setUint16(offset, _fontData.typoAscent, Endian.little);
    offset += 2;

    // typoDescent (2 bytes, negative)
    byteData.setInt16(offset, _fontData.typoDescent, Endian.little);
    offset += 2;

    // typoLineGap (2 bytes)
    byteData.setUint16(offset, _fontData.typoLineGap, Endian.little);
    offset += 2;

    // min Y (2 bytes)
    byteData.setInt16(offset, _fontData.minY, Endian.little);
    offset += 2;

    // max Y (2 bytes)
    byteData.setUint16(offset, _fontData.maxY, Endian.little);
    offset += 2;

    // default advanceWidth (2 bytes)
    final defaultAdvanceWidth = _monospaced
        ? _fontData.glyphs.isNotEmpty
              ? _fontData.glyphs.first.advanceWidth.round()
              : 0
        : 0;
    byteData.setUint16(offset, defaultAdvanceWidth, Endian.little);
    offset += 2;

    // kerningScale, FP12.4 unsigned (2 bytes)
    byteData.setUint16(offset, (_kerningScale * 16).round(), Endian.little);
    offset += 2;

    // indexToLocFormat (1 byte)
    buffer[offset++] = _indexToLocFormat;

    // glyphIdFormat (1 byte)
    buffer[offset++] = _glyphIdFormat;

    // advanceWidthFormat (1 byte)
    buffer[offset++] = _advanceWidthFormat;

    // Bits per pixel (1 byte)
    buffer[offset++] = _options.bpp;

    // Glyph BBox x/y bits length (1 byte)
    buffer[offset++] = _xyBits;

    // Glyph BBox w/h bits length (1 byte)
    buffer[offset++] = _whBits;

    // Glyph advanceWidth bits length (1 byte)
    buffer[offset++] = _advanceWidthBits;

    // Compression alg ID (1 byte)
    buffer[offset++] = _compressionCode;

    // Subpixel rendering (1 byte)
    buffer[offset++] = _subpixelsMode;

    // Reserved (1 byte, align to 2x)
    offset += 1;

    // Underline position (2 bytes)
    byteData.setInt16(offset, _fontData.underlinePosition, Endian.little);
    offset += 2;

    // Underline thickness (2 bytes)
    byteData.setUint16(offset, _fontData.underlineThickness, Endian.little);
    offset += 2;

    // Set table marker
    for (int i = 0; i < 4; i++) {
      buffer[4 + i] = label.codeUnitAt(i);
    }

    return buffer;
  }
}
