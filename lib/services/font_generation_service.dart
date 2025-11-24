import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:app/services/font_extraction_service.dart';
import 'package:dart_lv_font_conv/dart_lv_font_conv.dart';
import 'package:app/models/switch_hub/config.dart';

/// Service for generating optimized LVGL font data from SwitchHub configuration
/// using the built-in NotoSansSC-Regular.ttf font file
/// This service implements efficient on-demand character extraction using dart_lv_font_conv library
class FontGenerationService {
  static const String _assetFontPath = 'assets/NotoSansSC-Regular.ttf';

  // Cache for generated fonts to avoid re-generation
  static final Map<String, Map<String, dynamic>> _fontCache = {};
  static final Map<String, Uint8List> _binaryFontCache = {};

  // Maximum number of cached fonts
  static const int _maxCacheSize = 10;

  /// Generate font data for all characters used in the SwitchHub configuration
  ///
  /// [config] - The SwitchHub configuration containing UI text
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [includeCommonChars] - Whether to include common characters (default: false)
  ///
  /// Returns [Map<String, dynamic>] containing the generated font data
  static Future<Map<String, dynamic>> generateFontData(
    SwitchHubConfig config, {
    int fontSize = 16,
    int bpp = 2,
    bool includeCommonChars = false,
  }) async {
    // Create a cache key
    final cacheKey = _createFontCacheKey(
      config,
      fontSize,
      bpp,
      includeCommonChars,
    );

    // Check if we already have this font cached
    if (_fontCache.containsKey(cacheKey)) {
      print('[FontGeneration] Using cached font data for key: $cacheKey');
      return _fontCache[cacheKey]!;
    }

    // Extract characters from configuration
    final characters = FontExtractionService.getCharacterSet(
      config,
      includeCommonChars: includeCommonChars,
    );

    // Convert Set to List and sort for consistency
    final characterList = characters.toList()..sort();

    // Load the built-in font file
    print('[FontGeneration] Loading built-in font file...');
    final fontBytes = await _loadBuiltInFont();

    // Prepare arguments for external library
    final args = <String, dynamic>{
      'font': [
        {
          'source_path': 'built-in.ttf',
          'source_bin': fontBytes,
          'ranges': [
            {
              'range': characterList.map((c) => c.codeUnitAt(0)).toList(),
              'symbols': null,
            }
          ],
        }
      ],
      'size': fontSize,
      'bpp': bpp,
      'format': 'dump',
      'auto_level2': false,
      'auto_center': false,
      'compress': true,
      'compress_pre': false,
      'use_color': false,
      'serif': false,
      'subpixel': false,
      'retain_1px': false,
      'no_kerning': true,
      'no_compression': false,
      'auto_font_name': false,
      'lv_font': true,
      'output': 'dump.txt',
    };

    print('[FontGeneration] Extracting ${characterList.length} characters...');
    final result = await convert(args);

    // Extract font data from result
    final dumpData = result.values.first;
    final fontData = _parseDumpData(dumpData);

    // Cache the result
    _cacheFontData(cacheKey, fontData);

    return fontData;
  }

