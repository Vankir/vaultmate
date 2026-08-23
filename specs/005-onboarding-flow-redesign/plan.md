# Implementation Plan: Onboarding Flow Redesign

**Branch**: `005-onboarding-flow-redesign` | **Date**: 2026-08-23 | **Spec**: [specs/005-onboarding-flow-redesign/spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-onboarding-flow-redesign/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Replace VaultMate's two disconnected first-run gates — the multi-page `introduction_screen` carousel (`lib/src/screens/introduction/onboarding.dart`) and the standalone vault-folder screen (`lib/src/screens/init/init.dart`) — with a single, non-skippable 3-screen sequence: (1) a condensed, single-screen feature list, (2) a default task-format choice (Inline tasks / TaskNotes / Both), and (3) vault folder selection, preserving today's auto-detect/manual-pick capability. Onboarding completion collapses from two independent boolean gates (`onboarding_complete`, `vaultDirectory == null`) into one gate satisfied only once a folder is chosen on screen 3. The Settings "show onboarding again" toggle is removed. The saved task-format preference also becomes a persisted setting (editable later in Settings, independent of onboarding) that `TaskEditorCubit` — the single choke point every task-creation entry point in the app already routes through — reads to pre-select a new task's format, while leaving already-existing tasks' formats untouched on edit/resave.

*(This plan originally referenced a separate feature, `004-task-format-onboarding`, for the task-format behavior. That feature has since been merged into this spec — see spec.md's "Input" note — because it was never more than this feature's screen 2 plus its downstream task-creation effect. All task-format work below is native to this plan; there is no longer a cross-feature dependency.)*

## Technical Context

**Language/Version**: Dart (SDK `>=3.0.0`), Flutter

**Primary Dependencies**: `flutter_bloc`/`bloc` (Cubit state management, matching `InitCubit`/`TaskEditorCubit` precedent), `shared_preferences` (settings persistence), `filesystem_picker`/`file_picker`/`external_path`/`permission_handler` (existing vault folder scan & manual selection), `provider`. The `introduction_screen` package (used only by the file this feature replaces) is a candidate for removal — confirmed in research.md. No new packages required for the task-format preference — it reuses `shared_preferences` and the existing `TaskEditorCubit`/`TaskType` (`lib/src/core/tasks/task_source.dart`) infrastructure.

**Storage**: `SharedPreferences` for onboarding/settings state (no schema/database); the vault itself is plain markdown files on the local filesystem (unaffected by this feature).

**Testing**: `flutter_test` (widget tests for the 3 screens, Cubit/bloc unit tests for the new single onboarding-completion gate), per Constitution III.

**Target Platform**: iOS + Android (Constitution "Platform & Distribution Constraints" — parity required). Vault auto-detection is Android-only today (`InitCubit.startScanning`, `lib/src/screens/init/cubit/init_cubit.dart:24-27`); this is a pre-existing, already-disclosed platform asymmetry that screen 3 preserves unchanged, not a new one introduced by this feature.

**Project Type**: Mobile app (single Flutter project; `lib/src/{core,screens,widgets}`), no backend/API component.

**Performance Goals**: No system throughput targets; the only timing target is user-paced (SC-001: full sequence completable in under 60s), not a technical performance budget.

**Constraints**: Local-first / no telemetry (Constitution I) — the new completion-gate logic must not add any tracking. Existing users who already have `onboardingComplete == true` and a `vaultDirectory` set must never see the new sequence (FR-012). GPLv3-license-compatible dependencies only. Changing the task-format preference must never retroactively touch already-saved tasks (FR-017); editing an existing task must never apply the preference to it (FR-018).

**Scale/Scope**: 3 screens replacing 2 existing screens/files; one new/consolidated completion-gate check in `lib/app.dart`; one new persisted preference (task format) read at the single point (`TaskEditorCubit`) all task-creation entry points already share; no new backend, one new `SharedPreferences` key beyond what exists today.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Local-First & Privacy by Default | PASS | No new data leaves the device; no analytics/telemetry added. The onboarding-completion state stays in local `SharedPreferences`, as today. |
| II. Obsidian Markdown Compatibility | PASS | Screen 2 introduces a *choice* of which existing, already-compatible serializer (`TaskParser`/inline markdown vs. `TaskNoteSaver`) a new task defaults to — it does not change either format's on-disk representation. `TaskType.taskNote`/`TaskType.markdown` (`lib/src/core/tasks/task_source.dart:5`) are reused unchanged; no parser/serializer code is modified. |
| III. Test-First for Parsing & Business Logic (NON-NEGOTIABLE) | PASS (action required) | The onboarding-completion logic is not under `lib/src/core`, but it is real business logic (replacing two independent boolean gates with one, plus the task-format default pre-selection in `TaskEditorCubit`). Plan commits to Cubit/widget test coverage for the new gate, the 3-screen navigation flow, and the default-format pre-selection logic before merge. |
| IV. Branch & Release Discipline | PASS (with note) | Constitution describes `develop` as the integration branch; this repo currently has no `develop` branch — every existing feature branch (`002-*`, `003-*`, and this `005-*`) is cut from `main` via the Spec Kit branch-creation hook, consistent with actual current practice. (The formerly-separate `004-task-format-onboarding` branch/spec has been merged into this one — see spec.md.) This is a pre-existing, repo-wide discrepancy between the constitution text and practice, not something introduced by this plan; flagged here for visibility, not treated as a blocking violation. |
| V. Consistent State Management & Simplicity | PASS | Reuses the existing Cubit/`flutter_bloc` pattern (matching `InitCubit`); no new state-management paradigm. The `introduction_screen` dependency becomes unused once the carousel is replaced — removing it (rather than leaving dead code) fits this principle's "no unjustified dependency" guidance; confirmed as a research decision, executed as a task. |
| Platform & Distribution Constraints | PASS (with existing exception) | iOS/Android parity preserved: all 3 screens render on both platforms. The pre-existing Android-only vault auto-scan is unchanged by this feature and was already an explicit fallback (manual selection) on iOS, matching the constitution's "called out explicitly, with fallback" allowance for platform-exclusive capabilities. |

No unresolved violations requiring Complexity Tracking.

**Post-design re-check** (after Phase 0/1, see research.md and data-model.md): No new violations introduced. The design removes a dependency (`introduction_screen`) rather than adding one, reuses the existing `SharedPreferences` keys and Cubit pattern, and adds test coverage per Constitution III. Table above stands unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/005-onboarding-flow-redesign/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

No `contracts/` directory: this feature has no external API, CLI, or service interface — it is an in-app UI flow with no boundary consumed by another system.

### Source Code (repository root)

Single Flutter mobile app (Constitution "Consistent State Management & Simplicity" — fit the existing `lib/src` structure, no new top-level layout):

```text
lib/
├── app.dart                                  # _buildHomeWidget: today's two-gate check
│                                              #   (onboardingComplete, then vaultDirectory==null)
│                                              #   collapses into one call into the new flow
├── src/
│   ├── screens/
│   │   ├── onboarding/                       # NEW — replaces introduction/ and absorbs init/
│   │   │   ├── onboarding_flow.dart          #   hosts the 3-screen PageView/stepper + Cubit
│   │   │   ├── cubit/
│   │   │   │   ├── onboarding_flow_cubit.dart
│   │   │   │   └── onboarding_flow_state.dart
│   │   │   ├── welcome_screen.dart           #   screen 1 (FR-002)
│   │   │   ├── task_format_screen.dart       #   screen 2 (FR-003/FR-004): explanation + choice UI
│   │   │   └── folder_selection_screen.dart  #   screen 3 (FR-006/FR-007), carries over init/'s scan+pick logic
│   │   ├── introduction/                     # REMOVED (onboarding.dart) — superseded by onboarding/
│   │   ├── init/                             # REMOVED (init.dart, cubit/init_cubit.dart) — logic
│   │   │                                     #   relocates into onboarding/folder_selection_screen.dart
│   │   ├── settings/
│   │   │   ├── settings_service.dart         # + task_format_preference key (FR-005/FR-013);
│   │   │   │                                 #   onboarding_complete key semantics updated (FR-010)
│   │   │   ├── settings_controller.dart      # same, + exposes the format preference to settings_view
│   │   │   └── settings_view.dart            # "Show on-boarding screen" toggle removed (FR-011);
│   │   │                                     #   new "default task format" entry added (FR-013)
│   │   └── task_editor/
│   │       └── cubit/
│   │           └── task_editor_cubit.dart    # `_taskNoteFormat` init reads the saved preference
│   │                                         #   instead of hardcoded `false` (FR-014/FR-016); every
│   │                                         #   task-creation entry point already routes through here
│   └── core/                                 # unchanged by this feature (no parser/serializer edits)
└── ...

test/
└── src/
    └── screens/
        └── onboarding/                       # NEW — widget tests per screen + Cubit unit tests
            ├── onboarding_flow_cubit_test.dart
            ├── welcome_screen_test.dart
            ├── task_format_screen_test.dart
            └── folder_selection_screen_test.dart
```

**Structure Decision**: Extend the existing single-Flutter-app layout with one new `lib/src/screens/onboarding/` module that supersedes both `lib/src/screens/introduction/` and `lib/src/screens/init/`. This keeps the established `core`/`screens`/`widgets` split and Cubit-per-screen-group convention (mirrors `TaskEditorCubit`, `InitCubit`) rather than introducing a new pattern. `init/`'s vault-scan/pick logic is relocated, not rewritten, into `folder_selection_screen.dart`'s Cubit, preserving FR-006's "keep existing capability" requirement.

Confirmed via `grep -rln "TaskEditorCubit("` across `lib/`: every task-creation UI (`app.dart`'s task-editor route, `inbox_tasks.dart`, and the AI chat bubble at `obsi_chat_bubble.dart`) already constructs a `TaskEditorCubit`. FR-014 ("consistent across every entry point") is therefore satisfied by one change in `TaskEditorCubit`'s `_taskNoteFormat` initialization (`task_editor_cubit.dart:20`, currently hardcoded `false`) — no per-entry-point duplication needed. FR-018 (editing an existing task preserves its format) is already structurally guaranteed: the format toggle is gated by `isNewTask` (`task_editor_cubit.dart:32,75`) and only affects new tasks, so this plan only needs a regression test confirming that behavior, not new code.

## Complexity Tracking

*No Constitution Check violations — this section is not applicable.*
