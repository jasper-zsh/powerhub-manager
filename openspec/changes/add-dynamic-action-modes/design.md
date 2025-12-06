# Design Document: Dynamic Action Modes Integration

## Architecture Overview

This enhancement extends the existing orchestration system to support dynamic action modes from the PowerHub BLE protocol. The design maintains backward compatibility while adding sophisticated temporal control capabilities.

## Current State Analysis

### Existing CommandAction System
- **CommandActionType enum**: Currently supports `channelValue` and `presetTrigger`
- **CommandAction class**: Contains controller ID, type, channel, value, and preset ID
- **SetCommand class**: Encodes static PWM commands as `[0x00][channel][value]`
- **Orchestration flow**: Actions → Command packets → BLE service → PowerHub device

### Limitations of Current System
- Only supports static value changes (immediate setting)
- No temporal control or animation capabilities
- Underutilizes PowerHub hardware capabilities
- Limited creative possibilities for lighting automation

## Proposed Architecture Changes

### 1. Extended CommandActionType Enum

#### New Action Types
```dart
enum CommandActionType {
  channelValue,      // Existing: immediate static value (0x00)
  presetTrigger,     // Existing: preset activation
  gradientMode,      // New: 渐变模式 with target value and duration (0x01)
  blinkMode,         // New: 闪烁模式 with period timing (0x02)
  strobeMode         // New: 频闪模式 with complex timing (0x03)
}
```

### 2. Enhanced CommandAction Class

#### Extended Parameter Structure
```dart
class CommandAction {
  final String controllerId;
  final CommandActionType type;
  final int? channel;
  final int? value;                    // For channelValue and gradientMode

  // New parameters for dynamic modes
  final int? duration;                 // For gradientMode (ms)
  final int? period;                   // For blinkMode (ms)
  final int? count;                    // For strobeMode
  final int? totalTime;                // For strobeMode (ms)
  final int? pauseTime;                // For strobeMode (ms)
  final int? presetId;                 // For presetTrigger
}
```

### 3. Mode-Specific Command Classes

#### GradientModeCommand
```dart
class GradientModeCommand extends ControlCommand {
  final int targetValue;
  final int duration;  // milliseconds

  // Encodes: [0x01][channel][targetValue][duration_high][duration_low]
  List<int> toBytes() => [0x01, channel, targetValue,
                         (duration >> 8) & 0xFF, duration & 0xFF];
}
```

#### BlinkModeCommand
```dart
class BlinkModeCommand extends ControlCommand {
  final int period;  // milliseconds

  // Encodes: [0x02][channel][period_high][period_low]
  List<int> toBytes() => [0x02, channel,
                         (period >> 8) & 0xFF, period & 0xFF];
}
```

#### StrobeModeCommand
```dart
class StrobeModeCommand extends ControlCommand {
  final int count;
  final int totalTime;   // milliseconds
  final int pauseTime;   // milliseconds

  // Encodes: [0x03][channel][count][total_time_high][total_time_low][pause_time_high][pause_time_low]
  List<int> toBytes() => [
    0x03, channel, count,
    (totalTime >> 8) & 0xFF, totalTime & 0xFF,
    (pauseTime >> 8) & 0xFF, pauseTime & 0xFF
  ];
}
```

### 4. Parameter Validation Framework

#### Validation Rules by Mode
```dart
abstract class ActionValidator {
  static String? validate(CommandAction action) {
    switch (action.type) {
      case CommandActionType.channelValue:
        return _validateChannelValue(action);
      case CommandActionType.gradientMode:
        return _validateGradientMode(action);
      case CommandActionType.blinkMode:
        return _validateBlinkMode(action);
      case CommandActionType.strobeMode:
        return _validateStrobeMode(action);
    }
  }
}
```

### 5. UI Integration Architecture

#### Dynamic Parameter Forms
- **Mode Selection**: Dropdown/radio button to choose action type
- **Conditional Forms**: Show/hide parameter fields based on selected mode
- **Real-time Validation**: Immediate feedback for parameter validation
- **Parameter Helpers**: Context-sensitive help text and examples

#### Preview Enhancement
- **Timeline Visualization**: Show temporal aspects of dynamic actions
- **Effect Simulation**: Visual preview of gradient, blink, and strobe patterns
- **Duration Indicators**: Time-based indicators for duration and period parameters

### 6. Command Execution Flow

