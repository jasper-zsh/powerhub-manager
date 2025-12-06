# Implementation Tasks: Add Dynamic Action Modes to Orchestration System

## Task 1: Extend CommandActionType and CommandAction Data Models
**File**: `lib/models/orchestration/toggle_scene.dart`
**Effort**: 2 hours
**Dependencies**: None

### Subtasks:
- [x] Add gradientMode, blinkMode, and strobeMode to CommandActionType enum
- [x] Extend CommandAction class with mode-specific parameters (duration, period, count, totalTime, pauseTime)
- [x] Update CommandAction validation logic for new action types
- [x] Update JSON serialization/deserialization for extended CommandAction
- [x] Update fromJson constructor to handle new action types with backward compatibility

### Acceptance Criteria:
- CommandActionType enum includes all three new dynamic modes
- CommandAction class accepts and validates mode-specific parameters
- JSON serialization preserves all dynamic action parameters
- Backward compatibility maintained for existing channelValue actions
- Validation provides clear error messages for invalid parameter combinations

## Task 2: Create Mode-Specific Command Classes
**Files**: `lib/models/control_command/`
**Effort**: 3 hours
**Dependencies**: Task 1

### Subtasks:
- [x] Create GradientModeCommand class extending ControlCommand
- [x] Create BlinkModeCommand class extending ControlCommand
- [x] Create StrobeModeCommand class extending ControlCommand
- [x] Implement proper BLE packet encoding according to POWERHUB_BLE.md specifications
- [x] Add validation logic for mode-specific parameter constraints
- [x] Add unit tests for all command encoding/decoding scenarios

### Acceptance Criteria:
- GradientModeCommand encodes target value and duration as [0x01][channel][value][duration_high][duration_low]
- BlinkModeCommand encodes period as [0x02][channel][period_high][period_low]
- StrobeModeCommand encodes count, total time, and pause time as [0x03][channel][count][total_time_high][total_time_low][pause_time_high][pause_time_low]
- All commands validate parameter ranges before encoding
- 100% test coverage for command encoding and validation

## Task 3: Extend BLE Service with Dynamic Mode Support
**File**: `lib/services/switch_hub_ble_service.dart`
**Effort**: 2 hours
**Dependencies**: Task 2

### Subtasks:
- [x] Add sendGradientCommand() method for gradient mode commands
- [x] Add sendBlinkCommand() method for blink mode commands
- [x] Add sendStrobeCommand() method for strobe mode commands
- [x] Update command routing logic to handle new command types
- [x] Add error handling for dynamic command transmission failures
- [x] Add integration tests for BLE service with new command types

### Acceptance Criteria:
- BLE service successfully transmits all dynamic mode commands
- Proper error handling for transmission failures and device incompatibility
- Integration tests verify end-to-end command transmission
- Command routing maintains existing functionality for static commands
- Performance acceptable for dynamic command sequences

## Task 4: Extend Orchestration Provider with Dynamic Action Execution
**File**: `lib/providers/orchestration_provider.dart`
**Effort**: 3 hours
**Dependencies**: Task 3

### Subtasks:
- [x] Update action execution logic to handle new CommandActionType values
- [x] Add mode-specific command creation and BLE service calls
- [x] Extend command bundle preview to handle dynamic actions
- [x] Add progress tracking for duration-based actions (gradient mode)
- [x] Update error handling for dynamic action execution failures
- [x] Add unit tests for orchestration provider with dynamic actions

### Acceptance Criteria:
- Orchestration provider executes all three dynamic action types correctly
- Preview functionality works with dynamic actions
- Error handling provides clear feedback for dynamic action failures
- Progress tracking works for gradient mode transitions
- Unit tests cover all dynamic action execution scenarios

## Task 5: Create Dynamic Action Parameter Validation System
**File**: `lib/models/orchestration/action_validator.dart` (new)
**Effort**: 2 hours
**Dependencies**: Task 1

### Subtasks:
- [x] Create ActionValidator class with mode-specific validation methods
- [x] Implement validateGradientMode() with range checks for value and duration
- [x] Implement validateBlinkMode() with period validation and frequency recommendations
- [x] Implement validateStrobeMode() with complex timing relationship validation
- [x] Add comprehensive error messages with suggested corrections
- [x] Add unit tests for all validation scenarios and edge cases

### Acceptance Criteria:
- Validation covers all parameter ranges and edge cases
- Error messages are user-friendly and include suggestions
- Validation prevents invalid parameters from reaching command generation
- Unit tests cover normal ranges, boundary conditions, and invalid inputs
- Validation performance acceptable for real-time UI validation

## Task 6: Update Command Bundle Editor UI for Dynamic Actions
**File**: `lib/widgets/orchestration/command_bundle_editor.dart`
**Effort**: 4 hours
**Dependencies**: Task 5

### Subtasks:
- [x] Add action type selector with new dynamic mode options
- [x] Create conditional parameter forms for each dynamic mode
- [x] Implement real-time parameter validation with error display
- [x] Add helper text and examples for each parameter field
- [x] Update action list display to show dynamic action descriptions
- [x] Add keyboard-friendly input methods for numeric parameters

### Acceptance Criteria:
- Users can select and configure all three dynamic action modes
- Real-time validation provides immediate feedback
- Parameter forms are intuitive with helpful guidance
- Dynamic actions display clearly in action list with descriptions
- UI remains responsive with parameter input and validation

