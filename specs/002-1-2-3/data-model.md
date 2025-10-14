# Data Model — Optimized Device Connection Management

## Entities

### SavedController
- **Identifier**: Stable BLE device identifier (MAC address or BLE UUID) — unique per saved entry.
- **Alias**: User-defined label (1–32 characters, unique per user).
- **LastConnectedAt**: Timestamp of most recent successful session (nullable).
- **ConnectionStatus**: Enum (`connected`, `connecting`, `disconnected`, `unavailable`).
- **RetryPolicy**: Struct containing `maxAttempts`, `attemptCount`, `backoffSeconds`, `lastAttemptAt`.
- **DeviceCapabilities**: Optional metadata (supported channels, firmware version) for UI hints.
- **Notes**: Optional free-form text (<=140 characters) for user reminders.

**Validation Rules**
- Alias must be non-empty, trimmed, and unique within the saved list.
- Identifier is immutable once stored; attempts to save duplicate identifiers trigger replace-or-cancel flow.
- RetryPolicy.attemptCount resets to zero after a successful connection.

### ConnectionStatusRecord
- **SavedControllerId**: Foreign key referencing `SavedController.identifier`.
- **ScanState**: Enum (`idle`, `scanning`, `waitingRetry`).
- **LastScanAt**: Timestamp of last scan initiation.
- **LastResult**: Enum (`found`, `notFound`, `error`).
- **ErrorReason**: Optional descriptive code/message (`bluetooth_off`, `permission_denied`, `timeout`, `unknown`).
- **NextRetryAt**: Timestamp when the next scan should begin.

**Relationships**
- One-to-one with `SavedController` (mirrors current foreground status).
- Aggregated by the device management provider to display multi-device progress.

## State Transitions

### ConnectionStatus Lifecycle
1. `disconnected` → `connecting` when a scan identifies the device and connection initiation starts.
2. `connecting` → `connected` upon handshake completion; reset retry counters.
3. `connecting` → `unavailable` if retries exceed `RetryPolicy.maxAttempts` or `LastResult` = `error`.
4. `unavailable` → `disconnected` when the user manually retries or the device reappears after a cool-off.
5. `connected` → `disconnected` when the link drops unexpectedly; increments retry counters and triggers scan loop.

### ScanState Lifecycle
1. `idle` → `scanning` whenever the app enters foreground with disconnects pending.
2. `scanning` → `waitingRetry` if device not found; schedule `NextRetryAt` with backoff.
3. `waitingRetry` → `scanning` once current time ≥ `NextRetryAt`.
4. Any state → `idle` when all saved controllers are `connected` or user stops scanning.

## Derived Aggregates

- **ConnectionDashboardSummary**
  - `totalSaved`: count of `SavedController`.
  - `connectedCount`: controllers where `ConnectionStatus = connected`.
  - `recoveringCount`: controllers in `connecting` or `waitingRetry`.
  - `unavailableCount`: controllers flagged `unavailable`.
  - Used to drive UI badges and determine when scanning can pause.

## Persistence Notes

- Saved controllers persist via local storage (keyed by identifier). Records serialize to JSON arrays for `shared_preferences`.
- Connection status records are ephemeral, kept in-memory via providers, and reconstructed on app launch by replaying saved controllers with default states.
