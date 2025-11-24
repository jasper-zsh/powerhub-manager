import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models/font_data.dart';
import 'models/font_glyph.dart';
import 'font_converter_service.dart';

/// Parses TTF fonts and extracts glyph information compatible with lv_font_conv.
class TtfParser {
  static const int _sfntVersion = 0x00010000;
  static const int _ttcTag = 0x74746366; // 'ttcf'
  static const int _trueTypeTag = 0x74727565; // 'true'
  static const int _otfTag = 0x4F54544F; // 'OTTO'

  // Cached fonts indexed by hash of their raw bytes.
  static final Map<String, _LoadedFont> _fontCache = {};

  /// Parse a font file and extract glyph data for the provided characters.
  static Future<FontData> parseTtfFile(
    String filePath,
    List<String> characters, {
    int size = 16,
    int bpp = 2,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('TTF file not found: $filePath');
    }

    final bytes = await file.readAsBytes();
    return parseTtfBytes(bytes, characters, size: size, bpp: bpp);
  }

  /// Parse raw font bytes and extract glyphs.
  static Future<FontData> parseTtfBytes(
    Uint8List bytes,
    List<String> characters, {
    int size = 16,
    int bpp = 2,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final fontKey = _createFontKey(bytes);
    var loadedFont = _fontCache[fontKey];

    if (loadedFont == null) {
      final tables = _parseFontStructure(bytes);
      loadedFont = await _loadFont(bytes, fontKey, tables);
      _fontCache[fontKey] = loadedFont;
    }

    final glyphs = <FontGlyph>[];
    final seen = <int>{};
    final runes = characters.expand((c) => c.runes);

    for (final codePoint in runes) {
      if (seen.contains(codePoint)) continue;
      seen.add(codePoint);

      // Check cmap to ensure glyph exists in the font before rendering.
      if (loadedFont.tables.cmapTable.getGlyphIndex(codePoint) == 0) {
        continue;
      }

      final glyph = await _renderGlyph(loadedFont, codePoint, size);
      if (glyph != null) glyphs.add(glyph);
    }

    if (glyphs.isEmpty) {
      return FontConverterService.createBasicFontData(
        size: size,
        glyphs: const [],
        ascent: 0,
        descent: 0,
        underlinePosition: -(size * 0.1).round(),
        underlineThickness: (size * 0.05).round(),
      );
    }

    glyphs.sort((a, b) => a.code.compareTo(b.code));

    final metrics = _fontMetrics.fromTables(
      loadedFont.tables,
      size,
    );

    return FontConverterService.createBasicFontData(
      size: size,
      glyphs: glyphs,
      ascent: glyphs
          .map((g) => g.bbox.y + g.bbox.height)
          .reduce((a, b) => a > b ? a : b),
      descent: glyphs.map((g) => g.bbox.y).reduce((a, b) => a < b ? a : b),
      typoAscent: metrics.typoAscent,
      typoDescent: metrics.typoDescent,
      typoLineGap: metrics.typoLineGap,
      underlinePosition: metrics.underlinePosition,
      underlineThickness: metrics.underlineThickness,
    );
  }

  /// Reset parser caches.
  static void clearCache() {
    _fontCache.clear();
  }

  static String _createFontKey(Uint8List bytes) {
    final sampleSize = bytes.length > 2048 ? 2048 : bytes.length;
    int hash = bytes.length;

    for (int i = 0; i < sampleSize; i++) {
      hash = ((hash << 5) - hash + bytes[i]) & 0xFFFFFFFF;
    }

    return '$hash.${bytes.length}';
  }

  static Future<_LoadedFont> _loadFont(
    Uint8List bytes,
    String key,
    _TtfFontData tables,
  ) async {
    final family = 'lv_font_${key.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
    final loader = FontLoader(family);
    final byteData = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    loader.addFont(Future.value(byteData));
    await loader.load();

    return _LoadedFont(family, tables);
  }

  static Future<FontGlyph?> _renderGlyph(
    _LoadedFont font,
    int codePoint,
    int size,
  ) async {
    final cacheKey = '$codePoint@$size';
    final cached = font.glyphCache[cacheKey];
    if (cached != null) return cached;

    final paragraphBuilder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontFamily: font.fontFamily,
        fontSize: size.toDouble(),
        textDirection: ui.TextDirection.ltr,
      ),
    );

