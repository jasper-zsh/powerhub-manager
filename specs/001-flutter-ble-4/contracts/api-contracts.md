# API Contracts: Flutter BLE App for ESP32 PWM Controller

All BLE operations target the custom service UUID `5E0B0001-6F72-4761-8E3E-7A1C1B5F9B11`, which exposes characteristics 0xFFF0–0xFFF5. Multi-byte fields are big-endian unless otherwise noted.

## 1. Device Management API

### Scan for Devices
**Purpose**: Discover nearby ESP32 PWM controllers

**Method**: BLE Scan
**Path**: N/A (BLE discovery)
**Request**:
- Timeout: int (seconds, default 10)

**Response**:
- devices: List<PWMController>
  - id: string (BLE device ID)
  - name: string (device name)
  - rssi: int (signal strength)

**Error Codes**:
- BLE_NOT_SUPPORTED: Device doesn't support BLE
- PERMISSION_DENIED: Missing BLE permissions
- SCAN_FAILED: Scan operation failed

### Connect to Device
**Purpose**: Establish connection to a specific PWM controller

**Method**: BLE Connect
**Path**: N/A (BLE connection)
**Request**:
- deviceId: string (BLE device ID)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- DEVICE_NOT_FOUND: Device not in range
- CONNECTION_FAILED: Failed to establish connection
- TIMEOUT: Connection attempt timed out

### Disconnect from Device
**Purpose**: Terminate connection to PWM controller

**Method**: BLE Disconnect
**Path**: N/A (BLE disconnection)
**Request**:
- deviceId: string (BLE device ID)

**Response**:
- success: bool

## 2. Channel Control API

### Read Channel States
**Purpose**: Get current values of all 4 channels

**Method**: BLE Read Characteristic
**Characteristic**: 0xFFF0
**Request**:
- deviceId: string (BLE device ID)

**Response**:
- channels: List<int> (4 values, 0-255) parsed from 4-byte payload `[CH1][CH2][CH3][CH4]`

**Error Codes**:
- READ_FAILED: Failed to read characteristic
- INVALID_DATA: Received data format is incorrect

### Send Set Command
**Purpose**: Send a set value command to a specific channel

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF1
**Request**:
- deviceId: string (BLE device ID)
- command: SetCommand
  - channel: int (0-3)
  - value: int (0-255)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_CHANNEL: Channel number out of range
- INVALID_VALUE: Value out of range

**Encoding Notes**: Payload serialized as `[0x00][channel][value]`. Multiple commands may be concatenated in one write.

### Send Fade Command
**Purpose**: Send a fade/transition command to a specific channel

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF1
**Request**:
- deviceId: string (BLE device ID)
- command: FadeCommand
  - channel: int (0-3)
  - targetValue: int (0-255)
  - duration: int (0-65535 ms)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_CHANNEL: Channel number out of range
- INVALID_TARGET_VALUE: Target value out of range
- INVALID_DURATION: Duration out of range

**Encoding Notes**: Payload serialized as `[0x01][channel][targetValue][durationMSB][durationLSB]`.

### Send Blink Command
**Purpose**: Send a blink command to a specific channel

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF1
**Request**:
- deviceId: string (BLE device ID)
- command: BlinkCommand
  - channel: int (0-3)
  - period: int (0-65535 ms)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_CHANNEL: Channel number out of range
- INVALID_PERIOD: Period out of range

**Encoding Notes**: Payload serialized as `[0x02][channel][periodMSB][periodLSB]`.

### Send Strobe Command
**Purpose**: Send a strobe command to a specific channel

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF1
**Request**:
- deviceId: string (BLE device ID)
- command: StrobeCommand
  - channel: int (0-3)
  - flashCount: int (0-255)
  - totalDuration: int (0-65535 ms)
  - pauseDuration: int (0-65535 ms)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_CHANNEL: Channel number out of range
- INVALID_FLASH_COUNT: Flash count out of range
- INVALID_TOTAL_DURATION: Total duration out of range
- INVALID_PAUSE_DURATION: Pause duration out of range

**Encoding Notes**: Payload serialized as `[0x03][channel][flashCount][totalDurationMSB][totalDurationLSB][pauseDurationMSB][pauseDurationLSB]`.

## 3. Preset Management API

### Read All Presets from Device
**Purpose**: Get all presets stored on the device

**Method**: BLE Read Characteristic
**Characteristic**: 0xFFF2
**Request**:
- deviceId: string (BLE device ID)

**Response**:
- rawPresetData: Uint8List (binary stream of `[PresetID][CommandCount][Commands…]` blocks)
- presets: List<Preset> (parsed client-side; each preset uses control command serialization)

**Error Codes**:
- READ_FAILED: Failed to read characteristic
- INVALID_DATA: Received data format is incorrect

### Save Preset to Device
**Purpose**: Save a preset to the device

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF3
**Request**:
- deviceId: string (BLE device ID)
- preset: Preset
  - id: int (preset ID, 1-255, 0 is reserved)
  - commandCount: int (number of commands)
  - commands: List<ControlCommand> (list of commands)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_PRESET_ID: Preset ID out of range or reserved
