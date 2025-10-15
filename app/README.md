# PowerHub Manager

PowerHub Manager is a Flutter application for configuring and operating ESP32
PWM controllers over Bluetooth Low Energy. The app provides real-time channel
control, preset orchestration, and resilient device management tailored for
multi-controller environments.

## Navigation Overview

The application now uses a three-tab layout:

1. **Orchestrate** – Build switch-based automations, preview command bundles, and
   inspect execution logs.
2. **Saved Devices** – Manage aliases, reorder controllers, and review scene
   dependencies.
3. **Control** – Select a connected controller for real-time channel tuning and
   preset triggering with offline guidance.

## Saved Controller Management

- **Save & Alias Devices** – Store any discovered controller with a friendly
  alias for quick recognition. Aliases are validated locally to avoid
  duplicates and persist between sessions.
- **Auto-Reconnect Loop** – While the app is in the foreground, all saved
  controllers continuously scan and reconnect. Retry attempts back off before
  marking a controller unavailable, and the loop resumes when the app returns
  to the foreground.
- **Multi-Device Status** – At-a-glance dashboards show how many controllers
  are connected, scanning, waiting to retry, or unreachable. Saved controller
  rows include inline rename/remove actions plus live connection badges.

## Development Workflow

### Requirements

- Flutter 3.x SDK and matching platform toolchains
- An ESP32-based PowerHub controller (or simulator) advertising BLE services

### Useful Commands

```bash
cd app

# Fetch project dependencies
flutter pub get

# Run focused unit tests
flutter test test/unit/saved_controller_autoconnect_test.dart
flutter test test/unit/saved_controller_management_test.dart
flutter test test/unit/orchestration_provider_test.dart

# Run focused integration tests
flutter test test/integration/auto_reconnect_test.dart
flutter test test/integration/saved_controller_management_test.dart
flutter test test/integration/orchestration_flow_test.dart
flutter test test/integration/device_control_screen_test.dart

# Launch the application
flutter run
```

### Project Structure Highlights

- `lib/providers/app_state_provider.dart` – Central state management,
  auto-reconnect scheduling, and saved controller workflows.
- `lib/services/ble_service.dart` – BLE scanning, connection handling, and
  characteristic IO utilities.
- `lib/services/storage_service.dart` – Shared preferences-based persistence
  for presets and saved controllers.
- `lib/widgets/saved_controller_list.dart` – Saved controller list component
  with inline management controls and status chips.
- `lib/providers/device_control_provider.dart` – Bridges manual controller
  control callbacks to the UI while tracking busy state and selections.
- `lib/screens/orchestration_screen.dart` – Toggle-focused automation builder
  with command preview and execution log access.
- `lib/screens/device_control_screen.dart` – Manual controller adjustment
  surface with channel sliders, preset triggers, and offline handling.

## Additional Resources

- [Flutter documentation](https://docs.flutter.dev/)
- [flutter_blue_plus package](https://pub.dev/packages/flutter_blue_plus)
- [permission_handler package](https://pub.dev/packages/permission_handler)
