# Font Converter Service

A Dart implementation of the lv_font_conv font conversion logic for Flutter applications. This service converts TTF/OTF fonts to a compact binary format suitable for embedded systems.

## Features

- Converts fonts to binary format (compatible with lv_font_conv)
- Supports 1-8 bits per pixel for anti-aliasing
- Optional RLE compression with XOR prefilter
- Kerning support
- Multiple subpixel rendering modes
- Compact storage with bounding boxes only

## Usage

### Basic Usage

```dart
import 'package:your_app/services/font_converter/font_converter_service.dart';

// Create font options
final options = FontConverterService.createOptions(
  bpp: 4, // 4 bits per pixel for anti-aliasing
  size: 16, // 16px font size
  noCompress: false, // Enable compression
  noKerning: true, // No kerning for simplicity
);

// Create glyphs
final glyphs = [
  FontConverterService.createBasicGlyph(
    code: 0x41, // 'A'
    pixels: [
      [0, 0, 1, 1, 1, 1, 1], // Row 0
      [0, 1, 1, 1, 1, 1, 1], // Row 1
      [1, 1, 1, 1, 1, 1, 1], // Row 2
      // ... more rows
    ],
    advanceWidth: 8.0,
    x: 0,
    y: 7,
  ),
  // ... more glyphs
];

// Create font data
final fontData = FontConverterService.createBasicFontData(
  size: options.size,
  glyphs: glyphs,
  ascent: 7,
  descent: 0,
  typoAscent: 7,
  typoDescent: 0,
  typoLineGap: 2,
  underlinePosition: -1,
  underlineThickness: 1,
);

// Convert to binary format
final binaryData = FontConverterService.convertToBinary(fontData, options);

// Save to file
await FontConverterService.saveBinaryFont(
  fontData,
  options,
  'my_font.bin',
);
```

### Advanced Usage with Kerning

```dart
// Create glyphs with kerning
final glyphA = FontConverterService.createBasicGlyph(
  code: 0x41, // 'A'
  pixels: /* ... pixel data ... */,
  advanceWidth: 6.0,
);

final glyphV = FontConverterService.createBasicGlyph(
  code: 0x56, // 'V'
  pixels: /* ... pixel data ... */,
  advanceWidth: 6.0,
);

// Add kerning: when 'V' follows 'A', move closer by 1 pixel
glyphA.kerning[0x56] = -1.0;

final glyphs = [glyphA, glyphV];

// Create font options with kerning enabled
final options = FontConverterService.createOptions(
  bpp: 2,
  size: 12,
  noCompress: false,
  noKerning: false, // Enable kerning
);

// Convert and save
final fontData = FontConverterService.createBasicFontData(
  size: options.size,
  glyphs: glyphs,
  // ... other metrics ...
);

await FontConverterService.saveBinaryFont(fontData, options, 'kerning_font.bin');
```

## Font Options

- `bpp`: Bits per pixel (1, 2, 3, 4, or 8)
- `size`: Font size in pixels
- `lcd`: Enable horizontal subpixel rendering (3x horizontal resolution)
- `lcdV`: Enable vertical subpixel rendering (3x vertical resolution)
- `useColorInfo`: Use glyph color info from font to create grayscale icons
- `noCompress`: Disable RLE compression
- `noPrefilter`: Disable bitmap lines filter (XOR) used to improve compression ratio
- `byteAlign`: Pad bitmap line endings to whole bytes
- `stride`: Align each glyph's stride to specified number of bytes
- `align`: Align each glyph address to specified number of bytes
- `noKerning`: Drop kerning info to reduce size

## Font Data Structure

### FontGlyph

Represents a single glyph with:
- `code`: Unicode code point
- `advanceWidth`: Advance width of the glyph
- `bbox`: Bounding box (x, y, width, height)
- `kerning`: Map of kerning values for following glyphs
- `pixels`: 2D array of pixel values (0-255)

### FontData

Contains complete font information:
- `ascent`: Maximum Y coordinate of any glyph
- `descent`: Minimum Y coordinate of any glyph (negative value)
- `typoAscent`: Typographic ascent
- `typoDescent`: Typographic descent (negative value)
- `typoLineGap`: Typographic line gap
- `size`: Font size in pixels
- `glyphs`: List of all glyphs
- `underlinePosition`: Underline position
- `underlineThickness`: Underline thickness

## Binary Format

The binary format is compatible with the lv_font_conv specification and includes:

1. **Head Table**: Font header with metrics and format information
2. **Cmap Table**: Character code to glyph ID mapping
3. **Loca Table**: Glyph data offsets
4. **Glyf Table**: Glyph bitmap data with compression
5. **Kern Table**: Optional kerning information

## Compression

Uses modified I3BN RLE compression:
- Requires minimal repeat count (1) to enter RLE mode
- Uses 1-bit replacement for first 10 repeats
- 6-bit counter for longer sequences
- Optional XOR prefilter for improved compression ratio

## Testing

Run the unit tests:

```bash
flutter test test/unit/font_converter_test.dart
```

## Examples

See `example.dart` for complete working examples:
- Basic font creation
- Font with kerning