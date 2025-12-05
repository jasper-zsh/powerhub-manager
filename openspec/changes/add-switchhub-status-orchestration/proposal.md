# Change: Add SwitchHub Status Orchestration Logic to UI

## Why
The current Flutter app lacks implementation of the status UI orchestration features defined in the SWITCHHUB_BLE.md protocol. The app needs to parse and display real-time status data from multiple devices in configurable UI slots, supporting local voltage monitoring and remote device data aggregation.

## What Changes
- Add status slot configuration parsing from BLE 0xFFF3 characteristic
- Implement real-time status data orchestration from multiple sources (local + remote PowerHubs)
- Add configurable UI components for dual status slot display per switch
- Support voltage, current, and temperature data types with proper formatting
- Add data refresh mechanisms and error handling for remote device connectivity
- Integrate status display into existing orchestration screen UI

## Impact
- Affected specs: switchhub-ble, ui-orchestration
- Affected code:
  - lib/services/switch_hub_ble_service.dart (BLE protocol handling)
  - lib/providers/ (state management for status data)
  - lib/screens/orchestration_screen.dart (UI integration)
  - lib/widgets/ (new status display components)
  - lib/models/ (status slot configuration models)