    paragraphBuilder.pushStyle(
      ui.TextStyle(color: const ui.Color(0xFFFFFFFF)),
    );

    final glyphText = String.fromCharCode(codePoint);
    paragraphBuilder.addText(glyphText);

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ui.ParagraphConstraints(width: size * 2.0));

    final boxes = paragraph.getBoxesForRange(0, glyphText.length);
    final lineMetrics = paragraph.computeLineMetrics();
    final advanceWidth = lineMetrics.isNotEmpty
        ? lineMetrics.first.width
        : paragraph.longestLine;

    if (boxes.isEmpty) {
      final glyph = FontGlyph(
        code: codePoint,
        advanceWidth: advanceWidth,
        bbox: const BoundingBox(x: 0, y: 0, width: 0, height: 0),
        kerning: const <int, double>{},
        pixels: const [],
      );

      font.glyphCache[cacheKey] = glyph;
      return glyph;
    }

    final box = boxes.first;
    final glyphWidth = (box.right - box.left).ceil();
    final glyphHeight = (box.bottom - box.top).ceil();

    if (glyphWidth <= 0 || glyphHeight <= 0) {
      final glyph = FontGlyph(
        code: codePoint,
        advanceWidth: advanceWidth,
        bbox: BoundingBox(
          x: box.left.round(),
          y: (paragraph.alphabeticBaseline - box.top - glyphHeight).round(),
          width: 0,
          height: 0,
        ),
        kerning: const <int, double>{},
        pixels: const [],
      );

      font.glyphCache[cacheKey] = glyph;
      return glyph;
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawParagraph(paragraph, ui.Offset.zero);

    final int imgWidth =
        (paragraph.width.ceil()).clamp(1, size * 4) as int;
    final int imgHeight =
        (paragraph.height.ceil()).clamp(1, size * 4) as int;

    final picture = recorder.endRecording();
    final image = await picture.toImage(imgWidth, imgHeight);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    final pixels = <List<int>>[];
    final data = byteData!;
    for (int y = 0; y < glyphHeight; y++) {
      final row = <int>[];
      final srcY = _clampInt((box.top + y).round(), 0, imgHeight - 1);
      for (int x = 0; x < glyphWidth; x++) {
        final srcX = _clampInt((box.left + x).round(), 0, imgWidth - 1);
        final idx = (srcY * imgWidth + srcX) * 4;
        row.add(data.getUint8(idx + 3));
      }
      pixels.add(row);
    }

    final baselineToTop = paragraph.alphabeticBaseline - box.top;
    final bboxY = (baselineToTop - glyphHeight).round();
    final glyph = FontGlyph(
      code: codePoint,
      advanceWidth: advanceWidth,
      bbox: BoundingBox(
        x: box.left.round(),
        y: bboxY,
        width: glyphWidth,
        height: glyphHeight,
      ),
      kerning: const <int, double>{},
      pixels: pixels,
    );

    font.glyphCache[cacheKey] = glyph;
    return glyph;
  }
}

class _LoadedFont {
  final String fontFamily;
  final _TtfFontData tables;
  final Map<String, FontGlyph> glyphCache = {};

  _LoadedFont(this.fontFamily, this.tables);
}

class _fontMetrics {
  final int typoAscent;
  final int typoDescent;
  final int typoLineGap;
  final int underlinePosition;
  final int underlineThickness;

  const _fontMetrics({
    required this.typoAscent,
    required this.typoDescent,
    required this.typoLineGap,
    required this.underlinePosition,
    required this.underlineThickness,
  });

  static _fontMetrics fromTables(_TtfFontData tables, int size) {
    final unitsPerEm = tables.headTable.unitsPerEm;
    final scale = unitsPerEm > 0 ? size / unitsPerEm : 1.0;

    int typoAscent = (size * 0.8).round();
    int typoDescent = -(size * 0.2).round();
    int typoLineGap = (size * 0.1).round();
    int underlinePosition = -(size * 0.1).round();
    int underlineThickness = (size * 0.05).round();

    if (tables.os2Table != null) {
      typoAscent = (tables.os2Table!.typoAscent * scale).round();
      typoDescent = (tables.os2Table!.typoDescent * scale).round();
      typoLineGap = (tables.os2Table!.typoLineGap * scale).round();
    }

    if (tables.postTable != null) {
      underlinePosition = (tables.postTable!.underlinePosition * scale).round();
      underlineThickness =
          (tables.postTable!.underlineThickness * scale).round();
    }

    return _fontMetrics(
      typoAscent: typoAscent,
      typoDescent: typoDescent,
      typoLineGap: typoLineGap,
      underlinePosition: underlinePosition,
      underlineThickness: underlineThickness,
    );
  }
}