#### Extended Orchestration Provider
```dart
class OrchestrationProvider {
  Future<void> _executeAction(CommandAction action) async {
    switch (action.type) {
      case CommandActionType.channelValue:
        final command = SetCommand(channel: action.channel!, value: action.value!);
        await _bleService.sendSetCommand(command);
        break;

      case CommandActionType.gradientMode:
        final command = GradientModeCommand(
          channel: action.channel!,
          targetValue: action.value!,
          duration: action.duration!,
        );
        await _bleService.sendGradientCommand(command);
        break;

      case CommandActionType.blinkMode:
        final command = BlinkModeCommand(
          channel: action.channel!,
          period: action.period!,
        );
        await _bleService.sendBlinkCommand(command);
        break;

      case CommandActionType.strobeMode:
        final command = StrobeModeCommand(
          channel: action.channel!,
          count: action.count!,
          totalTime: action.totalTime!,
          pauseTime: action.pauseTime!,
        );
        await _bleService.sendStrobeCommand(command);
        break;
    }
  }
}
```

## Data Flow Diagram

```
User Input (Orchestration UI)
       ↓
CommandAction Creation (with mode-specific parameters)
       ↓
Parameter Validation (ActionValidator)
       ↓
Command Generation (mode-specific command classes)
       ↓
BLE Packet Encoding (according to POWERHUB_BLE.md)
       ↓
BLE Service Transmission
       ↓
PowerHub Device Execution
       ↓
Hardware Effect (gradient/blink/strobe)
```

## Component Interaction

### Core Components
1. **CommandAction**: Extended data model with mode-specific parameters
2. **Command Classes**: Mode-specific encoding classes extending ControlCommand
3. **Validation System**: Comprehensive parameter validation per mode
4. **UI Components**: Dynamic forms and preview components
5. **BLE Service**: Extended with mode-specific command methods
6. **Orchestration Provider**: Enhanced action execution logic

### External Dependencies
- **POWERHUB_BLE.md**: Protocol specification for command encoding
- **Existing BLE Infrastructure**: Reuse current communication patterns
- **UI Framework**: Flutter components for dynamic forms

## Error Handling Strategy

### Parameter Validation Errors
- **Range Validation**: Ensure values within expected ranges (0-255, reasonable durations)
- **Type Validation**: Verify parameter types and combinations
- **Mode-Specific Rules**: Apply validation rules specific to each mode

### Execution Errors
- **BLE Communication Failures**: Handle connection issues during command transmission
- **Device Compatibility**: Verify device supports requested dynamic modes
- **Parameter Encoding**: Catch encoding errors before BLE transmission

### UI Error States
- **Validation Feedback**: Real-time error messages for invalid parameters
- **Execution Status**: Visual feedback for command execution success/failure
- **Fallback Options**: Graceful degradation to static modes if dynamic modes fail

## Performance Considerations

### Memory Usage
- **Command Objects**: Lightweight command classes with minimal memory footprint
- **Parameter Storage**: Efficient storage of mode-specific parameters
- **UI State**: Optimized state management for dynamic parameter forms

### Execution Performance
- **Command Encoding**: Efficient byte array generation for BLE packets
- **Validation Speed**: Fast parameter validation without UI blocking
- **Preview Rendering**: Optimized preview visualization for dynamic effects

### BLE Communication
- **Packet Size**: Dynamic mode commands slightly larger than static commands
- **Transmission Time**: Minimal impact on BLE transmission performance
- **Command Queue**: Handle multiple dynamic commands in sequence

## Testing Strategy

### Unit Tests
- **Parameter Validation**: Test all validation scenarios for each mode
- **Command Encoding**: Verify correct BLE packet generation
- **Edge Cases**: Test boundary values and error conditions

### Integration Tests
- **End-to-End Flow**: Test complete orchestration execution with dynamic modes
- **BLE Communication**: Verify command transmission to real PowerHub devices
- **UI Interaction**: Test parameter input and validation flow

### User Testing
- **Usability**: Evaluate user experience with dynamic parameter configuration
- **Effect Visualization**: Verify preview accurately represents real effects
- **Workflow Integration**: Test dynamic modes within complete orchestration workflows

## Future Extensibility

### Potential Extensions
- **Custom Waveforms**: Support for user-defined timing curves
- **Effect Presets**: Predefined gradient, blink, and strobe patterns
- **Music Sync**: Integration with audio input for synchronized effects
- **Scene Templates**: Templates combining multiple dynamic effects

### Architectural Considerations
- **Plugin Architecture**: Design for easy addition of new modes
- **Configuration Persistence**: Save dynamic effect configurations
- **Performance Monitoring**: Track execution performance and device response
- **Version Compatibility**: Handle firmware updates with new mode support