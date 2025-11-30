# Change: Remove Unused Code and Tests

## Why
The codebase contains unused screens, empty directories, and overly complex service implementations that are not actively utilized in the application's navigation or core functionality. Removing these will simplify maintenance, reduce cognitive load, and improve code clarity.

## What Changes
- Remove completely unused `reconnect_status_screen.dart` file
- Remove empty `lib/tests/` directory
- Consolidate overly complex font upload services into simpler implementation
- Remove telemetry settings components if not actively used in navigation
- Clean up any unused model files or repositories that are no longer referenced

## Impact
- Affected specs: code-cleanup (new capability for maintaining code quality)
- Affected code: lib/screens/, lib/services/, lib/tests/, potentially lib/models/
- Reduces code complexity and maintenance overhead
- Improves build times and app bundle size