  /// Generate binary font data for all characters used in the SwitchHub configuration
  ///
  /// [config] - The SwitchHub configuration containing UI text
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [includeCommonChars] - Whether to include common characters (default: false)
  /// [noCompress] - Disable RLE compression (default: false)
  /// [noKerning] - Drop kerning info to reduce size (default: true)
  ///
  /// Returns [Uint8List] containing the binary font data
  static Future<Uint8List> generateBinaryFont(
    SwitchHubConfig config, {
    int fontSize = 16,
    int bpp = 2,
    bool includeCommonChars = false,
    bool noCompress = false,
    bool noKerning = true,
  }) async {
    // Create a cache key
    final cacheKey = _createBinaryFontCacheKey(
      config,
      fontSize,
      bpp,
      includeCommonChars,
      noCompress,
      noKerning,
    );

    // Check if we already have this binary font cached
    if (_binaryFontCache.containsKey(cacheKey)) {
      print(
        '[FontGeneration] Using cached binary font data for key: $cacheKey',
      );
      return _binaryFontCache[cacheKey]!;
    }

    // Extract characters from configuration
    final characters = FontExtractionService.getCharacterSet(
      config,
      includeCommonChars: includeCommonChars,
    );

    // Convert Set to List and sort for consistency
    final characterList = characters.toList()..sort();

    // Load the built-in font file
    print('[FontGeneration] Loading built-in font file...');
    final fontBytes = await _loadBuiltInFont();

    // Prepare arguments for external library for binary format
    final args = <String, dynamic>{
      'font': [
        {
          'source_path': 'built-in.ttf',
          'source_bin': fontBytes,
          'ranges': [
            {
              'range': characterList.map((c) => c.codeUnitAt(0)).toList(),
              'symbols': null,
            }
          ],
        }
      ],
      'size': fontSize,
      'bpp': bpp,
      'format': 'bin',
      'auto_level2': false,
      'auto_center': false,
      'compress': !noCompress,
      'compress_pre': false,
      'use_color': false,
      'serif': false,
      'subpixel': false,
      'retain_1px': false,
      'no_kerning': noKerning,
      'no_compression': noCompress,
      'auto_font_name': false,
      'lv_font': true,
      'output': 'font.bin',
    };

    print('[FontGeneration] Extracting ${characterList.length} characters...');
    final result = await convert(args);

    // Extract binary data from result
    final binaryData = Uint8List.fromList(result.values.first);

    // Cache the result
    _cacheBinaryFontData(cacheKey, binaryData);

    return binaryData;
  }

  /// Generate font data with custom character set
  ///
  /// [characters] - List of characters to include in the font
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  ///
  /// Returns [Map<String, dynamic>] containing the generated font data
  static Future<Map<String, dynamic>> generateFontDataForCharacters(
    List<String> characters, {
    int fontSize = 16,
    int bpp = 2,
  }) async {
    // Create a cache key
    final cacheKey = _createCharacterFontCacheKey(characters, fontSize, bpp);

    // Check if we already have this font cached
    if (_fontCache.containsKey(cacheKey)) {
      print('[FontGeneration] Using cached font data for key: $cacheKey');
      return _fontCache[cacheKey]!;
    }

    // Remove duplicates and sort for consistency
    final uniqueCharacters = characters.toSet().toList()..sort();

    // Load the built-in font file
    final fontBytes = await _loadBuiltInFont();

    // Prepare arguments for external library
    final args = <String, dynamic>{
      'font': [
        {
          'source_path': 'built-in.ttf',
          'source_bin': fontBytes,
          'ranges': [
            {
              'range': uniqueCharacters.map((c) => c.codeUnitAt(0)).toList(),
              'symbols': null,
            }
          ],
        }
      ],
      'size': fontSize,
      'bpp': bpp,
      'format': 'dump',
      'auto_level2': false,
      'auto_center': false,
      'compress': true,
      'compress_pre': false,
      'use_color': false,
      'serif': false,
      'subpixel': false,
      'retain_1px': false,
      'no_kerning': true,
      'no_compression': false,
      'auto_font_name': false,
      'lv_font': true,
      'output': 'dump.txt',
    };

    final result = await convert(args);
    final dumpData = result.values.first;
    final fontData = _parseDumpData(dumpData);

    // Cache the result
    _cacheFontData(cacheKey, fontData);

    return fontData;
  }

