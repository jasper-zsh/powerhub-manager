# Data Model: Flutter BLE App for ESP32 PWM Controller

## Entities

### PWMController
Represents the ESP32-based 4-channel PWM controller device.

**Fields:**
- id: String (Unique identifier for the device)
- name: String (Human-readable device name)
- rssi: int (Signal strength indicator)
- isConnected: bool (Connection status)
- connectionTime: DateTime? (When the connection was established)

**Relationships:**
- channels: List<Channel> (The 4 PWM channels controlled by this device)
- presets: List<Preset> (Presets stored on the device)

**Validation Rules:**
- id must be a valid BLE device identifier
- name must not be empty
- rssi must be between -100 and 0
- channels list must contain exactly 4 Channel objects

### Channel
Represents one of the 4 PWM output channels.

**Fields:**
- id: int (Channel number, 0-3 corresponding to ESP32 GPIO7-10)
- value: int (Current PWM value, 0-255 where 0 is off and 255 is full on)
- name: String (Optional human-readable name for the channel)
- isEnabled: bool (Whether the channel is active)

**Relationships:**
- controller: PWMController (The controller this channel belongs to)

**Validation Rules:**
- id must be between 0 and 3
- value must be between 0 and 255
- name can be empty but not null

**State Transitions:**
- value: 0→255 (Direct setting)
- isEnabled: true↔false (Enable/disable channel)

### Preset
Represents a saved configuration of control commands for all 4 channels.

**Fields:**
- id: int (Preset identifier, 1-255 as per ESP32 specification, 0 is reserved)
- name: String (Human-readable name for the preset)
- commandCount: int (Number of control commands in this preset)
- commands: List<ControlCommand> (List of control commands, up to 255 as per ESP32 specification)
- createdAt: DateTime (When the preset was created)
- updatedAt: DateTime (When the preset was last modified)
- isFavorite: bool (Whether the user has marked this as a favorite)

**Relationships:**
- controller: PWMController (The controller this preset is for)

**Validation Rules:**
- id must be between 1 and 255 (0 is reserved)
- name must not be empty
- commandCount must match the number of commands in the commands list
- commands list must not be empty
- each command must be valid according to ControlCommand validation rules

### BLEConnection
Represents the BLE connection state and communication methods.

**Fields:**
- deviceId: String (BLE device identifier)
- isConnected: bool (Current connection status)
- lastConnected: DateTime? (When last connected)
- connectionAttempts: int (Number of connection attempts)
- errorCount: int (Number of communication errors)

**Methods:**
- connect(): Future<void> (Establish connection to device)
- disconnect(): Future<void> (Disconnect from device)
- sendCommand(List<int> data): Future<void> (Send command to device)
- readCharacteristic(String characteristicId): Future<List<int>> (Read from characteristic)

## Control Commands

### ControlCommand (Abstract Base Class)
Represents a single control command for a channel.

**Fields:**
- channel: int (Channel number, 0-3)
- rawData: List<int> (Raw byte data for BLE transmission)

**Methods:**
- toBytes(): List<int> (Convert command to byte array for BLE transmission)
- getType(): String (Get command type identifier)

**Validation Rules:**
- channel must be between 0 and 3
- rawData must be properly formatted according to ESP32 specification

### SetCommand extends ControlCommand
Represents the simple set value command.

**Fields:**
- channel: int (Channel number, 0-3)
- value: int (Target PWM value, 0-255)

**Methods:**
- toBytes(): List<int> (Convert command to byte array: [0x00, channel, value])

**Validation Rules:**
- channel must be between 0 and 3
- value must be between 0 and 255

### FadeCommand extends ControlCommand
Represents the fade/transition command.

**Fields:**
- channel: int (Channel number, 0-3)
- targetValue: int (Target PWM value, 0-255)
- duration: int (Fade duration in milliseconds, 0-65535)

**Methods:**
- toBytes(): List<int> (Convert command to byte array: [0x01, channel, targetValue, durationMSB, durationLSB])

**Validation Rules:**
- channel must be between 0 and 3
- targetValue must be between 0 and 255
- duration must be between 0 and 65535

### BlinkCommand extends ControlCommand
Represents the blink command.

**Fields:**
- channel: int (Channel number, 0-3)
- period: int (Blink period in milliseconds, 0-65535)

**Methods:**
- toBytes(): List<int> (Convert command to byte array: [0x02, channel, periodMSB, periodLSB])

