## Context

The SwitchHub BLE protocol defines a sophisticated status UI orchestration system where switches can display real-time data from multiple sources. The Flutter PowerHub Manager app currently has basic BLE communication and device control but lacks the status orchestration features defined in section 3.4 of SWITCHHUB_BLE.md.

Each switch can display up to two status slots showing data from:
- Local SwitchHub device (voltage only)
- Remote PowerHub devices (voltage, current, temperature)

## Goals / Non-Goals

**Goals:**
- Parse status slot configuration from BLE 0xFFF3 characteristic JSON
- Orchestrate real-time data collection from multiple BLE devices
- Display formatted status data in existing orchestration UI
- Support all data types: VOLTAGE, CHANNEL_CURRENT, TOTAL_CURRENT, TEMPERATURE
- Handle connection failures and data unavailability gracefully

**Non-Goals:**
- Full device monitoring dashboard (already exists in monitoring screen)
- Historical data logging or trends
- Advanced data visualization beyond simple text display
- Custom alerting based on status values

## Decisions

### 1. State Management Architecture
- **Decision**: Use Riverpod's AsyncNotifier for status orchestration state
- **Rationale**: Leverages existing provider architecture, handles async data gracefully, provides automatic loading/error states
- **Alternative**: ChangeNotifier - rejected for manual state management complexity

### 2. Data Collection Strategy
- **Decision**: Poll-based collection with caching
- **Rationale**: BLE notifications already exist for device monitoring, can reuse existing subscription mechanisms
- **Alternative**: Push-based - rejected due to complexity of managing multiple notification streams

### 3. Remote Device Communication
- **Decision**: Use existing BleService for remote PowerHub communication
- **Rationale**: Reuses proven BLE implementation, reduces code duplication
- **Alternative**: New dedicated service - rejected for unnecessary complexity

### 4. Error Handling Approach
- **Decision**: Graceful degradation with "--" display for unavailable data
- **Rationale**: Matches common UI patterns for missing sensor data
- **Alternative**: Explicit error messages - rejected for cluttering the UI

## Risks / Trade-offs

**Risk**: High BLE traffic with multiple device polling
**Mitigation**: Implement intelligent refresh intervals and batch operations

**Risk**: Connection state management complexity across multiple devices
**Mitigation**: Use existing connection health monitoring from BleService

**Trade-off**: Simplicity vs. Performance
- Chose simpler implementation that may have slightly higher latency
- Can optimize later if performance issues arise

**Trade-off**: UI Space vs. Information Density
- Dual status slots per switch provides good balance
- Can expand to more slots in future if needed

## Migration Plan

### Phase 1: Core Models and BLE Integration
1. Add status slot data models
2. Extend BLE service to parse status_slots JSON
3. Basic data collection without UI integration

### Phase 2: State Management and UI Components
1. Create StatusOrchestrationProvider
2. Build status display widgets
3. Integrate into existing orchestration screen

### Phase 3: Polish and Optimization
1. Add error handling and edge cases
2. Optimize data refresh rates
3. Add final UI polish and animations

### Rollback Strategy
- All changes are additive - can safely disable status features via feature flag
- Existing functionality remains untouched
- Models can be removed without breaking existing code

## Open Questions

1. **Refresh Rate Strategy**: Should remote data refresh rates be adaptive based on connection quality?
2. **Caching Duration**: How long to cache status data when devices disconnect?
3. **Priority Handling**: Which data source takes priority when multiple devices provide the same data type?
4. **User Preferences**: Should users be able to customize refresh intervals or disable certain status slots?

## Implementation Notes

### Data Flow Architecture
```
BLE 0xFFF3 JSON → StatusSlot models → StatusOrchestrationProvider → UI Widgets
     ↓
Remote Device Data Collection → StatusCache → FormattedDisplay
```

### Key Components
- **StatusSlot**: Configuration model for individual status display
- **StatusOrchestrationProvider**: State management and data coordination
- **StatusSlotWidget**: UI component for displaying formatted status data
- **StatusCollector**: Service for gathering data from multiple sources

### Integration Points
- **Existing BleService**: For all BLE communication
- **Existing Providers**: Leverage current state management patterns
- **Orchestration Screen**: Add status display to existing ToggleCard components
- **Monitoring Screen**: Reuse existing device discovery and connection logic