  /// Generate binary font data with custom character set
  ///
  /// [characters] - List of characters to include in the font
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [noCompress] - Disable RLE compression (default: false)
  /// [noKerning] - Drop kerning info to reduce size (default: true)
  ///
  /// Returns [Uint8List] containing the binary font data
  static Future<Uint8List> generateBinaryFontForCharacters(
    List<String> characters, {
    int fontSize = 16,
    int bpp = 2,
    bool noCompress = false,
    bool noKerning = true,
  }) async {
    // Create a cache key
    final cacheKey = _createCharacterBinaryFontCacheKey(
      characters,
      fontSize,
      bpp,
      noCompress,
      noKerning,
    );

    // Check if we already have this binary font cached
    if (_binaryFontCache.containsKey(cacheKey)) {
      print(
        '[FontGeneration] Using cached binary font data for key: $cacheKey',
      );
      return _binaryFontCache[cacheKey]!;
    }

    // Remove duplicates and sort for consistency
    final uniqueCharacters = characters.toSet().toList()..sort();

    // Load the built-in font file
    final fontBytes = await _loadBuiltInFont();

    // Prepare arguments for external library for binary format
    final args = <String, dynamic>{
      'font': [
        {
          'source_path': 'built-in.ttf',
          'source_bin': fontBytes,
          'ranges': [
            {
              'range': uniqueCharacters.map((c) => c.codeUnitAt(0)).toList(),
              'symbols': null,
            }
          ],
        }
      ],
      'size': fontSize,
      'bpp': bpp,
      'format': 'bin',
      'auto_level2': false,
      'auto_center': false,
      'compress': !noCompress,
      'compress_pre': false,
      'use_color': false,
      'serif': false,
      'subpixel': false,
      'retain_1px': false,
      'no_kerning': noKerning,
      'no_compression': noCompress,
      'auto_font_name': false,
      'lv_font': true,
      'output': 'font.bin',
    };

    final result = await convert(args);
    final binaryData = Uint8List.fromList(result.values.first);

    // Cache the result
    _cacheBinaryFontData(cacheKey, binaryData);

    return binaryData;
  }

  /// Generate minimal font data for a single character
  ///
  /// [character] - Single character to include in the font
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  ///
  /// Returns [Map<String, dynamic>] containing the generated font data
  static Future<Map<String, dynamic>> generateMinimalFontData(
    String character, {
    int fontSize = 16,
    int bpp = 2,
  }) async {
    if (character.isEmpty) {
      throw ArgumentError('Character cannot be empty');
    }

    // Create a cache key
    final cacheKey = _createMinimalFontCacheKey(character, fontSize, bpp);

    // Check if we already have this font cached
    if (_fontCache.containsKey(cacheKey)) {
      print(
        '[FontGeneration] Using cached minimal font data for character: $character',
      );
      return _fontCache[cacheKey]!;
    }

    // Load the built-in font file
    final fontBytes = await _loadBuiltInFont();

    // Prepare arguments for external library
    final args = <String, dynamic>{
      'font': [
        {
          'source_path': 'built-in.ttf',
          'source_bin': fontBytes,
          'ranges': [
            {
              'range': [character.codeUnitAt(0)],
              'symbols': null,
            }
          ],
        }
      ],
      'size': fontSize,
      'bpp': bpp,
      'format': 'dump',
      'auto_level2': false,
      'auto_center': false,
      'compress': true,
      'compress_pre': false,
      'use_color': false,
      'serif': false,
      'subpixel': false,
      'retain_1px': false,
      'no_kerning': true,
      'no_compression': false,
      'auto_font_name': false,
      'lv_font': true,
      'output': 'dump.txt',
    };

    final result = await convert(args);
    final dumpData = result.values.first;
    final fontData = _parseDumpData(dumpData);

    // Cache the result
    _cacheFontData(cacheKey, fontData);

    return fontData;
  }

