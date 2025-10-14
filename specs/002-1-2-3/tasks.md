---
description: "Task list for Optimized Device Connection Management"
---

# Tasks: Optimized Device Connection Management

**Input**: Design documents from `/specs/002-1-2-3/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Project guidelines require TDD. Each story lists test tasks that MUST be completed (and fail) before implementation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Shared test utilities used by multiple stories

- [X] T001 [P] [Setup] Create saved controller fixture helpers in `app/test/test_utils/saved_controller_fixtures.dart` for unit and integration tests.
- [X] T002 [P] [Setup] Implement shared preferences test harness bootstrap in `app/test/test_utils/shared_preferences_stub.dart` to isolate storage-dependent tests.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core data structures and provider scaffolding required by all stories  
**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [Foundation] Define `SavedController` model with alias validation helpers in `app/lib/models/saved_controller.dart`.
- [X] T004 [Foundation] Add `ConnectionStatusRecord` and `ConnectionDashboardSummary` data classes in `app/lib/models/connection_status_record.dart`.
- [X] T005 [Foundation] Extend `app/lib/services/storage_service.dart` with load/save scaffolding for saved controller collections (returning placeholders for now).
- [X] T006 [Foundation] Update `app/lib/providers/app_state_provider.dart` to initialize saved controller state collections and expose read-only getters from storage.

**Checkpoint**: Foundation ready — user story implementation can now begin in parallel

---

## Phase 3: User Story 1 – Save controller with alias (Priority: P1) 🎯 MVP

**Goal**: Allow users to save connected controllers with unique aliases and reload them on launch.  
**Independent Test**: Connect to a new controller, save with alias, restart app, confirm saved list persists with alias and identifier.

### Tests for User Story 1 (write before implementation)

- [X] T007 [P] [US1] Add failing unit tests for alias uniqueness and persistence in `app/test/unit/saved_controller_storage_test.dart`.
- [X] T008 [P] [US1] Add failing integration test ensuring saved controllers persist across relaunch in `app/test/integration/saved_controller_persistence_test.dart`.

### Implementation for User Story 1

- [X] T009 [US1] Implement saved controller add logic with alias validation and duplicate handling in `app/lib/services/storage_service.dart`.
- [X] T010 [US1] Implement save/load workflows and error surfacing in `app/lib/providers/app_state_provider.dart`.
- [X] T011 [P] [US1] Create reusable saved controller list widget in `app/lib/widgets/saved_controller_list.dart`.
- [X] T012 [US1] Update `app/lib/screens/home_screen.dart` to prompt for alias, trigger save, and render saved controller list via the new widget.

**Checkpoint**: User Story 1 independently functional and testable

---

## Phase 4: User Story 2 – Auto-connect all saved controllers (Priority: P2)

**Goal**: Automatically reconnect all saved controllers while the app is in the foreground until each is connected or marked unavailable.  
**Independent Test**: Place multiple saved controllers in range, foreground the app, verify scanning continues until each connects or is marked unreachable after retries.

### Tests for User Story 2 (write before implementation)

- [X] T013 [P] [US2] Add failing unit tests covering reconnection retry loop and state transitions in `app/test/unit/saved_controller_autoconnect_test.dart`.
- [X] T014 [P] [US2] Add failing integration test verifying all saved controllers auto-connect in the foreground in `app/test/integration/auto_reconnect_test.dart`.

### Implementation for User Story 2

- [X] T015 [US2] Extend `app/lib/services/ble_service.dart` with helper methods for scanning saved controller identifiers and reporting availability.
- [X] T016 [US2] Implement reconnection scheduler and `ConnectionStatusRecord` updates in `app/lib/providers/app_state_provider.dart`.
- [X] T017 [US2] Update `app/lib/widgets/connection_status.dart` to display multi-device reconnection progress and unreachable states.
- [X] T018 [US2] Update `app/lib/main.dart` (or lifecycle handler) to trigger auto-reconnect when entering foreground and pause when backgrounded.

**Checkpoint**: User Stories 1 and 2 both independently functional

---

## Phase 5: User Story 3 – Manage multiple saved controllers (Priority: P3)

**Goal**: Enable users to rename or remove saved controllers and keep reconnection logic in sync.  
**Independent Test**: Rename a saved controller, remove another, restart app, confirm changes persist and removed controllers stop reconnection attempts.

### Tests for User Story 3 (write before implementation)

- [X] T019 [P] [US3] Add failing unit tests for rename/remove behavior and retry cancellation in `app/test/unit/saved_controller_management_test.dart`.
- [X] T020 [P] [US3] Add failing integration test verifying management updates propagate immediately in `app/test/integration/saved_controller_management_test.dart`.

### Implementation for User Story 3

- [X] T021 [US3] Implement rename/remove persistence logic and retry resets in `app/lib/services/storage_service.dart`.
- [X] T022 [US3] Extend `app/lib/providers/app_state_provider.dart` with rename/remove actions synchronizing `ConnectionStatusRecord`.
- [X] T023 [US3] Enhance `app/lib/widgets/saved_controller_list.dart` with rename/remove UI controls and status badges.
- [X] T024 [US3] Update `app/lib/screens/home_screen.dart` to surface saved controller management actions and dialogs.

**Checkpoint**: All user stories independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T025 [P] [Polish] Update `app/README.md` with multi-device management instructions and auto-reconnect behavior notes.
- [X] T026 [Polish] Execute quickstart validation and capture results in `specs/002-1-2-3/quickstart.md`.
- [X] T027 [Polish] Run `flutter analyze` and `flutter test` from `/app`, addressing lint or test issues across stories.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 → Phase 2**: Setup utilities must exist before foundational structures rely on them.
- **Phase 2 → Phase 3+**: Foundational models/providers block all user stories.
- **Phase 3 → Phase 4 → Phase 5**: User stories should be tackled in priority order (P1 → P2 → P3) to deliver incremental value.
- **Phase 6**: Begins after desired user stories complete.

### User Story Dependencies

- **US1 (P1)**: Depends on foundational phase; no dependency on other stories.
- **US2 (P2)**: Depends on foundational phase and US1 saved controller persistence.
- **US3 (P3)**: Depends on foundational phase and US1 persistence; integrates with US2 status tracking but remains independently testable once US2 interfaces exist.

### Task-Level Notes

- Tests in each story (T007/T008, T013/T014, T019/T020) must be written before corresponding implementation tasks.
- Provider and storage updates (T009/T010, T015–T016, T021–T022) execute sequentially to avoid merge conflicts.
- UI tasks (T011/T012, T017, T023/T024) occur after business logic to keep layers aligned.

---

## Parallel Execution Examples

### User Story 1

- In parallel: T007 and T008 (separate test files).  
- After tests: T011 (new widget) can run alongside T009/T010 once provider interfaces are defined.

### User Story 2

- In parallel: T013 and T014 (independent tests).  
- Once T015 completes, T017 can start while T016 finalizes provider logic; both touch different files.

### User Story 3

- In parallel: T019 and T020 (test files).  
- After T021, UI enhancement T023 can run concurrently with provider updates T022 because they touch different files (`widgets` vs `providers`).

---

## Implementation Strategy

### MVP First (User Story 1)
1. Complete Phases 1–2.
2. Implement Phase 3 tasks to deliver persistent saved controllers with aliases.
3. Validate using T007/T008 and checkpoint the MVP.

### Incremental Delivery
1. Ship MVP (US1).  
2. Add auto-reconnect logic (US2) and verify independently (T013/T014).  
3. Layer on management capabilities (US3) once prior stories approved.

### Parallel Team Strategy
1. Pair completes Phases 1–2.  
2. Developer A focuses on US1, Developer B on US2, Developer C on US3 once dependencies clear.  
3. Use checkpoints after each story to ensure independent validation before merging.