class _TtfFontData {
  final Uint8List bytes;
  final Map<String, _TableEntry> tables;
  final _CmapTable cmapTable;
  final _HeadTable headTable;
  final _Os2Table? os2Table;
  final _PostTable? postTable;

  _TtfFontData(
    this.bytes,
    this.tables,
    this.cmapTable,
    this.headTable,
    this.os2Table,
    this.postTable,
  );
}

class _TableEntry {
  final String tag;
  final int offset;
  final int length;
  final int checksum;

  const _TableEntry({
    required this.tag,
    required this.offset,
    required this.length,
    required this.checksum,
  });
}

_TtfFontData _parseFontStructure(Uint8List bytes) {
  final reader = _ByteReader(bytes);
  final version = reader.readUint32BE();

  if (version == TtfParser._ttcTag) {
    throw Exception('TTC fonts are not supported');
  }

  if (version != TtfParser._sfntVersion &&
      version != TtfParser._trueTypeTag &&
      version != TtfParser._otfTag) {
    throw Exception('Unsupported TTF format: 0x${version.toRadixString(16)}');
  }

  final numTables = reader.readUint16BE();
  reader.skip(6);

  final tables = <String, _TableEntry>{};

  for (int i = 0; i < numTables; i++) {
    final tagValue = reader.readUint32BE();
    final tag = String.fromCharCodes([
      (tagValue >> 24) & 0xFF,
      (tagValue >> 16) & 0xFF,
      (tagValue >> 8) & 0xFF,
      tagValue & 0xFF,
    ]);

    final checksum = reader.readUint32BE();
    final offset = reader.readUint32BE();
    final length = reader.readUint32BE();

    tables[tag] = _TableEntry(
      tag: tag,
      offset: offset,
      length: length,
      checksum: checksum,
    );
  }

  final cmapEntry = tables['cmap'];
  if (cmapEntry == null) {
    throw Exception('Required cmap table not found');
  }

  final headEntry = tables['head'];
  if (headEntry == null) {
    throw Exception('Required head table not found');
  }

  final cmap = _CmapTable(bytes, cmapEntry);
  final head = _HeadTable(bytes, headEntry.offset);

  _Os2Table? os2;
  if (tables.containsKey('OS/2')) {
    os2 = _Os2Table(bytes, tables['OS/2']!.offset);
  }

  _PostTable? post;
  if (tables.containsKey('post')) {
    post = _PostTable(bytes, tables['post']!.offset);
  }

  return _TtfFontData(bytes, tables, cmap, head, os2, post);
}

class _ByteReader {
  final ByteData _data;
  int _offset;

  _ByteReader(Uint8List bytes)
      : _data = ByteData.view(
          bytes.buffer,
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ),
        _offset = 0;

  int readUint16BE() {
    final value = _data.getUint16(_offset, Endian.big);
    _offset += 2;
    return value;
  }

  int readUint32BE() {
    final value = _data.getUint32(_offset, Endian.big);
    _offset += 4;
    return value;
  }

  void skip(int bytes) {
    _offset += bytes;
  }
}

class _CmapTable {
  final ByteData _data;
  final int format;
  final int offset;

  factory _CmapTable(Uint8List bytes, _TableEntry entry) {
    final data = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final info = _findUnicodeSubtable(bytes, entry);
    return _CmapTable._(data, info.format, info.offset);
  }

  _CmapTable._(this._data, this.format, this.offset);

