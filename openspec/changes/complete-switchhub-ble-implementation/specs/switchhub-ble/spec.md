## ADDED Requirements

### Requirement: SwitchHub BLE Service Discovery
The system SHALL discover SwitchHub devices using the specific service UUID and parse advertisement data.

#### Scenario: Successful device discovery
- **WHEN** BLE scanning is initiated
- **THEN** the system shall filter devices using service UUID `119B5F1B-1C7A-3E8E-6147-672F-0200-0B5E`
- **AND** parse advertisement data for device capabilities
- **AND** maintain a registry of discovered devices

#### Scenario: Service UUID not found
- **WHEN** no devices with the specified service UUID are found
- **THEN** the system shall continue scanning with timeout
- **AND** provide appropriate user feedback

### Requirement: Configuration Reading Protocol
The system SHALL read complete configuration data from SwitchHub devices using chunked transfer.

#### Scenario: Read complete configuration
- **WHEN** configuration read is requested
- **THEN** the system shall first read metadata from characteristic 0xFFF3
- **AND** extract total_size, chunk_size, schema_version, and revision
- **AND** use ATT Read Blob with offset to retrieve all chunks
- **AND** reassemble complete JSON configuration

#### Scenario: Chunked read error recovery
- **WHEN** a chunk read fails
- **THEN** the system shall retry the failed chunk up to 3 times
- **AND** abort the entire read operation if all retries fail
- **AND** provide specific error information to the user

### Requirement: Configuration Writing Protocol
The system SHALL write configuration data to SwitchHub devices using chunked transfer with validation.

#### Scenario: Successful configuration write
- **WHEN** configuration is pushed to device
- **THEN** the system shall split JSON into chunks of appropriate size
- **AND** write each chunk using `[chunk_seq(2B)][total_chunks(2B)][payload...]` format
- **AND** validate complete reception before considering write successful

#### Scenario: Write failure handling
- **WHEN** device returns error during chunk write
- **THEN** the system shall abort the entire write operation
- **AND** report specific error details
- **AND** maintain device in consistent state

### Requirement: Service Connection Management
The system SHALL maintain robust connections with SwitchHub devices including proper disconnect handling.

#### Scenario: Connection establishment
- **WHEN** connecting to a SwitchHub device
- **THEN** the system shall perform service discovery
- **AND** negotiate MTU size for optimal transfer
- **AND** establish notification subscriptions

#### Scenario: Unexpected disconnection
- **WHEN** connection is lost unexpectedly
- **THEN** the system shall attempt automatic reconnection up to 3 times
- **AND** restore notification subscriptions
- **AND** notify user of connection status changes

## MODIFIED Requirements

### Requirement: Status Flag Format
The system SHALL use SwitchHub-compliant status flag format with bit1=0 indicating no temperature.

#### Scenario: Status flag interpretation
- **WHEN** reading status flags from characteristic 0xFFF2
- **THEN** the system shall interpret bit1=0 as no temperature sensor available
- **AND** ignore legacy flag bits that are not applicable to SwitchHub hardware
- **AND** provide appropriate status display based on available data

#### Scenario: Status flag generation
- **WHEN** generating status data for notifications
- **THEN** the system shall set bit1=0 consistently
- **AND** include only relevant system state information
- **AND** maintain compatibility with existing parsers

### Requirement: Configuration Management UI
The system SHALL provide user interface for reading, writing, and managing SwitchHub device configurations.

#### Scenario: Configuration reading interface
- **WHEN** user initiates configuration read from device
- **THEN** the system shall display progress bar with chunk transfer status
- **AND** show current operation (reading metadata, downloading chunks, assembling)
- **AND** provide estimated time remaining for large configurations
- **AND** allow cancellation of long-running read operations

#### Scenario: Configuration comparison and diff view
- **WHEN** multiple device configurations are available
- **THEN** the system shall provide side-by-side comparison interface
- **AND** highlight differences in switch logic, thresholds, and UI settings
- **AND** allow selective copying of configuration sections between devices
- **AND** show version history and change timestamps

#### Scenario: Bulk configuration management
- **WHEN** managing configurations for multiple devices
- **THEN** the system shall provide multi-select interface for device groups
- **AND** allow simultaneous configuration push to selected devices
- **AND** show individual device operation status and progress
- **AND** provide roll-back capability for failed bulk operations

#### Scenario: Configuration backup and restore
- **WHEN** user creates configuration backup
- **THEN** the system shall store configuration with timestamp and device metadata
- **AND** provide restore interface with preview before applying
- **AND** support scheduling automatic periodic backups
- **AND** allow export/import of configuration files for external backup

### Requirement: Integration UI Enhancement
The system SHALL integrate new features seamlessly into existing user interface.

#### Scenario: Enhanced device list
- **WHEN** displaying device list
- **THEN** the system shall show real-time status indicators for each device
- **AND** display current battery level and connection status
- **AND** provide quick access buttons for monitoring and power management
- **AND** indicate devices with unsynchronized configuration changes

#### Scenario: Navigation integration
- **WHEN** user navigates the application
- **THEN** the system shall provide dedicated menu entries for new features
- **AND** integrate monitoring controls into existing orchestration workflows
- **AND** add power management options to device settings screens
- **AND** maintain consistent navigation patterns with existing UI