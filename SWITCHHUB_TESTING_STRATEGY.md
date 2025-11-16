# SwitchHub Integration Testing Strategy

## 1. Overview

This document outlines the comprehensive testing strategy for SwitchHub integration into the Flutter PowerHub Manager app, ensuring reliable operation and smooth user experience.

## 2. Testing Objectives

### 2.1 Primary Goals
- **Functionality Verification**: Ensure all SwitchHub features work correctly
- **Compatibility Testing**: Validate integration with existing PowerHub devices
- **User Experience Testing**: Confirm smooth migration and operation
- **Performance Testing**: Verify system responsiveness and stability
- **Error Handling Testing**: Ensure graceful failure handling

### 2.2 Success Criteria
- All SwitchHub characteristics accessible and functional
- Successful JSON upload/download with CRC verification
- Reliable multi-PowerHub device coordination
- Seamless migration from current orchestration system
- Robust error handling and recovery

## 3. Test Environment Setup

### 3.1 Hardware Requirements
- **SwitchHub Device**: ESP32 development board with SwitchHub firmware v0.5+
- **PowerHub Devices**: 2-4 devices with firmware v1.6+
- **Mobile Devices**: Android and iOS test devices
- **Network Isolation**: Test both online and offline scenarios

### 3.2 Software Requirements
- **Flutter App**: Development build with SwitchHub integration
- **Debug Tools**: BLE sniffer, log analysis tools
- **Test Framework**: Unit, widget, and integration test setup
- **Mock Services**: Test doubles for BLE operations

## 4. Unit Testing Strategy

### 4.1 SwitchHub Data Models
```dart
// Test file: test/unit/switchhub_models_test.dart
void main() {
  group('SwitchHubConfig', () {
    test('should serialize to correct JSON format', () {
      final config = SwitchHubConfig(
        schemaVersion: 1,
        switches: [testSwitch],
      );
      
      final json = config.toJson();
      expect(json['schema_version'], equals(1));
      expect(json['switches'], isA<List>());
    });
    
    test('should deserialize from valid JSON', () {
      final json = {
        'schema_version': 1,
        'switches': [testSwitchJson],
      };
      
      final config = SwitchHubConfig.fromJson(json);
      expect(config.schemaVersion, equals(1));
      expect(config.switches.length, equals(1));
    });
    
    test('should handle invalid JSON gracefully', () {
      expect(() => SwitchHubConfig.fromJson({}), throwsException);
    });
  });
}
```

### 4.2 Command Mapping Tests
```dart
// Test file: test/unit/switchhub_command_mapper_test.dart
void main() {
  group('SwitchHubCommandMapper', () {
    test('should map set command correctly', () {
      final action = CommandAction(
        controllerId: 'test-device',
        type: CommandActionType.channelValue,
        channel: 2,
        value: 128,
      );
      
      final packet = SwitchHubCommandMapper.mapFromAppCommand(action);
      expect(packet.mode, equals(0x00));
      expect(packet.channel, equals(2));
      expect(packet.payload, equals(base64.encode([128])));
    });
    
    test('should map fade command correctly', () {
      final action = CommandAction(
        controllerId: 'test-device',
        type: CommandActionType.fade,
        channel: 1,
        targetValue: 255,
        duration: 2000,
      );
      
      final packet = SwitchHubCommandMapper.mapFromAppCommand(action);
      expect(packet.mode, equals(0x01));
      expect(packet.channel, equals(1));
      
      final decoded = base64.decode(packet.payload);
      expect(decoded[0], equals(255));
      expect((decoded[1] << 8) | decoded[2], equals(2000));
    });
  });
}
```

### 4.3 JSON Upload/Download Tests
```dart
// Test file: test/unit/switchhub_orchestration_service_test.dart
void main() {
  group('SwitchHubOrchestrationService', () {
    test('should split large JSON into chunks correctly', () {
      final service = MockSwitchHubOrchestrationService();
      final largeJson = 'x' * 1000; // 1KB test data
      
      final chunks = service.splitIntoChunks(largeJson, chunkSize: 247);
      expect(chunks.length, equals(5)); // 4 full chunks + 1 partial
      expect(chunks.last.length, lessThanOrEqualTo(247));
    });
    
    test('should calculate CRC32 correctly', () {
      final testData = 'test data for CRC32';
      final crc32 = SwitchHubOrchestrationService.calculateCrc32(testData);
      expect(crc32, equals(expectedCrc32Value));
    });
    
    test('should handle chunked upload with verification', () async {
      final mockService = MockSwitchHubOrchestrationService();
      final testData = createTestOrchestrationJson();
      
      await mockService.uploadOrchestrationJson(testData);
      
      verify(mockService.writeChunk(0, any, any)).called(1);
      verify(mockService.writeChunk(1, any, any)).called(1);
      verify(mockService.verifyAndCommitCrc32(any)).called(1);
    });
  });
}
```

