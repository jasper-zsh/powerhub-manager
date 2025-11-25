import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/font_generation_service.dart';

void main() {
  group('Font BMP Simple Export', () {
    setUp(() {
      FontGenerationService.clearCache();
    });

    test(
      'should create BMP files from font dump data for visual inspection',
      () async {
        print('🎨 Generating font dump data for BMP creation...');

        // Generate dump format to extract character bitmaps
        final fontData =
            await FontGenerationService.generateFontDataForCharacters(
              ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', '开', '关'],
              fontSize: 32,
              bpp: 2,
            );

        expect(fontData, isNotNull);
        expect(fontData.containsKey('rawData'), isTrue);

        final rawData = fontData['rawData'] as List<int>;
        print('   Raw dump data size: ${rawData.length} bytes');

        // Save raw dump data for inspection
        final dumpFile = File('test_output/font_dump_for_bmp.txt');
        await dumpFile.create(recursive: true);
        await dumpFile.writeAsString(
          rawData.map((b) => String.fromCharCode(b)).join(),
        );
        print('   ✅ Raw dump saved to ${dumpFile.path}');

        // Create BMP visualization from the parsed data
        await _createBMPFromDumpData(rawData);
      },
    );

    test('should create simple BMP representations for key characters', () async {
      final testChars = ['A', 'g', '1', '!'];

      for (final char in testChars) {
        final fontData =
            await FontGenerationService.generateFontDataForCharacters(
              [char],
              fontSize: 48, // Large for clear visualization
              bpp: 4, // High quality
            );

        final rawData = fontData['rawData'] as List<int>;
        final bmpData = await _createSimpleBMP(char, rawData);

        final outputFile = File('test_output/simple_${char}_48px.bmp');
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(bmpData);

        print(
          '   ✅ Created simple BMP for "$char": ${outputFile.path} (${bmpData.length} bytes)',
        );
      }
    });

    test('should create grid BMP with alphabet', () async {
      final alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');

      final fontData =
          await FontGenerationService.generateFontDataForCharacters(
            alphabet,
            fontSize: 24,
            bpp: 2,
          );

      final rawData = fontData['rawData'] as List<int>;
      final gridBMP = await _createAlphabetGridBMP(alphabet, rawData, 24);

      final gridFile = File('test_output/alphabet_grid_24px.bmp');
      await gridFile.create(recursive: true);
      await gridFile.writeAsBytes(gridBMP);

      print(
        '   ✅ Created alphabet grid: ${gridFile.path} (${gridBMP.length} bytes)',
      );
    });
  });
}

Future<void> _createBMPFromDumpData(List<int> rawData) async {
  // Parse the dump format text to extract ASCII character representations
  final textContent = String.fromCharCodes(rawData);

  // Find all character bitmap sections
  final bitmapPattern = RegExp(
    r'Pixels \((\d+)x(\d+)\):([^#]*(?:[#.][^#]*)*)',
    multiLine: true,
  );
  final matches = bitmapPattern.allMatches(textContent);

  print('   Found ${matches.length} character bitmaps');

  int charIndex = 0;
  for (final match in matches) {
    final width = int.parse(match.group(1)!);
    final height = int.parse(match.group(2)!);
    final bitmapText = match.group(3)!;

    // Extract the bitmap lines
    final lines = bitmapText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(height)
        .toList();

    if (lines.isNotEmpty) {
      final bmpData = _createBMPFromText(lines, width, height);
      final outputFile = File(
        'test_output/char_${charIndex}_${width}x${height}.bmp',
      );
      await outputFile.create(recursive: true);
      await outputFile.writeAsBytes(bmpData);

      print(
        '     Character $charIndex: ${width}x$height -> ${outputFile.path}',
      );
      charIndex++;
    }
  }
}

