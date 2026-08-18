# Implementation Plan: Task List Swipe Actions

**Branch**: `feature/001-task-swipe-actions` | **Date**: 2026-08-18 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-task-swipe-actions/spec.md`

## Summary

Replace the Inbox "Plus" and Today "Minus" icon buttons on the shared `InboxTasks` screen with
swipe gestures on each task row, using Flutter's built-in `Dismissible` widget (no new
dependency): swipe-left on Today reschedules to tomorrow, swipe-right on Today clears the
scheduled date back to Inbox, swipe-left on Inbox schedules for today, swipe-right on Inbox asks
for confirmation and then permanently deletes the task. Two new `TaskManager` methods
(`scheduleForTomorrow`, `deleteTask`) are added alongside the existing `scheduleForToday` /
`removeFromToday`, wired through two new `InboxTasksCubit` methods, following the exact pattern
already used for the buttons being replaced.

## Technical Context

**Language/Version**: Dart (SDK `>=3.0.0`), Flutter 3.35.1 / Dart 3.9.0 (per CI in
`.github/workflows/main.yml`, documented in `RELEASE_PROCESS.md`)

**Primary Dependencies**: Flutter SDK only — `Dismissible` (built-in widget) for the swipe
gesture; `flutter_bloc`/`bloc` for the existing `InboxTasksCubit` pattern. No new third-party
package is added.

**Storage**: Local markdown files in the user's Obsidian vault, read/written via the existing
`TaskManager` / `TaskSaver` / `TasksFileStorage` layers. N/A for a database.

**Testing**: `flutter_test` + `mockito` (existing dev dependencies): unit tests for the two new
`TaskManager` methods (mirroring `test/task_manager_unit_test.dart`), widget tests for the swipe
gestures and button removal (mirroring `test/src/screens/inbox_tasks/main_messages_test.dart`).

**Target Platform**: iOS and Android via Flutter (single codebase, no platform-channel code
required — `Dismissible` and the cubit logic are pure Dart/Flutter).

**Project Type**: Mobile app (existing single Flutter project — `lib/src/{core,screens,widgets}`).

**Performance Goals**: Swipe gesture tracks the user's finger at native frame rate (Flutter
default); the resulting task update (local file write) completes with no visible jank — same
budget as the existing Plus/Minus button taps they replace.

**Constraints**: Must remain fully offline/local-first (no network call introduced); must not
introduce a new runtime dependency without justification (Constitution Principle V); must not
change the on-disk markdown format beyond the same fields the existing Plus/Minus actions already
change (Constitution Principle II).

**Scale/Scope**: One shared screen (`InboxTasks`, driven by its existing `today` flag), 4 swipe
behaviors, 2 new `TaskManager` methods, 2 new `InboxTasksCubit` methods, removal of 2 buttons.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| I. Local-First & Privacy by Default | All new methods write only to the local vault via the existing `TaskManager`/`TaskSaver` path; no analytics/telemetry/network calls introduced. | PASS |
| II. Obsidian Markdown Compatibility | Reschedule-to-tomorrow reuses the exact field (`task.scheduled`) and save path as the existing, already-compatible `scheduleForToday`/`removeFromToday`. Delete must remove only the task's own markdown line, tested against the same fixtures used for existing parser/saver compatibility tests. | PASS (delete path needs its own fixture-based test — tracked in Phase 1 data model / tasks) |
| III. Test-First for Parsing & Business Logic | New `TaskManager` methods (`scheduleForTomorrow`, `deleteTask`) require unit tests before merge, plus a regression test for the due-today guard reused on swipe-right/Today. | PASS (enforced at task-generation/implementation phase) |
| IV. Branch & Release Discipline | Work happens on `feature/001-task-swipe-actions`, cut from `main` (this repo's actual working branch, matching current practice), merged via PR. | PASS |
| V. Consistent State Management & Simplicity | Reuses the existing `InboxTasksCubit`/`ChangeNotifier` `TaskManager` pattern; uses Flutter's built-in `Dismissible` instead of adding a third-party swipe-action package (e.g. `flutter_slidable`), since the feature needs direct swipe-to-commit semantics, not a reveal-then-tap action panel. | PASS |
| Platform & Distribution Constraints | Pure Dart/Flutter implementation is inherently identical on iOS and Android; no platform-exclusive code. Because this changes task read/write logic, the home-screen widget code paths (`android/app/.../TasksWidget`, iOS widget) must be checked for any assumption that scheduled-date changes and deletions only ever happen through the existing button actions. | PASS (verify widget refresh path in Phase 1 / tasks; `TaskManager.saveTasks` already calls `notifyListeners()`, which is what the existing buttons rely on for widget sync, so new methods routed through `saveTask`/`saveTasks` inherit this for free) |
| Development Workflow & Quality Gates | PR into `main`, CI (`run_tests`) must pass. | PASS |

No violations requiring the Complexity Tracking table.

**Post-Design Re-Check** (after Phase 1 — `research.md`, `data-model.md`, `contracts/`,
`quickstart.md`): No new entity, dependency, or architectural layer was introduced during design.
`deleteTask` reuses the existing per-file save/rewrite path (`data-model.md`); widget sync is
inherited "for free" via the existing `notifyListeners()` call already present in
`TaskManager.saveTasks`. All gates above still PASS; no violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-task-swipe-actions/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md         # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/src/
├── core/tasks/
│   ├── task_manager.dart              # add scheduleForTomorrow(Task), deleteTask(Task)
│   └── savers/
│       ├── task_saver.dart            # verify/extend to support removing a task's line
│       └── task_note_saver.dart       # verify/extend to support removing a task's line
├── screens/inbox_tasks/
│   ├── inbox_tasks.dart               # wrap TaskCard in Dismissible, remove Plus/Minus buttons
│   └── cubit/
│       └── inbox_tasks_cubit.dart     # add postponeToTomorrowPressed, deleteTaskPressed
└── widgets/
    └── task_card.dart                 # no gesture logic here; Dismissible wraps it in inbox_tasks.dart

test/
├── task_manager_unit_test.dart        # unit tests for scheduleForTomorrow, deleteTask
└── src/screens/inbox_tasks/
    └── swipe_actions_test.dart        # new: widget tests for the 4 swipe behaviors + button removal
```

**Structure Decision**: Single existing Flutter project (`lib/src/core` / `screens` / `widgets`,
mirrored under `test/`). No new module, package, or project boundary — this is additive logic
inside the existing `InboxTasks` screen and `TaskManager`/`InboxTasksCubit` layers.
