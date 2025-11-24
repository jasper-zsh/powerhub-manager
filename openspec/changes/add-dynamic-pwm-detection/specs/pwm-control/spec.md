## MODIFIED Requirements

### Requirement: PWM Channel Control
The system SHALL provide control over all available PWM channels discovered on the connected PowerHub device.

#### Scenario: Variable channel count control
- **WHEN** controlling a device with N PWM channels (1 ≤ N ≤ 16)
- **THEN** the system SHALL provide individual control for each channel 0 through N-1
- **AND** enforce channel ID validation based on discovered channel count

#### Scenario: Channel control command validation
- **WHEN** sending control commands to a PWM channel
- **THEN** the system SHALL validate channel ID against discovered capabilities
- **AND** reject commands targeting non-existent channels with appropriate error

## REMOVED Requirements

### Requirement: Fixed Channel Range Validation
**Reason**: Channel count is now dynamic, fixed 0-5 range invalid for devices with different channel counts.
**Migration**: Implement dynamic range validation based on discovered channel count.

The system SHALL validate PWM channel IDs to be between 0 and 5 inclusive.