# Contract Tests: Flutter BLE App for ESP32 PWM Controller

## 1. Device Management Contract Tests

### Test: Scan for Devices
```dart
void main() {
  test('Scan for devices should return list of PWM controllers', () async {
    // Arrange
    final bleService = MockBLEService();
    final deviceManager = DeviceManager(bleService);
    
    // Act
    final devices = await deviceManager.scanForDevices(timeout: 10);
    
    // Assert
    expect(devices, isNotEmpty);
    expect(devices.first, isA<PWMController>());
    expect(devices.first.id, isNotEmpty);
  });
  
  test('Scan should fail when BLE is not supported', () async {
    // Arrange
    final bleService = MockBLEService();
    when(bleService.isSupported()).thenAnswer((_) async => false);
    final deviceManager = DeviceManager(bleService);
    
    // Act & Assert
    expect(
      () => deviceManager.scanForDevices(),
      throwsA(equals('BLE_NOT_SUPPORTED'))
    );
  });
}
```

### Test: Connect to Device
```dart
void main() {
  test('Connect to device should establish BLE connection', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    
    // Act
    final result = await device.connect();
    
    // Assert
    expect(result.success, isTrue);
    expect(device.isConnected, isTrue);
  });
  
  test('Connect should fail when device is out of range', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'unavailable_device', name: 'Unavailable Device');
    when(bleService.connect('unavailable_device'))
      .thenThrow(DeviceNotFoundException());
    
    // Act & Assert
    expect(
      () => device.connect(),
      throwsA(equals('DEVICE_NOT_FOUND'))
    );
  });
}
```

## 2. Channel Control Contract Tests

### Test: Read Channel States
```dart
void main() {
  test('Read channel states should return 4 values', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    when(bleService.readCharacteristic('test_device', '0xFFF0'))
      .thenAnswer((_) async => [128, 64, 32, 16]);
    
    // Act
    final states = await device.readChannelStates();
    
    // Assert
    expect(states, hasLength(4));
    expect(states, everyElement(isIn(range(0, 255))));
  });
  
  test('Read channel states should fail on invalid data', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    when(bleService.readCharacteristic('test_device', '0xFFF0'))
      .thenAnswer((_) async => [128, 64]); // Only 2 values instead of 4
    
    // Act & Assert
    expect(
      () => device.readChannelStates(),
      throwsA(equals('INVALID_DATA'))
    );
  });
}
```

### Test: Send Set Command
```dart
void main() {
  test('Send set command should send correct command', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = SetCommand(channel: 0, value: 128);
    
    // Act
    final result = await device.sendSetCommand(command);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device', 
      '0xFFF1', 
      [0x00, 0x00, 128] // Mode 0 (set), Channel 0, Value 128
    )).called(1);
  });
  
  test('Send set command should fail with invalid channel', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = SetCommand(channel: 5, value: 128); // Invalid channel
    
    // Act & Assert
    expect(
      () => device.sendSetCommand(command),
      throwsA(equals('INVALID_CHANNEL'))
    );
  });
  
  test('Send set command should fail with invalid value', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = SetCommand(channel: 0, value: 300); // Invalid value
    
    // Act & Assert
    expect(
      () => device.sendSetCommand(command),
      throwsA(equals('INVALID_VALUE'))
    );
  });
}
```

### Test: Send Fade Command
```dart
void main() {
  test('Send fade command should send correct command', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = FadeCommand(channel: 1, targetValue: 64, duration: 2000);
    
    // Act
    final result = await device.sendFadeCommand(command);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device', 
      '0xFFF1', 
      [0x01, 0x01, 64, 0x07, 0xD0] // Mode 1 (fade), Channel 1, Value 64, Duration 2000ms (0x07D0)
    )).called(1);
  });
  
  test('Send fade command should fail with invalid channel', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = FadeCommand(channel: 5, targetValue: 64, duration: 2000); // Invalid channel
    
    // Act & Assert
    expect(
      () => device.sendFadeCommand(command),
      throwsA(equals('INVALID_CHANNEL'))
    );
  });
  
  test('Send fade command should fail with invalid target value', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = FadeCommand(channel: 0, targetValue: 300, duration: 2000); // Invalid target value
    
    // Act & Assert
    expect(
      () => device.sendFadeCommand(command),
      throwsA(equals('INVALID_TARGET_VALUE'))
    );
  });
  
  test('Send fade command should fail with invalid duration', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = FadeCommand(channel: 0, targetValue: 64, duration: 70000); // Invalid duration
    
    // Act & Assert
    expect(
      () => device.sendFadeCommand(command),
      throwsA(equals('INVALID_DURATION'))
    );
  });
}
```

