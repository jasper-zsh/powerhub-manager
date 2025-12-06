## MODIFIED Requirements

### Requirement: Channel Current Parameter Validation for Multi-Channel Support
The system SHALL validate channel current parameters to support both single channel and comma-separated multi-channel formats.

#### Scenario: Validate single channel parameter (backward compatibility)
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with single channel parameter "0"
- **THEN** the system shall accept the parameter as valid
- **AND** validate that channel number is between 0 and 15
- **AND** return no validation error

#### Scenario: Validate multi-channel comma-separated parameter
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with parameter "0,1,2"
- **THEN** the system shall parse the comma-separated values into individual channel numbers
- **AND** validate each channel number is between 0 and 15
- **AND** ensure no duplicate channel numbers exist
- **AND** ensure total number of channels does not exceed 8
- **AND** return no validation error

#### Scenario: Reject invalid channel numbers in multi-channel parameter
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with parameter "0,16,2"
- **THEN** the system shall detect channel 16 as invalid (outside 0-15 range)
- **AND** return validation error indicating which channel is invalid
- **AND** reject the configuration

#### Scenario: Reject duplicate channels in multi-channel parameter
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with parameter "0,1,0"
- **THEN** the system shall detect channel 0 appears twice
- **AND** return validation error indicating duplicate channels not allowed
- **AND** reject the configuration

#### Scenario: Reject too many channels in parameter
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with 9 or more channel numbers
- **THEN** the system shall detect the parameter exceeds maximum channel limit
- **AND** return validation error indicating maximum 8 channels allowed
- **AND** reject the configuration

#### Scenario: Handle malformed parameter format
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with parameter "0,1.5,2"
- **THEN** the system shall detect the malformed number "1.5"
- **AND** return validation error indicating parameter format error
- **AND** reject the configuration

#### Scenario: Handle empty or null parameters
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" without params field
- **THEN** the system shall return validation error indicating parameters are required
- **AND** reject the configuration

## ADDED Requirements

### Requirement: Multi-Channel Parameter Parsing
The system SHALL parse comma-separated channel parameters into structured channel lists for data collection.

#### Scenario: Parse simple comma-separated parameter
- **WHEN** parsing parameter "1,2,3"
- **THEN** the system shall split the string by commas
- **AND** trim whitespace from each segment
- **AND** convert each segment to integer
- **AND** return channel list [1, 2, 3]

#### Scenario: Parse parameter with whitespace
- **WHEN** parsing parameter " 1 , 2 , 3 "
- **THEN** the system shall trim whitespace from each channel number
- **AND** successfully parse into channel list [1, 2, 3]
- **AND** handle irregular spacing gracefully

#### Scenario: Parse single channel parameter (backward compatibility)
- **WHEN** parsing parameter "5"
- **THEN** the system shall return single-channel list [5]
- **AND** behave identically to existing single channel parsing

#### Scenario: Parse non-sequential channel parameter
- **WHEN** parsing parameter "1,3,5,7"
- **THEN** the system shall return channel list [1, 3, 5, 7]
- **AND** support any combination of valid channel numbers

#### Scenario: Parse parameter in mixed order
- **WHEN** parsing parameter "5,2,8,1"
- **THEN** the system shall return channel list [5, 2, 8, 1]
- **AND** preserve the order specified by user
- **AND** not sort or reorder channel numbers

### Requirement: Channel List Validation
The system SHALL validate parsed channel lists according to business rules and constraints.

#### Scenario: Validate channel range constraints
- **WHEN** channel list contains negative number "-1"
- **THEN** the system shall identify negative channel as invalid
- **AND** return specific error about negative channels

- **WHEN** channel list contains number "16"
- **THEN** the system shall identify channel 16 as exceeding maximum
- **AND** return specific error about channel range violation

#### Scenario: Validate channel uniqueness constraints
- **WHEN** channel list contains duplicate "3,5,3"
- **THEN** the system shall detect channel 3 appears twice
- **AND** return error about duplicate channels not allowed
- **AND** provide helpful message indicating which channel is duplicated

#### Scenario: Validate channel count constraints
- **WHEN** channel list contains 9 channels "0,1,2,3,4,5,6,7,8"
- **THEN** the system shall identify this exceeds maximum of 8 channels
- **AND** return error about maximum channel limit
- **AND** suggest reducing number of channels

### Requirement: Parameter Description Updates
The system SHALL update parameter descriptions to reflect new multi-channel capabilities.

#### Scenario: Update parameter description for single channel
- **WHEN** user queries parameter description for CHANNEL_CURRENT
- **THEN** the system shall indicate support for both single and multiple channels
- **AND** provide examples of both formats
- **AND** explain comma-separated syntax

#### Scenario: Provide format examples in parameter description
- **WHEN** displaying help for CHANNEL_CURRENT parameters
- **THEN** the system shall show examples: "0", "1,2,3", "0,2,4,6"
- **AND** explain each format represents valid channel combinations
- **AND** mention constraints (max 8 channels, no duplicates)