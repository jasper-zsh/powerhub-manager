# Navigation Redesign: 6 Tab → 3 Tab

**Date:** 2026-04-08
**Status:** Approved

## Problem

The app currently has 6 bottom navigation tabs (Orchestrate, Devices, Control, Monitor, Power, SwitchHub), which exceeds Material Design's recommended 3-5 destinations. Functions are flat-mapped to tabs rather than organized by device type and usage pattern.

## Decision

Restructure navigation from 6 flat tabs to 3 purpose-driven tabs, with device configuration folded into detail pages accessed from the device list.

## Navigation Structure

| Index | Label | Icon | Page |
|-------|-------|------|------|
| 0 | 开关编排 | `toggle_on` | `OrchestrationScreen` (unchanged) |
| 1 | 设备管理 | `devices` | `DeviceListScreen` (new) |
| 2 | 设备监控 | `monitor_heart` | `UnifiedMonitoringScreen` (new) |

- `IndexedStack` is preserved for state retention across tabs
- Device detail pages use `Navigator.push` for navigation

## Tab Details

### Tab 0: 开关编排 (Orchestration)

No changes. Existing `OrchestrationScreen` stays as-is with tab index adjusted to 0.

### Tab 1: 设备管理 (Device Management)

**Device List Page** (`DeviceListScreen`):
- Merged list of PowerHub and SwitchHub devices
- Each item shows: device name, type indicator (icon/label), connection status, connect/disconnect button
- PopupMenu per item: rename, delete
- FAB: add device (PowerHub via BLE scan or sample; SwitchHub via BLE scan)
- Tapping an item → `Navigator.push` to type-specific detail page with `deviceId`

**PowerHub Detail Page** (`PowerHubDetailScreen`):
- Receives `deviceId`, auto-loads device config and telemetry on entry
- PWM channel control (sliders, quick actions: All Off/On/50%/Random) — migrated from `DeviceControlScreen`
- Telemetry display (input voltage, temperature, total current, thermal protection) — migrated from `DeviceControlScreen`
- Power management config (sleep/wake voltage thresholds, temperature thresholds, force sleep/wake) — migrated from `PowerManagementScreen`
- No device selector, no manual refresh button

**SwitchHub Detail Page** (`SwitchHubDetailScreen`):
- Receives `deviceId`, auto-loads voltage thresholds and config on entry
- Voltage threshold configuration — migrated from `SwitchHubMonitoringScreen`
- No device selector, no manual "Read" button

### Tab 2: 设备监控 (Monitoring)

**Unified Monitoring Page** (`UnifiedMonitoringScreen`):
- Merged view of all connected devices' real-time monitoring data
- PowerHub devices: input voltage, temperature, channel current summary, thermal protection status
- SwitchHub devices: voltage monitoring, connection status, last update time
- No manual device selection — automatically shows all connected devices
- Data sourced from existing `monitoringControllerProvider` and `switchHubControllerProvider`

## File Changes

### New Files
- `lib/screens/device_list_screen.dart` — Device list page
- `lib/screens/powerhub_detail_screen.dart` — PowerHub detail page
- `lib/screens/switchhub_detail_screen.dart` — SwitchHub detail page
- `lib/screens/unified_monitoring_screen.dart` — Unified monitoring page

### Modified Files
- `lib/main.dart` — Bottom navigation: 6 tabs → 3 tabs, reference new pages

### Removed Files
- `lib/screens/saved_controller_management_screen.dart` — Absorbed into device list + detail pages
- `lib/screens/device_control_screen.dart` — Absorbed into PowerHub detail page
- `lib/screens/power_management_screen.dart` — Absorbed into PowerHub detail page
- `lib/screens/switchhub_monitoring_screen.dart` — Config absorbed into SwitchHub detail, monitoring into unified page

### Unchanged
- `lib/screens/orchestration_screen.dart` — Logic unchanged, tab index adjusted to 0
- All existing provider/controller logic — UI reorganization only, no business logic changes