### Test: Send Blink Command
```dart
void main() {
  test('Send blink command should send correct command', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = BlinkCommand(channel: 2, period: 1000);
    
    // Act
    final result = await device.sendBlinkCommand(command);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device', 
      '0xFFF1', 
      [0x02, 0x02, 0x03, 0xE8] // Mode 2 (blink), Channel 2, Period 1000ms (0x03E8)
    )).called(1);
  });
  
  test('Send blink command should fail with invalid channel', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = BlinkCommand(channel: 5, period: 1000); // Invalid channel
    
    // Act & Assert
    expect(
      () => device.sendBlinkCommand(command),
      throwsA(equals('INVALID_CHANNEL'))
    );
  });
  
  test('Send blink command should fail with invalid period', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = BlinkCommand(channel: 0, period: 70000); // Invalid period
    
    // Act & Assert
    expect(
      () => device.sendBlinkCommand(command),
      throwsA(equals('INVALID_PERIOD'))
    );
  });
}
```

### Test: Send Strobe Command
```dart
void main() {
  test('Send strobe command should send correct command', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = StrobeCommand(channel: 3, flashCount: 5, totalDuration: 2000, pauseDuration: 1000);
    
    // Act
    final result = await device.sendStrobeCommand(command);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device', 
      '0xFFF1', 
      [0x03, 0x03, 0x05, 0x07, 0xD0, 0x03, 0xE8] // Mode 3 (strobe), Channel 3, Flash count 5, Total duration 2000ms, Pause duration 1000ms
    )).called(1);
  });
  
  test('Send strobe command should fail with invalid channel', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = StrobeCommand(channel: 5, flashCount: 5, totalDuration: 2000, pauseDuration: 1000); // Invalid channel
    
    // Act & Assert
    expect(
      () => device.sendStrobeCommand(command),
      throwsA(equals('INVALID_CHANNEL'))
    );
  });
  
  test('Send strobe command should fail with invalid flash count', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = StrobeCommand(channel: 0, flashCount: 300, totalDuration: 2000, pauseDuration: 1000); // Invalid flash count
    
    // Act & Assert
    expect(
      () => device.sendStrobeCommand(command),
      throwsA(equals('INVALID_FLASH_COUNT'))
    );
  });
  
  test('Send strobe command should fail with invalid total duration', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = StrobeCommand(channel: 0, flashCount: 5, totalDuration: 70000, pauseDuration: 1000); // Invalid total duration
    
    // Act & Assert
    expect(
      () => device.sendStrobeCommand(command),
      throwsA(equals('INVALID_TOTAL_DURATION'))
    );
  });
  
  test('Send strobe command should fail with invalid pause duration', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final command = StrobeCommand(channel: 0, flashCount: 5, totalDuration: 2000, pauseDuration: 70000); // Invalid pause duration
    
    // Act & Assert
    expect(
      () => device.sendStrobeCommand(command),
      throwsA(equals('INVALID_PAUSE_DURATION'))
    );
  });
}
```

## 3. Preset Management Contract Tests

### Test: Read All Presets from Device
```dart
void main() {
  test('Read all presets should parse preset data correctly', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    // Mock data: 2 presets
    // Preset 1: ID=1, 1 command (Set channel 0 to 100)
    // Preset 2: ID=2, 1 command (Fade channel 1 to 200 over 3000ms)
    when(bleService.readCharacteristic('test_device', '0xFFF2'))
      .thenAnswer((_) async => [
        // Preset 1
        1, // Preset ID
        1, // Command count
        0x00, 0x00, 100, // Set mode, channel 0, value 100
        // Preset 2
        2, // Preset ID
        1, // Command count
        0x01, 0x01, 200, 0x0B, 0xB8 // Fade mode, channel 1, value 200, duration 3000ms (0x0BB8)
      ]);
    
    // Act
    final presets = await device.readAllPresets();
    
    // Assert
    expect(presets, hasLength(2));
    expect(presets[0].id, equals(1));
    expect(presets[0].commandCount, equals(1));
    expect(presets[0].commands.first, isA<SetCommand>());
    expect((presets[0].commands.first as SetCommand).value, equals(100));
    expect(presets[1].id, equals(2));
    expect(presets[1].commandCount, equals(1));
    expect(presets[1].commands.first, isA<FadeCommand>());
    expect((presets[1].commands.first as FadeCommand).targetValue, equals(200));
    expect((presets[1].commands.first as FadeCommand).duration, equals(3000));
  });
}
```

