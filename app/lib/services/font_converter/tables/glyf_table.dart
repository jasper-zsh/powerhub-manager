import 'dart:typed_data';
import '../models/font_data.dart';
import '../models/font_options.dart';
import '../models/font_glyph.dart';
import '../utils/font_utils.dart';
import '../utils/compression.dart';

/// Bit stream writer for compression
class BitStream {
  final Uint8List _buffer;
  int _byteIndex = 0;
  int _bitIndex = 0;

  BitStream(this._buffer);

  void writeBit(int bit) {
    if (bit == 1) {
      _buffer[_byteIndex] |= (1 << _bitIndex);
    } else {
      _buffer[_byteIndex] &= ~(1 << _bitIndex);
    }

    _bitIndex++;
    if (_bitIndex >= 8) {
      _bitIndex = 0;
      _byteIndex++;
      if (_byteIndex >= _buffer.length) {
        throw Exception('BitStream buffer overflow');
      }
    }
  }

  int get byteIndex => _bitIndex > 0 ? _byteIndex + 1 : _byteIndex;
}

/// Write bits to bit stream
void _writeBits(BitStream bitStream, int value, int bitCount) {
  for (int i = 0; i < bitCount; i++) {
    final bit = (value >> i) & 1;
    bitStream.writeBit(bit);
  }
}

/// Glyf table containing glyph bitmap data
class GlyfTable {
  static const String label = 'glyf';
  static const int headLength = 8; // 4x aligned

  final FontData _fontData;
  final FontOptions _options;
  final Map<int, int> _glyphId;
  final int _advanceWidthFormat;
  final int _xyBits;
  final int _whBits;
  final int _advanceWidthBits;
  final bool _monospaced;

  bool _compiled = false;
  late List<Uint8List> _binData;

  GlyfTable(
    this._fontData,
    this._options,
    this._glyphId,
    this._advanceWidthFormat,
    this._xyBits,
    this._whBits,
    this._advanceWidthBits,
    this._monospaced,
  );

  /// Compile the glyf table
  void _compile() {
    if (_compiled) return;
    _compiled = true;

    // Initialize binData with enough space for all glyphs
    final maxId = _glyphId.values.isNotEmpty
        ? _glyphId.values.reduce((a, b) => a > b ? a : b)
        : 0;
    _binData = List.generate(maxId + 1, (index) => Uint8List(0));

    for (final glyph in _fontData.glyphs) {
      final id = _glyphId[glyph.code]!;
      _binData[id] = _compileGlyph(glyph);
    }
  }

  /// Compile a single glyph
  Uint8List _compileGlyph(FontGlyph glyph) {
    // Estimate buffer size
    final stride = FontUtils.widthToStride(
      glyph.bbox.width,
      _options.bpp,
      _options.stride,
    );
    int estimatedSize = 100 + (stride * glyph.bbox.height) + _options.align;

    if (estimatedSize <= 0) {
      estimatedSize = 128 * 1024; // Fallback for empty glyphs
    }

    final buffer = Uint8List(estimatedSize);
    final bitStream = BitStream(buffer);

    // Store advance width if not monospaced
    if (!_monospaced) {
      final width = _widthToInt(glyph.advanceWidth);
      _writeBits(bitStream, width, _advanceWidthBits);
    }

    // Store X, Y, width, height
    _writeBits(bitStream, glyph.bbox.x, _xyBits);
    _writeBits(bitStream, glyph.bbox.y, _xyBits);
    _writeBits(bitStream, glyph.bbox.width, _whBits);
    _writeBits(bitStream, glyph.bbox.height, _whBits);

    // Store pixels
    final pixels = FontUtils.pixelsToBpp(glyph.pixels, _options.bpp);
    _storePixels(bitStream, pixels, glyph.bbox.width);

    // Shrink to actual size
    final actualSize = bitStream.byteIndex;
    final resultSize = _options.align > 1
        ? ((actualSize + _options.align - 1) ~/ _options.align) * _options.align
        : actualSize;

    final result = Uint8List(resultSize);
    result.setRange(0, actualSize, buffer);

    return result;
  }

