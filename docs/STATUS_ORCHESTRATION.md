# SwitchHub Status Orchestration

## Overview

The SwitchHub Status Orchestration feature enables real-time monitoring and display of status data from multiple BLE devices directly in the orchestration interface. This implementation follows the protocol specifications defined in `SWITCHHUB_BLE.md`.

## Features

### ✅ **Implemented Features**

#### **Data Models**
- **StatusSlot**: Core model for status slot configuration with JSON serialization
- **StatusSlotConfiguration**: UI-level model for managing dual status slots per switch
- **StatusDataSource**: Remote device tracking with connection state and caching
- **StatusDataType**: Enum for supported data types (VOLTAGE, CHANNEL_CURRENT, TOTAL_CURRENT, TEMPERATURE)

#### **BLE Integration**
- **Local Data Collection**: Voltage monitoring from SwitchHub devices via BLE 0xFFF2
- **Remote Device Support**: PowerHub data collection from multiple connected devices
- **Protocol Compliance**: Full support for SWITCHHUB_BLE.md status slot specification
- **Error Handling**: Robust connection management and graceful failure handling

#### **State Management**
- **StatusOrchestrationProvider**: Riverpod-based state management with automatic refresh
- **Connection Monitoring**: Real-time tracking of remote device connectivity
- **Data Caching**: Efficient data storage and retrieval with staleness detection
- **Periodic Refresh**: Automatic 2-second refresh intervals for local data

#### **UI Components**
- **StatusSlotWidget**: Individual status display with icons, color coding, and connection indicators
- **StatusDisplayRow**: Dual-slot layout support with error handling
- **Data Type Support**: Icons and colors for voltage, current, and temperature
- **Connection States**: Visual indicators for connected, connecting, and failed states
- **Orchestration Integration**: Status display embedded in existing ToggleCard components

#### **Data Refresh & Connectivity**
- **StatusRefreshService**: Dedicated service for managing device connections and data refresh
- **Automatic Retries**: Exponential backoff for failed connections
- **Connection Health**: Monitoring and recovery of device connections
- **Manual Refresh**: On-demand status data updates
- **Performance Optimization**: Efficient data fetching and UI updates

#### **Testing**
- **Unit Tests**: 26 passing tests for all data models and validation logic
- **Widget Tests**: 10 passing tests for UI components and error states
- **Provider Tests**: 9 passing tests for state management logic
- **Error Scenarios**: Comprehensive coverage of connection failures and data errors

## Architecture

### **Data Flow**
```
SwitchHub Config → Status Slots → Orchestration Provider → UI Components
     ↓                          ↓                ↓
BLE 0xFFF3 Characteristic → Data Collection → Real-time Display
```

### **Key Components**

1. **StatusSlot Models** (`lib/models/switch_hub/`)
   - `status_slot_config.dart` - Core status slot definition
   - `status_slot_configuration.dart` - UI configuration management
   - `status_data_source.dart` - Remote device tracking
   - `status_data_type.dart` - Supported data types enum

2. **State Management** (`lib/providers/`)
   - `status_orchestration_provider.dart` - Riverpod provider for status orchestration

3. **UI Components** (`lib/widgets/status/`)
   - `status_slot_widget.dart` - Individual status display widget
   - Components for dual-slot layout and empty states

4. **Services** (`lib/services/`)
   - `status_refresh_service.dart` - Data refresh and connectivity management
   - `switch_hub_ble_service.dart` - Extended with status data collection

## Usage

### **Configuration Example**

Status slots are configured in the SwitchHub configuration JSON:

```json
{
  "schema_version": 1,
  "switches": [
    {
      "switch_id": 1,
      "revision": 1,
      "on": { "type": "leaf", "sequence": [] },
      "off": { "type": "leaf", "sequence": [] },
      "ui": {
        "channel_label": "客厅场景",
        "on_label": "开启",
        "off_label": "关闭",
        "status_slots": [
          {
            "source_mac": "LOCAL",
            "data_type": "VOLTAGE",
            "label": "输入电压"
          },
          {
            "source_mac": "AA:BB:CC:DD:EE:FF",
            "data_type": "CHANNEL_CURRENT",
            "params": "0",
            "label": "主灯电流"
          }
        ]
      }
    }
  ]
}
```

### **Integration Example**

The status display automatically integrates into the orchestration screen:

```dart
// In ToggleCard widget
Consumer(
  builder: (context, ref, child) {
    final statusConfigurations = ref.watch(statusConfigurationsProvider);
    final configuration = statusConfigurations[switchId];

    if (configuration != null) {
      return StatusDisplayRow(
        slot1: configuration.slot1,
        slot2: configuration.slot2,
      );
    }
    return const StatusDisplayEmptyState();
  },
)
```

