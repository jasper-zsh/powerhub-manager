## MODIFIED Requirements

### Requirement: Multi-Channel Status Slot Display
The system SHALL display multi-channel current sum information in status slot widgets with appropriate formatting and indicators.

#### Scenario: Display single channel current (existing behavior)
- **WHEN** a status slot displays CHANNEL_CURRENT with parameter "0"
- **THEN** the system SHALL display current value with existing formatting
- **AND** SHALL use standard current icon and color scheme
- **AND** SHALL show label as configured by user
- **AND** SHALL maintain existing visual presentation

#### Scenario: Display multi-channel current sum
- **WHEN** a status slot displays CHANNEL_CURRENT with parameter "0,1,2"
- **THEN** the system SHALL display sum of channels 0, 1, and 2
- **AND** SHALL use same visual formatting as single channel display
- **AND** SHALL display appropriate icon for current data type
- **AND** SHALL show user-configured label or default multi-channel label

#### Scenario: Generate default labels for multi-channel displays
- **WHEN** no custom label is provided for multi-channel parameter "1,3,5"
- **THEN** the system SHALL generate default label "Channels 1,3,5 Current"
- **AND** SHALL display the generated label in the status slot
- **AND** SHALL format channel list clearly in the label

#### Scenario: Display user-configured labels for multi-channel
- **WHEN** user provides custom label "Living Room Lights" for parameter "0,2,4"
- **THEN** the system SHALL display the custom label instead of default
- **AND** SHALL maintain user's preferred naming for channel groups
- **AND** SHALL not show channel numbers when custom label is provided

## ADDED Requirements

### Requirement: Multi-Channel Status Indicators
The system SHALL provide visual indicators to distinguish single channel from multi-channel current displays.

#### Scenario: Show multi-channel indicator icon
- **WHEN** displaying status slot with multi-channel parameter "0,1,2"
- **THEN** the system SHALL display multi-channel indicator icon
- **AND** SHALL distinguish from single channel current icon
- **AND** SHALL maintain consistent visual design language
- **AND** SHALL provide tooltip explaining multi-channel display

#### Scenario: Display channel count information
- **WHEN** hovering over multi-channel status slot
- **THEN** the system SHALL show tooltip with channel information
- **AND** SHALL display "Channels: 0, 1, 2" in tooltip
- **AND** SHALL provide additional context about sum calculation
- **AND** SHALL help users understand what is being monitored

#### Scenario: Show multi-channel connection status
- **WHEN** some channels in multi-channel parameter have connection issues
- **THEN** the system SHALL display partial connection indicator
- **AND** SHALL distinguish from complete connection failure
- **AND** SHALL provide visual feedback about data availability
- **AND** SHALL allow users to identify which channels are problematic

### Requirement: Multi-Channel Status Slot Configuration
The system SHALL support configuration of multi-channel current parameters in status slot editor.

#### Scenario: Configure multi-channel parameters in status slot editor
- **WHEN** user edits status slot with CHANNEL_CURRENT data type
- **THEN** the system SHALL provide input field for channel parameters
- **AND** SHALL accept comma-separated channel numbers
- **AND** SHALL validate input in real-time
- **AND** SHALL show format helper text with examples

#### Scenario: Validate multi-channel input in real-time
- **WHEN** user types "0,1,2" in parameter input field
- **THEN** the system SHALL validate each channel number as typed
- **AND** SHALL show validation errors immediately for invalid inputs
- **AND** SHALL provide helpful error messages for format issues
- **AND** SHALL prevent saving invalid configurations

#### Scenario: Provide format assistance for multi-channel input
- **WHEN** user is editing CHANNEL_CURRENT parameters
- **THEN** the system SHALL display input format examples
- **AND** SHALL show "Examples: 0 (single channel), 0,1,2 (multi-channel)"
- **AND** SHALL provide context help for parameter format
- **AND** SHALL link to detailed documentation

### Requirement: Multi-Channel Error Display
The system SHALL display appropriate error states for multi-channel current monitoring.

#### Scenario: Display partial data errors
- **WHEN** some channels in multi-channel parameter fail to provide data
- **THEN** the system SHALL display warning icon in status slot
- **AND** SHALL show partial data warning message
- **AND** SHALL continue displaying sum of available channels
- **AND** SHALL indicate which channels are experiencing issues

#### Scenario: Display complete data failure
- **WHEN** all channels in multi-channel parameter fail to provide data
- **THEN** the system SHALL display error state in status slot
- **AND** SHALL show connection error icon and message
- **AND** SHALL display "--" instead of current value
- **AND** SHALL implement retry mechanism with visual feedback

#### Scenario: Show detailed error information on interaction
- **WHEN** user taps on multi-channel status slot with errors
- **THEN** the system SHALL display detailed error information
- **AND** SHALL show which specific channels are failing
- **AND** SHALL provide connection status for each channel
- **AND** SHALL offer retry options for failed channels

### Requirement: Multi-Channel Status Animation and Feedback
The system SHALL provide appropriate visual feedback for multi-channel status updates.

#### Scenario: Animate multi-channel value updates
- **WHEN** multi-channel sum value changes from 2.500A to 3.125A
- **THEN** the system SHALL animate the value change smoothly
- **AND** SHALL use consistent animation timing with single channel updates
- **AND** SHALL provide visual feedback for value changes
- **AND** SHALL maintain responsiveness during frequent updates

#### Scenario: Show loading states for multi-channel data collection
- **WHEN** collecting data from multiple channels
- **THEN** the system SHALL display loading indicator
- **AND** SHALL show progress for multi-channel data collection
- **AND** SHALL indicate when individual channels complete
- **AND** SHALL provide feedback about collection progress

#### Scenario: Display connection status changes for multi-channel
- **WHEN** connection status changes for channels in multi-channel display
- **THEN** the system SHALL update connection indicators appropriately
- **AND** SHALL animate transitions between connection states
- **AND** SHALL maintain visual consistency across status changes
- **AND** SHALL provide immediate feedback for status changes