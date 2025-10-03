# Implementation Plan: Flutter App for BLE-Controlled 4-Channel PWM Controller

**Branch**: `001-flutter-ble-4` | **Date**: Thursday, September 18, 2025 | **Spec**: [/specs/001-flutter-ble-4/spec.md](/specs/001-flutter-ble-4/spec.md)
**Input**: Feature specification from `/specs/001-flutter-ble-4/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Create a Flutter mobile application that can connect to an ESP32-based 4-channel PWM controller via Bluetooth Low Energy (BLE) to control each channel's PWM output and manage presets. The app will provide real-time control of PWM values (0-255) through sliders, allow users to create and recall named presets, and maintain a persistent connection to the device.

The ESP32 controller uses custom BLE characteristics for communication:
- 0xFFF0: Read channel states (4 bytes, 0-255)
- 0xFFF1: Write control commands
- 0xFFF2: Read all presets
- 0xFFF3: Write a single preset
- 0xFFF4: Execute a preset

According to the ESP32 documentation, the controller supports advanced modes including fade, blink, and strobe operations that must be properly implemented in the Flutter app with separate data structures for each command type to improve readability.

## Technical Context
**Language/Version**: Dart/Flutter 3.x, minimum SDK version 2.17  
**Primary Dependencies**: flutter_blue_plus (BLE library), provider (state management), shared_preferences (local storage)  
**Storage**: shared_preferences for preset persistence, local SQLite database for more complex data if needed  
**Testing**: flutter_test for unit tests, integration_test for widget and integration tests  
**Target Platform**: Android 7.0+ and iOS 12+, with potential future expansion to desktop platforms  
**Project Type**: mobile (app+BLE service)  
**Performance Goals**: <100ms response time for PWM adjustments, <500ms for preset loading  
**Constraints**: Must handle BLE disconnections gracefully, support offline preset management, work with ESP32's big-endian byte order, implement all ESP32 control modes (set, fade, blink, strobe) with separate data structures for each command type  
**Scale/Scope**: Single mobile app with 4 main channel controls, preset management, and device connection screens

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Based on the constitution at `/memory/constitution.md`:

1. **Library-First Principle**: The app should be structured with reusable components:
   - BLE communication library
   - PWM controller model
   - Preset management library
   - UI components for sliders and preset controls

2. **CLI Interface Principle**: Core functionality should be accessible via CLI where possible:
   - Preset export/import via command line
   - Device scanning and connection via CLI

3. **Test-First Principle**: All core functionality must have corresponding tests:
   - Unit tests for data models
   - Integration tests for BLE communication
   - Widget tests for UI components

4. **Integration Testing**: Critical integration points require testing:
   - BLE connection and communication
   - Preset storage and retrieval
   - PWM value synchronization
   - Advanced mode operations (fade, blink, strobe)

5. **Observability**: App should provide debugging capabilities:
   - Logging for BLE operations
   - Error reporting for connection issues
   - Performance metrics for response times

## Project Structure

### Documentation (this feature)
```
specs/001-flutter-ble-4/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 3: Mobile + API (when "iOS/Android" detected)
app/
├── lib/
│   ├── models/
│   │   ├── pwm_controller.dart
│   │   ├── channel.dart
│   │   ├── preset.dart
│   │   ├── control_command/
│   │   │   ├── set_command.dart
│   │   │   ├── fade_command.dart
│   │   │   ├── blink_command.dart
│   │   │   └── strobe_command.dart
│   │   └── control_modes.dart
│   ├── services/
│   │   ├── ble_service.dart
│   │   └── storage_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── channel_control_screen.dart
│   │   └── preset_management_screen.dart
│   ├── widgets/
│   │   ├── channel_slider.dart
│   │   ├── preset_list.dart
│   │   └── connection_status.dart
│   ├── providers/
│   │   └── app_state_provider.dart
│   └── main.dart
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
└── pubspec.yaml

ios/ or android/
└── [platform-specific structure]
```

**Structure Decision**: Option 3 (Mobile app) as this is a Flutter mobile application for BLE device control.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - Best practices for Flutter BLE implementations with complex protocols and separate command structures
   - ESP32 BLE characteristic interaction patterns for advanced modes with distinct data structures
   - Cross-platform BLE compatibility for Android/iOS with complex data structures
   - Data persistence strategies for Flutter apps with complex preset structures
   - UI/UX patterns for real-time device control with advanced modes

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research flutter_blue_plus library for ESP32 BLE communication with advanced modes and separate command structures"
     Task: "Research best practices for cross-platform BLE device control with complex protocols in Flutter"
     Task: "Research state management patterns for real-time device control apps with advanced features"
     Task: "Research local data persistence strategies for Flutter apps with complex data structures"
     Task: "Research UI/UX patterns for PWM controller interfaces with advanced mode controls"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - PWMController: Represents the ESP32 device with 4 channels
   - Channel: Individual PWM channel with value (0-255) and ID (0-3)
   - Preset: Named configuration storing control commands for all 4 channels
   - SetCommand: Represents a set value command with specific parameters
   - FadeCommand: Represents a fade/transition command with specific parameters
   - BlinkCommand: Represents a blink command with specific parameters
   - StrobeCommand: Represents a strobe command with specific parameters
   - BLEConnection: Connection state and communication methods

2. **Generate API contracts** from functional requirements:
   - Device scanning and connection API
   - Channel value update API with all control modes
   - Preset save/load/delete API with proper ESP32 preset structure
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh gemini` for your AI assistant
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Each contract → contract test task [P]
- Each entity → model creation task [P] 
- Each user story → integration test task
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Tests before implementation 
- Dependency order: Models before services before UI
- Mark [P] for parallel execution (independent files)

**Estimated Output**: 25-30 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Mobile app complexity | Real-time device control requires responsive UI | Web interface would have higher latency and poor UX for real-time control |
| BLE dependency | ESP32 controller only supports BLE communication | No alternative communication method available on the hardware |
| Advanced mode implementation | ESP32 supports fade, blink, and strobe modes that provide value to users | Simple on/off control would not utilize the full capabilities of the hardware |
| Separate command structures | Improves code readability and maintainability | Single generic structure would be harder to understand and maintain |

## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*