### Test: Save Preset to Device
```dart
void main() {
  test('Save preset should send correct data format', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final preset = Preset(
      id: 1,
      name: 'Test Preset',
      commandCount: 2,
      commands: [
        SetCommand(channel: 0, value: 100),
        SetCommand(channel: 1, value: 50)
      ]
    );
    
    // Act
    final result = await device.savePresetToDevice(preset);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device',
      '0xFFF3',
      [
        1, // Preset ID
        2, // Command count
        0x00, 0x00, 100, // Command 1: Set mode, channel 0, value 100
        0x00, 0x01, 50   // Command 2: Set mode, channel 1, value 50
      ]
    )).called(1);
  });
  
  test('Delete preset should send correct data format', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    final preset = Preset(
      id: 1,
      name: 'Test Preset',
      commandCount: 0, // Command count 0 means delete
      commands: []
    );
    
    // Act
    final result = await device.savePresetToDevice(preset);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device',
      '0xFFF3',
      [1, 0] // Preset ID 1, Command count 0 (delete)
    )).called(1);
  });
}
```

### Test: Execute Preset
```dart
void main() {
  test('Execute preset should send correct command', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    
    // Act
    final result = await device.executePreset(1);
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device',
      '0xFFF4',
      [1] // Preset ID 1
    )).called(1);
  });
  
  test('Execute all channels off should send correct command', () async {
    // Arrange
    final bleService = MockBLEService();
    final device = PWMController(id: 'test_device', name: 'Test Device');
    
    // Act
    final result = await device.executePreset(0); // 0 means turn off all channels
    
    // Assert
    expect(result.success, isTrue);
    verify(bleService.writeCharacteristic(
      'test_device',
      '0xFFF4',
      [0] // Preset ID 0 (turn off all)
    )).called(1);
  });
}
```

## 4. Local Storage Contract Tests

### Test: Save Local Preset
```dart
void main() {
  test('Save local preset should store in shared preferences', () async {
    // Arrange
    final storageService = MockStorageService();
    final presetManager = PresetManager(storageService);
    final preset = Preset(
      id: 1,
      name: 'Test Preset',
      commandCount: 1,
      commands: [SetCommand(channel: 0, value: 100)],
      isFavorite: false
    );
    
    // Act
    final id = await presetManager.saveLocalPreset(preset);
    
    // Assert
    expect(id, equals(1));
    verify(storageService.savePreset(id, any)).called(1);
  });
}
```

### Test: Load Local Presets
```dart
void main() {
  test('Load local presets should return all saved presets', () async {
    // Arrange
    final storageService = MockStorageService();
    final presetManager = PresetManager(storageService);
    when(storageService.loadAllPresets()).thenAnswer((_) async => {
      '1': {
        'name': 'Preset 1',
        'commandCount': 1,
        'commands': [
          {
            'type': 'SetCommand',
            'channel': 0,
            'value': 100
          }
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isFavorite': false
      },
      '2': {
        'name': 'Preset 2',
        'commandCount': 1,
        'commands': [
          {
            'type': 'FadeCommand',
            'channel': 1,
            'targetValue': 200,
            'duration': 3000
          }
        ],
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'isFavorite': true
      }
    });
    
    // Act
    final presets = await presetManager.loadLocalPresets();
    
    // Assert
    expect(presets, hasLength(2));
    expect(presets[0].name, equals('Preset 1'));
    expect(presets[0].commands.first, isA<SetCommand>());
    expect(presets[1].isFavorite, isTrue);
    expect(presets[1].commands.first, isA<FadeCommand>());
  });
}
```