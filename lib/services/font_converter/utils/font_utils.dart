import 'dart:typed_data';

/// Utility functions for font conversion
class FontUtils {
  /// Count the number of bits needed to represent an unsigned value
  static int unsignedBits(int value) {
    if (value == 0) return 1;
    int count = 0;
    while (value > 0) {
      count++;
      value >>= 1;
    }
    return count;
  }

  /// Count the number of bits needed to represent a signed value
  static int signedBits(int value) {
    if (value >= 0) return unsignedBits(value) + 1;
    return unsignedBits(value.abs() - 1) + 1;
  }

  /// Align value to 4-byte boundary
  static int align4(int size) {
    if (size % 4 == 0) return size;
    return size + 4 - (size % 4);
  }

  /// Align buffer length to 4-byte boundary (returns copy with zero-filled tail)
  static Uint8List alignBuffer4(Uint8List buffer) {
    final alignedSize = align4(buffer.length);
    final alignedBuffer = Uint8List(alignedSize);
    alignedBuffer.setRange(0, buffer.length, buffer);
    return alignedBuffer;
  }

  /// Convert array with uint16 data to buffer
  static Uint8List uint16ListToBuffer(List<int> values) {
    final buffer = Uint8List(values.length * 2);
    for (int i = 0; i < values.length; i++) {
      buffer.buffer.asByteData().setUint16(i * 2, values[i], Endian.little);
    }
    return buffer;
  }

  /// Convert array with uint32 data to buffer
  static Uint8List uint32ListToBuffer(List<int> values) {
    final buffer = Uint8List(values.length * 4);
    for (int i = 0; i < values.length; i++) {
      buffer.buffer.asByteData().setUint32(i * 4, values[i], Endian.little);
    }
    return buffer;
  }

  /// Pre-filter image to improve compression ratio using XOR with previous line
  static List<List<int>> prefilter(List<List<int>> pixels) {
    if (pixels.isEmpty) return pixels;

    final result = <List<int>>[];

    // First line remains unchanged
    result.add(List<int>.from(pixels[0]));

    // XOR each subsequent line with the previous one
    for (int i = 1; i < pixels.length; i++) {
      final line = <int>[];
      for (int j = 0; j < pixels[i].length; j++) {
        line.add(pixels[i][j] ^ pixels[i - 1][j]);
      }
      result.add(line);
    }

    return result;
  }

  /// Convert 8-bit opacity to bpp-bit
  static List<List<int>> pixelsToBpp(List<List<int>> pixels, int bpp) {
    return pixels
        .map((line) => line.map((p) => p >> (8 - bpp)).toList())
        .toList();
  }

  /// Calculate stride for a given width
  static int widthToStride(int width, int bpp, int stride) {
    if (stride > 0) {
      final byteCount = (width * bpp + 7) ~/ 8;
      final finalLength = ((byteCount + stride - 1) ~/ stride) * stride;
      return finalLength;
    }
    return (width * bpp + 7) ~/ 8;
  }

  /// Sum a list of integers
  static int sum(List<int> values) {
    return values.reduce((a, b) => a + b);
  }
}
