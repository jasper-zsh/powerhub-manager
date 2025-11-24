# Font Upload Protocol Migration Guide

## Overview

This guide helps migrate from the legacy font upload protocol to the enhanced SwitchHub font uploader protocol. The new protocol provides robust error handling, real-time progress reporting, and comprehensive recovery mechanisms.

## Key Changes

### Protocol Differences

| Aspect | Legacy Protocol | Enhanced Protocol |
|--------|----------------|------------------|
| **Data Channel** | 0xFFF1 only | 0xFFF1 (data) + 0xFFF2 (status) |
| **Error Handling** | Basic ATT errors | Comprehensive error notifications |
| **Progress Reporting** | Client-side estimates | Real-time device progress |
| **Memory Management** | None | 80% threshold warnings |
| **Retry Logic** | Manual | Automatic with exponential backoff |
| **Timeout Management** | None | 30-second chunk timeouts |

### Message Format Changes

#### Legacy Format
```
[0x05][length(2B)][sequence(2B)][payload...] - Data chunks only
```

#### Enhanced Format
```
// Data chunks
[0x05][chunk_len_hi][chunk_len_lo][seq_hi][seq_lo][payload...]

// Completion packet
[0x05][0x00][0x00][final_seq_hi][final_seq_lo]

// Status notifications (0xFFF2)
[0xFE][seq_hi][seq_lo][percentage] - Progress
[0xFF][error_code][param_hi][param_lo] - Errors
[0xFD][usage_hi][usage_mid][usage_lo] - Memory warnings
```

## Migration Steps

### 1. Update Dependencies

No new dependencies are required. The enhanced protocol uses existing Flutter Blue Plus and Dart libraries.

### 2. Update Service Usage

#### Before (Legacy)
```dart
final bleService = SwitchHubBleService();

await bleService.pushFontData(
  device,
  fontData,
  chunkSize: 200,
  onProgress: (current, total) {
    print('Progress: $current/$total');
  },
);
```

#### After (Enhanced)
```dart
final enhancedService = EnhancedFontUploadService();

await enhancedService.uploadFontData(
  device: device,
  fontData: fontData,
  chunkSize: 4096, // Recommended optimal size
  onProgress: (progress) {
    print('Progress: ${progress.currentSequence}/${progress.totalSequences} (${progress.percentage}%)');
  },
  onError: (error) {
    print('Upload error: ${error.message}');
  },
  onSuccess: () {
    print('Upload completed successfully');
  },
  onMemoryWarning: (warning) {
    print('Memory warning: ${warning.toString()}');
  },
);
```

### 3. Update Provider Integration

#### Before
```dart
await orchestrationProvider.pushFontDataToSwitchHub(
  sceneId,
  device: device,
  fontSize: 16,
  onProgress: (current, total) => updateUI(current, total),
);
```

#### After
```dart
await orchestrationProvider.pushFontDataToSwitchHub(
  sceneId,
  device: device,
  fontSize: 16,
  onProgress: (current, total) => updateUI(current, total),
  onFontError: (error) => showError(error),
  onFontSuccess: () => showSuccess(),
  onMemoryWarning: (warning) => showWarning(warning),
);
```

### 4. Handle New Error Types

The enhanced protocol introduces specific error types:

```dart
enum FontUploadError {
  attError,              // BLE ATT layer errors
  timeout,               // 30-second chunk timeout
  disconnection,         // Device disconnected
  fontApplicationFailed, // Font validation failed
  sequenceError,         // Wrong sequence number
  sizeExceeded,          // Font > 1MB or chunk > 65KB
  characteristicNotFound, // 0xFFF1 or 0xFFF2 missing
  unknownProtocolError,  // Unknown protocol error
}
```

### 5. Update Error Handling

#### Before
```dart
try {
  await bleService.pushFontData(device, fontData);
} catch (e) {
  print('Upload failed: $e');
  // Manual retry logic
}
```

#### After
```dart
try {
  await enhancedService.uploadFontData(
    device: device,
    fontData: fontData,
    enableRetry: true, // Automatic retry with exponential backoff
  );
} on FontUploadException catch (e) {
  print('Upload failed: ${e.message}');
  // Error details and recovery suggestions available
}
```

## Configuration Changes

### Chunk Size Optimization

- **Legacy**: Fixed 200 bytes
- **Enhanced**: Adaptive 4KB-16KB recommended, max 65,535 bytes
- **Benefits**: Faster transfers, fewer round trips

### Timeout Configuration

