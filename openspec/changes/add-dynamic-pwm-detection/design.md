## Context

The current PowerHub implementation assumes all devices have exactly 6 PWM channels and a fixed monitoring configuration (2 temperature sensors + per-channel current + total current). This design limits support for new hardware variants with different capabilities.

The proposal introduces dynamic capability detection using the FFF1 characteristic response length to determine PWM channel count, and makes monitoring sensors configurable.

## Goals / Non-Goals

- Goals: Support variable PWM channel counts (1-N), flexible sensor configurations, enable new hardware variants
- Non-Goals: Backward compatibility with hardcoded assumptions (will require migration), support for dynamic channel addition/removal during operation

## Decisions

- Decision: Use FFF1 characteristic read response length to determine PWM channel count (4 bytes = 4 channels, etc.)
  - Alternatives considered: Fixed configuration file, separate capability discovery characteristic, device ID mapping
  - Rationale: Leverages existing BLE characteristic, minimal protocol changes, works with current hardware
- Decision: Device capability discovery occurs during initial connection, cached persistently
  - Alternatives considered: Real-time capability detection, capability broadcast notifications
  - Rationale: Capabilities are static hardware properties, caching reduces BLE overhead and improves UI responsiveness
- Decision: Remove total current sensor support entirely
  - Alternatives considered: Mark as optional, keep for legacy devices
  - Rationale: Simplifies monitoring model, per-channel current provides more granular data

## Risks / Trade-offs

- Risk: Existing devices may not support FFF1 reads for capability detection
  - Mitigation: Fallback to 6-channel default, version detection via firmware identifier
- Risk: UI complexity increases with variable channel counts
  - Mitigation: Responsive layout components, channel pagination for high counts
- Trade-off: Increased memory usage for variable channel storage vs. fixed arrays
  - Resolution: Use dynamic lists with reasonable upper limits (16 channels max)

## Migration Plan

1. Capability discovery enhancement
   - Add FFF1 read operation during device connection
   - Cache capabilities in saved controller data
   - Migrate existing saved controllers (assume 6 channels, full sensors)

2. Model refactoring
   - PWMController: Replace fixed 6-channel array with dynamic list
   - Channel: Remove hardcoded ID range validation (0-5)
   - MonitoringData: Remove total current, make temperature sensors optional

3. UI adaptation
   - Channel control cards: Support 1-N channels
   - Monitoring display: Hide unavailable sensors
   - Settings: Remove total current references

4. Testing and validation
   - Test with 1, 4, 6, 8 channel configurations
   - Validate with minimal sensor setups
   - Ensure legacy device compatibility

## Open Questions

- Maximum supported channel count (proposal: 16)
- Behavior when FFF1 read fails (proposal: default to 6 channels)
- Capability caching invalidation strategy (proposal: re-discover on firmware version changes)