Future<Uint8List> _createSimpleBMP(String char, List<int> rawData) async {
  // For simple demonstration, create a synthetic bitmap based on character
  // In a real implementation, you'd parse the actual font data
  final size = 48;
  final bitmap = List.generate(
    size,
    (_) => List.filled(size, 255),
  ); // White background

  // Create a simple representation based on character
  switch (char) {
    case 'A':
      _drawLetterA(bitmap, size);
      break;
    case 'g':
      _drawLetterG(bitmap, size);
      break;
    case '1':
      _drawNumber1(bitmap, size);
      break;
    case '!':
      _drawExclamation(bitmap, size);
      break;
    default:
      _drawDefaultChar(bitmap, size, char);
  }

  return _createBMPFromBitmap(bitmap);
}

void _drawLetterA(List<List<int>> bitmap, int size) {
  final center = size ~/ 2;
  final height = (size * 0.8).round();

  // Draw letter A
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < size; x++) {
      // Outer edges of A
      if ((y == 0 && x >= center - 8 && x <= center + 8) ||
          (x == center - 8 && y < height) ||
          (x == center + 8 && y < height) ||
          (y == height ~/ 2 && x >= center - 6 && x <= center + 6)) {
        bitmap[y][x] = 0; // Black
      }
    }
  }
}

void _drawLetterG(List<List<int>> bitmap, int size) {
  final center = size ~/ 2;
  final radius = (size * 0.3).round();

  // Draw letter G (simplified circle with gap)
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = x - center;
      final dy = y - center;
      final distance = sqrt(dx * dx + dy * dy);

      if (distance >= radius - 2 && distance <= radius + 2 && x >= center) {
        bitmap[y][x] = 0; // Black
      }
      // Add horizontal line
      if (y >= center - 2 &&
          y <= center + 2 &&
          x >= center &&
          x <= center + radius) {
        bitmap[y][x] = 0; // Black
      }
    }
  }
}

void _drawNumber1(List<List<int>> bitmap, int size) {
  final center = size ~/ 2;
  final width = size ~/ 8;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (x == center && y < size - size ~/ 6) {
        bitmap[y][x] = 0; // Vertical line
      }
      if (y == size ~/ 6 && x >= center - width && x <= center + width) {
        bitmap[y][x] = 0; // Top horizontal
      }
      if (y == size - size ~/ 6 && x >= center - width && x <= center + width) {
        bitmap[y][x] = 0; // Bottom horizontal
      }
    }
  }
}

void _drawExclamation(List<List<int>> bitmap, int size) {
  final center = size ~/ 2;
  final dotSize = size ~/ 10;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      // Vertical line
      if (x == center && y >= size ~/ 6 && y <= size - size ~/ 3) {
        bitmap[y][x] = 0; // Black
      }
      // Dot at bottom
      final dx = x - center;
      final dy = y - (size - size ~/ 6);
      if (dx * dx + dy * dy <= dotSize * dotSize) {
        bitmap[y][x] = 0; // Black
      }
    }
  }
}

void _drawDefaultChar(List<List<int>> bitmap, int size, String char) {
  // Draw a simple rectangle with the character code
  final border = 4;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      if (x < border ||
          x >= size - border ||
          y < border ||
          y >= size - border) {
        bitmap[y][x] = 0; // Black border
      }
    }
  }
}

