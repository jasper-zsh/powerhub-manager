import 'dart:typed_data';
import 'models/font_data.dart';
import 'models/font_options.dart';
import 'models/font_glyph.dart';
import 'utils/font_utils.dart';
import 'tables/head_table.dart';
import 'tables/cmap_table.dart';
import 'tables/glyf_table.dart';
import 'tables/loca_table.dart';
import 'tables/kern_table.dart';

/// Main font class that generates binary font data
class Font {
  final FontData _fontData;
  final FontOptions _options;

  // Map chars to IDs (zero is reserved)
  final Map<int, int> _glyphId = {0: 0};
  late int _lastId;

  // Font format parameters
  late int _minY;
  late int _maxY;
  late int _glyphIdFormat;
  late double _kerningScale;
  late int _advanceWidthFormat;
  late int _xyBits;
  late int _whBits;
  late int _advanceWidthBits;
  late bool _monospaced;
  late int _indexToLocFormat;
  late int _subpixelsMode;

  // Table instances
  late HeadTable _head;
  late CmapTable _cmap;
  late GlyfTable _glyf;
  late LocaTable _loca;
  late KernTable _kern;

  Font(this._fontData, this._options) {
    _createIds();
    _calculateFontMetrics();
    _initTables();
  }

  /// Create glyph IDs
  void _createIds() {
    _lastId = 1;

    for (final glyph in _fontData.glyphs) {
      _glyphId[glyph.code] = _lastId;
      _lastId++;
    }
  }

  /// Calculate font metrics
  void _calculateFontMetrics() {
    _minY = _fontData.glyphs
        .map((g) => g.bbox.y)
        .reduce((a, b) => a < b ? a : b);
    _maxY = _fontData.glyphs
        .map((g) => g.bbox.y + g.bbox.height)
        .reduce((a, b) => a > b ? a : b);

    // 0 => 1 byte, 1 => 2 bytes
    _glyphIdFormat = _glyphId.values.any((id) => id > 255) ? 1 : 0;

    // 1.0 by default, will be stored in font as FP12.4
    _kerningScale = 1.0;
    if (_fontData.glyphs.isNotEmpty) {
      final kerningMax = _fontData.glyphs
          .map((g) => g.kerning.values.map((v) => v.abs()))
          .expand((v) => v)
          .fold(0.0, (a, b) => a > b ? a : b);

      if (kerningMax >= 7.5) {
        _kerningScale = ((kerningMax / 7.5 * 16).ceil() / 16);
      }
    }

    // 0 => int, 1 => FP4
    _advanceWidthFormat = _hasKerning() ? 1 : 0;

    _xyBits = _fontData.glyphs
        .map(
          (g) => FontUtils.signedBits(
            g.bbox.x,
          ).clamp(FontUtils.signedBits(g.bbox.y), double.infinity),
        )
        .reduce((a, b) => a > b ? a : b)
        .toInt();

    _whBits = _fontData.glyphs
        .map(
          (g) => FontUtils.unsignedBits(
            g.bbox.width,
          ).clamp(FontUtils.unsignedBits(g.bbox.height), double.infinity),
        )
        .reduce((a, b) => a > b ? a : b)
        .toInt();

    _advanceWidthBits = _fontData.glyphs
        .map((g) => FontUtils.signedBits(_widthToInt(g.advanceWidth)))
        .reduce((a, b) => a > b ? a : b)
        .toInt();

    _monospaced = _fontData.glyphs.every(
      (v) => v.advanceWidth == _fontData.glyphs[0].advanceWidth,
    );

    // 0 => 2 bytes, 1 => 4 bytes
    _glyf = GlyfTable(
      _fontData,
      _options,
      _glyphId,
      _advanceWidthFormat,
      _xyBits,
      _whBits,
      _advanceWidthBits,
      _monospaced,
    );
    _indexToLocFormat = _glyf.getSize() > 65535 ? 1 : 0;

    _subpixelsMode = _options.lcd ? 1 : (_options.lcdV ? 2 : 0);
  }

  /// Initialize all tables
  void _initTables() {
    _head = HeadTable(
      _fontData,
      _options,
      _glyphId,
      _glyphIdFormat,
      _advanceWidthFormat,
      _xyBits,
      _whBits,
      _advanceWidthBits,
      _getCompressionCode(),
      _subpixelsMode,
      _kerningScale,
      _monospaced,
      _indexToLocFormat,
    );

    _cmap = CmapTable(_fontData, _glyphId);
    _glyf = GlyfTable(
      _fontData,
      _options,
      _glyphId,
      _advanceWidthFormat,
      _xyBits,
      _whBits,
      _advanceWidthBits,
      _monospaced,
    );
    _loca = _createLocaTable();
    _kern = KernTable(
      _fontData,
      _options,
      _glyphId,
      _glyphIdFormat,
      _kerningScale,
    );
  }

  /// Create loca table with proper offsets
  LocaTable _createLocaTable() {
    final offsets = <int>[];
    final glyphCount = _lastId;

    for (int i = 0; i < glyphCount; i++) {
      offsets.add(_glyf.getOffset(i));
    }

    return LocaTable(glyphCount, _indexToLocFormat, offsets);
  }

  /// Check if font has kerning
  bool _hasKerning() {
    if (_options.noKerning) return false;

    for (final glyph in _fontData.glyphs) {
      if (glyph.kerning.isNotEmpty) return true;
    }
    return false;
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

  /// Convert font to binary format
  Uint8List toBin() {
    final tables = <Uint8List>[];

    tables.add(_head.toBin());
    tables.add(_cmap.toBin());
    tables.add(_loca.toBin());
    tables.add(_glyf.toBin());
    tables.add(_kern.toBin());

    return _concatUint8Lists(tables);
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
