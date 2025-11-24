## Context

The PowerHub project currently maintains its own font converter implementation in `lib/services/font_converter/` to convert TTF fonts to LVGL format for SwitchHub devices. This duplicates functionality available in the dedicated `dart_lv_font_conv` library located at `/home/jasper/Codes/dart_lv_font_conv/`. The external library is specifically designed for LVGL font conversion and provides a more comprehensive and tested solution.

## Goals / Non-Goals

- Goals: Remove duplicate font conversion code, reduce maintenance burden, leverage specialized external library, reduce application size
- Non-Goals: Modify font conversion output format (maintain compatibility), change FontGenerationService API, support additional font formats

## Decisions

- Decision: Use local path dependency to `/home/jasper/Codes/dart_lv_font_conv`
  - Alternatives considered: Published pub.dev package, Git repository dependency
  - Rationale: Local development dependency allows for easy modifications and testing during development
- Decision: Replace FontConverterService with direct library calls
  - Alternatives considered: Keep FontConverterService as wrapper, migrate gradually
  - Rationale: Direct library usage is simpler and reduces indirection layer
- Decision: Remove entire font_converter directory
  - Alternatives considered: Keep models if useful, migrate incrementally
  - Rationale: External library provides its own models and utilities, maintaining duplicates adds confusion

## Risks / Trade-offs

- Risk: API differences between current implementation and external library
  - Mitigation: Adapter layer in FontGenerationService to maintain existing API contract
- Risk: Path dependency lock-in to specific file system location
  - Mitigation: Document dependency requirement, consider moving to Git dependency for production
- Trade-off: Loss of fine-grained control over font conversion process
  - Resolution: Leverage external library's configuration options, contribute changes back if needed

## Migration Plan

1. Dependency setup
   - Add dart_lv_font_conv as path dependency in pubspec.yaml
   - Test library functionality with current font assets
   - Validate output format compatibility

2. FontGenerationService refactoring
   - Replace FontConverterService calls with external library API
   - Maintain existing FontGenerationService interface
   - Update caching mechanism if needed
   - Test with existing SwitchHub configurations

3. Code cleanup
   - Remove entire lib/services/font_converter/ directory
   - Remove font converter related tests
   - Update all imports and references
   - Clean up unused dependencies

4. Testing and validation
   - Test font conversion with various font sizes and configurations
   - Validate binary output compatibility with SwitchHub devices
   - Performance testing to ensure no regression
   - Integration testing with complete workflow

## Open Questions

- Should FontGenerationService API remain unchanged for compatibility?
- How to handle any font format differences between implementations?
- Future dependency management (path vs Git vs published package)?