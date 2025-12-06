## MODIFIED Requirements

### Requirement: Extended CommandActionType for Dynamic Modes
The orchestration system SHALL extend the CommandActionType enum to support PowerHub dynamic action modes.

#### Scenario: Create gradient mode action with target value and duration
- **WHEN** user creates an orchestration action with type gradientMode
- **THEN** the system SHALL accept parameters for target brightness (0-255) and duration (milliseconds)
- **AND** SHALL validate that target value is within PWM range
- **AND** SHALL validate that duration is reasonable (1ms to 60 seconds)
- **AND** SHALL create CommandAction with gradientMode type and validated parameters

#### Scenario: Create blink mode action with period timing
- **WHEN** user creates an orchestration action with type blinkMode
- **THEN** the system SHALL accept parameter for period (milliseconds)
- **AND** SHALL validate that period is within reasonable range (50ms to 10 seconds)
- **AND** SHALL create CommandAction with blinkMode type and validated period

#### Scenario: Create strobe mode action with complex timing parameters
- **WHEN** user creates an orchestration action with type strobeMode
- **THEN** the system SHALL accept parameters for count, total time, and pause time
- **AND** SHALL validate that count is between 1 and 255
- **AND** SHALL validate that total time and pause time are reasonable (10ms to 60 seconds)
- **AND** SHALL ensure pause time is less than total time
- **AND** SHALL create CommandAction with strobeMode type and validated parameters

#### Scenario: Maintain backward compatibility with existing channelValue actions
- **WHEN** existing orchestration configurations use channelValue actions
- **THEN** the system SHALL continue to support channelValue actions without modification
- **AND** SHALL preserve existing parameter structure and behavior
- **AND** SHALL maintain compatibility with existing JSON serialization format

## ADDED Requirements

### Requirement: Dynamic Mode Parameter Validation
The system SHALL provide comprehensive validation for dynamic action mode parameters.

#### Scenario: Validate gradient mode parameters
- **WHEN** user configures gradient mode with target value 300
- **THEN** the system SHALL reject the configuration with error "Target value must be between 0 and 255"
- **AND** SHALL highlight the invalid target value field in the UI

- **WHEN** user configures gradient mode with duration 70000ms (70 seconds)
- **THEN** the system SHALL reject the configuration with error "Duration must be between 1ms and 60 seconds"
- **AND** SHALL provide suggested maximum value

#### Scenario: Validate blink mode parameters
- **WHEN** user configures blink mode with period 25ms
- **THEN** the system SHALL reject the configuration with error "Period must be at least 50ms for visible blinking"
- **AND** SHALL provide recommended minimum value

- **WHEN** user configures blink mode with period 15000ms (15 seconds)
- **THEN** the system SHALL warn about long period times
- **AND** SHALL allow configuration with user confirmation

#### Scenario: Validate strobe mode parameters
- **WHEN** user configures strobe mode with pause time greater than total time
- **THEN** the system SHALL reject configuration with error "Pause time must be less than total time"
- **AND** SHALL highlight both time parameters for correction

- **WHEN** user configures strobe mode with count 0 or 256
- **THEN** the system SHALL reject configuration with error "Count must be between 1 and 255"
- **AND** SHALL provide valid range information

### Requirement: Mode-Specific Command Generation
The system SHALL generate PowerHub BLE command packets for each dynamic action mode according to protocol specifications.

#### Scenario: Generate gradient mode BLE command
- **WHEN** orchestrating gradient mode action with channel 2, target value 180, duration 2000ms
- **THEN** the system SHALL generate BLE packet: `[0x01][0x02][0xB4][0x07][0xD0]`
- **AND** SHALL encode duration as 16-bit big-endian value (0x07D0 = 2000)
- **AND** SHALL transmit command to PowerHub device via BLE service

#### Scenario: Generate blink mode BLE command
- **WHEN** orchestrating blink mode action with channel 1, period 1000ms
- **THEN** the system SHALL generate BLE packet: `[0x02][0x01][0x03][0xE8]`
- **AND** SHALL encode period as 16-bit big-endian value (0x03E8 = 1000)
- **AND** SHALL verify command format matches POWERHUB_BLE.md specification

#### Scenario: Generate strobe mode BLE command
- **WHEN** orchestrating strobe mode action with channel 3, count 5, totalTime 3000ms, pauseTime 500ms
- **THEN** the system SHALL generate BLE packet: `[0x03][0x03][0x05][0x0B][0xB8][0x01][0xF4]`
- **AND** SHALL encode all time parameters as 16-bit big-endian values
- **AND** SHALL ensure byte order matches protocol specification

### Requirement: Dynamic Action UI Configuration
The orchestration interface SHALL support configuration of dynamic action mode parameters with intuitive user experience.

#### Scenario: Configure gradient mode parameters in orchestration UI
- **WHEN** user selects gradient mode from action type dropdown
- **THEN** the system SHALL display fields for target value (0-255 slider) and duration (ms input)
- **AND** SHALL show real-time preview of gradient effect duration
- **AND** SHALL provide helper text explaining gradient behavior

