# Conditional UI Specification

## ADDED Requirements

### Requirement: Conditional Rule Creation Interface

The system SHALL provide a user interface for creating and managing conditional automation rules using if-node logic.

#### Scenario: Basic Conditional Rule Creation
**Given** the user is in the orchestration screen
**When** they select "Add Conditional Rule"
**Then** the system shall display an interface with:
- A condition builder for boolean expressions
- Branch selectors for "then" and "else" command bundles
- A visual tree structure showing the conditional logic
- Save and cancel options

#### Scenario: Complex Nested Conditions
**Given** the user wants to create nested conditional logic
**When** they add an if-node as a child of an existing branch
**Then** the system shall support:
- Multiple levels of nesting (up to 10 levels deep)
- Visual indentation and connection lines
- Branch labeling for easy identification
- Collapse/expand functionality for complex trees

### Requirement: Boolean Expression Builder

The system SHALL provide a visual interface for building boolean expressions without manual text entry.

#### Scenario: Expression Construction
**Given** the user is creating a conditional rule
**When** they interact with the condition builder
**Then** the system shall provide:
- Toggle state selector with autocomplete (e.g., "SW1.ON", "SW2.OFF")
- Logical operator buttons (AND, OR, NOT)
- Parentheses buttons for grouping
- Real-time expression display with proper formatting

#### Scenario: Expression Validation
**Given** the user is building a boolean expression
**When** they add invalid syntax or undefined references
**Then** the system shall:
- Highlight syntax errors in real-time
- Provide specific error messages with suggestions
- Prevent saving rules with invalid conditions
- Show a visual indicator of expression validity

#### Scenario: Expression Examples
**Given** the user is learning boolean expressions
**When** they access the help or examples section
**Then** the system shall provide templates for common patterns:
- Simple conditions: "SW1.ON"
- Combined conditions: "SW1.ON AND SW2.ON"
- Negated conditions: "NOT SW3.OFF"
- Complex conditions: "(SW1.ON AND SW2.OFF) OR SW3.ON"

### Requirement: Command Bundle Branch Management

The system SHALL allow users to assign command bundles to conditional rule branches.

#### Scenario: Branch Assignment
**Given** the user has created command bundles
**When** editing a conditional rule
**Then** the system shall provide:
- A bundle selector for the "then" branch
- An optional bundle selector for the "else" branch
- Multiple bundle selection per branch
- Bundle preview with action descriptions

#### Scenario: Multi-Bundle Execution
**Given** the user assigns multiple bundles to a conditional branch
**When** the condition matches and executes
**Then** the system shall execute bundles in the order specified, with:
- Sequential execution with configurable delays
- Error handling for individual bundle failures
- Execution logging and status reporting
- Option to continue or stop on bundle failure

### Requirement: Conditional Rule Visualization

The system SHALL provide visual feedback about conditional rule execution and current state.

#### Scenario: Rule Preview
**Given** the user has configured conditional rules
**When** viewing the orchestration interface
**Then** the system shall display:
- Current toggle states highlighted
- Active conditional rule branches marked
- Inactive branches shown in muted colors
- Execution indicators for rules that will fire

#### Scenario: What-If Analysis
**Given** the user wants to test conditional logic
**When** they simulate different toggle states
**Then** the system shall provide:
- Interactive state toggles for simulation
- Real-time preview of which rules would execute
- Execution path highlighting
- Performance metrics display (rule count, depth, complexity)

#### Scenario: Execution Timeline
**Given** complex conditional logic with multiple rules
**When** analyzing rule behavior
**Then** the system shall show:
- Chronological execution order
- Rule dependencies and relationships
- Estimated execution time for each rule
- Visual connections between related rules

## MODIFIED Requirements

### Requirement: Orchestration Screen Layout

The orchestration screen SHALL be enhanced to accommodate conditional rule management alongside existing command bundles.

#### Scenario: Unified Interface
**Given** the user is managing an orchestration scene
**When** viewing the orchestration screen
**Then** the system shall provide:
- Tabbed interface for "Direct Bundles" and "Conditional Rules"
- Consistent visual design across both sections
- Quick switching between bundle and rule management
- Unified preview panel showing both types of items

#### Scenario: Rule-Bundle Relationship
**Given** the user has both direct bundles and conditional rules
**When** viewing the orchestration overview
**Then** the system shall display:
- Clear distinction between direct and conditional execution
- Visual connections showing rule-bundle relationships
- Execution order indicators
- Status indicators for each rule and bundle

### Requirement: JSON Serialization and Storage

The conditional logic system SHALL integrate with existing orchestration data models and storage mechanisms.

#### Scenario: Data Persistence
**Given** the user creates conditional rules
**When** they save the orchestration scene
**Then** the system shall:
- Serialize conditional rules to JSON format
- Maintain compatibility with existing ToggleScene structure
- Preserve all conditional logic relationships
- Validate data integrity before storage

#### Scenario: Backward Compatibility
**Given** existing orchestration configurations without conditional rules
**When** loading older scenes
**Then** the system shall:
- Handle missing conditional logic gracefully
- Maintain full functionality for existing direct bundles
- Allow gradual migration to conditional logic
- Preserve all existing configurations without modification

## REMOVED Requirements

No requirements are removed in this specification, as all existing functionality is preserved and enhanced.

## Cross-Reference Requirements

### Related to: Conditional Logic Validation (spec: conditional-validation)

- Error messages from validation system shall be displayed in the condition builder
- Validation status shall be reflected in UI visual indicators
- Performance warnings shall be shown in rule preview panels

### Related to: Execution Engine (spec: conditional-execution)

- Execution results shall be displayed in preview panels
- Performance metrics from execution engine shall be shown to users
- Error states from execution shall be reflected in UI indicators

### Related to: Export/Import (spec: conditional-export)

- Conditional rules shall be included in orchestration JSON exports
- Import validation results shall be displayed in the UI
- Template availability shall be shown in rule creation interface