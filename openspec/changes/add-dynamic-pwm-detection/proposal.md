# Change: Add Dynamic PWM Channel Detection and Flexible Monitoring

## Why
The current implementation assumes all PowerHub devices have exactly 6 PWM channels, fixed monitoring capabilities (2 temperature sensors + per-channel current + total current), and a static device configuration. This limits support for devices with different channel counts and varying sensor configurations, reducing flexibility for future hardware variants.

## What Changes
- **BREAKING**: Remove hardcoded 6-channel assumption throughout the codebase
- **NEW**: Dynamic PWM channel count detection based on FFF1 characteristic response length
- **NEW**: Flexible monitoring configuration supporting variable temperature sensors (0 or more)
- **NEW**: Optional per-PWM-channel current sensing capability
- **REMOVED**: Total current sensor support from all device types
- **UPDATED**: Device capability discovery and configuration persistence
- **UPDATED**: UI to adapt to variable channel counts and sensor availability

## Impact
- Affected specs: device-capabilities, pwm-control, monitoring
- Affected code: `lib/models/pwm_controller.dart`, `lib/models/channel.dart`, `lib/models/monitoring_data.dart`, `lib/services/ble_service.dart`, device discovery, UI components
- Data migration: Existing saved controllers will need capability re-detection