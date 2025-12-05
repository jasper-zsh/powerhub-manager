## ADDED Requirements

### Requirement: Status Slot Configuration Parsing
The system SHALL parse status slot configurations from SwitchHub BLE 0xFFF3 characteristic JSON data.

#### Scenario: Parse valid status slots configuration
- **WHEN** a SwitchHub device sends configuration data with status_slots array
- **THEN** the system shall parse each status slot into structured data models
- **AND** validate data_type, source_mac, and parameters according to protocol
- **AND** reject invalid configurations with appropriate error messages

#### Scenario: Handle invalid status slot JSON
- **WHEN** the status_slots JSON contains invalid data_type or malformed parameters
- **THEN** the system shall log validation errors
- **AND** skip invalid slots without crashing the parsing process

### Requirement: Multi-Device Status Data Orchestration
The system SHALL collect and coordinate status data from multiple BLE devices according to status slot configurations.

#### Scenario: Local voltage data collection
- **WHEN** a status slot specifies source_mac as "LOCAL" and data_type as "VOLTAGE"
- **THEN** the system shall read voltage data from the local SwitchHub device
- **AND** format the value in volts with appropriate precision
- **AND** update the UI display every 2 seconds

#### Scenario: Remote device data collection
- **WHEN** a status slot specifies a remote PowerHub MAC address
- **THEN** the system shall establish BLE connection to the remote device
- **AND** collect the specified data type from the appropriate characteristic
- **AND** handle connection failures gracefully with fallback behavior

#### Scenario: Channel current monitoring
- **WHEN** a status slot specifies data_type as "CHANNEL_CURRENT" with channel parameter
- **THEN** the system shall read current data from the specified PowerHub channel
- **AND** validate channel parameter range (0-15)
- **AND** display the current value in amperes with appropriate formatting

#### Scenario: Temperature zone monitoring
- **WHEN** a status slot specifies data_type as "TEMPERATURE" with zone parameter
- **THEN** the system shall read temperature data from the specified zone ("POWER" or "CONTROL")
- **AND** validate zone parameter values
- **AND** display temperature in degrees Celsius

### Requirement: Status Data Type Support
The system SHALL support all status data types defined in the SwitchHub BLE protocol.

#### Scenario: Voltage data type
- **WHEN** processing VOLTAGE data type from any source
- **THEN** the system shall convert millivolt values to volts (V)
- **AND** display with 2 decimal places for precision
- **AND** handle missing or invalid voltage data appropriately

#### Scenario: Total current data type
- **WHEN** processing TOTAL_CURRENT data type from PowerHub devices
- **THEN** the system shall calculate the sum of all channel currents
- **AND** display the result in amperes (A)
- **AND** update the display when individual channel values change

#### Scenario: Temperature data type
- **WHEN** processing TEMPERATURE data type with zone parameter
- **THEN** the system shall read temperature from the specified device zone
- **AND** display in degrees Celsius (°C)
- **AND** handle cases where temperature sensors are not available

### Requirement: Connection Health Management
The system SHALL monitor and maintain connections to remote devices for status data collection.

#### Scenario: Remote device connection failure
- **WHEN** connection to a remote PowerHub device fails
- **THEN** the system shall display connection status indicators
- **AND** implement automatic retry logic with exponential backoff
- **AND** show "--" for unavailable data during connection issues

#### Scenario: Connection recovery
- **WHEN** a previously disconnected remote device becomes available
- **THEN** the system shall automatically re-establish the connection
- **AND** resume normal data collection and display
- **AND** clear any error indicators in the UI

### Requirement: Data Refresh and Caching
The system SHALL implement efficient data refresh strategies and caching for status information.

#### Scenario: Local data refresh
- **WHEN** displaying local device status data
- **THEN** the system shall refresh the data every 2 seconds
- **AND** update the UI immediately when new values are available
- **AND** maintain a cache of recent values for smooth display

#### Scenario: Remote data refresh
- **WHEN** displaying remote device status data
- **THEN** the system shall refresh data based on connection quality and data type
- **AND** implement intelligent refresh intervals to optimize BLE traffic
- **AND** cache data to handle temporary connection interruptions