```dart
final config = FontUploadTimeoutConfig(
  chunkTimeout: Duration(seconds: 30),        // Per chunk
  connectionTimeout: Duration(seconds: 10),    // Inactivity
  overallTimeout: Duration(minutes: 10),       // Total upload
  progressReportInterval: Duration(seconds: 1), // Rate limiting
);
```

### Retry Configuration

```dart
final retryConfig = RetryConfig(
  maxRetries: 3,
  initialDelay: Duration(seconds: 1),
  backoffMultiplier: 2.0,
  maxDelay: Duration(seconds: 16),
);
```

## Backward Compatibility

### Feature Flags

The enhanced service includes backward compatibility support:

```dart
// Use legacy protocol if device doesn't support 0xFFF2
if (!await _deviceSupportsEnhancedProtocol(device)) {
  await _useLegacyFontUpload(device, fontData);
} else {
  await _useEnhancedFontUpload(device, fontData);
}
```

### Gradual Migration

1. **Phase 1**: Deploy enhanced service alongside legacy
2. **Phase 2**: Enable enhanced protocol for new devices
3. **Phase 3**: Migrate existing devices
4. **Phase 4**: Remove legacy protocol

## Testing Your Migration

### Unit Tests

```dart
test('font upload handles timeout correctly', () async {
  final service = EnhancedFontUploadService();

  // Mock device with timeout behavior
  final mockDevice = createMockDeviceWithTimeout();

  await expectLater(
    () => service.uploadFontData(device: mockDevice, fontData: testFontData),
    throwsA(isA<FontUploadException>()),
  );
});
```

### Integration Tests

```dart
test('end-to-end font upload flow', () async {
  final service = EnhancedFontUploadService();
  final device = await connectToTestDevice();

  bool success = false;
  String? lastError;

  await service.uploadFontData(
    device: device,
    fontData: testFontData,
    onSuccess: () => success = true,
    onError: (error) => lastError = error.message,
  );

  expect(success, true);
  expect(lastError, null);
});
```

## Troubleshooting

### Common Issues

#### 1. 0xFFF2 Characteristic Not Found
```
Error: FONT_STATUS_CHARACTERISTIC_NOT_FOUND
```
**Solution**: Device firmware doesn't support enhanced protocol. Use legacy protocol or update device firmware.

#### 2. Upload Timeout
```
Error: Upload timeout: 30 seconds elapsed
```
**Solution**: Check connection stability, reduce chunk size, or increase timeout configuration.

#### 3. Sequence Error
```
Error: Sequence error: expected 5, got 7
```
**Solution**: Enhanced service automatically restarts upload. Check for concurrent uploads or connection interference.

#### 4. Memory Warning
```
Warning: Memory usage: 850KB (83.1%)
```
**Solution**: Reduce chunk size or font complexity. Enhanced service adapts automatically.

### Debug Mode

Enable detailed logging:

```dart
// In debug builds
EnhancedFontUploadService.enableDebugLogging = true;
```

### Performance Monitoring

Monitor upload performance:

```dart
service.uploadFontData(
  device: device,
  fontData: fontData,
  onProgress: (progress) {
    final elapsed = DateTime.now().difference(startTime);
    final rate = progress.currentSequence / elapsed.inSeconds;
    print('Transfer rate: ${rate.toStringAsFixed(2)} chunks/sec');
  },
);
```

## Rollback Strategy

If issues arise during migration:

1. **Immediate**: Use feature flag to disable enhanced protocol
2. **Temporary**: Fall back to legacy `SwitchHubBleService.pushFontData()`
3. **Permanent**: Remove enhanced service if compatibility issues persist

```dart
bool useEnhancedProtocol = true; // Feature flag

Future<void> uploadFont(BluetoothDevice device, Uint8List fontData) async {
  if (useEnhancedProtocol) {
    try {
      await enhancedService.uploadFontData(device: device, fontData: fontData);
    } catch (e) {
      // Fallback to legacy protocol
      await legacyService.pushFontData(device, fontData);
    }
  } else {
    await legacyService.pushFontData(device, fontData);
  }
}
```

## Support

For migration issues:

1. Check device firmware version for 0xFFF2 support
2. Verify BLE connection stability
3. Monitor device memory usage during uploads
4. Review error logs for specific error codes
5. Test with smaller fonts first

## Resources

- [Font Upload Protocol Specification](docs/font-upload-protocol-spec.md)
- [Error Code Reference](docs/font-upload-error-codes.md)
- [API Documentation](docs/font-upload-api.md)
- [Troubleshooting Guide](docs/font-upload-troubleshooting.md)