# Font Upload Error Code Reference

## Overview

This document provides a comprehensive reference for all error codes and messages used in the enhanced SwitchHub font upload protocol. Errors are categorized by source and include recovery recommendations.

## Protocol Error Types

### 0xFF Prefix - Status and Error Notifications

#### Upload Status Codes

| Code | Name | Description | Recovery |
|------|------|-------------|----------|
| `0x00` | Success | Font upload completed successfully | N/A |
| `0x02` | Upload Started | Device has started processing font upload | Continue monitoring |

#### Error Codes

| Code | Name | Description | Recovery | Parameter Meaning |
|------|------|-------------|----------|------------------|
| `0x01` | Timeout | 30 seconds elapsed without activity | Restart upload | N/A |
| `0x03` | Font Application Failed | Font validation or application failed | Reduce chunk size, retry | ESP error code |
| `0x04` | Sequence Error | Wrong chunk sequence number received | Restart from sequence 0 | Expected sequence |
| `0x05` | Disconnection | Device disconnected during upload | Reconnect, restart upload | N/A |

### ATT Error Codes (BLE Layer)

| Error Code | Hex Value | Name | Description | Recoverable | Recovery Action |
|------------|-----------|------|-------------|-------------|----------------|
| `0x05` | `0x05` | Insufficient Authentication | Pairing required | No | User must pair device |
| `0x06` | `0x06` | Request Not Supported | Malformed font data | Yes | Verify font format |
| `0x07` | `0x07` | Invalid Offset | Data positioning error | Yes | Restart upload |
| `0x08` | `0x08` | Insufficient Authorization | Operation not permitted | No | Check permissions |
| `0x0A` | `0x0A` | Invalid State | Invalid sequence or upload state | Yes | Restart upload |
| `0x0C` | `0x0C` | Insufficient Encryption Key Size | Security requirements not met | No | Update security |
| `0x0D` | `0x0D` | Invalid Attribute Value Length | Chunk size mismatch | Yes | Adjust chunk size |
| `0x0E` | `0x0E` | Unlikely | Font validation or application failed | Yes | Verify font data |
| `0x11` | `0x11` | Insufficient Resources | Memory allocation failed | Yes | Reduce font size |

### Client-Side Error Types

| Error Type | Description | Common Causes | Recovery |
|------------|-------------|---------------|----------|
| `sizeExceeded` | Font or chunk size exceeds limits | Font > 1MB or chunk > 65KB | Optimize font, reduce chunk size |
| `characteristicNotFound` | Required BLE characteristic missing | 0xFFF1 or 0xFFF2 not available | Check device firmware |
| `unknownProtocolError` | Unrecognized protocol message | Protocol version mismatch | Update firmware or fallback |
| `attError` | Generic BLE ATT layer error | Connection issues | Check connection, retry |

## Error Message Examples

### Timeout Errors

```
Font upload timeout: 30 seconds elapsed
Upload timeout - max retries reached
Chunk timeout approaching in 5s
```

### Memory Errors

```
Font size exceeds maximum allowed size of 1048576 bytes
Chunk size exceeds maximum allowed size of 65535 bytes
Memory warning: 850KB (83.1%)
Memory warning approaching: 5s remaining
```

### Sequence Errors

```
Sequence error: expected 5, got 7
Invalid sequence or upload state
Sequence error - restarting upload from beginning
```

### Font Application Errors

```
Font application failed on device
Font application failed (ESP error: 0x1234) - retrying with smaller chunks
Malformed font data
Font validation or application failed
```

### Connection Errors

```
Device disconnected during upload
Connection timeout: 10 seconds elapsed
Insufficient resources - device memory allocation failed
```

## Recovery Strategies

### Automatic Recovery

The enhanced font upload service implements automatic recovery for:

1. **Timeout Errors**: Exponential backoff retry
2. **Sequence Errors**: Immediate restart from sequence 0
3. **Memory Warnings**: Chunk size reduction
4. **ATT Errors**: Protocol-aware retry logic

