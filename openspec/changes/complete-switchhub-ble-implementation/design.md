## Context
SwitchHub is a BLE control device that orchestrates PowerHub devices without having its own output channels. The current implementation has solid data models and configuration management but is missing critical BLE protocol features for real-time monitoring, power management, and proper command translation.

## Goals / Non-Goals
- **Goals**:
  - Full compliance with SWITCHHUB_BLE.md specification
  - Real-time voltage monitoring with notifications
  - Complete power management command support
  - Bidirectional configuration synchronization (read + write)
  - Robust error handling and connection management
- **Non-Goals**:
  - Adding temperature sensing (hardware limitation)
  - Modifying existing PowerHub protocol
  - Changing the UI architecture or data model design

## Decisions

### 1. Characteristic Implementation Strategy
- **Decision**: Implement each BLE characteristic as a separate service class with unified interface
- **Rationale**: Current monolithic service makes it hard to maintain protocol separation
- **Alternatives considered**: Single service with characteristic handlers (rejected for complexity)

### 2. Status Flag Format
- **Decision**: Use simplified SwitchHub format: `[voltage(2B)][status_flags(1B)][reserved(1B)]`
- **Rationale**: Matches specification, reduces confusion, hardware has no temperature sensors
- **Alternatives considered**: Maintaining complex flag system (rejected for spec compliance)

### 3. Command Translation Architecture
- **Decision**: Create dedicated PowerHub command translator that converts SwitchHub sequences to BLE packets
- **Rationale**: Clean separation of concerns, easier to test and maintain
- **Alternatives considered**: Inline translation in service (rejected for testability)

### 4. Error Handling Strategy
- **Decision**: Implement comprehensive BLE ATT error mapping with retry logic
- **Rationale**: Required by specification, provides better user experience
- **Alternatives considered**: Basic error propagation (rejected for poor UX)

## Risks / Trade-offs
- **Risk**: Breaking existing clients with status flag format change
  - **Mitigation**: Version the protocol and provide migration path
- **Risk**: PowerHub command translation complexity
  - **Mitigation**: Comprehensive testing and clear error messages
- **Trade-off**: Additional complexity vs full specification compliance
  - **Decision**: Prioritize compliance for long-term maintainability

## Migration Plan
1. Implement new characteristics alongside existing ones
2. Add version negotiation to detect protocol capabilities
3. Gradually migrate clients to new format
4. Remove deprecated code after transition period

## UI/UX Design Decisions

### Real-time Monitoring Interface
- **Dashboard Layout**: Multi-device status cards with live voltage gauges
- **Status Slots**: Configurable display areas bound to device characteristics
- **Controls**: Notification toggle, frequency slider, device selection
- **Visual Feedback**: Color-coded voltage levels, connection status indicators

### Power Management Interface
- **Threshold Configuration**: Dual slider interface for sleep/wake voltages
- **Safety Validation**: Range checking with visual warnings for unsafe values
- **Status Display**: Battery level visualization with power state indicators
- **Quick Actions**: Sleep/wake toggle buttons with confirmation dialogs

### Configuration Management Interface
- **Read Operations**: Progress-based UI for large file transfers
- **Version Comparison**: Side-by-side diff view for configuration changes
- **Bulk Operations**: Multi-select device interface for batch operations
- **Backup/Restore**: Timeline-based backup management with restore points

## Open Questions
- Should we implement backward compatibility for the old status flag format during transition?
- What should be the default chunk size for configuration reading operations?
- How should we handle concurrent configuration read/write operations?
- What is the optimal refresh rate for real-time monitoring UI updates?
- Should monitoring continue when app is in background, and at what frequency?