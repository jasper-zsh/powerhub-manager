# Feature Specification: Switch Orchestration Experience Revamp

**Feature Branch**: `003-3-ifttt-if`  
**Created**: 2025-10-14  
**Status**: Draft  
**Input**: User description: "重新组织界面和功能布局，将所有功能拆分为3个界面：主界面为开关编排界面，可以编排拨动开关用于控制设备，开关的两个状态分别对应一组指令，支持在一个状态内控制多个控制器的通道，支持简单的IFTTT编排（if-else和获取开关状态）；另外两个功能界面分别为已保存设备管理和设备控制；设备控制界面支持选择已连接的控制器对单个控制器进行控制"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Build switch-driven automations (Priority: P1)

Power users design a switch-based scene where each toggle position triggers predefined actions across one or more controllers, including simple if/else logic based on switch state.

**Why this priority**: Delivers the primary value of orchestrating complex device behavior from a single entry point, replacing the current fragmented workflow.

**Independent Test**: Create a new scene with a toggle, assign both states to command bundles touching multiple controllers, add an if/else branch, activate the toggle, and verify expected commands fire in a simulator log.

**Acceptance Scenarios**:

1. **Given** an empty orchestration workspace, **When** the user adds a toggle and configures state “On” with two controller-channel actions, **Then** publishing the scene executes all mapped commands when “On” is activated.
2. **Given** a scene with an if/else branch referencing the same toggle, **When** the toggle state changes, **Then** only the matching branch executes and the decision is recorded in the automation history.
3. **Given** the user edits a command bundle, **When** changes are saved, **Then** the system validates conflicts (duplicate controller-channel, missing targets) before enabling publish.

---

### User Story 2 - Manage saved controllers (Priority: P2)

Device owners access a dedicated management screen to review, rename, reorder, and delete saved controllers without leaving the orchestration flow.

**Why this priority**: Clear separation keeps orchestration focused while still granting maintenance access to saved device data that scenes rely on.

**Independent Test**: Open the management screen, rename one controller, remove another, verify the list updates immediately, and confirm changes persist after relaunch.

**Acceptance Scenarios**:

1. **Given** multiple saved controllers, **When** the user renames one, **Then** the new alias appears in both the management list and orchestration component pickers.
2. **Given** a stale controller entry, **When** it is removed, **Then** any scenes referencing it display a warning tag until remapped.

---

### User Story 3 - Direct device control (Priority: P3)

Operators need a focused view to select a connected controller and adjust channels or presets manually outside of scenes.

**Why this priority**: Provides fast path for manual overrides and diagnostics without disrupting saved automations.

**Independent Test**: From the device control screen, pick an online controller, change two channel values, trigger a preset, and confirm the device updates in real time.

**Acceptance Scenarios**:

1. **Given** multiple controllers connected, **When** the user selects one in the device control screen, **Then** only that controller’s real-time state and controls are shown.
2. **Given** an offline controller, **When** the user attempts to access it, **Then** the screen offers reconnect guidance and disables direct control actions.

---

### Edge Cases

- Toggle scenes referencing controllers that become unavailable mid-execution must gracefully skip unresolved actions and notify the user post-run.
- If conflicting automations target the same controller-channel simultaneously, the system resolves precedence (latest toggle action wins) and logs the override.
- Nested if/else rules beyond one level should be disallowed or automatically flattened with user feedback.
- Users offline while editing scenes should be warned that publishing requires connectivity to validate controller availability.
- Device control screen should handle partial controller telemetry (e.g., missing channel data) by showing fallback placeholders rather than blocking access.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The application MUST present three primary navigation destinations: switch orchestration (default landing), saved device management, and device control.
- **FR-002**: The orchestration screen MUST allow users to create, edit, duplicate, and delete toggle components where each state maps to a command bundle.
- **FR-003**: Each toggle state MUST support scheduling actions across multiple controllers and channels, including setting PWM values and invoking presets.
- **FR-004**: The orchestration engine MUST support simple conditional logic (single-level if/else) referencing existing toggle states and system variables (e.g., current switch position).
- **FR-005**: Users MUST be able to preview/simulate a scene, see the ordered list of commands that will run, and confirm before deployment.
- **FR-006**: The saved device management screen MUST list all saved controllers with alias, status, and last-seen time, and support rename, remove, and reorder operations with instant persistence.
- **FR-007**: Removing a saved controller MUST trigger dependency checks and highlight impacted scenes until those scenes are updated or archived.
- **FR-008**: The device control screen MUST allow selecting any currently connected controller, display live channel states, and expose manual controls (channels, presets, telemetry refresh) without affecting other controllers.
- **FR-009**: Switching between the three primary screens MUST preserve in-progress edits (e.g., unsaved scene changes) with clear prompts before discarding.
- **FR-010**: The system MUST log orchestration executions, including which branch fired, actions dispatched, and any skipped steps due to offline controllers.

### Key Entities *(include if feature involves data)*

- **Toggle Scene**: Represents a user-defined automation composed of toggles, states, associated command bundles, and conditional branches.
- **Command Bundle**: Group of controller-channel actions and optional preset triggers tied to a toggle state.
- **Conditional Rule**: Defines an if/else statement, specifying evaluated switch state(s), comparison logic, and target command bundle reference.
- **Saved Controller**: Persisted device entry with alias, connectivity status, metadata, and references to scenes where it is used.
- **Execution Log Entry**: Historical record of orchestration runs, including timestamp, trigger, branch taken, and outcome summary.

## Assumptions

- Conditional logic is limited to one level of if/else per toggle to avoid complex branching that would overwhelm mobile UI.
- Users manage a maximum of five controllers concurrently; UI layouts and performance expectations align to this scale.
- Command bundles execute sequentially per state; no parallel execution is required.
- Existing presets remain available for reuse within command bundles without schema changes.
- Device control interactions should reflect changes within two seconds to feel responsive.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 90% of pilot users create and activate a new switch scene within 10 minutes during usability testing.
- **SC-002**: 95% of executed scenes complete with all intended actions when target controllers are online, as measured in execution logs over two weeks.
- **SC-003**: Support tickets related to “confusing device control workflow” decrease by 40% within one release cycle after launch.
- **SC-004**: Manual controller adjustments from the device control screen reflect on the device within 2 seconds in 95% of observed sessions.
