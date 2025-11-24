## MODIFIED Requirements

### Requirement: Font Generation Service
The system SHALL provide font generation capabilities using the external `dart_lv_font_conv` library for converting TTF fonts to LVGL binary format.

#### Scenario: Font conversion with external library
- **WHEN** generating LVGL font data from TTF assets
- **THEN** the system SHALL use the `dart_lv_font_conv` library for conversion
- **AND** maintain the same binary output format as the previous implementation
- **AND** preserve existing FontGenerationService API for compatibility

#### Scenario: Character set extraction
- **WHEN** extracting character sets from SwitchHub configurations
- **THEN** the system SHALL use external library character collection capabilities
- **AND** support the same character range and Unicode handling as before
- **AND** maintain caching behavior for performance

#### Scenario: Font binary generation
- **WHEN** generating binary font data for SwitchHub devices
- **THEN** the system SHALL produce compatible LVGL font binary format
- **AND** support the same font size and bpp (bits per pixel) options
- **AND** maintain compression and optimization features

## REMOVED Requirements

### Requirement: Internal Font Converter Implementation
**Reason**: Duplicate functionality now provided by dedicated `dart_lv_font_conv` library.
**Migration**: Replace with external library calls and remove entire internal implementation.

The system SHALL provide an internal font converter service for converting TTF fonts to LVGL binary format using custom implementation.

### Requirement: Font Converter Models and Utilities
**Reason**: External library provides its own models and utilities.
**Migration**: Remove all font converter specific models, tables, and utility classes.

The system SHALL provide font converter models including FontData, FontOptions, FontGlyph, and related table parsing utilities.