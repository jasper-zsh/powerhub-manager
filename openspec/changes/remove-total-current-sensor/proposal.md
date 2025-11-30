# Change: Remove Total Current Sensor

## Why
The total current sensor has been removed from the hardware design, making all related code in the PowerHub manager obsolete and potentially causing runtime errors when accessing non-existent sensor data.

## What Changes
- **REMOVED**: Total current sensor support from monitoring data model
- **REMOVED**: FFF6 characteristic parsing for total input current
- **REMOVED**: UI components displaying total current values
- **REMOVED**: Test cases validating total current functionality
- **UPDATED**: Monitoring data parsing to skip total current bytes
- **UPDATED**: BLE service to remove FFF6 monitoring UUID references

## Impact
- Affected specs: monitoring (new capability needed)
- Affected code: `lib/models/monitoring_data.dart`, UI screens, BLE service, test files
- Data migration: Existing saved controllers may reference removed total current field
- Protocol: FFF6 characteristic parsing needs to be updated for new data format