  int getGlyphIndex(int charCode) {
    if (format == 4) {
      int cursor = offset + 2; // format already read
      cursor += 2;
      cursor += 2; // language
      final segCountX2 = _data.getUint16(cursor, Endian.big);
      cursor += 2;
      final segCount = segCountX2 ~/ 2;

      cursor += 6; // searchRange, entrySelector, rangeShift

      final endCodes = List<int>.generate(
        segCount,
        (i) => _data.getUint16(cursor + i * 2, Endian.big),
      );

      cursor += segCount * 2;
      cursor += 2; // reservedPad

      final startCodes = List<int>.generate(
        segCount,
        (i) => _data.getUint16(cursor + i * 2, Endian.big),
      );
      cursor += segCount * 2;

      final idDeltas = List<int>.generate(
        segCount,
        (i) => _data.getInt16(cursor + i * 2, Endian.big),
      );
      cursor += segCount * 2;

      final idRangeOffsets = List<int>.generate(
        segCount,
        (i) => _data.getUint16(cursor + i * 2, Endian.big),
      );
      cursor += segCount * 2;

      for (int i = 0; i < segCount; i++) {
        if (charCode < startCodes[i] || charCode > endCodes[i]) continue;

        if (idRangeOffsets[i] == 0) {
          return (charCode + idDeltas[i]) & 0xFFFF;
        }

        final ro = idRangeOffsets[i];
        final glyphIndexOffset = (ro ~/ 2) + (charCode - startCodes[i]);
        final pos = cursor + (i * 2) + ro + (glyphIndexOffset * 2);
        return _data.getUint16(pos, Endian.big);
      }

      return 0;
    }

    if (format == 12) {
      int cursor = offset + 4; // skip format + reserved
      cursor += 4; // length
      cursor += 4; // language
      final groupCount = _data.getUint32(cursor, Endian.big);
      cursor += 4;
      final groupsOffset = cursor;

      for (int i = 0; i < groupCount; i++) {
        final base = groupsOffset + i * 12;
        final startCode = _data.getUint32(base, Endian.big);
        final endCode = _data.getUint32(base + 4, Endian.big);
        final startGlyph = _data.getUint32(base + 8, Endian.big);

        if (charCode < startCode || charCode > endCode) continue;

        return (startGlyph + (charCode - startCode)) & 0xFFFFFFFF;
      }

      return 0;
    }

    return 0;
  }

  static _CmapSubtable _findUnicodeSubtable(
    Uint8List bytes,
    _TableEntry entry,
  ) {
    final data = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    int cursor = entry.offset;
    cursor += 2; // version
    final numTables = data.getUint16(cursor, Endian.big);
    cursor += 2;

    for (int i = 0; i < numTables; i++) {
      final platformId = data.getUint16(cursor, Endian.big);
      cursor += 2;
      final encodingId = data.getUint16(cursor, Endian.big);
      cursor += 2;
      final subOffset = data.getUint32(cursor, Endian.big);
      cursor += 4;

      if (platformId == 0 || (platformId == 3 && encodingId == 1)) {
        final offset = entry.offset + subOffset;
        final format = data.getUint16(offset, Endian.big);
        return _CmapSubtable(offset: offset, format: format);
      }
    }

    throw Exception('No Unicode cmap subtable found');
  }
}

class _CmapSubtable {
  final int offset;
  final int format;

  const _CmapSubtable({required this.offset, required this.format});
}

class _HeadTable {
  final int unitsPerEm;

  _HeadTable(Uint8List bytes, int offset)
      : unitsPerEm = ByteData.view(
          bytes.buffer,
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ).getUint16(offset + 18, Endian.big);
}

class _Os2Table {
  final int typoAscent;
  final int typoDescent;
  final int typoLineGap;

  _Os2Table(Uint8List bytes, int offset)
      : this._(
          ByteData.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          ),
          offset,
        );

  _Os2Table._(ByteData data, int offset)
      : typoAscent = data.getInt16(offset + 68, Endian.big),
        typoDescent = data.getInt16(offset + 70, Endian.big),
        typoLineGap = data.getInt16(offset + 72, Endian.big);
}

class _PostTable {
  final int underlinePosition;
  final int underlineThickness;

  _PostTable(Uint8List bytes, int offset)
      : this._(
          ByteData.view(
            bytes.buffer,
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          ),
          offset,
        );

  _PostTable._(ByteData data, int offset)
      : underlinePosition = data.getInt16(offset + 8, Endian.big),
        underlineThickness = data.getInt16(offset + 10, Endian.big);
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
