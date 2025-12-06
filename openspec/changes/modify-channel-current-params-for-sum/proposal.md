# Modify Channel Current Parameters for Sum Support

## Summary

Modify the `CHANNEL_CURRENT` data type in UI status orchestration to support comma-separated channel numbers for displaying the sum of multiple channels, while maintaining backward compatibility with single channel configurations.

## Problem Statement

Currently, the `CHANNEL_CURRENT` data type only supports monitoring a single channel (0-15) via the `params` field. Users need the ability to monitor the combined current consumption of multiple channels, which requires visiting multiple status slots or using `TOTAL_CURRENT` (which includes all channels).

## Proposed Solution

Extend the existing `CHANNEL_CURRENT` data type parameter validation and data collection logic to:

1. Accept comma-separated channel numbers (e.g., "0,1,2", "3,5,7,9")
2. Parse and validate each channel number in the list
3. Collect current data from each specified channel
4. Calculate and display the sum of all specified channels
5. Maintain backward compatibility with single channel parameters

## Key Benefits

- **Enhanced Monitoring**: Users can monitor combined current consumption of specific channel groups
- **Flexible Configuration**: Any combination of channels can be summed (e.g., all lighting channels, all power outlets)
- **Backward Compatibility**: Existing single channel configurations continue to work unchanged
- **Minimal UI Changes**: Leverages existing status slot infrastructure
- **Performance Efficient**: Single data collection operation for multiple channels

## Implementation Scope

1. **Data Model Updates**: Modify `StatusDataType.channelCurrent.validateParameters()`
2. **Data Collection Logic**: Extend BLE service to handle multi-channel sum calculations
3. **UI Display**: Update status slot widget to handle sum display formatting
4. **Validation Logic**: Enhanced parameter validation for comma-separated channels
5. **Testing**: Comprehensive test coverage for validation, data collection, and display

## Technical Approach

### Parameter Format Support
- Single channel: `"0"` → Display channel 0 current (existing behavior)
- Multiple channels: `"0,1,2"` → Display sum of channels 0, 1, and 2
- Mixed order: `"3,1,4"` → Display sum of channels 1, 3, and 4
- Non-sequential: `"0,2,5,7"` → Display sum of specific channels

### Validation Rules
- Each channel number must be 0-15
- No duplicate channels allowed
- Maximum 8 channels per sum (performance consideration)
- Empty or whitespace-only strings rejected
- Invalid channel numbers cause parameter validation failure

### Display Format
- Single channel: "1.250A" (existing)
- Multiple channels: "3.750A" (sum display)
- Label: User-configurable, defaults to "Channels {list} Current"

## Risk Assessment

### Low Risk
- **Backward Compatibility**: Single channel configurations unchanged
- **Limited Scope**: Only modifies existing CHANNEL_CURRENT behavior
- **Testing**: Existing test infrastructure can be extended

### Mitigation Strategies
- Comprehensive validation prevents invalid configurations
- Graceful fallback for malformed parameters
- Unit tests cover all parameter combinations
- Integration tests verify BLE data collection accuracy

## Success Criteria

1. Single channel configurations work exactly as before
2. Comma-separated channel parameters are properly validated
3. Sum calculations are accurate across all channel combinations
4. UI displays are formatted correctly for both single and sum modes
5. Performance remains acceptable with multi-channel sums
6. All existing tests continue to pass