# Qwen Code Context for Flutter BLE App

## Project Overview
This project implements a Flutter mobile application for controlling an ESP32-based 4-channel PWM controller via Bluetooth Low Energy (BLE). The app provides real-time control of PWM values and preset management with support for advanced control modes.

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
│   │   ├── preset.dart
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
│   │   └── preset_management_screen.dart
│   ├── widgets/
│   │   ├── channel_slider.dart
│   │   ├── preset_list.dart
│   │   └── connection_status.dart
│   ├── providers/
│   │   └── app_state_provider.dart
│   └── main.dart
```

## ESP32 PWM Controller Protocol
The ESP32 device uses custom BLE characteristics:
- 0xFFF0: Read channel states (4 bytes, values 0-255)
- 0xFFF1: Write control commands
- 0xFFF2: Read all presets
- 0xFFF3: Write a single preset
- 0xFFF4: Execute a preset

### Control Commands
The ESP32 supports four control commands, each with its own dedicated data structure:

1. **SetCommand**: Immediate value setting
   - Format: [0x00][Channel][Value]
   - File: `lib/models/control_command/set_command.dart`

2. **FadeCommand**: Gradual transition to target value
   - Format: [0x01][Channel][Target Value][Duration MSB][Duration LSB]
   - File: `lib/models/control_command/fade_command.dart`

3. **BlinkCommand**: Periodic on/off blinking
   - Format: [0x02][Channel][Period MSB][Period LSB]
   - File: `lib/models/control_command/blink_command.dart`

4. **StrobeCommand**: Rapid flashing with pause
   - Format: [0x03][Channel][Flash Count][Total Duration MSB][Total Duration LSB][Pause Duration MSB][Pause Duration LSB]
   - File: `lib/models/control_command/strobe_command.dart`

### Preset Structure
Presets on the device are stored as:
[Preset ID][Command Count][Command 1][Command 2]...[Command N]

Each command follows the control command format above.

## Recent Changes
1. Updated data model to use separate data structures for each command type
2. Corrected API contracts to match separate command structures
3. Updated contract tests to reflect proper command-specific testing
4. Enhanced preset structure to support complex control commands

## Development Guidelines
- Follow TDD approach: write tests first, then implement
- Use Provider for state management
- Handle BLE disconnections gracefully
- Ensure cross-platform compatibility (Android/iOS)
- Maintain consistent UI/UX across all screens
- Use big-endian byte order for all BLE communications
- Implement all four ESP32 control commands with separate data structures
- Properly serialize/deserialize preset data according to ESP32 specification
- Each command type has its own dedicated class with specific fields and validation