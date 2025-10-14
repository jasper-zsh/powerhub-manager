# Feature Specification: Optimized Device Connection Management

**Feature Branch**: `002-1-2-3`  
**Created**: 2025-10-14  
**Status**: Draft  
**Input**: User description: "优化设备连接逻辑： 1. 增加保存设备功能，支持为已保存的设备指定别名 2. 支持管理多个设备 3. 程序在前台时，持续扫描并连接已保存的设备，直到全部设备都已连接 4. 任意已保存设备掉线后，重复扫描-连接的过程，直到全部设备都恢复连接"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save controller with alias (Priority: P1)

Returning users want the app to remember trusted controllers and label them meaningfully for quick identification.

**Why this priority**: Without saved controllers and aliases, users must rediscover devices every session, blocking efficient control.

**Independent Test**: Can be validated by connecting to a new controller, saving it with a custom alias, closing and reopening the app, and seeing the saved entry retained with the alias.

**Acceptance Scenarios**:

1. **Given** a user connects to a new controller, **When** they choose to save it and enter an alias, **Then** the controller appears in their saved list with that alias and its unique identifier.
2. **Given** a user has saved controllers, **When** they relaunch the app, **Then** the saved list persists with aliases and last-known connection status indicators.

---

### User Story 2 - Auto-connect all saved controllers (Priority: P2)

While actively using the app, users expect all saved controllers in range to reconnect automatically without manual intervention.

**Why this priority**: Ensures reliable control by removing manual steps and honoring the promise that saved controllers stay connected when needed.

**Independent Test**: Place multiple saved controllers in range, bring the app to the foreground, and verify the app scans until each controller is connected or flagged as unreachable.

**Acceptance Scenarios**:

1. **Given** the app enters the foreground with saved controllers nearby, **When** scanning starts, **Then** the app continues until every available saved controller is connected or marked unavailable after a retry threshold.

---

### User Story 3 - Manage multiple saved controllers (Priority: P3)

Power users need to monitor, rename, and remove saved controllers to keep the list accurate as devices change or are replaced.

**Why this priority**: Maintaining a clean list prevents stale connections and avoids confusion when controlling several controllers.

**Independent Test**: From the saved controller list, rename one device, remove another, and confirm changes persist across sessions and reflected in connection behavior.

**Acceptance Scenarios**:

1. **Given** a user opens the saved controller list, **When** they rename or remove a controller, **Then** the list updates immediately and remains consistent after app restart.

---

### Edge Cases

- Saved controller goes out of range during foreground scanning—system should mark it unreachable without stalling attempts for other controllers.
- Duplicate controller identifiers detected—system should prevent saving duplicates or prompt the user to replace the existing entry.
- User removes a controller while a reconnection attempt is in progress—system should stop retrying and update connection status immediately.
- App transitions to background mid-scan—system pauses scanning and resumes when returning to foreground without losing progress.
- Saved controller is powered off and then on again—system should detect its return and reconnect without user action.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to add a currently discovered or connected controller to a saved list and assign a custom alias before completing the save.
- **FR-002**: System MUST enforce alias entry rules (non-empty, per-user uniqueness) and provide user feedback when validation fails.
- **FR-003**: System MUST persist saved controllers (identifier, alias, metadata) locally so the list survives app restarts and device reboots.
- **FR-004**: System MUST display all saved controllers in a dedicated management view showing current connection status, alias, and underlying identifier.
- **FR-005**: System MUST let users rename or remove any saved controller, with changes reflected immediately in the management view and underlying data.
- **FR-006**: When the app is in the foreground and any saved controller is disconnected, the system MUST continuously scan for saved controllers until each is connected or confirmed unreachable after configurable retry attempts.
- **FR-007**: Upon detecting a saved controller reconnection or disconnection event, the system MUST update the user-facing status within one refresh cycle (e.g., list refresh or status indicator).
- **FR-008**: If a saved controller is manually removed, the system MUST cease all current and future reconnection attempts for that controller until it is saved again.
- **FR-009**: System MUST support concurrent management and reconnection attempts for at least five saved controllers without user intervention.

### Key Entities *(include if feature involves data)*

- **Saved Controller**: Represents a trusted device with attributes such as unique identifier, user-defined alias, last connected timestamp, connection status, retry state, and optional notes.
- **Connection Status Record**: Tracks the real-time state of each saved controller, including whether scanning is active, last scan attempt, last error reason, and whether retries remain.

## Assumptions

- Foreground refers to the period when the app is actively visible to the user; background behavior aligns with existing platform policies that restrict continuous scanning.
- Users typically manage up to five controllers; performance and UI expectations are scoped to that scale.
- Saved controller identifiers remain stable across sessions; if a device changes identifiers, it is treated as a new controller.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 95% of saved controllers that are powered on and within range reconnect automatically within 20 seconds of the app entering the foreground during field testing.
- **SC-002**: 90% of usability test participants successfully save a new controller with a custom alias in under 30 seconds without guidance.
- **SC-003**: 90% of monitored reconnection attempts recover from an unexpected disconnect without requiring user action within 30 seconds.
- **SC-004**: Support inquiries about “lost” or “duplicate” controllers decrease by 40% within one release cycle following launch, indicating easier multi-device management.
