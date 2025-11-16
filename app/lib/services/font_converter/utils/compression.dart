import 'dart:typed_data';
import '../models/font_options.dart';

/// Bit stream writer for compression
class BitStream {
  final Uint8List _buffer;
  int _byteIndex = 0;
  int _bitIndex = 0;

  BitStream(this._buffer);

  /// Write bits to stream
  void writeBits(int value, int bitCount) {
    for (int i = 0; i < bitCount; i++) {
      final bit = (value >> i) & 1;
      _writeBit(bit);
    }
  }

  /// Write a single bit to stream
  void _writeBit(int bit) {
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

  /// Get the number of bytes used so far
  int get byteIndex => _bitIndex > 0 ? _byteIndex + 1 : _byteIndex;
}

/// Enhanced font compression with multiple algorithms
class FontCompression {
  /// Compress pixel data using the most appropriate algorithm
  static Uint8List compress(List<int> pixels, FontOptions options) {
    // Try different compression methods and choose the best one
    final methods = [
      () => _compressWithModifiedI3BN(pixels, options),
      () => _compressWithRLE(pixels, options),
      () => _compressWithHuffman(pixels, options),
      () => _compressWithLZ77(pixels, options),
    ];

    Uint8List? bestCompressed;
    int bestSize = pixels.length * options.bpp ~/ 8;

    for (final method in methods) {
      try {
        final compressed = method();
        if (compressed.length < bestSize) {
          bestSize = compressed.length;
          bestCompressed = compressed;
        }
      } catch (e) {
        // Ignore compression errors and try next method
      }
    }

    return bestCompressed ?? _compressRaw(pixels, options);
  }

  /// Compress using modified I3BN algorithm (original method with improvements)
  static Uint8List _compressWithModifiedI3BN(
    List<int> pixels,
    FontOptions options,
  ) {
    // Constants for compression
    const rleSkipCount = 1;
    const rleBitCollapsedCount = 10;
    const rleCounterBits = 6;
    const rleCounterMax = (1 << rleCounterBits) - 1;
    const rleMaxRepeats = rleCounterMax + rleBitCollapsedCount + 1;

    // Estimate buffer size (worst case)
    final estimatedSize = pixels.length * options.bpp + 1024;
    final buffer = Uint8List(estimatedSize);
    final bitStream = BitStream(buffer);

    int offset = 0;

    while (offset < pixels.length) {
      final pixel = pixels[offset];

      // Count consecutive same pixels
      int same = 1;
      while (offset + same < pixels.length &&
          pixels[offset + same] == pixel &&
          same < rleMaxRepeats + rleSkipCount) {
        same++;
      }

      offset += same;

      // If not enough for RLE - write as is
      if (same <= rleSkipCount) {
        for (int i = 0; i < same; i++) {
          for (int j = 0; j < options.bpp; j++) {
            final bit = (pixel >> j) & 1;
            if (bit == 1) {
              bitStream._buffer[bitStream._byteIndex] |=
                  (1 << bitStream._bitIndex);
            } else {
              bitStream._buffer[bitStream._byteIndex] &=
                  ~(1 << bitStream._bitIndex);
            }

            bitStream._bitIndex++;
            if (bitStream._bitIndex >= 8) {
              bitStream._bitIndex = 0;
              bitStream._byteIndex++;
              if (bitStream._byteIndex >= bitStream._buffer.length) {
                throw Exception('BitStream buffer overflow');
              }
            }
          }
        }
        continue;
      }

      // Write the first "skipped" head as is
      for (int i = 0; i < rleSkipCount; i++) {
        for (int j = 0; j < options.bpp; j++) {
          final bit = (pixel >> j) & 1;
          if (bit == 1) {
            bitStream._buffer[bitStream._byteIndex] |=
                (1 << bitStream._bitIndex);
          } else {
            bitStream._buffer[bitStream._byteIndex] &=
                ~(1 << bitStream._bitIndex);
          }

          bitStream._bitIndex++;
          if (bitStream._bitIndex >= 8) {
            bitStream._bitIndex = 0;
            bitStream._byteIndex++;
            if (bitStream._byteIndex >= bitStream._buffer.length) {
              throw Exception('BitStream buffer overflow');
            }
          }
        }
      }

      same -= rleSkipCount;

      // Not reached state to use counter => dump bit-extended
      if (same <= rleBitCollapsedCount) {
        for (int j = 0; j < options.bpp; j++) {
          final bit = (pixel >> j) & 1;
          if (bit == 1) {
            bitStream._buffer[bitStream._byteIndex] |=
                (1 << bitStream._bitIndex);
          } else {
            bitStream._buffer[bitStream._byteIndex] &=
                ~(1 << bitStream._bitIndex);
          }

          bitStream._bitIndex++;
          if (bitStream._bitIndex >= 8) {
            bitStream._bitIndex = 0;
            bitStream._byteIndex++;
            if (bitStream._byteIndex >= bitStream._buffer.length) {
              throw Exception('BitStream buffer overflow');
            }
          }
        }
        for (int i = 0; i < same; i++) {
          if (i < same - 1) {
            bitStream.writeBits(1, 1); // RLE repeat
          } else {
            bitStream.writeBits(0, 1); // RLE repeat last
          }
        }
        continue;
      }

      same -= rleBitCollapsedCount + 1;

      // Use counter for longer sequences
      bitStream.writeBits(pixel, options.bpp);
      for (int i = 0; i < rleBitCollapsedCount + 1; i++) {
        bitStream.writeBits(1, 1); // RLE repeat
      }
      bitStream.writeBits(same, rleCounterBits);
    }

    // Return the actual used portion of the buffer
    return buffer.sublist(0, bitStream.byteIndex);
  }

