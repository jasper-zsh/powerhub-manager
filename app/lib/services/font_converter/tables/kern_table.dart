import 'dart:typed_data';
import '../models/font_data.dart';
import '../models/font_options.dart';
import '../models/font_glyph.dart';
import '../utils/font_utils.dart';

/// Kern table for storing kerning information
class KernTable {
  static const String label = 'kern';
  static const int headLength = 8; // 4x aligned

  final FontData _fontData;
  final FontOptions _options;
  final Map<int, int> _glyphId;
  final int _glyphIdFormat;
  final double _kerningScale;

  KernTable(
    this._fontData,
    this._options,
    this._glyphId,
    this._glyphIdFormat,
    this._kerningScale,
  );

  /// Convert the kern table to binary format
  Uint8List toBin() {
    if (_options.noKerning || !_hasKerning()) {
      return _createEmptyTable();
    }

    // For simplicity, we'll use format 0 (sorted pairs)
    return _createSortedPairsFormat();
  }

  /// Check if font has kerning information
  bool _hasKerning() {
    for (final glyph in _fontData.glyphs) {
      if (glyph.kerning.isNotEmpty) return true;
    }
    return false;
  }

  /// Create empty kern table
  Uint8List _createEmptyTable() {
    final buffer = Uint8List(headLength);
    final byteData = buffer.buffer.asByteData();

    byteData.setUint32(0, headLength, Endian.little);

    // Set table marker
    for (int i = 0; i < 4; i++) {
      buffer[4 + i] = label.codeUnitAt(i);
    }

    // Format type (0)
    buffer[7] = 0;

    return buffer;
  }

  /// Create kern table in sorted pairs format (format 0)
  Uint8List _createSortedPairsFormat() {
    final pairs = <List<int>>[];
    final values = <int>[];

    // Collect all kerning pairs
    for (final glyph in _fontData.glyphs) {
      final leftId = _glyphId[glyph.code]!;

      for (final entry in glyph.kerning.entries) {
        final rightCode = entry.key;
        final rightGlyph = _glyphByCode(rightCode);
        if (rightGlyph == null) continue;

        final rightId = _glyphId[rightCode]!;
        final kerningValue = entry.value;

        pairs.add([leftId, rightId]);
        values.add(_kernToFp(kerningValue));
      }
    }

    // Create data
    final data = <Uint8List>[];

    // Add pair count
    final countBuffer = Uint8List(4);
    countBuffer.buffer.asByteData().setUint32(0, pairs.length, Endian.little);
    data.add(countBuffer);

    // Add pairs
    for (final pair in pairs) {
      if (_glyphIdFormat == 0) {
        // 16-bit IDs
        final pairBuffer = Uint8List(4);
        final byteData = pairBuffer.buffer.asByteData();
        byteData.setUint16(0, pair[0], Endian.little);
        byteData.setUint16(2, pair[1], Endian.little);
        data.add(pairBuffer);
      } else {
        // 32-bit IDs
        final pairBuffer = Uint8List(8);
        final byteData = pairBuffer.buffer.asByteData();
        byteData.setUint32(0, pair[0], Endian.little);
        byteData.setUint32(4, pair[1], Endian.little);
        data.add(pairBuffer);
      }
    }

    // Add values
    final valuesBuffer = Uint8List.fromList(values);
    data.add(valuesBuffer);

    // Combine all parts
    final buffer = _concatUint8Lists([Uint8List(headLength), ...data]);

    // Set header fields
    final byteData = buffer.buffer.asByteData();
    byteData.setUint32(0, buffer.length, Endian.little);

    // Set table marker
    for (int i = 0; i < 4; i++) {
      buffer[4 + i] = label.codeUnitAt(i);
    }

    // Format type (0)
    buffer[7] = 0;

    return buffer;
  }

  /// Find glyph by code
  FontGlyph? _glyphByCode(int code) {
    for (final glyph in _fontData.glyphs) {
      if (glyph.code == code) return glyph;
    }
    return null;
  }

  /// Convert kerning to FP4.4 fixed point
  int _kernToFp(double val) {
    return ((val / _kerningScale) * 16).round();
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
