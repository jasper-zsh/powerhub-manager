# Implementation Plan: Switch Orchestration Experience Revamp

**Branch**: `003-3-ifttt-if` | **Date**: 2025-10-14 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/003-3-ifttt-if/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Reimagine the PowerHub UI into three focused screens: switch orchestration as the default hub, saved device management, and single-device control. Deliver a toggle-based automation builder with state-specific command bundles, multi-controller actions, and single-level if/else branching while preserving real-time manual control options.

## Technical Context

**Language/Version**: Dart (Flutter 3.x)  
**Primary Dependencies**: `flutter_blue_plus`, `provider`, `shared_preferences`  
**Storage**: Local persistence via `shared_preferences` plus execution logs persisted in-device  
**Testing**: Flutter widget and integration tests with `flutter_test` and mock BLE layers  
**Target Platform**: Mobile (Android and iOS)  
**Project Type**: Flutter mobile application  
**Performance Goals**: Toggle activation executes commands within 1 second of user action; UI renders new orchestration components without jank on mid-range devices  
**Constraints**: BLE operations in foreground only; automation editor must remain usable offline with deferred publish; limit orchestration to ≤5 toggles per scene to maintain clarity  
**Scale/Scope**: Up to 5 controllers managed concurrently; 3 primary screens with supporting dialogs/modals

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- Constitution file remains a placeholder with no enforceable principles; proceed under documented assumption of compliance and revisit once governance updates content.

## Project Structure

### Documentation (this feature)

```
specs/003-3-ifttt-if/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
└── tasks.md
```

### Source Code (repository root)

```
app/
├── lib/
│   ├── main.dart
│   ├── models/
│   ├── providers/
│   ├── screens/
│   ├── services/
│   └── widgets/
└── test/
    ├── unit/
    ├── integration/
    └── widget_test.dart
```

**Structure Decision**: Continue extending existing Flutter app modules; add orchestration-specific models, providers, screens, and widgets under `app/lib`, with mirrored tests in `app/test`.

## Complexity Tracking

*No constitution violations identified; section intentionally left empty.*