## 5. Integration Testing Strategy

### 5.1 BLE Connection Tests
```dart
// Test file: test/integration/switchhub_connection_test.dart
void main() {
  group('SwitchHub BLE Integration', () {
    late SwitchHubBLEService bleService;
    late MockFlutterBluePlus mockBluePlus;
    
    setUp(() {
      mockBluePlus = MockFlutterBluePlus();
      bleService = SwitchHubBLEService(mockBluePlus);
    });
    
    test('should discover SwitchHub service correctly', () async {
      // Mock device with SwitchHub service UUID
      final mockDevice = createMockSwitchHubDevice();
      when(mockBluePlus.scanResults).thenAnswer((_) async* {
        yield [ScanResult(device: mockDevice, rssi: -50)];
      });
      
      final devices = await bleService.scanForDevices();
      expect(devices.length, equals(1));
      expect(devices.first.type, equals(DeviceType.switchHub));
    });
    
    test('should connect to SwitchHub and discover characteristics', () async {
      final mockDevice = createMockSwitchHubDevice();
      when(mockBluePlus.connect(any)).thenAnswer((_) async {});
      
      await bleService.connect(mockDevice.remoteId.str);
      
      verify(mockBluePlus.connect(mockDevice.remoteId.str)).called(1);
      expect(bleService.isConnected, isTrue);
    });
    
    test('should read SwitchHub characteristics', () async {
      await setupMockConnection();
      
      final powerConfig = await bleService.readPowerManagementConfig();
      expect(powerConfig.sleepVoltageThreshold, greaterThan(0));
      
      final monitoringData = await bleService.readMonitoringData();
      expect(monitoringData.inputVoltageMillivolts, greaterThan(0));
    });
  });
}
```

### 5.2 Orchestration Execution Tests
```dart
// Test file: test/integration/switchhub_orchestration_test.dart
void main() {
  group('SwitchHub Orchestration Execution', () {
    late SwitchHubOrchestrationProvider provider;
    late MockBLEService mockBLEService;
    
    setUp(() async {
      mockBLEService = MockBLEService();
      provider = SwitchHubOrchestrationProvider(
        bleService: mockBLEService,
        storageService: MockStorageService(),
      );
      await provider.initialize();
    });
    
    test('should execute switch state change correctly', () async {
      final testConfig = createTestOrchestrationConfig();
      await provider.loadOrchestration(testConfig);
      
      await provider.executeSwitch(1, 'on');
      
      verify(mockBLEService.writeOrchestrationChunk(any)).called(1);
      expect(provider.lastExecutionResult, equals(ExecutionResult.success));
    });
    
    test('should handle multi-device coordination', () async {
      final multiDeviceConfig = createMultiDeviceTestConfig();
      await provider.loadOrchestration(multiDeviceConfig);
      
      await provider.executeSwitch(1, 'on');
      
      // Verify commands sent to multiple PowerHubs
      verify(mockBLEService.sendCommandToPowerHub('AA:BB:CC:DD:EE:FF', any)).called(1);
      verify(mockBLEService.sendCommandToPowerHub('11:22:33:44:55:66', any)).called(1);
    });
  });
}
```

