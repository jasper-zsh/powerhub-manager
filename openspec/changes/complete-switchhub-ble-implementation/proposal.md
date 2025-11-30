# Change: Complete SwitchHub BLE Protocol Implementation

## Why
The current SwitchHub implementation is approximately 70% complete but missing critical BLE protocol features defined in SWITCHHUB_BLE.md, particularly real-time monitoring (0xFFF2), proper power management commands (0xFFF1), configuration reading capabilities, and protocol-compliant error handling.

**NOTE**: SwitchHub is a BLE control device that orchestrates PowerHub devices. SwitchHub has its own BLE service (0xFFF1, 0xFFF2, 0xFFF3) and sends commands TO PowerHub devices using PowerHub's protocol.

## What Changes
- **BREAKING**: Update status flag format to match SwitchHub specification (bit1=0 indicates no temperature)
- Add real-time monitoring characteristic (0xFFF2) with read + notify capabilities
- Implement voltage threshold management commands (0x01/0x02) for power management
- Add configuration reading protocol with chunked transfer support
- Implement PowerHub command translation and routing logic
- Add comprehensive error handling with BLE ATT error codes
- Fix service discovery and advertisement parsing
- Add proper connection management with disconnect handling

## Impact
- **Affected specs**: switchhub-ble (new), power-management (new), real-time-monitoring (new)
- **Affected code**:
  - `lib/services/switch_hub_ble_service.dart` - major updates to BLE protocol
  - `lib/models/switch_hub/` - status format fixes and state context updates
  - `lib/repositories/switch_hub_command_service.dart` - implement command translation
  - `lib/controllers/switch_hub_controller.dart` - add monitoring and config reading
  - Integration tests and comprehensive unit test coverage