  /// Simple RLE compression
  static Uint8List _compressWithRLE(List<int> pixels, FontOptions options) {
    final result = <int>[];

    int i = 0;
    while (i < pixels.length) {
      final pixel = pixels[i];
      int count = 1;

      // Count consecutive same pixels
      while (i + count < pixels.length &&
          pixels[i + count] == pixel &&
          count < 255) {
        count++;
      }

      if (count > 3) {
        // Use RLE encoding for sequences longer than 3
        result.add(0xFF); // RLE marker
        result.add(count);
        result.add(pixel);
      } else {
        // Write raw pixels for short sequences
        for (int j = 0; j < count; j++) {
          result.add(pixel);
        }
      }

      i += count;
    }

    return Uint8List.fromList(result);
  }

  /// Simple Huffman compression
  static Uint8List _compressWithHuffman(List<int> pixels, FontOptions options) {
    // Count frequency of each pixel value
    final frequencies = <int, int>{};
    for (final pixel in pixels) {
      frequencies[pixel] = (frequencies[pixel] ?? 0) + 1;
    }

    // Create a simple Huffman tree (simplified)
    final codes = <int, List<int>>{};
    final sortedFreq = frequencies.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    // Assign variable-length codes based on frequency
    int codeLength = 1;
    for (final entry in sortedFreq) {
      codes[entry.key] = List.filled(codeLength, 0);
      codeLength = (codeLength % 8) + 1; // Keep codes reasonable length
    }

    // Encode the data
    final buffer = Uint8List(pixels.length * 2); // Overestimate
    final bitStream = BitStream(buffer);

    for (final pixel in pixels) {
      final code = codes[pixel]!;
      for (final bit in code) {
        bitStream._writeBit(bit);
      }
    }

    return buffer.sublist(0, bitStream.byteIndex);
  }

