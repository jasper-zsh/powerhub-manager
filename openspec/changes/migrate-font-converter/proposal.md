# Change: Migrate Font Converter to External Dart Library

## Why
The current project contains a custom font converter implementation that duplicates functionality already available in the dedicated `dart_lv_font_conv` library. Maintaining duplicate font conversion code increases maintenance burden, code complexity, and the risk of inconsistencies. Migrating to the external library reduces code duplication and leverages the specialized font conversion expertise in the dedicated library.

## What Changes
- **NEW**: Add dependency on `dart_lv_font_conv` library for font conversion functionality
- **REMOVED**: Complete font converter implementation in `lib/services/font_converter/`
- **UPDATED**: FontGenerationService to use external library API
- **REMOVED**: Font converter models, tables, and utility classes
- **UPDATED**: All font conversion imports and API calls
- **REMOVED**: Font converter tests (replaced by library tests)

## Impact
- Affected specs: font-management
- Affected code: `lib/services/font_converter/` (entire directory), `lib/services/font_generation_service.dart`, related tests
- Dependencies: New pub dependency on local `dart_lv_font_conv` package
- Build impact: Reduced compilation time, smaller application bundle