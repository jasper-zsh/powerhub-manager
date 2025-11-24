## MODIFIED Requirements

### Requirement: Real-time Monitoring Data
The system SHALL provide real-time monitoring data for available sensors based on device capabilities, excluding total current.

#### Scenario: Variable sensor monitoring
- **WHEN** receiving FFF6 monitoring data from a device
- **THEN** the system SHALL parse available sensor data based on discovered capabilities
- **INCLUDING** input voltage, temperature sensors (if available), per-channel currents (if available)
- **AND** ignore total current field in monitoring data

#### Scenario: Temperature sensor variability
- **WHEN** device supports M temperature sensors (0 ≤ M ≤ 4)
- **THEN** the system SHALL process temperature data for each available sensor
- **AND** gracefully handle missing or invalid temperature sensor data

#### Scenario: Per-channel current monitoring
- **WHEN** device supports per-channel current sensing
- **THEN** the system SHALL display individual channel current for each PWM channel
- **AND** calculate aggregated metrics (sum, average) from available channels

## REMOVED Requirements

### Requirement: Total Input Current Monitoring
**Reason**: Total current is redundant with per-channel current and not supported by all device variants.
**Migration**: Remove total current field, calculate aggregates from per-channel data when needed.

The system SHALL monitor and display total input current via the FFF6 characteristic.