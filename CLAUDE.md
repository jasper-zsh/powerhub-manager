# PowerHub Manager - Flutter BLE App

## Project Overview
This project implements a Flutter mobile application for controlling an ESP32-based 6-channel PWM PowerHub via Bluetooth Low Energy (BLE). The app provides real-time control of PWM values, power management, and advanced monitoring features including voltage, temperature, and current tracking.

## Key Technologies
- Flutter 3.x with Dart
- flutter_blue_plus library for BLE communication
- Provider for state management
- shared_preferences for local data persistence

## Project Structure
```
app/
├── lib/
│   ├── models/
│   │   ├── pwm_controller.dart
│   │   ├── channel.dart
│   │   ├── power_management.dart
│   │   ├── monitoring_data.dart
│   │   └── control_command/
│   │       ├── set_command.dart
│   │       ├── fade_command.dart
│   │       ├── blink_command.dart
│   │       └── strobe_command.dart
│   ├── services/
│   │   ├── ble_service.dart
│   │   └── storage_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── channel_control_screen.dart
│   │   ├── power_management_screen.dart
│   │   └── monitoring_screen.dart
│   ├── widgets/
│   │   ├── channel_slider.dart
│   │   ├── power_status.dart
│   │   ├── monitoring_dashboard.dart
│   │   └── connection_status.dart
│   ├── providers/
│   │   └── app_state_provider.dart
│   └── main.dart
```

## ESP32 PowerHub Protocol

### BLE Service Configuration
- **Device Name**: "PowerHub"
- **Service UUID**: `119B5F1B-1C7A-3E8E-6147-672F-0100-0B5E` (custom 128-bit UUID)
- **Connection**: Single device connection
- **MTU Support**: Up to 247 bytes

### GATT Characteristics

#### 1. Channel State (UUID: 0xFFF0)
- **Properties**: Read + Notify
- **Data Format**: 6 bytes `[CH0, CH1, CH2, CH3, CH4, CH5]`
- **Range**: 0-255 per channel
- **Notification**: Sent only when channel states change

#### 2. Channel Control (UUID: 0xFFF1)
- **Properties**: Write + Write No Response
- **Command Format**: `[Mode(1)][Channel(1)][Parameters(N)]`
- **Batch Operations**: Multiple commands in single write supported

#### 3. Power Management (UUID: 0xFFF5)
- **Properties**: Read + Write + Write No Response
- **Read Format**: 8 bytes configuration data
- **Write Format**: 3 bytes `[Command(1)][Parameters(2)]`

#### 4. Real-time Monitoring (UUID: 0xFFF6)
- **Properties**: Read + Notify
- **Data Format**: 36 bytes complete monitoring data
- **Update Frequency**: Periodic based on ADC sampling configuration

### Control Commands Protocol

#### Command Format
```
[Mode(1 byte)][Channel(1 byte)][Parameters(N bytes)]
```

#### Control Modes

| Mode | Name | Parameters | Description |
|------|------|------------|-------------|
| 0x00 | Set | Value(1) | Immediate brightness setting |
| 0x01 | Fade | Target(1), Duration(2) | Smooth transition |
| 0x02 | Blink | Period(2) | Periodic blinking |
| 0x03 | Strobe | Count(1), Total(2), Pause(2) | Strobe effect |

#### Channel Mapping
- **Range**: 0-5 (6 PWM channels)
- **Hardware Mapping**:
  - CH0: GPIO8
  - CH1: GPIO9
  - CH2: GPIO10
  - CH3: GPIO11
  - CH4: GPIO12
  - CH5: GPIO13

#### Command Examples
```dart
// Set channel 0 to maximum brightness
[0x00][0x00][0xFF]

// Fade channel 1 to 128 brightness over 2 seconds
[0x01][0x01][0x80][0x00][0x02]

// Blink channel 2 with 1 second period
[0x02][0x02][0x00][0x04]

// Strobe channel 3: 5 times, 500ms total, 200ms pause
[0x03][0x03][0x05][0x00][0x02][0x00][0xC8]
```

### Power Management Protocol

#### Read Response Format (8 bytes)
```
Offset  Size  Type    Description
0       2     uint16  High temp threshold (0.01°C)
2       2     int16   Recovery threshold (0.01°C)
4       2     uint16  Sleep voltage threshold (mV)
6       2     uint16  Wake voltage threshold (mV)
```

