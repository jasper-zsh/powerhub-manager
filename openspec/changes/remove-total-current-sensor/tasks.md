## 1. Model Updates
- [ ] 1.1 Remove totalInputCurrent field from MonitoringData class
- [ ] 1.2 Update MonitoringData constructor to remove totalInputCurrent parameter
- [ ] 1.3 Update fromBytes() factory constructor to skip total current bytes
- [ ] 1.4 Adjust expected data length validation from 36 to 32 bytes
- [ ] 1.5 Remove totalInputCurrent from toString() method
- [ ] 1.6 Add helper method for calculating total from per-channel currents

## 2. Data Parsing Updates
- [ ] 2.1 Update per-channel current parsing loop to account for removed total current
- [ ] 2.2 Add backward compatibility handling for 36-byte legacy data
- [ ] 2.3 Update FFF6 characteristic parsing to start per-channel currents at byte 6
- [ ] 2.4 Add validation for variable channel count data parsing
- [ ] 2.5 Test parsing with both 32-byte and 36-byte data formats

## 3. UI Component Updates
- [ ] 3.1 Remove totalInputCurrent references from device_control_screen.dart
- [ ] 3.2 Update connection_status.dart to use calculated total current
- [ ] 3.3 Modify monitoring_screen.dart to display calculated total
- [ ] 3.4 Update power_status.dart total current display
- [ ] 3.5 Add UI labels to distinguish calculated vs measured totals
- [ ] 3.6 Handle edge cases where all channel currents are invalid

## 4. BLE Service Updates
- [ ] 4.1 Review FFF6 UUID references in ble_service.dart
- [ ] 4.2 Update monitoring characteristic handling documentation
- [ ] 4.3 Add error handling for malformed data packets
- [ ] 4.4 Update BLE service test cases for new data format

## 5. Test Updates
- [ ] 5.1 Remove totalInputCurrent from monitoring_data_test.dart fixtures
- [ ] 5.2 Update test cases expecting 36-byte format to use 32-byte format
- [ ] 5.3 Add tests for calculated total current functionality
- [ ] 5.4 Update monitoring_controller_test.dart test data
- [ ] 5.5 Add test cases for backward compatibility with 36-byte data
- [ ] 5.6 Update ble_service_test.dart FFF6 UUID tests if needed

## 6. Migration and Compatibility
- [ ] 6.1 Add firmware version detection for data format handling
- [ ] 6.2 Implement graceful fallback for malformed data
- [ ] 6.3 Update saved controller migration to handle old total current references
- [ ] 6.4 Add logging for data format detection and parsing issues

## 7. Documentation Updates
- [ ] 7.1 Update POWERHUB_BLE.md to reflect FFF6 data structure changes
- [ ] 7.2 Update any API documentation mentioning total current sensor
- [ ] 7.3 Add migration guide for developers using monitoring data
- [ ] 7.4 Update code comments in monitoring data model

## 8. Validation and Testing
- [ ] 8.1 Run existing test suite to identify breaking changes
- [ ] 8.2 Test with real hardware (if available) to confirm data parsing
- [ ] 8.3 Verify UI displays correct calculated totals
- [ ] 8.4 Test edge cases: zero channels, all invalid currents, mixed data
- [ ] 8.5 Performance testing for total current calculations
- [ ] 8.6 Integration testing with full monitoring workflow