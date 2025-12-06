# Add Dynamic Action Modes to Orchestration System

## Summary

Extend the orchestration system to support dynamic action modes from the PowerHub BLE protocol: 渐变模式 (gradient mode), 闪烁模式 (blink mode), and 频闪模式 (strobe mode). This will enable users to orchestrate advanced lighting effects with temporal control, moving beyond simple static PWM value changes.

## Problem Statement

Currently, the orchestration system only supports `channelValue` actions which immediately set PWM channels to specific static values (0-255). The PowerHub hardware supports three additional dynamic modes that enable temporal control:

1. **渐变模式 (Gradient Mode)** - Smooth transitions to target brightness over specified duration
2. **闪烁模式 (Blink Mode)** - Periodic blinking with specified period timing
3. **频闪模式 (Strobe Mode)** - Complex strobe effects with configurable count, timing, and pause intervals

Without orchestration support for these modes, users cannot create automated sequences that leverage the full capabilities of the PowerHub hardware.

## Proposed Solution

Extend the orchestration system to support dynamic action modes by:

1. **CommandActionType Extension**: Add new action types for gradient, blink, and strobe modes
2. **Parameter Modeling**: Define structured parameters for each mode based on BLE protocol specifications
3. **Command Generation**: Create command builders that encode mode-specific parameters into BLE packets
4. **UI Integration**: Update orchestration interface to support configuring dynamic action parameters
5. **Preview & Validation**: Enable preview and validation of dynamic action effects

## Key Benefits

- **Enhanced Lighting Effects**: Enable smooth transitions, periodic patterns, and complex strobe sequences
- **Temporal Control**: Add timing and duration control to orchestration capabilities
- **Hardware Optimization**: Leverage native PowerHub capabilities for efficient dynamic effects
- **Creative Possibilities**: Open up new possibilities for lighting automation and scene creation
- **Backward Compatibility**: Existing static channel value actions continue to work unchanged

## Implementation Scope

1. **Data Model Extensions**: Extend `CommandActionType` enum and `CommandAction` class with mode-specific parameters
2. **Command Builders**: Create specialized command classes for each dynamic mode
3. **BLE Integration**: Ensure proper encoding of dynamic mode commands according to POWERHUB_BLE.md
4. **UI Components**: Update orchestration interface to support parameter configuration
5. **Validation & Testing**: Add comprehensive validation and testing for dynamic modes
6. **Preview Enhancement**: Extend preview functionality to show dynamic effect timelines

## Technical Approach

### Mode Specifications (from POWERHUB_BLE.md)

**渐变模式 (Gradient Mode) - Mode 0x01**
- Format: `[0x01][channel][brightness][duration_high][duration_low]`
- Parameters: target brightness (0-255), duration (2 bytes, milliseconds)
- Behavior: Smooth fade from current state to target brightness over duration

**闪烁模式 (Blink Mode) - Mode 0x02**
- Format: `[0x02][channel][period_high][period_low]`
- Parameters: period (2 bytes, milliseconds)
- Behavior: Continuous blinking with specified period

**频闪模式 (Strobe Mode) - Mode 0x03**
- Format: `[0x03][channel][count][total_time_high][total_time_low][pause_time_high][pause_time_low]`
- Parameters: count (1 byte), total time (2 bytes), pause time (2 bytes)
- Behavior: Strobe for specified count with configurable timing

### New CommandActionType Values
- `channelValue` (existing) - Static PWM value setting
- `gradientMode` (new) - 渐变模式 with target value and duration
- `blinkMode` (new) - 闪烁模式 with period timing
- `strobeMode` (new) - 频闪模式 with count, time, and pause parameters

## Risk Assessment

### Medium Risk
- **Parameter Complexity**: Dynamic modes introduce more complex parameter sets that require careful validation
- **UI Complexity**: Configuration interfaces for temporal parameters add UI complexity
- **Debugging Challenges**: Dynamic effects are harder to debug and validate compared to static values

### Mitigation Strategies
- Comprehensive parameter validation with clear error messaging
- Visual preview and timeline visualization for dynamic effects
- Unit tests for all encoding/decoding scenarios
- Integration tests with real PowerHub hardware
- Progressive rollout with fallback to static modes

## Success Criteria

1. Users can orchestrate 渐变模式 actions with configurable target values and durations
2. Users can orchestrate 闪烁模式 actions with configurable period timing
3. Users can orchestrate 频闪模式 actions with configurable count, timing, and pause parameters
4. Dynamic actions can be combined with existing static actions in complex sequences
5. UI provides intuitive parameter configuration with validation and preview
6. All dynamic commands properly encode according to POWERHUB_BLE.md specifications
7. Backward compatibility maintained for existing orchestration configurations
8. Performance remains acceptable with complex dynamic action sequences

## Implementation Dependencies

- **POWERHUB_BLE.md**: Reference for exact command format and parameter encoding
- **Existing Orchestration Infrastructure**: Reuse current action execution and sequencing framework
- **Command Packet System**: Extend existing command packet generation for new modes
- **BLE Service Integration**: Ensure compatibility with existing BLE communication layer