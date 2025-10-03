# Quickstart Guide: Flutter BLE App for ESP32 PWM Controller

## Prerequisites

1. Flutter SDK 3.x installed
2. Android Studio or Xcode for mobile development
3. ESP32 PWM controller device powered on and in range
4. Mobile device with Bluetooth capability

## Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd powerhub-manager
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Quick Validation Steps

### 1. Device Discovery
**Given** the ESP32 PWM controller is powered on and within range
**When** the user opens the app and taps "Scan for devices"
**Then** the device should appear in the device list within 10 seconds

### 2. Device Connection
**Given** the device is visible in the device list
**When** the user taps on the device to connect
**Then** the app should show "Connected" status within 5 seconds

### 3. Channel Control
**Given** the app is connected to the device
**When** the user adjusts any channel slider
**Then** the corresponding channel output on the device should update within 100ms

### 4. Preset Creation
**Given** the user has adjusted channel values
**When** the user taps "Save Preset", enters a name, and confirms
**Then** the preset should appear in the preset list

### 5. Preset Recall
**Given** the user has created one or more presets
**When** the user selects a preset from the list
**Then** all 4 channel sliders should update to the preset values within 200ms

## Troubleshooting

### Device Not Found
1. Ensure the ESP32 device is powered on
2. Check that Bluetooth is enabled on your mobile device
3. Verify the device is within 10 meters of your mobile device
4. Restart the ESP32 device and try again

### Connection Issues
1. Ensure no other app is connected to the device
2. Restart the Bluetooth on your mobile device
3. Reset the ESP32 device
4. Check for firmware updates on the ESP32

### Channel Values Not Updating
1. Verify the connection status is "Connected"
2. Check that the correct device is selected
3. Restart the app and reconnect to the device

### Preset Issues
1. Ensure the preset name is not empty
2. Verify all channel values are within 0-255 range
3. Check available storage space on the device

## Sample Test Data

### Test Preset 1: "Dim Lights"
- Channel 1: 64 (25%)
- Channel 2: 32 (12.5%)
- Channel 3: 16 (6.25%)
- Channel 4: 8 (3.125%)

### Test Preset 2: "Bright Lights"
- Channel 1: 192 (75%)
- Channel 2: 128 (50%)
- Channel 3: 64 (25%)
- Channel 4: 32 (12.5%)

### Test Preset 3: "Strobe Effect"
- Channel 1: 255 (100%)
- Channel 2: 0 (0%)
- Channel 3: 255 (100%)
- Channel 4: 0 (0%)

## Expected Performance

1. Device scanning: < 10 seconds
2. Connection establishment: < 5 seconds
3. Channel value update: < 100ms
4. Preset save/load: < 300ms
5. App startup: < 3 seconds

## Test Commands

### Manual Testing
1. Open the app
2. Scan and connect to the device
3. Adjust each slider individually and observe device response
4. Create at least 3 presets with different configurations
5. Test preset recall functionality
6. Disconnect and reconnect to verify state persistence
7. Close and reopen app to verify preset persistence

### Automated Testing
```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test

# Run with coverage
flutter test --coverage
```

## Success Criteria

- [ ] Device discovery works reliably
- [ ] Connection establishment succeeds within 5 seconds
- [ ] All 4 channels can be controlled independently
- [ ] Channel updates are reflected on device within 100ms
- [ ] Presets can be saved and recalled correctly
- [ ] App maintains state between sessions
- [ ] Error handling provides clear feedback to users
- [ ] Performance meets specified targets