- INVALID_COMMAND_COUNT: Command count doesn't match commands list
- INVALID_COMMANDS: One or more commands are invalid

**Encoding Notes**: Serialize as `[PresetID][CommandCount][Command1…CommandN]`. To delete a preset, send `[PresetID][0x00]` (exactly 2 bytes).

### Delete Preset from Device
**Purpose**: Remove a preset from the device

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF3
**Request**:
- deviceId: string (BLE device ID)
- presetId: int (preset ID to delete, 1-255)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_PRESET_ID: Preset ID out of range or reserved

**Note**: Deletion semantics already covered by encoding `[PresetID][0x00]`.

### Execute Preset
**Purpose**: Apply a preset to the channels

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF4
**Request**:
- deviceId: string (BLE device ID)
- presetId: int (preset ID to execute, 0-255)
  - 0 = cancel all modes and turn off channels
  - 1-255 = execute specific preset

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_PRESET_ID: Preset ID out of range

## 4. Telemetry & Threshold API

### Read Device Telemetry
**Purpose**: Retrieve power and thermal telemetry snapshot

**Method**: BLE Read Characteristic
**Characteristic**: 0xFFF5
**Request**:
- deviceId: string (BLE device ID)

**Response**:
- vinMillivolts: int (uint16 BE)
- temperatureCentiDegrees: int (int16 BE)
- highThresholdCentiDegrees: int (int16 BE)
- recoverThresholdCentiDegrees: int (int16 BE)
- statusFlags: int (uint8)
- reservedByte: int (uint8)
- reservedWord: int (uint16)

**Error Codes**:
- READ_FAILED: Failed to read characteristic
- INVALID_DATA: Received data format is incorrect

### Subscribe to Telemetry Notifications
**Purpose**: Receive streaming telemetry updates

**Method**: BLE Notify
**Characteristic**: 0xFFF5
**Request**:
- deviceId: string (BLE device ID)

**Notification Payload**:
- vinMillivolts: int (uint16 BE)
- temperatureCentiDegrees: int (int16 BE)
- highThresholdCentiDegrees: int (int16 BE)
- recoverThresholdCentiDegrees: int (int16 BE)

**Status Flags (bitmask)**:
- bit0: 1 = thermal protection active
- bit1: 1 = last temperature sample valid
- bit2: reserved, transmit 0
- bit3: reserved for future deep-sleep policy (transmit 0)
- bit4-bit7: reserved, transmit 0

### Send Telemetry Command
**Purpose**: Adjust thresholds or trigger sleep/wake commands

**Method**: BLE Write Characteristic / Write Without Response
**Characteristic**: 0xFFF5
**Request**:
- deviceId: string (BLE device ID)
- commandId: int (0x01, 0x02, 0x03, 0x04, 0x11, 0x12)
- parameter: int (int16 BE, ignored for 0x03 and 0x04 but still transmitted)

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_COMMAND: Unsupported command ID
- INVALID_PARAMETER: Parameter out of range

**Encoding Notes**: Serialize as `[commandId][parameterMSB][parameterLSB]`.

## 5. Local Storage API

### Save Local Preset
**Purpose**: Save a preset to local storage

**Method**: Local Storage Write
**Path**: /presets
**Request**:
- preset: Preset
  - id: int (preset ID, 1-255)
  - name: string (preset name)
  - commandCount: int (number of commands)
  - commands: List<ControlCommand> (list of commands)
  - isFavorite: bool (optional)

**Response**:
- id: int (preset ID)
- createdAt: DateTime

**Error Codes**:
- STORAGE_ERROR: Failed to write to storage
- INVALID_DATA: Preset data format is incorrect

### Load Local Presets
**Purpose**: Get all presets from local storage

**Method**: Local Storage Read
**Path**: /presets
**Request**:
- None

**Response**:
- presets: List<Preset>
  - id: int (preset ID)
  - name: string (preset name)
  - commandCount: int (number of commands)
  - commands: List<ControlCommand> (list of commands)
  - createdAt: DateTime
  - updatedAt: DateTime
  - isFavorite: bool

**Error Codes**:
- STORAGE_ERROR: Failed to read from storage

### Update Local Preset
**Purpose**: Update a preset in local storage

**Method**: Local Storage Update
**Path**: /presets/{id}
**Request**:
- id: int (preset ID)
- preset: PresetUpdate
  - name: string? (optional)
  - commands: List<ControlCommand>? (optional)
  - isFavorite: bool? (optional)

**Response**:
- updatedAt: DateTime

**Error Codes**:
- STORAGE_ERROR: Failed to write to storage
- PRESET_NOT_FOUND: Preset with given ID not found
- INVALID_DATA: Preset data format is incorrect

### Delete Local Preset
**Purpose**: Remove a preset from local storage

**Method**: Local Storage Delete
**Path**: /presets/{id}
**Request**:
- id: int (preset ID)

**Response**:
- success: bool

**Error Codes**:
- STORAGE_ERROR: Failed to delete from storage
- PRESET_NOT_FOUND: Preset with given ID not found
