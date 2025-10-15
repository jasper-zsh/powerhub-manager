# Research Log — Switch Orchestration Experience Revamp

## App Architecture Guardrails

- **Decision**: Continue using the existing Flutter + Provider stack for state management and navigation (three primary routes/tabs).
- **Rationale**: Current codebase already uses Provider and Flutter navigation patterns; adding Riverpod or BLoC would increase complexity without clear benefit.
- **Alternatives considered**: Riverpod for more granular state control (rejected: migration overhead); Redux-style state (rejected: heavy for mobile).

## Conditional Logic Modeling

- **Decision**: Represent single-level if/else using a `ConditionalRule` entity tied to a toggle, referencing two `CommandBundle` ids (true/false) with optional condition expressions limited to switch state checks.
- **Rationale**: Matches spec requirement for simple branching while keeping data model and UX manageable for mobile editing.
- **Alternatives considered**: Depth-n tree structure (rejected: violates “simple IFTTT” constraint); rule scripting (rejected: non-intuitive for target users).

## Execution Logging Scope

- **Decision**: Store execution logs locally with an upper limit (e.g., 100 entries) and provide read interfaces for analytics. Consider backend synchronization later.
- **Rationale**: Allows immediate post-run review without introducing new backend dependencies.
- **Alternatives considered**: Cloud sync (rejected: out of scope), in-memory only (rejected: loses history after restart).

## Navigation & Routing Plan

- **Decision**: Implement a three-tab bottom navigation scaffold with tabs ordered as Orchestration (default), Devices, Control; leverage existing `AppStateProvider` for connection state while introducing a lightweight navigation coordinator.
- **Rationale**: Matches feature requirement for three dedicated screens while minimising rewrite of current navigation; bottom nav ensures quick switching between workflows.
- **Alternatives considered**: Drawer-based navigation (rejected: slower access); nested navigator stacks per tab (deferred unless deeper subflows required).
