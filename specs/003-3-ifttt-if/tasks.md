---
description: "Task list for Switch Orchestration Experience Revamp"
---

# Tasks: Switch Orchestration Experience Revamp

**Input**: Design documents from `/specs/003-3-ifttt-if/`
**Prerequisites**: plan.md, spec.md, research.md (data-model.md, contracts/, quickstart.md to be created during implementation)

**Tests**: Include targeted unit/integration tests where they provide clear regression coverage for orchestration flows.

**Organization**: Tasks are grouped by user story so each slice is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare project scaffolding for the three-screen layout and orchestration feature set.

- [X] T001 [Setup] Establish feature folder structure (`app/lib/features/orchestration/`, `app/test/features/orchestration/`) and update `analysis_options.yaml` includes to recognise new directories.
- [X] T002 [P] [Setup] Draft navigation plan doc in `specs/003-3-ifttt-if/research.md` append-only section covering tab routing assumptions for later reference.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core models, persistence, and provider scaffolding required before story work can begin.  
**⚠️ CRITICAL**: Complete these tasks before starting any user story.

- [X] T003 [Foundation] Create orchestration data models (`ToggleScene`, `ToggleState`, `CommandBundle`, `ConditionalRule`) with JSON serialization in `app/lib/models/orchestration/toggle_scene.dart`.
- [X] T004 [Foundation] Extend `app/lib/services/storage_service.dart` to persist orchestration scenes and execution logs (read/write, migration of existing data).
- [X] T005 [Foundation] Add execution log entity and capped storage helper in `app/lib/models/orchestration/execution_log_entry.dart` and integrate with storage service.
- [X] T006 [Foundation] Introduce `OrchestrationProvider` in `app/lib/providers/orchestration_provider.dart` handling scene lifecycle, command preview pipeline, and log ingestion (no UI bindings yet).

**Checkpoint**: Foundational data and provider scaffolding in place; user story implementation can commence.

---

## Phase 3: User Story 1 – Build switch-driven automations (Priority: P1) 🎯 MVP

**Goal**: Deliver the new orchestration screen enabling toggle-based automations with state-specific command bundles and single-level if/else branching.

**Independent Test**: Create a scene, assign actions to both toggle states with a conditional rule, publish, and verify commands/logs fire correctly in a simulated environment.

### Tests for User Story 1

- [X] T007 [P] [US1] Add unit tests for orchestration models & provider logic in `app/test/unit/orchestration_provider_test.dart` (scene creation, validation, logging).
- [X] T008 [P] [US1] Add integration test simulating toggle activation and command preview flow in `app/test/integration/orchestration_flow_test.dart` using mock controllers.

### Implementation for User Story 1

- [X] T009 [US1] Implement orchestration orchestration provider features in `app/lib/providers/orchestration_provider.dart` (toggle CRUD, branch evaluation, publish pipeline).
- [X] T010 [P] [US1] Build reusable orchestration widgets (toggle card, command bundle editor, conditional rule editor) in `app/lib/widgets/orchestration/`.
- [X] T011 [US1] Create new orchestration screen at `app/lib/screens/orchestration_screen.dart`, wiring widgets to provider and handling validation/publish prompts.
- [X] T012 [US1] Implement command preview and simulator view (ordered action list, conflict warnings) in `app/lib/widgets/orchestration/command_preview_sheet.dart`.
- [X] T013 [US1] Update navigation (e.g., bottom nav / tab router) in `app/lib/main.dart` and supporting files to make orchestration screen the default landing view.
- [X] T014 [US1] Extend execution logging (write & read) in `app/lib/services/storage_service.dart` and surface history drawer component in orchestration screen.

**Checkpoint**: Orchestration screen fully functional with tests passing and logs captured.

---

## Phase 4: User Story 2 – Manage saved controllers (Priority: P2)

**Goal**: Provide a dedicated management screen with rename, reorder, and delete capabilities while highlighting scene dependencies.

**Independent Test**: Rename a controller, remove another, confirm lists update, and affected scenes show warnings until remapped.

### Tests for User Story 2

- [X] T015 [P] [US2] Add widget/integration test for management actions in `app/test/integration/saved_controller_management_screen_test.dart` covering rename/remove + dependency warning.

### Implementation for User Story 2

