# Quickstart — Switch Orchestration Experience Revamp

## Goal
Validate the three-screen navigation (Orchestrate, Saved Devices, Control) and ensure automations, dependencies, and manual overrides behave as expected.

## Prerequisites
- Flutter environment configured per repository `app/README.md`
- At least one ESP32 PowerHub controller or BLE simulator
- Repository branch `003-3-ifttt-if` checked out

## Steps
1. **Install dependencies**
   ```bash
   cd app
   flutter pub get
   ```
2. **Run focused test suites**
   ```bash
   flutter test test/unit/orchestration_provider_test.dart
   flutter test test/unit/saved_controller_management_test.dart
   flutter test test/integration/orchestration_flow_test.dart
   flutter test test/integration/saved_controller_management_test.dart
   flutter test test/integration/device_control_screen_test.dart
   ```
3. **Launch the application**
   ```bash
   flutter run
   ```
4. **Orchestrate tab**
   - Create a new scene with a toggle and assign command bundles to both states.
   - Preview the scene and log the execution; verify actions and warnings appear.
5. **Saved Devices tab**
   - Rename an existing controller and remove another; confirm dependency warnings display for affected scenes.
   - Reorder controllers and ensure orchestration pickers reflect new order.
6. **Control tab**
   - Select a connected controller, adjust channel sliders, and trigger a preset.
   - Switch to an offline controller and confirm offline guidance is shown.

## Expected Outcomes
- Scenes can be authored, previewed, and logged from the Orchestrate tab without errors.
- Saved Devices tab persists alias changes, reorder operations, and flags impacted scenes upon removal.
- Control tab updates channel values through the provider callbacks, and preset buttons respect busy state while highlighting offline controllers.

## Validation Log (2025-10-14)

- ✅ `flutter test test/unit/orchestration_provider_test.dart`
- ✅ `flutter test test/unit/saved_controller_management_test.dart`
- ✅ `flutter test test/integration/orchestration_flow_test.dart`
- ✅ `flutter test test/integration/saved_controller_management_test.dart`
- ✅ `flutter test test/integration/device_control_screen_test.dart`
- ⏳ Manual orchestration/device control walkthrough (run on hardware or simulator)
