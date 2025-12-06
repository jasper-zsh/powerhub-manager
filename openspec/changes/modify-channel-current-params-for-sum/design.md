# Design Document: Channel Current Sum Parameters

## Architecture Overview

This enhancement extends the existing `CHANNEL_CURRENT` data type to support comma-separated channel numbers for sum calculation while maintaining full backward compatibility.

## Current State Analysis

### Existing Implementation
- **Parameter Format**: Single channel number as string (e.g., "0", "5")
- **Validation**: `int.tryParse()` with range check (0-15)
- **Data Collection**: Single channel read from PowerHub device
- **Display**: Current value in amperes (e.g., "1.250A")

### Status Slot Configuration Example
```json
{
  "source_mac": "AA:BB:CC:DD:EE:FF",
  "data_type": "CHANNEL_CURRENT",
  "params": "0",
  "label": "主灯电流"
}
```

## Proposed Architecture Changes

### 1. Parameter Parsing Enhancement

#### New Parameter Formats Supported
- Single channel: `"0"` → `[0]` (backward compatible)
- Multiple channels: `"0,1,2"` → `[0, 1, 2]`
- Mixed order: `"3,1,4"` → `[3, 1, 4]`
- Non-sequential: `"0,2,5,7"` → `[0, 2, 5, 7]`

#### Parsing Strategy
```dart
class ChannelParameterParser {
  static List<int> parseChannels(String? params) {
    if (params == null || params.trim().isEmpty) {
      throw ArgumentError('Parameters required for CHANNEL_CURRENT');
    }

    final channels = params
        .split(',')
        .map((s) => int.parse(s.trim()))
        .toList();

    // Validation logic here
    return channels;
  }
}
```

### 2. Validation Logic Updates

#### Enhanced Validation Rules
1. **Required Parameters**: Empty or null params still rejected
2. **Individual Channel Validation**: Each channel must be 0-15
3. **Duplicate Detection**: Same channel cannot appear twice
4. **Maximum Channels**: Limit to 8 channels (performance consideration)
5. **Format Validation**: Proper comma-separated format

#### Validation Implementation
```dart
String? validateParameters(String? params) {
  if (!requiresParameters) {
    return params == null || params.isEmpty ? null : 'This data type does not accept parameters';
  }

  if (params == null || params.trim().isEmpty) {
    return 'This data type requires parameters';
  }

  try {
    final channels = _parseChannelList(params);

    // Individual channel validation
    for (final channel in channels) {
      if (channel < 0 || channel > 15) {
        return 'Channel number $channel must be between 0 and 15';
      }
    }

    // Duplicate channel detection
    if (channels.length != channels.toSet().length) {
      return 'Duplicate channels not allowed in sum parameters';
    }

    // Maximum channels limit
    if (channels.length > 8) {
      return 'Maximum 8 channels allowed in sum parameters';
    }

    return null;
  } catch (e) {
    return 'Channel parameter format error: ${e.toString()}';
  }
}
```

### 3. Data Collection Enhancement

#### BLE Service Updates
The `StatusRefreshService` will be extended to handle multi-channel data collection:

```dart
Future<double> collectChannelCurrentSum(String deviceMac, List<int> channels) async {
  double totalCurrent = 0.0;

  for (final channel in channels) {
    final channelCurrent = await readChannelCurrent(deviceMac, channel);
    totalCurrent += channelCurrent;
  }

  return totalCurrent;
}
```

#### Performance Optimization
- **Batch Reads**: Collect all channel data in single BLE operation where possible
- **Parallel Processing**: Concurrent reads for multiple channels
- **Error Handling**: Individual channel failures don't break sum calculation

### 4. Display and Formatting

#### Display Label Generation
- Single channel: Use existing label or default "Channel {N} Current"
- Multiple channels: Default to "Channels {list} Current" or user label

#### Value Formatting
- **Precision**: Maintain 3 decimal places (existing behavior)
- **Unit**: Always display as amperes "A"
- **Error Display**: Show "--" for failed data collection

### 5. Backward Compatibility Strategy

#### Migration Approach
1. **Zero Breaking Changes**: Existing single channel configs work unchanged
2. **Gradual Adoption**: Users can migrate to multi-channel when ready
3. **Automatic Detection**: Parameter parser handles both formats transparently
4. **Feature Detection**: UI can detect multi-channel vs single channel

#### Configuration Examples
```json
// Existing (continues to work)
{
  "data_type": "CHANNEL_CURRENT",
  "params": "0"
}

// New multi-channel support
{
  "data_type": "CHANNEL_CURRENT",
  "params": "0,1,2,3"
}

// Backward compatible - same result
{
  "data_type": "CHANNEL_CURRENT",
  "params": "5"
}
```

## Component Interaction Diagram

```
StatusSlot Config
       ↓
Parameter Parser (New)
       ↓
Validation Logic (Enhanced)
       ↓
StatusRefreshService (Extended)
       ↓
BLE Data Collection
       ↓
Sum Calculation (New)
       ↓
UI Display (Existing)
```

## Data Flow Examples

### Single Channel (Existing Flow)
```
"params": "0" → [0] → Read Channel 0 → 1.250A → Display "1.250A"
```

### Multi-Channel Sum (New Flow)
```
"params": "0,1,2" → [0,1,2] → Read Channels 0,1,2 → 1.250+0.875+1.100 → 3.225A → Display "3.225A"
```

## Error Handling Strategy

### Parameter Validation Errors
- **Invalid Format**: Clear error message for malformed parameter strings
- **Range Errors**: Specify which channel number is invalid
- **Duplicate Errors**: Identify duplicate channels in parameter list

### Data Collection Errors
- **Partial Failures**: Sum channels that succeed, show warning for failed channels
- **Complete Failure**: Display "--" with error indicator
- **Connection Errors**: Graceful degradation with retry logic

## Testing Strategy

### Unit Tests
- Parameter parsing with valid/invalid inputs
- Validation logic edge cases
- Sum calculation accuracy
- Error handling scenarios

### Integration Tests
- End-to-end data collection flow
- BLE service integration
- UI display updates
- Backward compatibility verification

### Performance Tests
- Multi-channel data collection performance
- Memory usage with various channel combinations
- UI responsiveness during data updates

## Configuration Migration

### No Migration Required
Existing configurations continue to work without any changes. New multi-channel functionality is opt-in through updated parameter formats.

### Documentation Updates
- Parameter format documentation
- Example configurations
- Migration guide for advanced users
- Troubleshooting guide for parameter validation

## Future Extensibility

### Potential Extensions
- Channel ranges (e.g., "0-3" equivalent to "0,1,2,3")
- Channel grouping (e.g., "lighting" predefined group)
- Expression support (e.g., "0+1+2" instead of "0,1,2")
- Named channel groups from device capabilities

### Design Considerations
- Keep current comma-separated format for simplicity
- Maintain performance with larger channel lists
- Consider memory constraints on embedded devices
- Preserve backward compatibility as primary goal