#### Write Commands (3 bytes)
```
[Command(1)][Parameters(2, int16, big-endian)]
```

#### Power Commands
| Command | Name | Parameters | Description |
|---------|------|------------|-------------|
| 0x01 | Set Sleep Threshold | uint16(mV) | Sleep voltage threshold |
| 0x02 | Set Wake Threshold | uint16(mV) | Wake voltage threshold |
| 0x03 | Force Sleep | - | Enter sleep mode |
| 0x04 | Force Wake | - | Force system wake |
| 0x11 | Set High Temp Threshold | int16(0.01°C) | Thermal protection threshold |
| 0x12 | Set Recovery Threshold | int16(0.01°C) | Thermal recovery threshold |

### Real-time Monitoring Protocol

#### Data Format (36 bytes)
```
Offset  Size  Type    Description
0       2     uint16  Input voltage (mV)
2       2     int16   Power zone temperature (0.01°C)
4       2     int16   Control zone temperature (0.01°C)
6       4     float   Total input current (A, IEEE 754)
10      24    -       6-channel current data (6 x float, A)
34      1     uint8   System status flags
35      1     -       Reserved
```

#### Status Flag Bits
- **bit0**: Thermal protection active
- **bit1**: Temperature data valid
- **bit2**: Current data valid
- **bit3**: Calibration status
- **bit4**: Peripheral power on
- **bit5-7**: Reserved

#### Temperature Sensors
- **Power Zone**: Monitors power-related components
- **Control Zone**: Monitors control circuit temperature
- **Invalid Data**: Marked with 0x8000

#### Current Data
- Each channel: 4-byte IEEE 754 float
- Range: CH1 (10-13) to CH6 (30-33)
- Unit: Amperes (A)

## Development Guidelines

### BLE Communication Best Practices
- Use big-endian byte order for all multi-byte values
- Implement MTU exchange for optimal performance
- Use write without response for control commands
- Subscribe to notifications for real-time updates
- Handle connection drops and automatic reconnection

### Data Processing
- **Channel States**: 6-byte arrays, map to UI sliders
- **Monitoring Data**: Parse IEEE 754 floats correctly
- **Temperature Data**: Handle 0x01°C precision and invalid markers
- **Status Flags**: Parse individual bits for system state

### Error Handling
- Implement BLE ATT error code handling
- Handle sensor data invalidation (0x8000 markers)
- Manage subscription state recovery
- Provide user-friendly error messages

### Performance Optimization
- Batch multiple control commands in single writes
- Use efficient data structures for monitoring updates
- Implement proper memory management for large datasets
- Optimize UI refresh rates for real-time data

### Testing Requirements
- Verify all 6 channel control operations
- Test power management configuration commands
- Validate monitoring data parsing (floats, temperatures)
- Test notification subscription and data accuracy
- Verify thermal protection behavior
- Test connection stability under various conditions

## Model Class Specifications

### PWM Controller Model
- Support 6 channels (0-5)
- Channel state management
- Connection status tracking
- Command batching capability

### Power Management Model
- Threshold configuration (voltage, temperature)
- System state management
- Sleep/wake control
- Protection status monitoring

### Monitoring Data Model
- Voltage monitoring (mV)
- Dual-zone temperature monitoring
- 6-channel current monitoring
- System status flag parsing
- Data validation and error handling

### Control Command Models
- SetCommand: Immediate value control
- FadeCommand: Smooth transitions
- BlinkCommand: Periodic operations
- StrobeCommand: Complex timing patterns
- Command serialization for BLE transport

## UI/UX Requirements

### Channel Control Screen
- 6 channel sliders with real-time feedback
- Control mode selection (Set, Fade, Blink, Strobe)
- Parameter input for advanced modes
- Batch operation support

### Power Management Screen
- Threshold configuration interface
- System status display
- Sleep/wake controls
- Thermal protection status

### Monitoring Dashboard
- Real-time voltage display
- Dual-zone temperature monitoring
- 6-channel current monitoring
- System status indicators
- Historical data visualization

### Connection Management
- Device discovery and pairing
- Connection status indicators
- Automatic reconnection handling
- MTU negotiation status

## Recent Changes
- Updated from 4-channel to 6-channel PWM control
- Added comprehensive power management features
- Implemented real-time monitoring with voltage, temperature, and current
- Enhanced BLE protocol with separate characteristics for different functions
- Added dual-zone temperature monitoring
- Implemented system status flag monitoring
- Enhanced error handling and data validation