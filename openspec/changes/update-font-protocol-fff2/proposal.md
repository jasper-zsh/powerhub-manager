# Change: Update Font Upload Protocol with Enhanced Error Handling and Progress Reporting

## Why
The current font upload implementation uses a simplified protocol that only utilizes BLE characteristic 0xFFF1 for data transfer. The protocol requires updating to implement robust error handling, real-time progress reporting via characteristic 0xFFF2, and comprehensive failure recovery mechanisms as specified in the SwitchHub font uploader protocol.

## What Changes
- **Add 0xFFF2 characteristic implementation** for status notifications, progress reporting, and error handling
- **Enhance 0xFFF1 communication** to follow exact protocol format with proper completion packets
- **Implement comprehensive error handling** with ATT error codes and client recovery mechanisms
- **Add progress reporting system** with real-time upload status via 0xFFF2 notifications
- **Implement timeout management** with 30-second chunk timeout and automatic recovery
- **Add memory management** with 80% usage warnings and automatic cleanup
- **Enhance upload validation** with font integrity checking and size limits (1MB max)

## Impact
- **Affected specs**: font-upload (new capability)
- **Affected code**:
  - `lib/services/switch_hub_ble_service.dart` - Main BLE service implementation
  - `lib/services/ble_service.dart` - Add 0xFFF2 characteristic support
  - `lib/providers/orchestration_provider.dart` - Enhanced error handling and progress callbacks
  - `lib/controllers/switch_hub_controller.dart` - Integration with new protocol
- **Breaking changes**: Yes - protocol format and error handling behavior will change
- **Backward compatibility**: No - requires device firmware update to support new protocol