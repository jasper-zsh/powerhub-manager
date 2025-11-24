## ADDED Requirements

### Requirement: Dynamic PWM Channel Discovery
The system SHALL discover the actual number of PWM channels supported by a PowerHub device by reading the FFF1 characteristic and interpreting the response length.

#### Scenario: Channel count discovery during connection
- **WHEN** establishing a new connection to a PowerHub device
- **THEN** the system SHALL read the FFF1 characteristic
- **AND** interpret the response length to determine PWM channel count (N bytes = N channels)
- **AND** configure the device model with exactly N channels

#### Scenario: Fallback capability detection
- **WHEN** FFF1 characteristic read fails or returns invalid data
- **THEN** the system SHALL default to 6 PWM channels
- **AND** log the fallback behavior for debugging

### Requirement: Device Capability Caching
The system SHALL cache discovered device capabilities persistently to avoid repeated capability detection operations.

#### Scenario: Capability cache hit
- **WHEN** reconnecting to a previously discovered device
- **THEN** the system SHALL use cached PWM channel count and sensor configuration
- **AND** skip FFF1 characteristic read for faster connection

#### Scenario: Capability cache invalidation
- **WHEN** device firmware version changes or cache corruption detected
- **THEN** the system SHALL re-discover device capabilities
- **AND** update the persistent cache

### Requirement: Flexible Sensor Configuration
The system SHALL support devices with variable sensor configurations including 0 or more temperature sensors and optional per-channel current sensing.

#### Scenario: Temperature sensor discovery
- **WHEN** discovering device capabilities
- **THEN** the system SHALL detect the number of available temperature sensors
- **AND** configure monitoring data model accordingly

#### Scenario: Per-channel current detection
- **WHEN** discovering device capabilities
- **THEN** the system SHALL detect if per-channel current sensing is available
- **AND** enable/disable current monitoring features based on capability

### Requirement: Device Capability Reporting
The system SHALL provide an interface to query device capabilities including channel count and available sensors.

#### Scenario: Capability query
- **WHEN** UI components need to render device-specific controls
- **THEN** the system SHALL provide accurate device capability information
- **INCLUDING** PWM channel count, temperature sensor count, current sensing availability
- **AND** update UI elements appropriately

## REMOVED Requirements

### Requirement: Fixed Six Channel Support
**Reason**: Hardware now supports variable channel counts, fixed assumption limits device support.
**Migration**: Replace with dynamic channel discovery using FFF1 characteristic.

The system SHALL assume all PowerHub devices have exactly 6 PWM channels.

### Requirement: Total Current Sensor Support
**Reason**: Per-channel current provides more granular data, total current adds redundancy.
**Migration**: Remove total current from monitoring model, update UI to use per-channel current aggregation.

The system SHALL support total input current monitoring via the FFF6 characteristic.