## MODIFIED Requirements

### Requirement: Multi-Channel Current Data Collection
The system SHALL collect and sum current data from multiple channels according to comma-separated channel parameters.

#### Scenario: Collect single channel current (backward compatibility)
- **WHEN** a status slot specifies CHANNEL_CURRENT with parameter "0"
- **THEN** the system shall read current data from channel 0 of the target PowerHub device
- **AND** return the single channel current value
- **AND** display the value in amperes with existing formatting

#### Scenario: Collect and sum multiple channel currents
- **WHEN** a status slot specifies CHANNEL_CURRENT with parameter "0,1,2"
- **THEN** the system shall read current data from channels 0, 1, and 2 of the target PowerHub device
- **AND** calculate the sum of all channel current values
- **AND** return the summed current value
- **AND** display the sum in amperes with existing formatting

#### Scenario: Handle multi-channel data collection errors
- **WHEN** data collection fails for one channel in a multi-channel parameter "0,1,2"
- **THEN** the system shall collect data from successful channels (0 and 2)
- **AND** calculate sum using only successful channel readings
- **AND** display warning indicator for partial data
- **AND** continue normal operation with available data

#### Scenario: Handle complete multi-channel data collection failure
- **WHEN** data collection fails for all channels in a multi-channel parameter
- **THEN** the system shall display connection error indicator
- **AND** show "--" for the current value
- **AND** implement retry logic for connection recovery

#### Scenario: Maintain performance with multi-channel operations
- **WHEN** collecting data from multiple channels simultaneously
- **THEN** the system shall optimize BLE operations to minimize data collection time
- **AND** batch channel reads where device protocol allows
- **AND** complete multi-channel collection within 3 seconds

## ADDED Requirements

### Requirement: Channel Current Sum Calculation
The system SHALL calculate accurate sums of multiple channel current values for display.

#### Scenario: Calculate simple sum of two channels
- **WHEN** channel 0 reports 1.250A and channel 1 reports 0.875A
- **THEN** the system shall calculate sum as 2.125A
- **AND** display the result with 3 decimal places precision
- **AND** maintain accuracy across floating-point operations

#### Scenario: Calculate sum of multiple channels
- **WHEN** channels [0,1,2,3] report [1.250A, 0.875A, 1.100A, 0.650A]
- **THEN** the system shall calculate sum as 3.875A
- **AND** handle variable number of channels in sum calculation
- **AND** ensure precision is maintained for all channel combinations

#### Scenario: Handle zero current channels in sum
- **WHEN** some channels in multi-channel parameter report 0.000A
- **THEN** the system shall include zero values in sum calculation
- **AND** display accurate sum excluding non-contributing channels
- **AND** not filter out zero values from calculation

#### Scenario: Handle decimal precision in sum calculation
- **WHEN** summing channels with various decimal values
- **THEN** the system shall maintain 3 decimal place precision
- **AND** round final sum appropriately for display
- **AND** avoid floating-point precision errors

### Requirement: Multi-Channel Display Formatting
The system SHALL format multi-channel current sum displays appropriately for the UI.

#### Scenario: Display multi-channel sum with proper formatting
- **WHEN** displaying sum of channels 0,1,2 as 3.125A
- **THEN** the system SHALL format display as "3.125A"
- **AND** SHALL use consistent formatting with single channel displays
- **AND** SHALL maintain 3 decimal place precision

#### Scenario: Generate appropriate labels for multi-channel displays
- **WHEN** no custom label is provided for multi-channel parameter "0,1,2"
- **THEN** the system SHALL generate default label "Channels 0,1,2 Current"
- **AND** SHALL display user-provided label when available
- **AND** SHALL support labels for both single and multi-channel configurations

#### Scenario: Handle display formatting edge cases
- **WHEN** sum calculation results in exactly 1.000A
- **THEN** the system SHALL display as "1.000A" (not "1A")
- **AND** SHALL maintain consistent decimal place display across all values
- **AND** SHALL handle formatting for very small or very large current sums

### Requirement: Multi-Channel Data Collection Optimization
The system SHALL optimize data collection performance for multi-channel current monitoring.

#### Scenario: Optimize BLE operations for multiple channels
- **WHEN** collecting data from channels 0,1,2,3,4,5
- **THEN** the system SHALL attempt to batch channel reads where protocol supports
- **AND** SHALL minimize number of BLE operations
- **AND** SHALL complete collection within performance targets

#### Scenario: Implement parallel channel data collection
- **WHEN** device protocol supports parallel channel reads
- **THEN** the system SHALL collect multiple channels simultaneously
- **AND** SHALL reduce overall data collection time
- **AND** SHALL handle partial failures in parallel operations

#### Scenario: Cache multi-channel data efficiently
- **WHEN** collecting data for multi-channel display
- **THEN** the system SHALL cache individual channel data for reuse
- **AND** SHALL update cache efficiently when individual channels change
- **AND** SHALL maintain cache coherence across multiple status slots

### Requirement: Multi-Channel Error Handling and Recovery
The system SHALL handle errors gracefully in multi-channel data collection scenarios.

#### Scenario: Partial channel data collection failure
- **WHEN** channel 1 data collection fails but channels 0 and 2 succeed for parameter "0,1,2"
- **THEN** the system SHALL display sum of successful channels (0 + 2)
- **AND** SHALL show warning indicator for partial data
- **AND** SHALL continue retrying failed channel individually
- **AND** SHALL update sum automatically when failed channel recovers

#### Scenario: Retry logic for individual channel failures
- **WHEN** a specific channel in multi-channel parameter consistently fails
- **THEN** the system SHALL implement individual channel retry logic
- **AND** SHALL not affect data collection from other channels
- **AND** SHALL track retry attempts per channel
- **AND** SHALL provide detailed error reporting

#### Scenario: Device connection issues affecting multi-channel data
- **WHEN** connection to PowerHub device is lost during multi-channel data collection
- **THEN** the system SHALL implement connection recovery procedures
- **AND** SHALL resume multi-channel data collection when connection restored
- **AND** SHALL maintain status indicators during connection issues
- **AND** SHALL preserve user configuration during connection problems