#### Scenario: Configure blink mode parameters in orchestration UI
- **WHEN** user selects blink mode from action type dropdown
- **THEN** the system SHALL display field for period (ms input with validation)
- **AND** SHALL show visual representation of blink timing
- **AND** SHALL provide examples of common period values (fast, medium, slow)

#### Scenario: Configure strobe mode parameters in orchestration UI
- **WHEN** user selects strobe mode from action type dropdown
- **THEN** the system SHALL display fields for count, total time, and pause time
- **AND** SHALL show timeline visualization of strobe pattern
- **AND** SHALL provide calculation of effective strobe frequency

#### Scenario: Show context-sensitive help for dynamic parameters
- **WHEN** user hovers over duration field in gradient mode
- **THEN** the system SHALL display tooltip explaining duration measurement and typical values
- **AND** SHALL provide examples for different use cases (quick fade, slow transition)

- **WHEN** user hovers over period field in blink mode
- **THEN** the system SHALL explain relationship between period and blink frequency
- **AND** SHALL show frequency calculation (Hz = 1000/period)

### Requirement: Dynamic Action Preview and Visualization
The system SHALL provide preview capabilities for dynamic action modes to help users understand effects before execution.

#### Scenario: Preview gradient mode effect timeline
- **WHEN** user configures gradient mode with 3-second duration
- **THEN** the system SHALL show timeline visualization starting from current value to target value
- **AND** SHALL indicate 3-second transition duration on timeline
- **AND** SHALL animate preview to show smooth transition effect

#### Scenario: Preview blink mode timing pattern
- **WHEN** user configures blink mode with 1000ms period
- **THEN** the system SHALL show visual pattern of on/off states with 500ms each
- **AND** SHALL display calculated frequency (1.0 Hz)
- **AND** SHALL animate preview with correct timing

#### Scenario: Preview strobe mode complex timing
- **WHEN** user configures strobe mode with count 5, totalTime 2000ms, pauseTime 300ms
- **THEN** the system SHALL show timeline with 5 strobe bursts and pause intervals
- **AND** SHALL calculate and display effective strobe rate
- **AND** SHALL animate preview with realistic timing visualization

#### Scenario: Show combined effect preview in orchestration sequence
- **WHEN** orchestration contains multiple dynamic actions
- **THEN** the system SHALL show combined preview timeline with all effects
- **AND** SHALL indicate overlapping or sequential effect timing
- **AND** SHALL highlight potential conflicts or interference between actions

### Requirement: Dynamic Action Execution and Monitoring
The system SHALL execute dynamic action modes and provide feedback on execution status and effect progress.

#### Scenario: Execute gradient mode with progress tracking
- **WHEN** gradient mode action starts execution
- **THEN** the system SHALL transmit gradient command to PowerHub device
- **AND** SHALL monitor execution progress over the specified duration
- **AND** SHALL provide visual feedback indicating transition in progress
- **AND** SHALL update status when transition completes

#### Scenario: Execute repeating blink mode actions
- **WHEN** blink mode action starts execution
- **THEN** the system SHALL transmit blink command to PowerHub device
- **AND** SHALL monitor for continuous blinking behavior
- **AND** SHALL provide status indicator showing active blinking
- **AND** SHALL handle command cancellation when sequence ends

#### Scenario: Execute strobe mode with count tracking
- **WHEN** strobe mode action starts execution
- **THEN** the system SHALL transmit strobe command to PowerHub device
- **AND** SHALL track progress through specified count of strobe bursts
- **AND** SHALL show remaining count during execution
- **AND** SHALL provide completion notification when all bursts finish

#### Scenario: Handle dynamic action execution errors
- **WHEN** PowerHub device fails to execute dynamic command
- **THEN** the system SHALL detect execution failure via BLE response
- **AND** SHALL display error message with troubleshooting information
- **AND** SHALL offer fallback to static value if available
- **AND** SHALL log error for debugging and device compatibility tracking

### Requirement: Dynamic Action Serialization and Persistence
The system SHALL properly serialize and deserialize dynamic action configurations for storage and sharing.

#### Scenario: Serialize gradient mode action to JSON
- **WHEN** saving orchestration configuration with gradient mode action
- **THEN** the system SHALL serialize gradient parameters in JSON format
- **AND** SHALL include type, channel, value, and duration fields
- **AND** SHALL maintain compatibility with existing JSON schema
- **AND** SHALL validate deserialization restores all parameters correctly

#### Scenario: Load orchestration configuration with dynamic actions
- **WHEN** loading saved orchestration containing dynamic actions
- **THEN** the system SHALL deserialize all dynamic action parameters
- **AND** SHALL validate loaded parameters against current validation rules
- **AND** SHALL handle migration from older schema versions if needed
- **AND** SHALL provide clear error messages for corrupted configurations

#### Scenario: Share orchestration configurations with dynamic actions
- **WHEN** user shares orchestration containing dynamic actions
- **THEN** the system SHALL export configuration in portable format
- **AND** SHALL include all dynamic action parameters
- **AND** SHALL ensure compatibility across different app versions
- **AND** SHALL validate configuration before export