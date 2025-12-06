# Add SwitchHub If-Node Support to Orchestration System

## Problem Statement

While the core SwitchHub if-node logic infrastructure exists in the codebase (`SwitchHubIfNode`, condition evaluator, state context), the orchestration system lacks comprehensive UI support for creating, editing, and managing conditional logic rules. Users cannot easily create IFTTT-style automation through the current orchestration interface.

## Proposed Solution

Add complete if-node support to the orchestration system by:

1. **Enhancing the orchestration UI** to support conditional logic rule creation and management
2. **Integrating if-node functionality** with the existing orchestration workflow
3. **Providing intuitive condition builders** for creating expressions like `(SW1.ON AND NOT SW2.OFF) OR SW3.ON`
4. **Ensuring proper validation and testing** of conditional logic scenarios

## Benefits

- **Enables Smart Automation**: Users can create conditional automations based on toggle states
- **Improves User Experience**: Visual condition builder instead of manual JSON editing
- **Maintains BLE Compliance**: Full compatibility with SWITCHHUB_BLE.md specification
- **Leverages Existing Infrastructure**: Builds upon the robust if-node implementation already present

## Scope

The implementation will focus on:

1. UI components for condition building and if-node management
2. Integration with existing orchestration data models
3. Validation and error handling for conditional logic
4. Testing and documentation
5. Backward compatibility with existing orchestration configurations

## Technical Approach

- Extend the orchestration screen with conditional rule editor
- Create reusable condition builder widgets
- Integrate with existing `SwitchHubIfNode` and condition evaluator
- Ensure proper JSON serialization/deserialization for if-logic
- Add comprehensive test coverage for conditional scenarios