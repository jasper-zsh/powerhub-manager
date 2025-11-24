## Context

The current font upload implementation uses BLE characteristic 0xFFF1 for both font data and status communication. The protocol summary specifies a dual-characteristic approach where 0xFFF1 handles font data chunks and 0xFFF2 handles status notifications, progress reporting, and error handling. This design document outlines the technical decisions for implementing the enhanced protocol.

## Goals / Non-Goals

### Goals
- Implement robust font upload with comprehensive error handling
- Provide real-time progress reporting via 0xFFF2 notifications
- Add automatic error recovery with exponential backoff
- Implement memory management with warnings at 80% capacity
- Support 1MB maximum font size with 65KB chunk limits
- Provide 30-second timeout management per chunk
- Maintain LVGL font format compatibility

### Non-Goals
- Change the font generation service or binary format
- Modify the UI for font upload (backend-only change)
- Support multiple concurrent font uploads
- Implement font compression or format conversion

## Decisions

### Characteristic Separation
**Decision**: Use 0xFFF1 for font data upload only, 0xFFF2 for status notifications and error handling
**Rationale**: Separates data and control channels, reduces interference, matches protocol specification

### Error Handling Strategy
**Decision**: Implement both ATT error codes and custom 0xFF-prefixed error notifications
**Rationale**: Provides immediate feedback via ATT errors and detailed error context via 0xFFF2 notifications

### Progress Reporting Format
**Decision**: Use 0xFE prefix for progress with sequence number and percentage
**Rationale**: Allows progress tracking with sequence validation and completion estimation

### Memory Management
**Decision**: Send 0xFD prefix warnings at 80% capacity (819KB), automatic cleanup on failures
**Rationale**: Prevents device memory exhaustion, provides early warning for large fonts

### Timeout Management
**Decision**: 30-second timeout per chunk, reset timer on each successful chunk
**Rationale**: Balances reliability with responsiveness, prevents stuck uploads

## Alternatives Considered

### Single Characteristic Approach
**Alternative**: Continue using 0xFFF1 for both data and status
**Rejected**: Protocol specification requires dual characteristics, would limit error handling capabilities

### JSON-based Status
**Alternative**: Use JSON format for status reporting
**Rejected**: Binary format is more compact, faster to parse, matches protocol specification

### Client-side Only Error Recovery
**Alternative**: Handle all error recovery on client side
**Rejected**: Device-side error detection provides faster feedback and more reliable state management

## Risks / Trade-offs

### Device Compatibility
**Risk**: Requires device firmware update to support 0xFFF2 characteristic
**Mitigation**: Maintain backward compatibility fallback during transition period

### Increased Complexity
**Risk**: More complex protocol increases testing surface area
**Mitigation**: Comprehensive unit tests and integration tests, gradual rollout

### Performance Overhead
**Risk**: Additional notifications may increase BLE traffic
**Mitigation**: Rate-limit progress reports to 1-second minimum, optimize notification payloads

### Memory Usage
**Risk**: Enhanced error handling may increase memory footprint
**Mitigation**: Efficient data structures, early cleanup on failures, memory warnings

## Migration Plan

### Phase 1: Foundation
1. Add 0xFFF2 characteristic discovery and subscription
2. Implement basic notification parsing framework
3. Add enhanced error handling infrastructure

### Phase 2: Protocol Implementation
1. Update 0xFFF1 data format to match specification exactly
2. Implement 0xFE progress notifications
3. Add 0xFF error notifications with all error codes
4. Implement 0xFD memory warnings

### Phase 3: Enhanced Features
1. Add timeout management and retry logic
2. Implement comprehensive error recovery
3. Add upload validation and integrity checking
4. Update integration points and error handling

### Phase 4: Testing & Rollout
1. Comprehensive testing with various font sizes
2. Error scenario testing (disconnections, timeouts, memory limits)
3. Gradual rollout with fallback support
4. Monitor performance and error rates

### Rollback Strategy
- Maintain existing protocol as fallback path
- Feature flag to enable/disable new protocol
- Monitor error rates and rollback if issues detected
- Keep old implementation available during transition period

## Open Questions

### Error Recovery Timing
- What is the optimal exponential backoff strategy?
- Should retry limits be configurable?
- How to handle partial upload recovery?

### Progress Reporting Granularity
- What is the ideal progress report frequency?
- Should progress be estimated or calculated based on actual bytes?
- How to handle progress during validation phase?

### Memory Management Strategy
- Should memory warnings trigger automatic chunk size reduction?
- How to handle memory warnings during critical operations?
- What cleanup strategies to implement on memory exhaustion?