  /// Load the built-in NotoSansSC-Regular.ttf font file
  static Future<Uint8List> _loadBuiltInFont() async {
    try {
      // Try to load from assets first
      final byteData = await rootBundle.load(_assetFontPath);
      return byteData.buffer.asUint8List();
    } catch (e) {
      // If loading from assets fails, try to load from file system
      // This might be useful for testing or development
      try {
        final file = File(_assetFontPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (fileError) {
        // Ignore file system error
      }

      // If both methods fail, throw an exception
      throw Exception(
        'Failed to load built-in font: $_assetFontPath. Error: $e',
      );
    }
  }

  /// Get font size information for the generated font
  ///
  /// [config] - The SwitchHub configuration
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [includeCommonChars] - Whether to include common characters (default: false)
  ///
  /// Returns a Map containing font size information
  static Future<Map<String, dynamic>> getFontInfo(
    SwitchHubConfig config, {
    int fontSize = 16,
    int bpp = 2,
    bool includeCommonChars = false,
  }) async {
    final binaryData = await generateBinaryFont(
      config,
      fontSize: fontSize,
      bpp: bpp,
      includeCommonChars: includeCommonChars,
    );

    final characters = FontExtractionService.getCharacterSet(
      config,
      includeCommonChars: includeCommonChars,
    );

    return {
      'characterCount': characters.length,
      'fontSize': fontSize,
      'bpp': bpp,
      'binarySize': binaryData.length,
      'includesCommonChars': includeCommonChars,
    };
  }

  /// Create a cache key for font data
  static String _createFontCacheKey(
    SwitchHubConfig config,
    int fontSize,
    int bpp,
    bool includeCommonChars,
  ) {
    // Extract unique characters from config
    final characters = FontExtractionService.extractUniqueCharacters(config);
    final characterList = characters.toList()..sort();
    final characterString = characterList.join('');

    return '${characterString}_${fontSize}_${bpp}_$includeCommonChars';
  }

  /// Create a cache key for binary font data
  static String _createBinaryFontCacheKey(
    SwitchHubConfig config,
    int fontSize,
    int bpp,
    bool includeCommonChars,
    bool noCompress,
    bool noKerning,
  ) {
    final fontKey = _createFontCacheKey(
      config,
      fontSize,
      bpp,
      includeCommonChars,
    );
    return '${fontKey}_${noCompress}_$noKerning';
  }

  /// Create a cache key for character-based font data
  static String _createCharacterFontCacheKey(
    List<String> characters,
    int fontSize,
    int bpp,
  ) {
    // Remove duplicates and sort for consistent cache keys
    final uniqueCharacters = characters.toSet().toList()..sort();
    final characterString = uniqueCharacters.join('');

    return '${characterString}_${fontSize}_$bpp';
  }

  /// Create a cache key for character-based binary font data
  static String _createCharacterBinaryFontCacheKey(
    List<String> characters,
    int fontSize,
    int bpp,
    bool noCompress,
    bool noKerning,
  ) {
    final fontKey = _createCharacterFontCacheKey(characters, fontSize, bpp);
    return '${fontKey}_${noCompress}_$noKerning';
  }

  /// Create a cache key for minimal font data
  static String _createMinimalFontCacheKey(
    String character,
    int fontSize,
    int bpp,
  ) {
    return '${character}_${fontSize}_$bpp';
  }

  /// Cache font data with size limit
  static void _cacheFontData(String key, Map<String, dynamic> fontData) {
    // If cache is full, remove the oldest entry
    if (_fontCache.length >= _maxCacheSize) {
      final firstKey = _fontCache.keys.first;
      _fontCache.remove(firstKey);
      print('[FontGeneration] Evicted font data from cache: $firstKey');
    }

    _fontCache[key] = fontData;
    print('[FontGeneration] Cached font data with key: $key');
  }

  /// Cache binary font data with size limit
  static void _cacheBinaryFontData(String key, Uint8List binaryData) {
    // If cache is full, remove the oldest entry
    if (_binaryFontCache.length >= _maxCacheSize) {
      final firstKey = _binaryFontCache.keys.first;
      _binaryFontCache.remove(firstKey);
      print('[FontGeneration] Evicted binary font data from cache: $firstKey');
    }

    _binaryFontCache[key] = binaryData;
    print(
      '[FontGeneration] Cached binary font data with key: $key (size: ${binaryData.length} bytes)',
    );
  }

  /// Clear all font caches
  static void clearCache() {
    _fontCache.clear();
    _binaryFontCache.clear();
    print('[FontGeneration] Cleared all font caches');
  }

  /// Parse dump data from external library format to internal format
  static Map<String, dynamic> _parseDumpData(List<int> dumpData) {
    // For now, return a basic structure. This can be enhanced based on needs
    return {
      'glyphs': [],
      'ascent': 0,
      'descent': 0,
      'rawData': dumpData,
    };
  }

  /// Get cache statistics
  static Map<String, dynamic> getCacheStats() {
    return {
      'fontDataCacheSize': _fontCache.length,
      'binaryFontCacheSize': _binaryFontCache.length,
      'maxCacheSize': _maxCacheSize,
    };
  }

  /// Generate binary font data with alphanumeric characters always included
  ///
  /// This method generates a font that contains both the characters extracted
  /// from the configuration AND a comprehensive set of alphanumeric characters
  /// (uppercase, lowercase, digits, and common punctuation).
  ///
  /// [config] - The SwitchHub configuration containing UI text
  /// [fontSize] - Font size in pixels (default: 16)
  /// [bpp] - Bits per pixel for anti-aliasing (default: 2)
  /// [noCompress] - Disable RLE compression (default: false)
  /// [noKerning] - Drop kerning info to reduce size (default: true)
  ///
  /// Returns [Uint8List] containing the binary font data
  static Future<Uint8List> generateBinaryFontWithAlphanumeric(
    SwitchHubConfig config, {
    int fontSize = 16,
    int bpp = 2,
    bool noCompress = false,
    bool noKerning = true,
  }) async {
    // Get extracted characters from config
    final configChars = FontExtractionService.getCharacterSet(config, includeCommonChars: false);

    // Get alphanumeric character set
    final alphanumericChars = _getAlphanumericCharacterSet();

    // Combine both sets
    final allChars = <String>{};
    allChars.addAll(configChars);
    allChars.addAll(alphanumericChars);

    // Convert to sorted list for consistency
    final characterList = allChars.toList()..sort();

    print('[FontGeneration] Generating font with ${characterList.length} characters (config: ${configChars.length}, alphanumeric: ${alphanumericChars.length})');

    // Load the built-in font file
    final fontBytes = await _loadBuiltInFont();

    // Prepare arguments for external library for binary format
    final args = <String, dynamic>{
      'font': [
        {
          'source_path': 'built-in.ttf',
          'source_bin': fontBytes,
          'ranges': [
            {
              'range': characterList.map((c) => c.codeUnitAt(0)).toList(),
              'symbols': null,
            }
          ],
        }
      ],
      'size': fontSize,
      'bpp': bpp,
      'format': 'bin',
      'auto_level2': false,
      'auto_center': false,
      'compress': !noCompress,
      'compress_pre': false,
      'use_color': false,
      'serif': false,
      'subpixel': false,
      'retain_1px': false,
      'no_kerning': noKerning,
      'no_compression': noCompress,
      'auto_font_name': false,
      'lv_font': true,
      'output': 'font.bin',
    };

    final result = await convert(args);
    final binaryData = Uint8List.fromList(result.values.first);

    return binaryData;
  }

  /// Get comprehensive alphanumeric character set
  static Set<String> _getAlphanumericCharacterSet() {
    final characters = <String>{};

    // Add all uppercase letters (A-Z)
    for (int i = 65; i <= 90; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add all lowercase letters (a-z)
    for (int i = 97; i <= 122; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add all digits (0-9)
    for (int i = 48; i <= 57; i++) {
      characters.add(String.fromCharCode(i));
    }

    // Add common punctuation and symbols
    final punctuation = ' !@#\$%^&*()_+-=[]{}|;:,.<>?/~`\'"\\';
    characters.addAll(punctuation.split(''));

    return characters;
  }
}
