# Research Findings: Flutter BLE App for ESP32 PWM Controller

## 1. Flutter BLE Libraries

### Decision
Use `flutter_blue_plus` as the primary BLE library for cross-platform compatibility.

### Rationale
- `flutter_blue_plus` is the most actively maintained fork of the original `flutter_blue` library
- Supports both Android and iOS with proper permission handling
- Has good documentation and community support
- Provides low-level access to BLE characteristics needed for ESP32 communication
- Compatible with Flutter 3.x

### Alternatives Considered
- `flutter_reactive_ble`: More modern reactive approach but less documentation
- `bluetooth_low_energy`: Lower-level but more complex to implement
- Platform-specific implementations: Would require separate code for Android/iOS

## 2. ESP32 BLE Communication Patterns

### Decision
Implement custom protocol based on ESP32 characteristic definitions within service UUID `5E0B0001-6F72-4761-8E3E-7A1C1B5F9B11`:
- 0xFFF0 (READ): 4-byte channel targets for CH1–CH4
- 0xFFF1 (WRITE/WRITE_NO_RSP): Concatenated `control_cmd_t` segments `[mode][channel][payload…]`
- 0xFFF2 (READ): Sequential binary stream of all preset blocks
- 0xFFF3 (WRITE/WRITE_NO_RSP): Upload/delete a single preset block (`CommandCount=0` deletes)
- 0xFFF4 (WRITE/WRITE_NO_RSP): Execute preset ID or cancel with `0x00`
- 0xFFF5 (READ/WRITE/NOTIFY): Power/thermal telemetry and threshold commands

### Rationale
- Direct mapping to ESP32 implementation ensures compatibility
- Custom protocol allows for precise control of all features
- Big-endian byte order handling required for proper communication

### Implementation Notes
- All data transmission must use big-endian byte order
- Control commands share a common envelope; validate payload length, channel range, and mode before send
- Preset serialization/deserialization must honor device format, including delete semantics
- Telemetry characteristic 0xFFF5 requires handling read responses, notify payloads, and short write commands for threshold adjustments

## 3. Cross-Platform BLE Compatibility

### Decision
Implement platform-specific permission handling and feature detection.

### Rationale
- Android and iOS have different BLE permission models
- iOS requires specific Info.plist entries for Bluetooth usage
- Android requires runtime permissions for BLE scanning

### Implementation Requirements
- Android: BLUETOOTH_SCAN, BLUETOOTH_CONNECT permissions (Android 12+)
- iOS: NSBluetoothAlwaysUsageDescription in Info.plist
- Proper error handling for devices that don't support BLE

## 4. State Management Patterns

### Decision
Use Provider package for state management with scoped models.

### Rationale
- Provider is officially recommended by Flutter team
- Good performance with minimal boilerplate
- Easy to test and maintain
- Well-documented with community support

### Implementation Structure
- AppStateProvider for global app state
- DeviceConnectionProvider for BLE connection state
- PresetProvider for preset management

## 5. Local Data Persistence

### Decision
Use shared_preferences for simple data and drift (SQLite) for complex data.

### Rationale
- shared_preferences is sufficient for preset storage
- Easy to implement and maintain
- Good performance for small datasets
- Drift provides type-safe database access if needed for more complex features

### Implementation Plan
- Store presets as JSON in shared_preferences
- Consider migration to drift if preset complexity increases
- Implement caching for recently used presets

## 6. UI/UX Patterns for PWM Control

### Decision
Use slider controls with numeric input for precise PWM value adjustment.

### Rationale
- Sliders provide intuitive real-time control
- Numeric input allows for precise value setting
- Visual feedback of current values is essential
- Responsive design for different screen sizes

### Implementation Details
- Custom slider widgets for better styling
- Real-time value display during adjustment
- Visual indication of connected/disconnected state
- Preset management with easy save/recall interface

## 7. Testing Strategy

### Decision
Implement three-tier testing approach:
- Unit tests for data models and business logic
- Widget tests for UI components
- Integration tests for BLE communication

### Rationale
- Comprehensive coverage of all app components
- flutter_test provides good tooling for all test types
- Integration tests can use mock BLE devices for consistent testing

## 8. Error Handling and User Feedback

### Decision
Implement comprehensive error handling with user-friendly messages.

### Rationale
- BLE communication is inherently unreliable
- Users need clear feedback about connection status
- Error recovery should be intuitive

### Implementation Plan
- Connection timeout handling
- Retry mechanisms for failed operations
- Clear error messages for common failure scenarios
- Graceful degradation when BLE is unavailable

## Conclusion

All research questions have been resolved, and we have a clear path forward for implementing the Flutter app. The chosen technologies and patterns provide a solid foundation for building a robust, cross-platform BLE controller app that can communicate effectively with the ESP32 PWM controller.