## Data Types

### **Supported Data Types**

1. **VOLTAGE** (`"VOLTAGE"`)
   - Local device input voltage (SwitchHub)
   - Remote device voltage (PowerHub)
   - Display format: "12.5V"

2. **CHANNEL_CURRENT** (`"CHANNEL_CURRENT"`)
   - Individual PowerHub channel current
   - Parameters: channel number (0-15)
   - Display format: "1.250A"

3. **TOTAL_CURRENT** (`"TOTAL_CURRENT"`)
   - Sum of all PowerHub channel currents
   - Display format: "2.750A"

4. **TEMPERATURE** (`"TEMPERATURE"`)
   - PowerHub device temperature
   - Parameters: zone ("POWER" or "CONTROL")
   - Display format: "27.5°C"

### **Connection States**

- **Connected**: Device successfully connected and data available
- **Connecting**: Connection attempt in progress
- **Disconnected**: No connection established
- **Connection Failed**: Connection attempt failed
- **Connection Lost**: Previously connected device lost

## Error Handling

### **Graceful Degradation**

- **Missing Data**: Displays "--" when data is unavailable
- **Connection Errors**: Shows error indicators and retry status
- **Invalid Configuration**: Validation errors logged and skipped
- **Protocol Mismatches**: Backward compatibility with legacy formats

### **Retry Logic**

- **Exponential Backoff**: Retry delays increase with each failure
- **Max Retries**: Limited to 3 retry attempts per device
- **Recovery**: Automatic recovery when device reconnects

## Performance

### **Optimizations**

- **Batch Updates**: UI updates batched to reduce rendering overhead
- **Smart Refresh**: Different intervals for local vs remote data
- **Connection Pooling**: Reuse existing BLE connections
- **Memory Efficient**: Minimal object allocation during refresh

### **Refresh Intervals**

- **Local Data**: 2 seconds (voltage from SwitchHub)
- **Remote Data**: Based on connection quality and data type
- **Manual Refresh**: Available on-demand via UI

## Future Enhancements

### **Not Yet Implemented**

- [ ] Status slot configuration UI in orchestration screen
- [ ] Manual status slot edit/delete functionality
- [ ] Historical data logging and trends
- [ ] Advanced data visualization
- [ ] Custom alerting based on status values
- [ ] Temperature sensor calibration

### **Potential Extensions**

- [ ] Support for additional data types
- [ ] Graphical status displays (gauges, charts)
- [ ] Export/import status configurations
- [ ] Status data analytics
- [ ] Push notifications for critical status changes

## Testing

### **Test Coverage**

- **Models**: 100% coverage with comprehensive validation tests
- **UI Components**: Widget tests for all display states and interactions
- **State Management**: Provider tests for initialization, updates, and error handling
- **Integration**: End-to-end testing of data flow from BLE to UI

### **Running Tests**

```bash
# Run all status orchestration tests
flutter test test/unit/status_slot_test.dart
flutter test test/widget/status_slot_widget_test.dart
flutter test test/unit/status_orchestration_provider_test.dart

# Run all tests
flutter test
```

## Troubleshooting

### **Common Issues**

1. **Status Not Displaying**
   - Check SwitchHub configuration includes valid `status_slots`
   - Verify BLE connection is established
   - Confirm data source device is connected

2. **Connection Errors**
   - Verify MAC address format (AA:BB:CC:DD:EE:FF)
   - Check device is within BLE range
   - Ensure device supports required characteristics

3. **Data Not Updating**
   - Check periodic refresh is active
   - Verify device connection status
   - Look for error messages in debug logs

### **Debug Logging**

Enable debug logging to troubleshoot issues:

```dart
// In StatusOrchestrationProvider
debugPrint('Status: Initializing with ${config.switches.length} switches');

// In StatusRefreshService
debugPrint('Status: Connected devices: ${_connectedDevices.length}');
```

## Contributing

When adding new data types or features:

1. Update `StatusDataType` enum
2. Extend BLE service data collection methods
3. Add UI icons and color coding
4. Update validation logic
5. Add comprehensive tests
6. Update documentation

## Compatibility

### **Protocol Version**
- Implements SWITCHHUB_BLE.md v0.6 status orchestration features
- Backward compatible with legacy status slot formats
- Forward compatible with future protocol extensions

### **Flutter Version**
- Requires Flutter 3.0+
- Uses Riverpod 2.0+ for state management
- Compatible with flutter_blue_plus 1.0+