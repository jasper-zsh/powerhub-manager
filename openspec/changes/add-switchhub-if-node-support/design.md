# Design: SwitchHub If-Node Support Architecture

## Overview

This design document outlines the architecture for adding comprehensive if-node support to the SwitchHub orchestration system. The implementation builds upon the existing `SwitchHubIfNode` infrastructure to provide a complete conditional logic solution for power management automation.

## Current State Analysis

### Existing Infrastructure
The codebase already contains a robust conditional logic foundation:

1. **SwitchHubLogicNode** (`lib/models/switch_hub/logic_node.dart`)
   - `SwitchHubIfNode`: Handles conditional logic with then/else branches
   - `SwitchHubLeafNode`: Contains command sequences to execute
   - Complete JSON serialization/deserialization support

2. **Condition Evaluation** (`lib/models/switch_hub/condition_evaluator.dart`)
   - Full boolean expression parser supporting AND, OR, NOT, parentheses
   - Syntax validation and error reporting
   - Integration with state context for evaluation

3. **State Context** (`lib/models/switch_hub/state_context.dart`)
   - Runtime state tracking for toggle switches
   - Identifier matching (SW1.ON, SW2.OFF, etc.)
   - Alias support for user-friendly references

### Current Gaps
- **UI Integration**: No user interface for creating conditional logic
- **Orchestration Integration**: Limited integration with orchestration workflow
- **User Experience**: Users must manually edit JSON to use conditional logic
- **Validation**: No comprehensive validation for conditional logic integrity

## Architecture Design

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Orchestration Screen                         │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  Direct Bundles │  │ Conditional Rules│  │ Rule Preview    │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    If-Node Management                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │Condition Builder│  │  If-Node Editor │  │Conditional      │  │
│  │                 │  │                 │  │Validator       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Execution Engine                               │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │State Context    │  │Condition Evaluator│  │Logic Execution  │  │
│  │                 │  │                 │  │                 │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **User Creation**: Users build conditional rules through the orchestration UI
2. **Validation**: ConditionalValidator checks rule integrity and references
3. **Serialization**: Rules are converted to JSON with SwitchHubIfNode structure
4. **Execution**: OrchestrationProvider evaluates conditions using existing infrastructure
5. **Device Control**: Matching branches execute command sequences

## Component Design

### 1. Condition Builder (`ConditionBuilder`)

**Purpose**: Visual interface for building boolean expressions

**Features**:
- Token-based expression builder (AND, OR, NOT, parentheses)
- Toggle state selector with autocomplete
- Real-time syntax validation
- Visual expression formatting

**Implementation**:
```dart
class ConditionBuilder extends StatefulWidget {
  final String? initialCondition;
  final Function(String) onConditionChanged;
  final List<String> availableToggles;

  // Builds expressions like (SW1.ON AND NOT SW2.OFF) OR SW3.ON
}
```

### 2. If-Node Editor (`IfRuleEditor`)

**Purpose**: Complete conditional rule creation and editing

**Features**:
- Condition input using ConditionBuilder
- Child node selection (then/else branches)
- Visual tree structure display
- Nested if-node support
- Drag-and-drop reordering

**Implementation**:
```dart
class IfRuleEditor extends StatefulWidget {
  final ConditionalRule? initialRule;
  final Function(ConditionalRule) onRuleChanged;
  final List<CommandBundle> availableBundles;
}
```

### 3. Conditional Validator (`ConditionalValidator`)

**Purpose**: Comprehensive validation for conditional logic

**Features**:
- Syntax validation for boolean expressions
- Reference validation (existing toggles)
- Circular dependency detection
- Performance impact analysis
- User-friendly error messages

**Implementation**:
```dart
class ConditionalValidator {
  ValidationResult validate(ConditionalRule rule, OrchestrationContext context);
  ValidationResult validateExpression(String expression, Set<String> availableToggles);
}
```

### 4. Conditional Preview (`ConditionalPreview`)

**Purpose**: Real-time visualization of conditional execution

**Features**:
- Current state display
- Execution path highlighting
- "What-if" scenario simulation
- Performance metrics
- Execution timeline

**Implementation**:
```dart
class ConditionalPreview extends StatelessWidget {
  final List<ConditionalRule> rules;
  final Map<String, String> currentState;
  final Map<String, String>? aliases;
}
```