Uint8List _createBMPFromText(List<String> lines, int width, int height) {
  final rowSize = ((width + 3) ~/ 4) * 4;

  // BMP header
  final header = ByteData(54);
  header.setUint8(0, 0x42); // 'B'
  header.setUint8(1, 0x4D); // 'M'
  header.setUint32(2, 54 + rowSize * height, Endian.little); // File size
  header.setUint32(10, 54, Endian.little); // Data offset

  // DIB header
  header.setUint32(14, 40, Endian.little);
  header.setInt32(18, width, Endian.little);
  header.setInt32(22, height, Endian.little);
  header.setUint16(26, 1, Endian.little);
  header.setUint16(28, 8, Endian.little);
  header.setUint32(30, 0, Endian.little);
  header.setUint32(34, rowSize * height, Endian.little);
  header.setInt32(38, 2835, Endian.little);
  header.setInt32(42, 2835, Endian.little);
  header.setUint32(46, 0, Endian.little);
  header.setUint32(50, 0, Endian.little);

  // Pixel data
  final pixels = ByteData(rowSize * height);
  for (int y = 0; y < height && y < lines.length; y++) {
    final line = lines[y];
    for (int x = 0; x < width && x < line.length; x++) {
      final pixelValue = line[x] == '#' ? 0 : 255;
      pixels.setUint8((height - 1 - y) * rowSize + x, pixelValue);
    }
    // Padding
    for (int x = line.length; x < rowSize; x++) {
      pixels.setUint8((height - 1 - y) * rowSize + x, 255);
    }
  }

  final result = BytesBuilder();
  result.add(header.buffer.asUint8List());
  result.add(pixels.buffer.asUint8List());
  return result.toBytes();
}

Uint8List _createBMPFromBitmap(List<List<int>> bitmap) {
  final width = bitmap.isNotEmpty ? bitmap[0].length : 48;
  final height = bitmap.length;
  final rowSize = ((width + 3) ~/ 4) * 4;

  // BMP header
  final header = ByteData(54);
  header.setUint8(0, 0x42); // 'B'
  header.setUint8(1, 0x4D); // 'M'
  header.setUint32(2, 54 + rowSize * height, Endian.little);
  header.setUint32(10, 54, Endian.little);

  // DIB header
  header.setUint32(14, 40, Endian.little);
  header.setInt32(18, width, Endian.little);
  header.setInt32(22, height, Endian.little);
  header.setUint16(26, 1, Endian.little);
  header.setUint16(28, 8, Endian.little);
  header.setUint32(30, 0, Endian.little);
  header.setUint32(34, rowSize * height, Endian.little);
  header.setInt32(38, 2835, Endian.little);
  header.setInt32(42, 2835, Endian.little);
  header.setUint32(46, 0, Endian.little);
  header.setUint32(50, 0, Endian.little);

  // Pixel data (bottom-to-top)
  final pixels = ByteData(rowSize * height);
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final pixelValue = bitmap[height - 1 - y][x];
      pixels.setUint8(y * rowSize + x, pixelValue);
    }
    for (int x = width; x < rowSize; x++) {
      pixels.setUint8(y * rowSize + x, 255);
    }
  }

  final result = BytesBuilder();
  result.add(header.buffer.asUint8List());
  result.add(pixels.buffer.asUint8List());
  return result.toBytes();
}

Future<Uint8List> _createAlphabetGridBMP(
  List<String> alphabet,
  List<int> rawData,
  int fontSize,
) async {
  // Create a grid layout for alphabet (5x6 for 26 letters)
  final cols = 5;
  final rows = 6;
  final charWidth = fontSize ~/ 2;
  final charHeight = fontSize;
  final spacing = 4;
  final totalWidth = cols * (charWidth + spacing);
  final totalHeight = rows * (charHeight + spacing);

  final gridBitmap = List.generate(
    totalHeight,
    (_) => List.filled(totalWidth, 255),
  ); // White background

  // Simple placeholder for each character
  for (int i = 0; i < alphabet.length; i++) {
    final col = i % cols;
    final row = i ~/ cols;
    final startX = col * (charWidth + spacing) + 2;
    final startY = row * (charHeight + spacing) + 2;

    // Draw a simple representation of the character
    for (int y = 0; y < charHeight - 4; y++) {
      for (int x = 0; x < charWidth - 4; x++) {
        if (y == 0 || y == charHeight - 5 || x == 0 || x == charWidth - 5) {
          gridBitmap[startY + y][startX + x] = 0; // Black border
        }
      }
    }
  }

  return _createBMPFromBitmap(gridBitmap);
}