## Task 7: Create Dynamic Action Preview Components
**File**: `lib/widgets/orchestration/dynamic_action_preview.dart` (new)
**Effort**: 4 hours
**Dependencies**: Task 6

### Subtasks:
- [x] Create GradientModePreview component with timeline visualization
- [x] Create BlinkModePreview component with pattern visualization
- [x] Create StrobeModePreview component with complex timing visualization
- [x] Add animated previews showing realistic effect timing
- [x] Implement frequency and duration calculations and display
- [x] Add combined preview for multiple dynamic actions in sequence

### Acceptance Criteria:
- Preview components accurately represent dynamic effect timing
- Animated previews show realistic visual representations
- Frequency and duration calculations are correct and clearly displayed
- Combined preview handles multiple dynamic actions effectively
- Preview performance is acceptable for real-time updates

## Task 8: Update Command Preview Sheet with Dynamic Action Support
**File**: `lib/widgets/orchestration/command_preview_sheet.dart`
**Effort**: 2 hours
**Dependencies**: Task 7

### Subtasks:
- [x] Update preview logic to handle dynamic action types
- [x] Integrate dynamic action preview components
- [x] Update command description generation for dynamic actions
- [x] Add timing information to command preview display
- [x] Ensure consistent styling with existing preview components

### Acceptance Criteria:
- Command preview sheet correctly displays all dynamic action types
- Dynamic action previews integrate seamlessly with existing preview logic
- Command descriptions clearly communicate dynamic action parameters
- Timing information is prominently displayed for temporal actions
- Visual consistency maintained across all action types

## Task 9: Add Comprehensive Unit Tests for Dynamic Actions
**Files**: Multiple test files
**Effort**: 3 hours
**Dependencies**: Tasks 1-8

### Subtasks:
- [x] Create test file for dynamic action data models (`test/unit/dynamic_action_test.dart`)
- [x] Create test file for command classes (`test/unit/dynamic_command_test.dart`)
- [x] Create test file for validation system (`test/unit/action_validator_test.dart`)
- [x] Create test file for preview components (`test/unit/dynamic_action_preview_test.dart`)
- [x] Update existing orchestration provider tests with dynamic actions
- [x] Create integration tests for complete dynamic action workflows

### Acceptance Criteria:
- 100% test coverage for new dynamic action functionality
- Tests cover normal operation, edge cases, and error conditions
- Integration tests verify end-to-end dynamic action workflows
- Existing tests continue to pass with extended functionality
- Performance tests ensure responsive UI with dynamic actions

## Task 10: Add Widget Tests for Dynamic Action UI
**Files**: Widget test files
**Effort**: 2 hours
**Dependencies**: Task 6, 7, 8

### Subtasks:
- [x] Create widget tests for command bundle editor with dynamic actions
- [x] Create widget tests for dynamic action preview components
- [x] Create widget tests for parameter validation and error display
- [x] Create widget tests for command preview sheet integration
- [x] Test UI responsiveness with various parameter combinations

### Acceptance Criteria:
- Widget tests cover all dynamic action UI components
- Tests verify correct parameter validation and error display
- Preview components render correctly with various parameter combinations
- UI maintains responsiveness with dynamic action configuration
- Integration tests verify complete user workflows

## Task 11: Integration Testing with Real PowerHub Devices
**Files**: Integration test files
**Effort**: 2 hours
**Dependencies**: All previous tasks

### Subtasks:
- [x] Create integration tests for gradient mode with real PowerHub devices
- [x] Create integration tests for blink mode with real PowerHub devices
- [x] Create integration tests for strobe mode with real PowerHub devices
- [x] Test complex orchestration sequences combining multiple dynamic actions
- [x] Verify timing accuracy and effect synchronization
- [x] Test error handling and recovery scenarios

### Acceptance Criteria:
- Integration tests verify correct PowerHub device response to dynamic commands
- Timing accuracy confirmed for all dynamic modes
- Complex orchestration sequences execute correctly
- Error handling works properly with real device communication
- Device compatibility verified across different PowerHub firmware versions

## Task 12: Documentation Updates
**Files**: Documentation files
**Effort**: 1 hour
**Dependencies**: Task 1

### Subtasks:
- [x] Update orchestration documentation with dynamic action examples
- [x] Add parameter reference guide for dynamic modes
- [x] Create troubleshooting guide for dynamic action issues
- [x] Update API documentation for extended CommandAction class
- [x] Add migration guide for existing orchestration configurations

### Acceptance Criteria:
- Documentation includes clear examples for all dynamic action modes
- Parameter reference provides comprehensive guidance for configuration
- Troubleshooting guide covers common issues and solutions
- API documentation accurately reflects extended functionality
- Migration guide helps users transition existing configurations

## Estimated Total Effort: 30 hours

## Parallel Work Opportunities:
- **Tasks 1, 2**: Can work in parallel (data model and command class development)
- **Tasks 3, 4**: Can work in parallel after Tasks 1, 2 (BLE service and orchestration provider)
- **Tasks 5, 6**: Can work in parallel after Task 1 (validation system and UI development)
- **Tasks 7, 8**: Can work in parallel after Task 6 (preview components and integration)
- **Tasks 9, 10**: Can work in parallel after implementation tasks
- **Task 11**: Must wait for all implementation tasks
- **Task 12**: Can work in parallel with other tasks after initial changes