## Integration Points

### Orchestration Screen Integration

**Location**: `lib/screens/orchestration_screen.dart`

**Changes Required**:
1. Add conditional rule management section
2. Integrate if-rule editor into existing workflow
3. Update command bundle display to show conditional vs direct rules
4. Add conditional rule preview panel

### ToggleState Enhancement

**Location**: `lib/models/orchestration/toggle_scene.dart`

**Changes Required**:
1. Add helper methods for if-node management
2. Enhance JSON serialization for conditional logic
3. Add validation methods for rule integrity
4. Create utility methods for rule manipulation

### Execution Engine Enhancement

**Location**: `lib/providers/orchestration_provider.dart`

**Changes Required**:
1. Integrate conditional logic evaluation with existing execution flow
2. Add state context creation for condition evaluation
3. Implement conditional logic execution logging
4. Add performance optimization for complex rule evaluation

## Data Models

### ConditionalRule

```dart
class ConditionalRule {
  final String id;
  final String description;
  final String condition;           // Boolean expression
  final List<String> thenBundles;    // Bundle IDs for true branch
  final List<String> elseBundles;    // Bundle IDs for false branch
  final bool isEnabled;
  final int priority;               // Execution priority
}
```

### Conditional Execution Context

```dart
class ConditionalExecutionContext {
  final Map<String, String> activeStates;  // toggleId -> stateId
  final Map<String, String> aliases;       // alias -> toggleId
  final List<String> executionPath;        // Path taken during evaluation
  final Map<String, dynamic> metrics;       // Performance metrics
}
```

## Performance Considerations

### Optimization Strategies

1. **Expression Caching**: Cache parsed expressions for repeated evaluation
2. **State Context Reuse**: Create single context per execution cycle
3. **Lazy Evaluation**: Only evaluate conditions when state changes
4. **Complexity Monitoring**: Track rule depth and execution time
5. **Parallel Processing**: Evaluate independent conditions concurrently

### Limits and Constraints

- **Maximum Rule Depth**: 10 levels of nesting
- **Maximum Expression Length**: 500 characters
- **Maximum Rules Per Toggle**: 50 conditional rules
- **Evaluation Timeout**: 100ms per rule evaluation

## Validation Strategy

### Syntax Validation
- Parentheses matching
- Operator placement validation
- Token sequence validation
- Reserved keyword usage

### Semantic Validation
- Toggle reference existence
- Circular dependency detection
- Performance impact assessment
- Rule completeness verification

### Runtime Validation
- State context integrity
- Execution path validation
- Error recovery mechanisms
- Logging and debugging support

## Error Handling

### User-Friendly Error Messages
- Syntax errors with position indicators
- Missing reference suggestions
- Performance warnings
- Conflict resolution guidance

### Recovery Mechanisms
- Graceful degradation for invalid conditions
- Automatic rule disabling on critical errors
- Backup/restore functionality for configurations
- Rollback support for failed changes

## Testing Strategy

### Unit Tests
- Individual component testing (ConditionBuilder, IfRuleEditor, etc.)
- Condition parser and evaluator testing
- Validation logic testing
- Performance benchmarking

### Integration Tests
- End-to-end conditional workflow testing
- State context integration testing
- JSON serialization/deserialization testing
- Execution engine integration testing

### User Experience Tests
- Widget testing for all UI components
- Accessibility testing
- Performance testing for complex scenarios
- Usability testing with real-world scenarios

## Security Considerations

### Input Validation
- Sanitize all user input for conditions
- Prevent injection attacks in boolean expressions
- Validate toggle references against available resources
- Limit expression complexity to prevent DoS attacks

### Data Integrity
- Validate JSON structure integrity
- Prevent circular dependencies
- Ensure proper serialization/deserialization
- Maintain backward compatibility

## Future Extensions

### Advanced Features
- Time-based conditions (time of day, day of week)
- External sensor conditions (temperature, voltage thresholds)
- Custom function support in expressions
- Machine learning-based condition optimization

### Integration Opportunities
- Home automation platform integration
- Voice assistant support
- Mobile app synchronization
- Cloud-based rule synchronization

This design provides a comprehensive foundation for implementing if-node support while leveraging the existing robust infrastructure and maintaining compatibility with the SWITCHHUB_BLE.md specification.