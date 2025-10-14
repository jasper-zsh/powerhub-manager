# Quickstart — Optimized Device Connection Management

## Goal
Verify that saved controllers persist with aliases and automatically reconnect while the app remains in the foreground.

## Prerequisites
- Flutter environment set up per repository `README.md`.
- At least two ESP32 PWM controllers advertising over BLE (or simulator endpoints) with stable identifiers.
- Mobile device or emulator with BLE support enabled.
- Repository branch `002-1-2-3` checked out.

## Steps
1. **Install dependencies**
   ```bash
   cd app
   flutter pub get
   ```
2. **Run automated tests focused on device management**
   ```bash
   flutter test test/unit/saved_controller_storage_test.dart
   flutter test test/unit/saved_controller_autoconnect_test.dart
   flutter test test/unit/saved_controller_management_test.dart
   flutter test test/integration/auto_reconnect_test.dart
   flutter test test/integration/saved_controller_management_test.dart
   ```
3. **Launch the application**
   ```bash
   flutter run
   ```
4. **Save controllers with aliases**
   - Discover each controller via the device list.
   - Choose “Save device” and assign a unique alias (e.g., “Living Room”, “Workshop”).
   - Confirm entries appear in the Saved Controllers view with correct status.
5. **Validate persistence**
   - Close and relaunch the app.
   - Verify saved controllers still appear with aliases and last-known status.
6. **Test auto-reconnection**
   - Ensure controllers are powered on and in range.
   - Bring the app to the foreground; observe scanning until all controllers show “Connected”.
7. **Simulate disconnect and recovery**
   - Power off one controller; confirm app marks it as “Unavailable” after retries.
   - Power it back on; confirm reconnection occurs automatically within 20 seconds.
8. **Manage the saved list**
   - Rename one controller and remove another.
   - Confirm UI updates immediately and reconnection attempts stop for the removed entry.

## Expected Outcomes
- Saved controllers persist across app restarts with custom aliases.
- Foreground scanning continues until all reachable controllers reconnect.
- Unavailable controllers trigger retry loops without blocking other connections.
- Renaming or removing controllers updates both the saved list and connection status tracking.

## Validation Log (2025-10-14)

- ✅ `flutter test test/unit/saved_controller_storage_test.dart`
- ✅ `flutter test test/unit/saved_controller_autoconnect_test.dart`
- ✅ `flutter test test/unit/saved_controller_management_test.dart`
- ✅ `flutter test test/integration/auto_reconnect_test.dart`
- ✅ `flutter test test/integration/saved_controller_management_test.dart`
- ⏳ `flutter run` (not executed during this validation pass)