  /// Store pixel data
  void _storePixels(BitStream bitStream, List<List<int>> pixels, int width) {
    if (_getCompressionCode() == 0 || _getCompressionCode() == 3) {
      _storePixelsRaw(bitStream, pixels, width);
    } else {
      _storePixelsCompressed(bitStream, pixels);
    }
  }

  /// Store raw pixel data
  void _storePixelsRaw(BitStream bitStream, List<List<int>> pixels, int width) {
    if (pixels.isEmpty) return;

    final bpp = _options.bpp;
    int bitPadLine = 0;

    if (_options.stride > 0) {
      final bitCount = pixels.first.length * bpp;
      final alignedBitCount =
          FontUtils.widthToStride(width, bpp, _options.stride) * 8;
      bitPadLine = alignedBitCount - bitCount;
    }

    for (final line in pixels) {
      for (final pixel in line) {
        _writeBits(bitStream, pixel, bpp);
      }

      if (bitPadLine > 0) {
        _addPadding(bitStream, bitPadLine ~/ bpp);
      }
    }
  }

  /// Store compressed pixel data
  void _storePixelsCompressed(BitStream bitStream, List<List<int>> pixels) {
    List<int> pixelData;

    if (_options.noPrefilter) {
      pixelData = pixels.expand((line) => line).toList();
    } else {
      pixelData = FontUtils.prefilter(pixels).expand((line) => line).toList();
    }

    // Use the enhanced compression algorithm
    final compressedData = FontCompression.compress(pixelData, _options);

    // Log compression statistics for debugging
    if (pixelData.isNotEmpty) {
      final stats = FontCompression.getCompressionStats(
        pixelData,
        compressedData,
      );
      print(
        '[GlyfTable] Compression: ${stats['spaceSavedPercent']} saved (${stats['compressedSize']}/${stats['originalSize']} bytes)',
      );
    }

    // Write compressed data bit by bit
    for (final byte in compressedData) {
      _writeBits(bitStream, byte, 8);
    }
  }

  /// Add padding bits
  void _addPadding(BitStream bitStream, int pad) {
    for (int i = 0; i < pad; i++) {
      _writeBits(bitStream, 0, _options.bpp);
    }
  }

  /// Write bits to bit stream
  void _writeBits(BitStream bitStream, int value, int bitCount) {
    for (int i = 0; i < bitCount; i++) {
      final bit = (value >> i) & 1;
      bitStream.writeBit(bit);
    }
  }

  /// Convert width to integer based on format
  int _widthToInt(double val) {
    if (_advanceWidthFormat == 0) return val.round();
    return (val * 16).round();
  }

  /// Get compression code
  int _getCompressionCode() {
    if (_options.noCompress) return 0;
    if (_options.bpp == 1) return 0;
    if (_options.noPrefilter) return 2;
    return 1;
  }

  /// Get the total size of the table
  int getSize() {
    _compile();

    int totalSize = headLength;
    for (final data in _binData) {
      totalSize += data.length;
    }

    return FontUtils.align4(totalSize);
  }

  /// Get offset for a glyph ID
  int getOffset(int id) {
    _compile();

    int offset = headLength;
    for (int i = 0; i < id; i++) {
      offset += _binData[i].length;
    }

    return offset;
  }

  /// Convert the glyf table to binary format
  Uint8List toBin() {
    _compile();

    final parts = <Uint8List>[];
    parts.add(Uint8List(headLength));
    parts.addAll(_binData);

    final buffer = _concatUint8Lists(parts);

    // Set header fields
    final byteData = buffer.buffer.asByteData();
    byteData.setUint32(0, buffer.length, Endian.little);

    // Set table marker
    for (int i = 0; i < 4; i++) {
      buffer[4 + i] = label.codeUnitAt(i);
    }

    return buffer;
  }

  /// Concatenate list of Uint8List
  Uint8List _concatUint8Lists(List<Uint8List> lists) {
    final totalLength = lists.fold(0, (sum, list) => sum + list.length);
    final result = Uint8List(totalLength);

    int offset = 0;
    for (final list in lists) {
      result.setRange(offset, offset + list.length, list);
      offset += list.length;
    }

    return result;
  }
}
