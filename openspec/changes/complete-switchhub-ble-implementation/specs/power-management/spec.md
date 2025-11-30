## ADDED Requirements

### Requirement: Voltage Threshold Management
The system SHALL manage sleep and wake voltage thresholds through characteristic 0xFFF1.

#### Scenario: Read voltage thresholds
- **WHEN** voltage thresholds are requested
- **THEN** the system shall read 4 bytes from characteristic 0xFFF1
- **AND** parse sleep voltage threshold from bytes 0-1 (uint16, mV)
- **AND** parse wake voltage threshold from bytes 2-3 (uint16, mV)
- **AND** validate thresholds are within acceptable ranges (3000-4200 mV)

#### Scenario: Set sleep voltage threshold
- **WHEN** sleep voltage threshold is set
- **THEN** the system shall write command `[0x01][voltage(2B)]` to characteristic 0xFFF1
- **AND** validate the voltage is within acceptable range
- **AND** return success if device acknowledges the command
- **AND** return appropriate error if command fails

#### Scenario: Set wake voltage threshold
- **WHEN** wake voltage threshold is set
- **THEN** the system shall write command `[0x02][voltage(2B)]` to characteristic 0xFFF1
- **AND** validate the voltage is within acceptable range
- **AND** ensure wake threshold is higher than sleep threshold
- **AND** return success if device acknowledges the command

### Requirement: Power Management Command Handling
The system SHALL handle all power management commands defined in the SwitchHub specification.

#### Scenario: Unsupported command rejection
- **WHEN** temperature-related commands (0x03, 0x04) are sent
- **THEN** the device shall return BLE_ATT_ERR_REQ_NOT_SUPPORTED
- **AND** the system shall handle this gracefully with user notification
- **AND** not retry temperature-specific commands

#### Scenario: Font update flow initiation
- **WHEN** font update command (0x05) is initiated
- **THEN** the system shall prepare for chunked font binary transfer
- **AND** validate font file size does not exceed 1024KB limit
- **AND** track chunk sequence numbers starting from 0
- **AND** validate each chunk before accepting next one

## MODIFIED Requirements

### Requirement: Power Management Characteristic Interface
The system SHALL provide a complete interface for all power management operations through characteristic 0xFFF1.

#### Scenario: Complete power management read
- **WHEN** reading power management configuration
- **THEN** the system shall return sleep and wake voltage thresholds
- **AND** include current power state information
- **AND** provide validation status of threshold values

#### Scenario: Power management error handling
- **WHEN** power management operations fail
- **THEN** the system shall map BLE ATT error codes to user-friendly messages
- **AND** provide retry mechanisms for transient failures
- **AND** maintain consistent device state despite failures

### Requirement: Power Management UI
The system SHALL provide user interface for configuring and managing SwitchHub power settings.

#### Scenario: Voltage threshold configuration interface
- **WHEN** user accesses power management settings
- **THEN** the system shall display current sleep and wake voltage thresholds
- **AND** provide dual-slider interface for adjusting both thresholds
- **AND** enforce wake threshold to be higher than sleep threshold
- **AND** show voltage values in both mV and percentage for clarity

#### Scenario: Safety validation UI
- **WHEN** user sets potentially unsafe voltage thresholds
- **THEN** the system shall display warning dialog with risks
- **AND** highlight out-of-range values in red
- **AND** provide recommended safe ranges with explanations
- **AND** require explicit confirmation before applying unsafe settings

#### Scenario: Power status visualization
- **WHEN** viewing power management dashboard
- **THEN** the system shall display current battery level as percentage
- **AND** show battery voltage with color-coded status indicator
- **AND** indicate current power mode (sleep/wake/active)
- **AND** provide quick toggle buttons for mode switching

#### Scenario: Power management quick actions
- **WHEN** user needs immediate power control
- **THEN** the system shall provide one-tap sleep/wake buttons
- **AND** show current power state prominently
- **AND** display time until next automatic action
- **AND** provide emergency stop for all power operations