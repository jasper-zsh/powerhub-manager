## ADDED Requirements

### Requirement: Per-Channel Current Aggregation
The system SHALL calculate and display total current by aggregating per-channel current measurements when total current sensor data is unavailable.

#### Scenario: UI displays calculated total current
- **WHEN** the monitoring interface requires total current display
- **THEN** the system SHALL sum all available per-channel current values
- **AND** display the result as calculated total current
- **AND** label the value to distinguish from sensor-measured totals

#### Scenario: Invalid channel current data handling
- **WHEN** one or more per-channel current values are invalid or unavailable
- **THEN** the system SHALL exclude invalid channels from total calculation
- **AND** display the sum of valid channels only
- **AND** indicate the calculation is partial if applicable

## MODIFIED Requirements

### Requirement: Monitoring Data Structure
The system SHALL parse monitoring data from FFF6 characteristic without total current field, using only voltage, temperature, per-channel currents, and status flags.

#### Scenario: FFF6 data parsing
- **WHEN** receiving 32-byte monitoring data from FFF6 characteristic
- **THEN** the system SHALL parse input voltage (2 bytes), power zone temperature (2 bytes), control zone temperature (2 bytes)
- **AND** parse per-channel current values (4 bytes per channel, variable count)
- **AND** parse system status flags (1 byte)
- **AND** ignore any bytes that previously contained total current data

#### Scenario: Legacy 36-byte data handling
- **WHEN** receiving 36-byte data from older firmware
- **THEN** the system SHALL parse the first 32 bytes as current format
- **AND** skip the total current field (bytes 6-9)
- **AND** continue parsing remaining per-channel currents from offset 10

## REMOVED Requirements

### Requirement: Total Input Current Monitoring
**Reason**: Hardware no longer includes total current sensor, removal prevents runtime errors and maintains alignment with physical device capabilities.
**Migration**: Replace with calculated total from per-channel current aggregation.

The system SHALL monitor and display total input current via the FFF6 characteristic.

#### Scenario: Total current display
- **WHEN** monitoring screen displays current information
- **THEN** total input current SHALL be shown from sensor data

### Requirement: FFF6 Total Current Parsing
**Reason**: Total current bytes removed from FFF6 data structure, parsing needs to skip these bytes.
**Migration**: Update parsing to exclude total current bytes and handle reduced data length.

The system SHALL parse total input current value from bytes 6-9 of the FFF6 characteristic data.

#### Scenario: Total current extraction
- **WHEN** processing FFF6 monitoring data
- **THEN** extract 32-bit float total current from bytes 6-9
- **AND** convert to amperes for display