### Manual Recovery

For non-recoverable errors:

1. **Authentication/Authorization**: User must pair device or check permissions
2. **Firmware Compatibility**: Update device firmware or use legacy protocol
3. **Font Corruption**: Regenerate font data or use different font

### Progressive Recovery

```dart
// Example of progressive recovery strategy
Future<void> recoverableUpload(Uint8List fontData) async {
  int attempt = 0;
  int chunkSize = 4096; // Start with optimal size

  while (attempt < 5) {
    try {
      await enhancedService.uploadFontData(
        device: device,
        fontData: fontData,
        chunkSize: chunkSize,
      );
      return; // Success
    } catch (e) {
      attempt++;

      if (e is FontUploadException) {
        switch (e.errorType) {
          case FontUploadError.memoryError:
            chunkSize = (chunkSize / 2).clamp(512, 2048);
            break;
          case FontUploadError.sizeExceeded:
            throw e; // Not recoverable
          case FontUploadError.timeout:
            await Future.delayed(Duration(seconds: attempt * 2));
            break;
          default:
            if (attempt >= 3) throw e; // Max retries for other errors
        }
      }
    }
  }
}
```

## Debug Information

### Error Logging

Enable detailed error logging:

```dart
// Enable debug mode
EnhancedFontUploadService.debugMode = true;

// Error details include:
// - Error type and code
// - Timestamp
// - Stack trace (if available)
// - Device state
// - Retry attempt number
```

### Error Context

Each error includes context for debugging:

```dart
class FontUploadErrorDetails {
  final FontUploadError type;
  final String message;
  final int? errorCode;
  final int? parameter;
  final DateTime timestamp;
  final Map<String, dynamic>? context;
}
```

### State Inspection

Monitor protocol state during errors:

```dart
enum FontUploadState {
  idle,           // No upload in progress
  initializing,   // Setting up upload session
  uploading,      // Transmitting chunks
  completing,     // Sending completion packet
  success,        // Upload completed
  error,          // Error occurred
  cancelled,      // Upload cancelled
}
```

## Troubleshooting Flowchart

```
Upload Failed?
├─ Check Error Type
│  ├─ Timeout?
│  │  ├─ Check connection stability
│  │  ├─ Reduce chunk size
│  │  └─ Retry with exponential backoff
│  ├─ Sequence Error?
│  │  ├─ Restart from beginning
│  │  └─ Check for concurrent uploads
│  ├─ Memory Error?
│  │  ├─ Check font size (< 1MB)
│  │  ├─ Reduce chunk size
│  │  └─ Optimize font complexity
│  ├─ ATT Error?
│  │  ├─ Check error code recoverability
│  │  ├─ Non-recoverable: User action required
│  │  └─ Recoverable: Automatic retry
│  └─ Characteristic Not Found?
│     ├─ Check device firmware version
│     ├─ Verify 0xFFF1/0xFFF2 support
│     └─ Fall back to legacy protocol
```

## Best Practices

### Error Prevention

1. **Validate Before Upload**: Check font size and format
2. **Connection Check**: Ensure stable BLE connection
3. **Memory Check**: Monitor device memory usage
4. **Firmware Check**: Verify device protocol support

### Error Handling

1. **Specific Handling**: Handle each error type appropriately
2. **User Feedback**: Provide clear error messages and recovery actions
3. **Logging**: Log errors with context for debugging
4. **Recovery**: Implement both automatic and manual recovery

### Testing

1. **Error Simulation**: Test with simulated errors
2. **Recovery Testing**: Verify recovery mechanisms work
3. **Edge Cases**: Test with large fonts and poor connections
4. **Performance**: Monitor impact on upload speed

## Resources

- [Font Upload Protocol Specification](font-upload-protocol-spec.md)
- [Migration Guide](font-upload-migration-guide.md)
- [API Documentation](font-upload-api.md)
- [Troubleshooting Guide](font-upload-troubleshooting.md)