## Context

The PowerHub hardware design has been updated to remove the total current sensor. This sensor was previously accessed via the FFF6 BLE characteristic and provided aggregated current measurement for all channels. The existing software implementation assumes this sensor is present and includes total current in the monitoring data model, UI displays, and test cases.

## Goals / Non-Goals

- Goals: Remove all references to total current sensor, update data parsing, ensure compatibility with new hardware, prevent runtime errors
- Non-Goals: Modify per-channel current sensing, change other monitoring capabilities (voltage, temperature), alter BLE communication protocol structure

## Decisions

- Decision: Remove totalInputCurrent field from MonitoringData model entirely
  - Alternatives considered: Mark as optional with null values, keep field but return 0.0
  - Rationale: Complete removal prevents confusion and aligns with hardware reality

- Decision: Update FFF6 parsing to skip 4 bytes previously used for total current
  - Alternatives considered: Keep parsing but discard data, maintain full 36-byte format
  - Rationale: Reduces memory usage, prevents stale data issues, aligns with actual hardware data stream

- Decision: Update all UI references to display aggregated per-channel current instead
  - Alternatives considered: Hide current display entirely, show "N/A"
  - Rationale: Maintains user functionality by calculating total from available per-channel data

- Decision: Remove FFF6 characteristic UUID from BLE service references
  - Alternatives considered: Keep UUID but mark as deprecated, return empty data
  - Rationale: Prevents confusion for future developers, clean codebase

## Risks / Trade-offs

- Risk: Existing devices may still send total current data, causing parsing misalignment
  - Mitigation: Version detection via firmware identifier, graceful fallback for old data formats
- Risk: UI users accustomed to seeing total current may lose visibility
  - Mitigation: Add calculated total from per-channel current with clear labeling
- Trade-off: Increased CPU usage for calculating total from per-channel values
  - Resolution: Minimal overhead calculation during UI updates only

## Migration Plan

1. Model updates
   - Remove totalInputCurrent field from MonitoringData class
   - Update fromBytes() factory constructor to skip total current parsing
   - Adjust expected data length from 36 to 32 bytes

2. BLE service updates
   - Remove FFF6 UUID constant or mark as deprecated
   - Update monitoring data parsing logic
   - Add error handling for legacy data formats

3. UI component updates
   - Remove direct totalInputCurrent references
   - Add calculated total display where needed
   - Update labels to clarify calculated vs measured values

4. Test updates
   - Remove totalInputCurrent from test fixtures
   - Update test cases expecting 36-byte data format
   - Add validation for calculated totals

## Open Questions

- Should we maintain backward compatibility with devices that still send 36-byte data?
- Is there a maximum number of channels for total calculation limits?
- Should the calculated total include rounding or precision considerations?