# Tasks: Flutter App for BLE-Controlled 4-Channel PWM Controller

**Input**: Design documents from `/specs/001-flutter-ble-4/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → If not found: ERROR "No implementation plan found"
   → Extract: tech stack, libraries, structure
2. Load optional design documents:
   → data-model.md: Extract entities → model tasks
   → contracts/: Each file → contract test task
   → research.md: Extract decisions → setup tasks
3. Generate tasks by category:
   → Setup: project init, dependencies, linting
   → Tests: contract tests, integration tests
   → Core: models, services, CLI commands
   → Integration: DB, middleware, logging
   → Polish: unit tests, performance, docs
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001, T002...)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests?
   → All entities have models?
   → All endpoints implemented?
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Mobile app**: `app/lib/`, `app/test/`

## Phase 3.1: Setup
- [ ] T001 Create Flutter project structure per implementation plan at `app/`
- [ ] T002 Initialize Flutter project with flutter_blue_plus, provider, shared_preferences dependencies in `app/pubspec.yaml`
- [ ] T003 [P] Configure linting and formatting tools in `app/analysis_options.yaml`

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Contract Tests (from contracts/contract-tests.md)
- [ ] T004 [P] Contract test for Device Management in `app/test/unit/device_management_test.dart`
- [ ] T005 [P] Contract test for Channel Control - Read Channel States in `app/test/unit/channel_control_read_test.dart`
- [ ] T006 [P] Contract test for Channel Control - Set Command in `app/test/unit/channel_control_set_test.dart`
- [ ] T007 [P] Contract test for Channel Control - Fade Command in `app/test/unit/channel_control_fade_test.dart`
- [ ] T008 [P] Contract test for Channel Control - Blink Command in `app/test/unit/channel_control_blink_test.dart`
- [ ] T009 [P] Contract test for Channel Control - Strobe Command in `app/test/unit/channel_control_strobe_test.dart`
- [ ] T010 [P] Contract test for Preset Management - Read All Presets in `app/test/unit/preset_management_read_test.dart`
- [ ] T011 [P] Contract test for Preset Management - Save Preset in `app/test/unit/preset_management_save_test.dart`
- [ ] T012 [P] Contract test for Preset Management - Delete Preset in `app/test/unit/preset_management_delete_test.dart`
- [ ] T013 [P] Contract test for Preset Management - Execute Preset in `app/test/unit/preset_management_execute_test.dart`
- [ ] T014 [P] Contract test for Local Storage in `app/test/unit/local_storage_test.dart`

### Integration Tests (from quickstart.md scenarios)
- [ ] T015 [P] Integration test for Device Discovery scenario in `app/test/integration/device_discovery_test.dart`
- [ ] T016 [P] Integration test for Device Connection scenario in `app/test/integration/device_connection_test.dart`
- [ ] T017 [P] Integration test for Channel Control scenario in `app/test/integration/channel_control_test.dart`
- [ ] T018 [P] Integration test for Preset Creation scenario in `app/test/integration/preset_creation_test.dart`
- [ ] T019 [P] Integration test for Preset Recall scenario in `app/test/integration/preset_recall_test.dart`

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### Data Models (from data-model.md)
- [ ] T020 [P] PWMController model in `app/lib/models/pwm_controller.dart`
- [ ] T021 [P] Channel model in `app/lib/models/channel.dart`
- [ ] T022 [P] Preset model in `app/lib/models/preset.dart`
- [ ] T023 [P] ControlCommand base class in `app/lib/models/control_command/control_command.dart`
- [ ] T024 [P] SetCommand model in `app/lib/models/control_command/set_command.dart`
- [ ] T025 [P] FadeCommand model in `app/lib/models/control_command/fade_command.dart`
- [ ] T026 [P] BlinkCommand model in `app/lib/models/control_command/blink_command.dart`
- [ ] T027 [P] StrobeCommand model in `app/lib/models/control_command/strobe_command.dart`
- [ ] T028 [P] BLEConnection model in `app/lib/models/ble_connection.dart`

### Services (from research.md and data-model.md)
- [ ] T029 [P] BLEService in `app/lib/services/ble_service.dart`
- [ ] T030 [P] StorageService in `app/lib/services/storage_service.dart`

### Providers (from research.md)
- [ ] T031 AppStateProvider in `app/lib/providers/app_state_provider.dart`

### Screens (from plan.md)
- [ ] T032 HomeScreen in `app/lib/screens/home_screen.dart`
- [ ] T033 ChannelControlScreen in `app/lib/screens/channel_control_screen.dart`
- [ ] T034 PresetManagementScreen in `app/lib/screens/preset_management_screen.dart`

### Widgets (from plan.md)
- [ ] T035 ChannelSlider widget in `app/lib/widgets/channel_slider.dart`
- [ ] T036 PresetList widget in `app/lib/widgets/preset_list.dart`
- [ ] T037 ConnectionStatus widget in `app/lib/widgets/connection_status.dart`

## Phase 3.4: Integration
- [ ] T038 Connect BLEService to PWMController model
- [ ] T039 Connect StorageService to Preset model
- [ ] T040 Implement AppStateProvider with device connection state
- [ ] T041 Implement error handling and user feedback

## Phase 3.5: Polish
- [ ] T042 [P] Unit tests for PWMController model in `app/test/unit/pwm_controller_model_test.dart`
- [ ] T043 [P] Unit tests for Channel model in `app/test/unit/channel_model_test.dart`
- [ ] T044 [P] Unit tests for Preset model in `app/test/unit/preset_model_test.dart`
- [ ] T045 [P] Unit tests for ControlCommand models in `app/test/unit/control_command_models_test.dart`
- [ ] T046 Performance tests (<100ms response time)
- [ ] T047 [P] Update documentation in `README.md`
- [ ] T048 Run manual testing scenarios from quickstart.md
- [ ] T049 Remove code duplication and optimize
- [ ] T050 Final validation of all success criteria

## Dependencies
- Tests (T004-T019) before implementation (T020-T037)
- Model tasks (T020-T028) before service tasks (T029-T030)
- Service tasks (T029-T030) before provider tasks (T031)
- Provider tasks (T031) before screen tasks (T032-T034)
- Screen tasks (T032-T034) before widget tasks (T035-T037)
- Core implementation (T020-T037) before integration (T038-T041)
- Implementation and integration before polish (T042-T050)

## Parallel Example
```
# Launch model creation tasks together:
task "T020 PWMController model in app/lib/models/pwm_controller.dart"
task "T021 Channel model in app/lib/models/channel.dart"
task "T022 Preset model in app/lib/models/preset.dart"
task "T023 ControlCommand base class in app/lib/models/control_command/control_command.dart"
task "T024 SetCommand model in app/lib/models/control_command/set_command.dart"
task "T025 FadeCommand model in app/lib/models/control_command/fade_command.dart"
task "T026 BlinkCommand model in app/lib/models/control_command/blink_command.dart"
task "T027 StrobeCommand model in app/lib/models/control_command/strobe_command.dart"

