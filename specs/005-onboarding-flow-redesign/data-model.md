# Data Model: Onboarding Flow Redesign

This feature has no database/schema; "data model" here means the persisted settings state and the in-memory flow state that govern the 3-screen sequence. No new `SharedPreferences` keys are introduced — existing keys are reused with tightened meaning (see research.md §2).

## Entities

### Onboarding Progress *(spec Key Entity)*

Represents whether a user has completed the unified 3-screen sequence. Replaces the current two independent states with one.

| Field | Type | Source | Notes |
|---|---|---|---|
| `onboardingComplete` | `bool` | `SharedPreferences` key `onboarding_complete` (existing, `settings_service.dart:33`) | `true` only once screen 3 finishes with a valid folder. Reused key; meaning tightened, not replaced. |
| `vaultDirectory` | `String?` | `SharedPreferences` key `vault_directory` (existing, `settings_service.dart:17`) | Set by screen 3 on completion; unchanged type/semantics from today's `Init` screen. |
| `isComplete` (derived, not persisted) | `bool` | computed as `onboardingComplete && vaultDirectory != null` | The single gate `app.dart` checks to decide whether to show the onboarding flow. |

**Validation rules**:
- The flow is only ever marked complete (`onboardingComplete = true`) after `vaultDirectory` is non-null — screen 3's folder selection MUST happen first, or already exist from a prior session, before completion is recorded (FR-005, FR-008).

**State transitions** (in-memory `OnboardingFlowCubit` state; only the final transition persists):

```
NotStarted
  → OnWelcome (screen 1)          [always entered first when isComplete == false]
  → OnTaskFormat (screen 2)       [Next from screen 1]
  → OnFolderSelection (screen 3)  [Next from screen 2, choice already saved per feature 004]
  → Complete                      [valid folder confirmed on screen 3 → persists onboardingComplete=true, vaultDirectory=<path>]
```

- Back-navigation (FR-007): `OnFolderSelection → OnTaskFormat → OnWelcome` is allowed and does not clear previously made choices (task format stays saved per 004; any partially-selected folder on screen 3 is simply not yet confirmed).
- No partial-progress persistence: if the app is closed between `OnWelcome` and `Complete`, the in-memory step position is lost; on relaunch `isComplete` is still `false`, so the flow restarts at `OnWelcome` (spec Edge Cases, Assumptions).

### Default Task Format Preference *(spec Key Entity)*

Represents which task format(s) the app should default new tasks to. Chosen on screen 2, changeable later in Settings (FR-013).

| Field | Type | Source | Notes |
|---|---|---|---|
| `taskFormatPreference` | `String` enum-like: `"inline"` \| `"taskNote"` \| `"both"` | New `SharedPreferences` key `task_format_preference` | Follows the existing string-flag pattern used by `dataViewDefaultMarkdownFormat` (`settings_service.dart:77-92`). Defaults to `"inline"` if unset (FR-016). |

**Validation rules**:
- Always one of the three values; no other value is ever written (screen 2 and the Settings entry both present a closed choice, per FR-004/FR-013).
- Changing this value MUST NOT alter already-saved tasks (FR-017) — it is read only at the moment a *new* task is created (FR-018).

**Consumption**: `TaskEditorCubit._taskNoteFormat` (`lib/src/screens/task_editor/cubit/task_editor_cubit.dart:20`) is initialized from this preference for new tasks only (`isNewTask` gate, `task_editor_cubit.dart:32,75`): `"inline"` → `false`, `"taskNote"` → `true`, `"both"` → `false` with the toggle still user-editable (FR-014/FR-015). Every task-creation entry point in the app already constructs a `TaskEditorCubit` (confirmed in plan.md), so this single read point satisfies FR-014's "every entry point" requirement with no duplication.

### Vault Directory *(existing setting — unchanged)*

Already defined by `SettingsService`/`SettingsController` (`vaultDirectory()`/`updateVaultDirectory()`). Screen 3 writes to it through the same API `InitCubit` uses today; no shape change.

## Relationships

```
Onboarding Progress ──depends on──> Default Task Format Preference (set on screen 2, editable later in Settings)
Onboarding Progress ──depends on──> Vault Directory (screen 3, relocated from Init/InitCubit)
Default Task Format Preference ──consumed by──> TaskEditorCubit (every task-creation entry point)
```

Onboarding Progress and Default Task Format Preference are both newly modeled by this feature; Vault Directory is consumed, not owned (its shape is unchanged from today's `Init`/`InitCubit`).
