import 'dart:typed_data';
import '../models/font_data.dart';
import '../models/font_glyph.dart';
import '../utils/font_utils.dart';

/// Cmap table for mapping character codes to glyph IDs
class CmapTable {
  static const String label = 'cmap';
  static const int headLength = 12; // 4x aligned

  final FontData _fontData;
  final Map<int, int> _glyphId;

  late List<Uint8List> _subHeads;
  late List<Uint8List> _subData;
  bool _compiled = false;

  CmapTable(this._fontData, this._glyphId);

  /// Compile the cmap table
  void _compile() {
    if (_compiled) return;
    _compiled = true;

    final subtablesPlan = _buildSubtablesPlan(
      _fontData.glyphs.map((g) => g.code).toList(),
    );

    _subHeads = [];
    _subData = [];

    for (final entry in subtablesPlan) {
      final format = entry['format'] as String;
      final codepoints = entry['codepoints'] as List<int>;

      final firstGlyph = _glyphByCode(codepoints.first);
      final startGlyphId = _glyphId[firstGlyph!.code]!;
      final minCode = codepoints.first;
      final maxCode = codepoints.last;
      final entriesCount = maxCode - minCode + 1;

      if (format == 'format0_tiny') {
        _subData.add(Uint8List(0));
        _subHeads.add(
          _createSubHeader(
            minCode,
            maxCode - minCode + 1,
            startGlyphId,
            entriesCount,
            2, // SUB_FORMAT_0_TINY
          ),
        );
      } else if (format == 'format0') {
        _subData.add(_createFormat0Data(minCode, maxCode, startGlyphId));
        _subHeads.add(
          _createSubHeader(
            minCode,
            maxCode - minCode + 1,
            startGlyphId,
            entriesCount,
            0, // SUB_FORMAT_0
          ),
        );
      } else if (format == 'sparse_tiny') {
        final sparseEntriesCount = codepoints.length;
        _subData.add(_createSparseTinyData(codepoints, startGlyphId));
        _subHeads.add(
          _createSubHeader(
            minCode,
            maxCode - minCode + 1,
            startGlyphId,
            sparseEntriesCount,
            3, // SUB_FORMAT_SPARSE_TINY
          ),
        );
      } else {
        // sparse
        final sparseEntriesCount = codepoints.length;
        _subData.add(_createSparseData(codepoints, startGlyphId));
        _subHeads.add(
          _createSubHeader(
            minCode,
            maxCode - minCode + 1,
            startGlyphId,
            sparseEntriesCount,
            1, // SUB_FORMAT_SPARSE
          ),
        );
      }
    }

    _updateAllOffsets();
  }

  /// Build subtables plan from list of codepoints
  List<Map<String, dynamic>> _buildSubtablesPlan(List<int> codepoints) {
    if (codepoints.isEmpty) return [];

    codepoints.sort();

    final result = <Map<String, dynamic>>[];
    int start = 0;

    print(
      '[CmapTable] Building subtables plan for ${codepoints.length} codepoints',
    );

    for (int i = 1; i <= codepoints.length; i++) {
      if (i == codepoints.length || codepoints[i] != codepoints[i - 1] + 1) {
        final range = codepoints.sublist(start, i);
        final isSparse = (range.last - range.first + 1) > range.length * 2;

        // Check if glyph ID range exceeds Format 0 limit (255)
        final firstGlyph = _glyphByCode(range.first);
        final lastGlyph = _glyphByCode(range.last);
        final firstGlyphId = firstGlyph != null
            ? _glyphId[firstGlyph.code]!
            : 0;
        final lastGlyphId = lastGlyph != null ? _glyphId[lastGlyph.code]! : 0;
        final glyphIdRange = lastGlyphId - firstGlyphId;
        final exceedsFormat0Limit = glyphIdRange > 255;

        print(
          '[CmapTable] Range ${range.first}-${range.last}: isSparse=$isSparse, glyphIdRange=$glyphIdRange, exceedsFormat0Limit=$exceedsFormat0Limit',
        );

        // Check if glyph IDs are sequential (required for sparse_tiny)
        bool areGlyphIdsSequential = true;
        if (range.length > 1) {
          int expectedId = firstGlyphId;
          for (int j = 0; j < range.length; j++) {
            final glyph = _glyphByCode(range[j]);
            if (glyph == null || _glyphId[glyph.code]! != expectedId) {
              areGlyphIdsSequential = false;
              break;
            }
            expectedId++;
          }
        }

        if (isSparse || exceedsFormat0Limit) {
          // Use sparse format, but only use sparse_tiny if glyph IDs are sequential
          if (range.length <= 8 && areGlyphIdsSequential) {
            result.add({'format': 'sparse_tiny', 'codepoints': range});
            print(
              '[CmapTable] Using sparse_tiny format for range ${range.first}-${range.last}',
            );
          } else {
            result.add({'format': 'sparse', 'codepoints': range});
            print(
              '[CmapTable] Using sparse format for range ${range.first}-${range.last}',
            );
          }
        } else {
          result.add({
            'format': range.length <= 16 ? 'format0_tiny' : 'format0',
            'codepoints': range,
          });
          print(
            '[CmapTable] Using ${range.length <= 16 ? 'format0_tiny' : 'format0'} format for range ${range.first}-${range.last}',
          );
        }

        start = i;
      }
    }

    return result;
  }