# Launch contract test tasks together:
task "T004 Contract test for Device Management in app/test/unit/device_management_test.dart"
task "T005 Contract test for Channel Control - Read Channel States in app/test/unit/channel_control_read_test.dart"
task "T006 Contract test for Channel Control - Set Command in app/test/unit/channel_control_set_test.dart"
task "T007 Contract test for Channel Control - Fade Command in app/test/unit/channel_control_fade_test.dart"
task "T008 Contract test for Channel Control - Blink Command in app/test/unit/channel_control_blink_test.dart"
task "T009 Contract test for Channel Control - Strobe Command in app/test/unit/channel_control_strobe_test.dart"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing
- Commit after each task
- Avoid: vague tasks, same file conflicts

## Task Generation Rules
*Applied during main() execution*

1. **From Contracts**:
   - Each contract test scenario → contract test task [P]
   - Each API endpoint → implementation task
   
2. **From Data Model**:
   - Each entity → model creation task [P]
   - Relationships → service layer tasks
   
3. **From User Stories**:
   - Each scenario → integration test [P]
   - Quickstart scenarios → validation tasks
   
4. **Ordering**:
   - Setup → Tests → Models → Services → Screens → Widgets → Integration → Polish
   - Dependencies block parallel execution

## Validation Checklist
*GATE: Checked by main() before returning*

- [x] All contracts have corresponding tests
- [x] All entities have model tasks
- [x] All tests come before implementation
- [x] Parallel tasks truly independent
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task