**Validation Rules:**
- channel must be between 0 and 3
- period must be between 0 and 65535

### StrobeCommand extends ControlCommand
Represents the strobe command.

**Fields:**
- channel: int (Channel number, 0-3)
- flashCount: int (Number of flashes, 0-255)
- totalDuration: int (Total strobe duration in milliseconds, 0-65535)
- pauseDuration: int (Pause duration in milliseconds, 0-65535)

**Methods:**
- toBytes(): List<int> (Convert command to byte array: [0x03, channel, flashCount, totalDurationMSB, totalDurationLSB, pauseDurationMSB, pauseDurationLSB])

**Validation Rules:**
- channel must be between 0 and 3
- flashCount must be between 0 and 255
- totalDuration must be between 0 and 65535
- pauseDuration must be between 0 and 65535

## Value Objects

### PWMValue
Represents a PWM value with validation.

**Fields:**
- rawValue: int (The 0-255 value)

**Validation Rules:**
- rawValue must be between 0 and 255

### ChannelState
Represents the complete state of all channels.

**Fields:**
- channel1: PWMValue
- channel2: PWMValue
- channel3: PWMValue
- channel4: PWMValue

## Data Flow

1. **Device Discovery**: BLEService discovers devices and creates PWMController entities
2. **Connection**: User connects to device, BLEConnection established
3. **State Synchronization**: App reads current channel states from 0xFFF0 characteristic
4. **Control**: User adjusts sliders or selects modes, specific ControlCommand created and sent to 0xFFF1 characteristic
5. **Preset Management**: User creates presets with control commands, Preset entities stored locally and on device
6. **Preset Execution**: User selects preset, command sent to 0xFFF4 characteristic to execute on device

## Serialization

### Preset Serialization for Local Storage
Presets are stored as JSON in shared_preferences:
```json
{
  "id": 1,
  "name": "Relaxing Lights",
  "commandCount": 2,
  "commands": [
    {
      "type": "SetCommand",
      "channel": 0,
      "value": 128
    },
    {
      "type": "FadeCommand",
      "channel": 1,
      "targetValue": 64,
      "duration": 2000
    }
  ],
  "createdAt": "2025-09-18T10:00:00Z",
  "updatedAt": "2025-09-18T10:00:00Z",
  "isFavorite": true
}
```

### Channel State Serialization
Channel states are serialized as 4-byte arrays for BLE communication with characteristic 0xFFF0:
```
[Byte 0: Channel 1 value][Byte 1: Channel 2 value][Byte 2: Channel 3 value][Byte 3: Channel 4 value]
```

### Control Command Serialization
Control commands follow ESP32 specification for BLE characteristic 0xFFF1:

SetCommand:
```
[0x00][Channel][Value]
```

FadeCommand:
```
[0x01][Channel][Target Value][Duration MSB][Duration LSB]
```

BlinkCommand:
```
[0x02][Channel][Period MSB][Period LSB]
```

StrobeCommand:
```
[0x03][Channel][Flash Count][Total Duration MSB][Total Duration LSB][Pause Duration MSB][Pause Duration LSB]
```

### Preset Serialization for Device Storage
Presets are serialized according to ESP32 specification for BLE characteristic 0xFFF3:
```
[Preset ID][Command Count][Command 1][Command 2]...[Command N]
```

Each command follows the control command serialization format above.

## Relationships Diagram

```
PWMController 1-----4 Channel
PWMController 1-----* Preset
PWMController 1-----1 BLEConnection
Preset 1-----* ControlCommand
SetCommand 1-----1 ControlCommand
FadeCommand 1-----1 ControlCommand
BlinkCommand 1-----1 ControlCommand
StrobeCommand 1-----1 ControlCommand
```

## Constraints

1. **Channel Count**: Always exactly 4 channels per controller
2. **Value Range**: Channel values always 0-255
3. **Preset ID Range**: Preset IDs 1-255 (0 is reserved)
4. **Command Count**: Each preset can contain up to 255 commands
5. **Connection State**: Only one active connection per controller
6. **Data Persistence**: Presets must be persisted locally between app sessions
7. **Byte Order**: All multi-byte values must use big-endian byte order for BLE communication
8. **Mode Consistency**: When executing presets, all commands in the preset are executed sequentially
9. **Command Type Safety**: Each command type has its own dedicated class with specific fields and validation