### 5.3 Migration Tests
```dart
// Test file: test/integration/switchhub_migration_test.dart
void main() {
  group('SwitchHub Migration', () {
    test('should convert toggle scenes to SwitchHub format', () async {
      final migrationService = SwitchHubMigrationService();
      final toggleScenes = createTestToggleScenes();
      
      final switchHubConfig = await migrationService.convertToSwitchHubFormat(toggleScenes);
      
      expect(switchHubConfig.switches.length, equals(toggleScenes.length));
      expect(switchHubConfig.schemaVersion, equals(1));
      
      // Verify specific conversion
      final convertedSwitch = switchHubConfig.switches.first;
      expect(convertedSwitch.on.type, equals('leaf'));
      expect(convertedSwitch.off.type, equals('leaf'));
    });
    
    test('should preserve command bundles in conversion', () async {
      final migrationService = SwitchHubMigrationService();
      final scenesWithBundles = createScenesWithComplexBundles();
      
      final switchHubConfig = await migrationService.convertToSwitchHubFormat(scenesWithBundles);
      
      final switchWithBundles = switchHubConfig.switches.first;
      expect(switchWithBundles.on.sequence?.length, greaterThan(0));
      
      // Verify command packet structure
      final commandPacket = switchWithBundles.on.sequence!.first.commandPackets.first;
      expect(commandPacket.mode, isA<int>());
      expect(commandPacket.channel, isA<int>());
      expect(commandPacket.payload, isA<String>());
    });
  });
}
```

## 6. Widget Testing Strategy

### 6.1 Orchestration UI Tests
```dart
// Test file: test/widget/switchhub_orchestration_screen_test.dart
void main() {
  testWidgets('should display SwitchHub switches correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => MockSwitchHubProvider(),
          child: SwitchHubOrchestrationScreen(),
        ),
      ),
    );
    
    // Verify switch controls are displayed
    expect(find.byType(SwitchHubSwitchControl), findsWidgets);
    expect(find.text('Switch 1'), findsOneWidget);
    expect(find.text('Switch 2'), findsOneWidget);
  });
  
  testWidgets('should handle switch state changes', (tester) async {
    final mockProvider = MockSwitchHubProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: mockProvider,
          child: SwitchHubOrchestrationScreen(),
        ),
      ),
    );
    
    // Tap switch to change state
    await tester.tap(find.byKey(Key('switch-1')));
    await tester.pump();
    
    verify(mockProvider.executeSwitch(1, any)).called(1);
  });
}
```

### 6.2 Migration Wizard Tests
```dart
// Test file: test/widget/switchhub_migration_wizard_test.dart
void main() {
  testWidgets('should guide user through migration steps', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SwitchHubMigrationWizard(),
      ),
    );
    
    // Step 1: Backup current configuration
    expect(find.text('Backup Current Configuration'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    
    // Step 2: Scan for PowerHub devices
    expect(find.text('Scanning for PowerHub Devices'), findsOneWidget);
    await tester.pump(Duration(seconds: 2));
    
    // Step 3: Device mapping
    expect(find.byType(DeviceMappingWidget), findsOneWidget);
  });
}
```

## 7. Performance Testing Strategy

### 7.1 Connection Performance
```dart
// Test file: test/performance/switchhub_connection_performance_test.dart
void main() {
  group('Connection Performance', () {
    test('should connect within acceptable time', () async {
      final stopwatch = Stopwatch()..start();
      
      await bleService.connectToSwitchHub(testDeviceId);
      
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
    });
    
    test('should handle concurrent connections efficiently', () async {
      final futures = <Future>[];
      final stopwatch = Stopwatch()..start();
      
      // Connect to multiple PowerHubs through SwitchHub
      for (int i = 0; i < 8; i++) {
        futures.add(switchHub.connectToPowerHub(testMacAddresses[i]));
      }
      
      await Future.wait(futures);
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(15000)); // 15 seconds max for 8 devices
    });
  });
}
```

### 7.2 Memory and Resource Usage
```dart
// Test file: test/performance/switchhub_memory_test.dart
void main() {
  group('Memory Usage', () {
    test('should handle large orchestration files efficiently', () async {
      final largeConfig = createLargeOrchestrationConfig(
        switchCount: 50,
        commandsPerSwitch: 20,
      );
      
      final memoryBefore = getCurrentMemoryUsage();
      await provider.loadOrchestration(largeConfig);
      final memoryAfter = getCurrentMemoryUsage();
      
      final memoryIncrease = memoryAfter - memoryBefore;
      expect(memoryIncrease, lessThan(10 * 1024 * 1024)); // Less than 10MB increase
    });
  });
}
```

## 8. End-to-End Testing Strategy

