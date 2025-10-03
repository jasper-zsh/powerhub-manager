# API Contracts: Flutter BLE App for ESP32 PWM Controller

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
- channels: List<int> (4 values, 0-255)

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

## 3. Preset Management API

### Read All Presets from Device
**Purpose**: Get all presets stored on the device

**Method**: BLE Read Characteristic
**Characteristic**: 0xFFF2
**Request**:
- deviceId: string (BLE device ID)

**Response**:
- presets: List<Preset>
  - id: int (preset ID, 1-255)
  - commandCount: int (number of commands in preset)
  - commands: List<ControlCommand> (list of commands)

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

**Note**: To delete a preset, send a preset with the same ID but commandCount = 0

### Execute Preset
**Purpose**: Apply a preset to the channels

**Method**: BLE Write Characteristic
**Characteristic**: 0xFFF4
**Request**:
- deviceId: string (BLE device ID)
- presetId: int (preset ID to execute, 0-255)
  - 0 = turn off all channels
  - 1-255 = execute specific preset

**Response**:
- success: bool
- error: string? (if success is false)

**Error Codes**:
- WRITE_FAILED: Failed to write characteristic
- INVALID_PRESET_ID: Preset ID out of range

## 4. Local Storage API

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