  /// Create subtable header
  Uint8List _createSubHeader(
    int rangeStart,
    int rangeLen,
    int glyphIdOffset,
    int total,
    int type,
  ) {
    final buffer = Uint8List(16);
    final byteData = buffer.buffer.asByteData();

    // Offset will be set later
    byteData.setUint32(4, rangeStart, Endian.little);
    byteData.setUint16(8, rangeLen, Endian.little);
    byteData.setUint16(10, glyphIdOffset, Endian.little);
    byteData.setUint16(12, total, Endian.little);
    buffer[14] = type;

    return buffer;
  }

  /// Update all subtable offsets
  void _updateAllOffsets() {
    int offset = headLength;
    offset += _subHeads.fold(0, (sum, head) => sum + head.length);

    for (int i = 0; i < _subHeads.length; i++) {
      final headData = _subHeads[i];
      headData.buffer.asByteData().setUint32(0, offset, Endian.little);
      offset += _subData[i].length;
    }
  }

  /// Find glyph by code
  FontGlyph? _glyphByCode(int code) {
    for (final glyph in _fontData.glyphs) {
      if (glyph.code == code) return glyph;
    }
    return null;
  }

  /// Create format 0 data
  Uint8List _createFormat0Data(int minCode, int maxCode, int startGlyphId) {
    final data = <int>[];

    for (int i = minCode; i <= maxCode; i++) {
      final glyph = _glyphByCode(i);

      if (glyph == null) {
        data.add(0);
        continue;
      }

      final idDelta = _glyphId[glyph.code]! - startGlyphId;
      if (idDelta < 0 || idDelta > 255) {
        throw Exception('Glyph ID delta out of Format 0 range');
      }

      data.add(idDelta);
    }

    return FontUtils.alignBuffer4(Uint8List.fromList(data));
  }

  /// Create sparse data
  Uint8List _createSparseData(List<int> codepoints, int startGlyphId) {
    final codepointsList = <int>[];
    final idsList = <int>[];

    for (final code in codepoints) {
      final glyph = _glyphByCode(code)!;
      final id = _glyphId[glyph.code]!;

      final codeDelta = code - codepoints.first;
      final idDelta = id - startGlyphId;

      if (codeDelta < 0 || codeDelta > 65535) {
        throw Exception('Codepoint delta out of range');
      }
      if (id < 0 || id > 65535) {
        throw Exception('Glyph ID out of range: $id');
      }

      codepointsList.add(codeDelta);
      idsList.add(idDelta);
    }

    return FontUtils.alignBuffer4(
      Uint8List.fromList([
        ...FontUtils.uint16ListToBuffer(codepointsList),
        ...FontUtils.uint16ListToBuffer(idsList),
      ]),
    );
  }

  /// Create sparse tiny data
  Uint8List _createSparseTinyData(List<int> codepoints, int startGlyphId) {
    final codepointsList = <int>[];

    for (final code in codepoints) {
      final glyph = _glyphByCode(code)!;
      final id = _glyphId[glyph.code]!;

      final codeDelta = code - codepoints.first;

      if (codeDelta < 0 || codeDelta > 65535) {
        throw Exception('Codepoint delta out of range');
      }

      codepointsList.add(codeDelta);
    }

    return FontUtils.alignBuffer4(FontUtils.uint16ListToBuffer(codepointsList));
  }

  /// Convert the cmap table to binary format
  Uint8List toBin() {
    _compile();

    final parts = <Uint8List>[];
    parts.add(Uint8List(headLength));
    parts.addAll(_subHeads);
    parts.addAll(_subData);

    final buffer = _concatUint8Lists(parts);

    // Set header fields
    final byteData = buffer.buffer.asByteData();
    byteData.setUint32(0, buffer.length, Endian.little);

    // Set table marker
    for (int i = 0; i < 4; i++) {
      buffer[4 + i] = label.codeUnitAt(i);
    }

    byteData.setUint32(8, _subHeads.length, Endian.little);

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