### 8.1 User Journey Tests
```dart
// Test file: test/e2e/switchhub_user_journey_test.dart
void main() {
  group('End-to-End User Journeys', () {
    test('should complete full migration journey', () async {
      // 1. Start with existing orchestration
      await setupExistingOrchestration();
      
      // 2. Run migration wizard
      await startMigrationWizard();
      await completeDeviceDiscovery();
      await completeConfigurationConversion();
      await completeValidation();
      
      // 3. Verify SwitchHub operation
      await connectToSwitchHub();
      await testSwitchExecution();
      await verifyStatusMonitoring();
      
      // 4. Confirm everything works
      expect(appState.currentMode, equals(AppMode.switchHub));
      expect(switchHubState.connectedPowerHubs.length, greaterThan(0));
    });
  });
}
```

### 8.2 Stress Testing
```dart
// Test file: test/e2e/switchhub_stress_test.dart
void main() {
  group('Stress Testing', () {
    test('should handle rapid switch operations', () async {
      for (int i = 0; i < 100; i++) {
        await provider.executeSwitch(1, i % 2 == 0 ? 'on' : 'off');
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      expect(provider.errorCount, lessThan(5)); // Less than 5% error rate
    });
    
    test('should maintain stability over extended operation', () async {
      final stopwatch = Stopwatch()..start();
      
      while (stopwatch.elapsedMinutes < 60) { // Run for 1 hour
        await provider.executeSwitch(1, 'on');
        await Future.delayed(Duration(seconds: 5));
        await provider.executeSwitch(1, 'off');
        await Future.delayed(Duration(seconds: 5));
      }
      
      expect(provider.connectionDrops, lessThan(3));
      expect(provider.memoryLeakDetected, isFalse);
    });
  });
}
```

## 9. Automated Testing Pipeline

### 9.1 Continuous Integration
```yaml
# .github/workflows/switchhub_test.yml
name: SwitchHub Integration Tests

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter test test/unit/switchhub_*
  
  integration-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter test test/integration/switchhub_*
  
  widget-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: subosito/flutter-action@v2
      - run: flutter test test/widget/switchhub_*
```

### 9.2 Test Data Management
```dart
// Test utilities for consistent test data
class SwitchHubTestDataFactory {
  static SwitchHubConfig createBasicConfig() {
    return SwitchHubConfig(
      schemaVersion: 1,
      switches: [
        SwitchHubSwitch(
          switchId: 1,
          revision: 1,
          on: SwitchHubLogicNode.leaf(sequence: [
            SwitchHubSequenceItem(
              targetMac: 'AA:BB:CC:DD:EE:FF',
              commandPackets: [createTestCommandPacket()],
            ),
          ]),
          off: SwitchHubLogicNode.leaf(sequence: []),
          ui: SwitchHubUIConfig(
            channelLabel: 'Test Switch',
            onLabel: 'On',
            offLabel: 'Off',
          ),
        ),
      ],
    );
  }
  
  static PowerHubCommandPacket createTestCommandPacket() {
    return PowerHubCommandPacket(
      mode: 0x00,
      channel: 1,
      payload: base64.encode([128]),
      retry: 1,
    );
  }
}
```

## 10. Test Coverage Requirements

### 10.1 Coverage Targets
- **Unit Tests**: 90%+ code coverage
- **Integration Tests**: 80%+ feature coverage
- **Widget Tests**: 85%+ UI coverage
- **E2E Tests**: All critical user journeys

### 10.2 Critical Test Areas
- BLE connection and characteristic access
- JSON serialization/deserialization
- Command mapping and execution
- Error handling and recovery
- Migration data conversion
- UI responsiveness and state management

## 11. Test Reporting and Metrics

### 11.1 Automated Reports
- **Test Execution Summary**: Pass/fail rates, execution times
- **Coverage Reports**: Line and branch coverage analysis
- **Performance Metrics**: Memory usage, response times
- **Error Analysis**: Failure patterns and root causes

### 11.2 Quality Gates
- **All tests must pass** before merge
- **Coverage targets must be met**
- **Performance benchmarks must be maintained**
- **No critical security vulnerabilities**

## 12. Manual Testing Guidelines

### 12.1 Device-Specific Testing
- **Multiple Android devices** (different OEMs, Android versions)
- **Multiple iOS devices** (different iPhone/iPad models)
- **Various BLE conditions** (interference, distance, obstacles)
- **Different network conditions** (online/offline/mixed)

### 12.2 User Scenario Testing
- **First-time user setup** and migration
- **Daily usage patterns** and workflows
- **Error recovery scenarios** and troubleshooting
- **Power management** and battery optimization

This comprehensive testing strategy ensures reliable SwitchHub integration and excellent user experience.