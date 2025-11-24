## ADDED Requirements

### Requirement: Enhanced Font Upload Protocol
The system SHALL implement the SwitchHub font uploader protocol using dual BLE characteristics (0xFFF1 for data, 0xFFF2 for status) with comprehensive error handling, progress reporting, and automatic recovery mechanisms.

#### Scenario: Protocol initialization and subscription
- **WHEN** initiating a font upload session
- **THEN** the system SHALL connect to the SwitchHub device
- **AND** subscribe to characteristic 0xFFF2 for status notifications
- **AND** validate font file size is ≤ 1MB before upload
- **AND** check for existing upload sessions by monitoring 0xFFF2 for 0xFF 0x02

#### Scenario: Chunked data transmission via 0xFFF1
- **WHEN** uploading font data in chunks
- **THEN** the system SHALL send chunks with format: [0x05][length(2B)][sequence(2B)][data...]
- **AND** split font data into chunks ≤ 65,535 bytes
- **AND** use recommended chunk sizes of 4KB-16KB for optimal performance
- **AND** send chunks sequentially starting from sequence 0

#### Scenario: Upload completion and finalization
- **WHEN** all font data chunks have been sent
- **THEN** the system SHALL send zero-length completion packet: [0x05][0x00][0x00][final_seq_hi][final_seq_lo]
- **AND** wait for success notification (0xFF 0x00) or error response
- **AND** ensure font is applied immediately and persists after reboot on success

### Requirement: Real-time Progress Reporting
The system SHALL provide real-time progress feedback via 0xFFF2 notifications with sequence tracking and completion percentage estimation.

#### Scenario: Progress notification parsing
- **WHEN** receiving 0xFE prefixed notifications from 0xFFF2
- **THEN** the system SHALL parse progress format: [0xFE][seq_hi][seq_lo][percentage]
- **AND** validate sequence number matches expected chunk
- **AND** update progress indicators with completion percentage (0-100)
- **AND** rate-limit progress updates to minimum 1-second intervals

#### Scenario: Upload started notification
- **WHEN** device sends upload started notification (0xFF 0x02)
- **THEN** the system SHALL recognize upload session initialization
- **AND** reset progress tracking and timeout timers
- **AND** prepare for incoming chunked data transmission

#### Scenario: Upload success confirmation
- **WHEN** device sends success notification (0xFF 0x00)
- **THEN** the system SHALL mark upload as completed successfully
- **AND** trigger any post-upload validation or confirmation steps
- **AND** update UI to reflect successful font application

### Requirement: Comprehensive Error Handling
The system SHALL implement robust error handling with ATT error codes, custom error notifications, and automatic recovery mechanisms.

#### Scenario: ATT error handling
- **WHEN** receiving BLE ATT errors during chunk transmission
- **THEN** the system SHALL handle specific error codes:
  - BLE_ATT_ERR_INSUFFICIENT_RES: Memory allocation failed
  - BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN: Chunk size mismatch
  - BLE_ATT_ERR_UNLIKELY: Font validation or application failed
  - BLE_ATT_ERR_REQ_NOT_SUPPORTED: Malformed font data
  - BLE_ATT_ERR_INVALID_STATE: Invalid sequence or upload state
- **AND** implement appropriate recovery strategies for each error type

#### Scenario: Custom error notification handling
- **WHEN** receiving 0xFF prefixed error notifications from 0xFFF2
- **THEN** the system SHALL parse error format: [0xFF][error_code][param_hi][param_lo]
- **AND** handle specific error types:
  - 0x01: Timeout (30 seconds elapsed) - restart upload
  - 0x03: Font application failed - verify font format, retry
  - 0x04: Sequence error - restart upload from sequence 0
  - 0x05: Disconnection during upload - check connection, restart
- **AND** provide user-friendly error messages and recovery suggestions

#### Scenario: Error recovery with exponential backoff
- **WHEN** encountering recoverable errors during upload
- **THEN** the system SHALL implement exponential backoff retry logic
- **AND** restart upload from sequence 0 on sequence errors
- **AND** attempt memory optimization on allocation failures
- **AND** validate connection stability before retry attempts
- **AND** limit retry attempts to prevent infinite loops

### Requirement: Memory Management and Monitoring
The system SHALL monitor device memory usage during font uploads and handle memory constraints with warnings and automatic cleanup.

#### Scenario: Memory warning handling
- **WHEN** receiving 0xFD prefixed memory warnings from 0xFFF2
- **THEN** the system SHALL parse warning format: [0xFD][usage_hi][usage_mid][usage_lo]
- **AND** extract current memory usage (24-bit value)
- **AND** trigger warnings when usage exceeds 80% of 1MB limit (819KB)
- **AND** consider reducing chunk sizes or pausing upload if memory is critical

#### Scenario: Progressive memory allocation
- **WHEN** device allocates memory for font data chunks
- **THEN** the system SHALL expect progressive memory allocation behavior
- **AND** monitor for memory exhaustion during large font uploads
- **AND** provide feedback on memory usage throughout upload process

#### Scenario: Automatic cleanup on failure
- **WHEN** upload fails or is cancelled
- **THEN** the system SHALL ensure automatic cleanup of allocated memory
- **AND** reset device upload state to prevent memory leaks
- **AND** prepare device for subsequent upload attempts

### Requirement: Timeout Management and Reliability
The system SHALL implement robust timeout management to ensure reliable font uploads with automatic recovery from stalled transfers.

#### Scenario: Chunk timeout handling
- **WHEN** sending font data chunks
- **THEN** the system SHALL maintain 30-second timeout per chunk
- **AND** reset timeout timer on each successful chunk transmission
- **AND** detect and handle timeout conditions (error code 0x01)
- **AND** implement retry logic with connection stability checks

#### Scenario: Connection stability monitoring
- **WHEN** monitoring BLE connection during upload
- **THEN** the system SHALL detect disconnections during upload
- **AND** handle disconnection errors (error code 0x05)
- **AND** attempt reconnection and upload restart from beginning
- **AND** provide user feedback on connection status and recovery actions

#### Scenario: Upload validation and integrity
- **WHEN** font upload completes successfully
- **THEN** the system SHALL perform font integrity validation
- **AND** verify font data completeness and format validity
- **AND** confirm successful LVGL font application on device
- **AND** persist success state and relevant metadata for future reference

## MODIFIED Requirements

### Requirement: Font Data Transfer Protocol
The system SHALL transfer font binary data to SwitchHub devices using the enhanced dual-characteristic protocol with improved error handling and progress reporting.

#### Scenario: Enhanced chunk transmission
- **WHEN** transmitting font data chunks via 0xFFF1
- **THEN** the system SHALL use exact protocol format: [0x05][chunk_len_hi][chunk_len_lo][seq_hi][seq_lo][payload...]
- **AND** validate chunk size limits (≤ 65,535 bytes per chunk)
- **AND** maintain sequence numbering starting from 0, incrementing by 1
- **AND** handle completion packet with zero-length payload correctly
- **AND** monitor 0xFFF2 for real-time status and error notifications

#### Scenario: Protocol compliance and validation
- **WHEN** implementing font upload protocol
- **THEN** the system SHALL comply with SwitchHub font uploader specification
- **AND** maintain compatibility with LVGL binary font format
- **AND** support existing font generation service output
- **AND** provide fallback to legacy protocol during transition period