  /// Simple LZ77 compression
  static Uint8List _compressWithLZ77(List<int> pixels, FontOptions options) {
    final result = <int>[];
    final windowSize = 256;
    final lookaheadSize = 15;

    int i = 0;
    while (i < pixels.length) {
      int bestLength = 0;
      int bestOffset = 0;

      // Look for matches in the sliding window
      final start = (i - windowSize).clamp(0, pixels.length);
      for (int j = start; j < i; j++) {
        int length = 0;
        while (i + length < pixels.length &&
            j + length < i &&
            pixels[j + length] == pixels[i + length] &&
            length < lookaheadSize) {
          length++;
        }

        if (length > bestLength) {
          bestLength = length;
          bestOffset = i - j;
        }
      }

      if (bestLength >= 3) {
        // Use back-reference
        result.add(0xFE); // LZ77 marker
        result.add(bestOffset);
        result.add(bestLength);
        i += bestLength;
      } else {
        // Write literal
        result.add(pixels[i]);
        i++;
      }
    }

    return Uint8List.fromList(result);
  }

  /// Raw compression (no compression)
  static Uint8List _compressRaw(List<int> pixels, FontOptions options) {
    final buffer = Uint8List((pixels.length * options.bpp + 7) ~/ 8);
    final bitStream = BitStream(buffer);

    for (final pixel in pixels) {
      bitStream.writeBits(pixel, options.bpp);
    }

    return buffer.sublist(0, bitStream.byteIndex);
  }

  /// Decompress data (for testing purposes)
  static List<int> decompress(Uint8List compressedData, FontOptions options) {
    // This is a placeholder for decompression
    // In a real implementation, you would need to implement decompression
    // for each compression method
    throw UnimplementedError('Decompression not implemented');
  }

  /// Get compression statistics
  static Map<String, dynamic> getCompressionStats(
    List<int> originalData,
    Uint8List compressedData,
  ) {
    return {
      'originalSize': originalData.length,
      'compressedSize': compressedData.length,
      'compressionRatio': compressedData.length / originalData.length,
      'spaceSaved': originalData.length - compressedData.length,
      'spaceSavedPercent':
          ((originalData.length - compressedData.length) /
                  originalData.length *
                  100)
              .toStringAsFixed(2) +
          '%',
    };
  }
}

/// Delta compression for font data
class DeltaCompression {
  /// Apply delta compression to a list of values
  static List<int> compressDelta(List<int> values) {
    if (values.isEmpty) return [];

    final result = <int>[];
    result.add(values[0]); // First value is stored as-is

    for (int i = 1; i < values.length; i++) {
      result.add(values[i] - values[i - 1]); // Store difference
    }

    return result;
  }

  /// Decompress delta-compressed values
  static List<int> decompressDelta(List<int> deltaValues) {
    if (deltaValues.isEmpty) return [];

    final result = <int>[];
    result.add(deltaValues[0]); // First value

    for (int i = 1; i < deltaValues.length; i++) {
      result.add(result[i - 1] + deltaValues[i]);
    }

    return result;
  }
}

/// Palette-based compression for fonts with limited colors
class PaletteCompression {
  /// Create a palette from pixel data
  static List<int> createPalette(List<int> pixels, int maxColors) {
    final frequency = <int, int>{};

    // Count frequency of each color
    for (final pixel in pixels) {
      frequency[pixel] = (frequency[pixel] ?? 0) + 1;
    }

    // Sort by frequency and take the most common colors
    final sortedColors = frequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final palette = <int>[];
    for (int i = 0; i < sortedColors.length && i < maxColors; i++) {
      palette.add(sortedColors[i].key);
    }

    return palette;
  }

  /// Compress pixel data using a palette
  static List<int> compressWithPalette(List<int> pixels, List<int> palette) {
    final colorToIndex = <int, int>{};
    for (int i = 0; i < palette.length; i++) {
      colorToIndex[palette[i]] = i;
    }

    final result = <int>[];
    for (final pixel in pixels) {
      final index = colorToIndex[pixel];
      if (index != null) {
        result.add(index);
      } else {
        // Use the closest color in palette (simplified)
        result.add(0);
      }
    }

    return result;
  }

  /// Decompress palette-compressed data
  static List<int> decompressWithPalette(List<int> indices, List<int> palette) {
    final result = <int>[];
    for (final index in indices) {
      if (index < palette.length) {
        result.add(palette[index]);
      } else {
        result.add(0);
      }
    }
    return result;
  }
}
