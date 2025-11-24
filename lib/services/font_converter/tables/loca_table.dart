import 'dart:typed_data';
import '../utils/font_utils.dart';

/// Loca table for storing glyph data offsets
class LocaTable {
  static const String label = 'loca';
  static const int headLength = 12; // 4x aligned

  final int _glyphCount;
  final int _indexToLocFormat;
  final List<int> _offsets;

  LocaTable(this._glyphCount, this._indexToLocFormat, this._offsets);

  /// Convert the loca table to binary format
  Uint8List toBin() {
    final parts = <Uint8List>[];
    parts.add(Uint8List(headLength));

    // Add offsets
    if (_indexToLocFormat == 0) {
      // 16-bit offsets
      final offsetData = Uint8List(_offsets.length * 2);
      final byteData = offsetData.buffer.asByteData();
      for (int i = 0; i < _offsets.length; i++) {
        byteData.setUint16(i * 2, _offsets[i], Endian.little);
      }
      parts.add(offsetData);
    } else {
      // 32-bit offsets
      final offsetData = FontUtils.uint32ListToBuffer(_offsets);
      parts.add(offsetData);
    }

    final buffer = _concatUint8Lists(parts);

    // Set header fields
    final byteData = buffer.buffer.asByteData();
    byteData.setUint32(0, buffer.length, Endian.little);

    // Set table marker
    for (int i = 0; i < 4; i++) {
      buffer[4 + i] = label.codeUnitAt(i);
    }

    byteData.setUint32(8, _offsets.length, Endian.little);

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