- [X] T016 [US2] Implement saved controller management screen UI in `app/lib/screens/saved_controller_management_screen.dart` with alias edit, reorder (drag-and-drop), and remove controls.
- [X] T017 [US2] Enhance orchestration provider to surface dependency metadata (scenes using each controller) stored in `app/lib/providers/orchestration_provider.dart` and update removal flows to flag impacts.
- [X] T018 [US2] Refresh component pickers within orchestration widgets to consume updated alias order and dependency badges.

**Checkpoint**: Saved controllers manageable independently; orchestration UI reflects changes immediately.

---

## Phase 5: User Story 3 – Direct device control (Priority: P3)

**Goal**: Build a focused device control screen for real-time adjustments to a selected connected controller without touching scenes.

**Independent Test**: Select each connected controller, adjust channels/presets, verify state updates, and confirm offline controllers show guidance.

### Tests for User Story 3

- [X] T019 [P] [US3] Add integration test for device control workflows in `app/test/integration/device_control_screen_test.dart` covering selection, channel updates, and offline handling.

### Implementation for User Story 3

- [X] T020 [US3] Create device control screen at `app/lib/screens/device_control_screen.dart` with controller selector, live telemetry, and manual channel/preset controls.
- [X] T021 [US3] Update `app/lib/providers/app_state_provider.dart` (or dedicated device provider) to expose per-controller control APIs compatible with new screen (no regression to automation).
- [X] T022 [US3] Add UI feedback for offline controllers (retry prompts, disabled controls) and share status widgets with orchestration screen where possible.

**Checkpoint**: Manual device control verified; coexistence with orchestration confirmed.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T023 [P] [Polish] Update navigation docs and onboarding copy in `app/README.md` and `specs/003-3-ifttt-if/quickstart.md` to describe the three-screen layout and new workflows.
- [X] T024 [Polish] Populate execution log quickstart scenario in `specs/003-3-ifttt-if/quickstart.md` with validation steps and update instructions.
- [X] T025 [Polish] Run regression suite (`flutter analyze`, focused `flutter test`) and address any failures introduced by new screens/providers.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup → Foundational**: Folder scaffolding and documentation updates precede model and provider work.
- **Foundational → Story Phases**: Complete T003–T006 before starting any user story tasks.
- **Story Order**: US1 (orchestration) → US2 (management) → US3 (device control). Later stories rely on orchestration provider outputs and navigation established in US1.
- **Polish**: Runs after all user stories deliver core functionality.

### User Story Dependencies

- **US1 (P1)**: Depends on foundational models/providers; no dependency on other stories.
- **US2 (P2)**: Depends on US1 data structures to identify scene-controller dependencies.
- **US3 (P3)**: Depends on navigation and device-provider updates from US1 setup; otherwise standalone.

### Within Stories

- Tests (T007, T008, T015, T019) precede corresponding implementation tasks.
- Provider/service updates finalize before UI wiring to avoid churn.
- Previews/logging (T012, T014) require provider publish logic (T009).

### Parallel Opportunities

- Setup tasks T001 and T002 operate independently.
- During US1, T010 (widgets) can proceed in parallel with T009 once data contracts agreed. T007 and T008 can run concurrently.
- US2 tasks T016 and T017 should stay sequential (same provider), but T018 can start after T017 interface defined.
- US3 tasks T020 and T021 should stay sequential; T022 can run once selection/telemetry APIs ready.

---

## Parallel Execution Examples

### User Story 1

- Parallel: T007 (unit tests) and T008 (integration test skeleton).
- Parallel: T010 (widget components) with T011 (screen shell) once provider API from T009 is stubbed.

### User Story 2

- After T017 defines dependency metadata, T018 (picker refresh) can proceed alongside UI refinements from T016.

### User Story 3

- After T021 exposes control APIs, T022 (offline feedback) can iterate while T020 finalizes layout tweaks.

---

## Implementation Strategy

### MVP First (User Story 1)
1. Complete Phases 1–2 (setup + foundational).
2. Implement US1 end-to-end, including tests and logging.
3. Validate orchestration flow before progressing.

### Incremental Delivery
1. Ship US1 as MVP.
2. Layer US2 management improvements, then US3 manual control enhancements.
3. Each increment maintains independence; re-run regression tests after each story.

### Parallel Team Strategy
1. One developer handles foundational models (T003–T006) while another prepares orchestration UI scaffolding (T001, T002).
2. After US1 foundation, split teams across US2 and US3 with shared oversight on provider changes to avoid conflicts.

---
