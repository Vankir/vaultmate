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

**Increment 2 (FR-011, FR-012 — added to spec.md after Increment 1 shipped)**: Increment 1 (above)
was implemented and merged (PR #51) scoped to the flat list view only, with icon-only swipe
backgrounds — `/speckit-analyze` found this leaves FR-011 (swipe parity across list/grouped/
calendar views) and FR-012 (text caption on every swipe icon) with zero task coverage, and SC-003
("Plus/Minus no longer appear anywhere") unmet in grouped/calendar views. This increment extends
the existing `_wrapTaskCardWithSwipe` helper to also wrap tasks rendered inside `FileView`
(grouped) and `CalendarView` (calendar), and adds a caption `Text` under each swipe icon. No new
`TaskManager`/`InboxTasksCubit` methods are needed — this is a presentation-layer extension of
already-shipped logic.

**Increment 3 (FR-013–FR-017, SC-007 — User Story 4, discoverability)**: The first time the Today
or Inbox screen loads with at least one task, one task row plays a brief self-driven nudge
animation that partially reveals its swipe backgrounds, paired with a screen-specific `SnackBar`
explaining what swipe left/right do on that screen. This plays once per screen, ever (state
persisted via `SharedPreferences` through the existing `SettingsService`/`SettingsController`
layer, mirroring the existing `showOverdueOnly` flag), and is cancelled immediately if the user
performs a real swipe. No new dependency, no `TaskManager` change — this is additive UI state in
`InboxTasksCubit`/`SettingsController` plus a new small animated widget in `inbox_tasks.dart`.

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

**Increment 2 Scale/Scope**: No new business-logic methods. Widen `FileView.taskCards` and
`CalendarView.taskCards` from `List<TaskCard>` to `List<Widget>` (2 files) so their render lists
can hold swipe-wrapped rows, and add one new required field to each (`FileView.fileName`,
`CalendarView.scheduledDate`) replacing their own `taskCards[0].task...` reads at render time (see
`research.md` Increment 2 correction); wrap those rows at their existing construction sites in
`_createFileViews`/`_createCalendarViews` (`inbox_tasks.dart`) using the existing
`_wrapTaskCardWithSwipe`; add a caption `Text` to `_buildSwipeBackground`'s `Icon` (1 method, same
file). 4 total call sites gain swipe; 1 background-builder method gains a caption.

**Increment 3 Scale/Scope**: 2 new `SettingsService`/`SettingsController` boolean flags
(`swipeHintShownToday`, `swipeHintShownInbox`), 2 new `InboxTasksCubit` members (a `swipeHintShown`
getter, a `markSwipeHintShown()` setter — both delegating to `SettingsController`, mirroring the
existing `showOverdueOnly` pattern), 1 new small `StatefulWidget` in `inbox_tasks.dart` for the
nudge animation, reuse of the existing `ScaffoldMessenger`/`SnackBar` pattern already used for
`InboxTasksMessage` for the explanatory text. No new package dependency (`AnimationController` is
part of the Flutter SDK, `SharedPreferences` is already a dependency).

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

### Increment 2 Constitution Re-Check (FR-011, FR-012)

| Principle | Check | Status |
|---|---|---|
| I. Local-First & Privacy by Default | Purely presentational (widget type widening + a `Text` caption); no new I/O, no network. | PASS |
| II. Obsidian Markdown Compatibility | No parser/saver change; `Task` fields are untouched. | PASS |
| III. Test-First for Parsing & Business Logic | No `lib/src/core` change — nothing new to unit-test there; widget-level parity is covered by the existing widget-test limitation already on record (see `research.md` swipe-wrap decision and `tasks.md` T009/T013 — `TaskManager.loadTasks` hangs under `testWidgets()`), so parity/caption verification stays manual via `quickstart.md`, same as Increment 1's UI wiring. | PASS |
| IV. Branch & Release Discipline | Continues on `feature/001-task-swipe-actions` (or a follow-up branch off `main`, since Increment 1 already merged) per normal PR flow. | PASS |
| V. Consistent State Management & Simplicity | Reuses `_wrapTaskCardWithSwipe` as-is (no new gesture/state pattern); widens an existing widget's field type rather than adding a new one. | PASS |
| Platform & Distribution Constraints | Same `Dismissible`-only, pure-Dart approach as Increment 1 — inherently identical on iOS/Android; no widget-code-path (home screen widget) interaction, since this only changes which in-app views render the already-existing swipe gesture. | PASS |
| Development Workflow & Quality Gates | PR into `main`, CI (`run_tests`) must pass. | PASS |

No violations requiring the Complexity Tracking table.

### Increment 3 Constitution Re-Check (FR-013–FR-017, User Story 4)

| Principle | Check | Status |
|---|---|---|
| I. Local-First & Privacy by Default | The "hint shown" flag is a local `SharedPreferences` boolean, same mechanism as every other app setting (`SettingsService`); no network call, no analytics event. | PASS |
| II. Obsidian Markdown Compatibility | No `Task`/parser/saver interaction at all — this feature never reads or writes vault content. | PASS |
| III. Test-First for Parsing & Business Logic | No `lib/src/core` change. The new `InboxTasksCubit.swipeHintShown`/`markSwipeHintShown()` members are simple delegations (mirroring `showOverdueOnly`, which has no dedicated unit test either); the animation/SnackBar timing itself is a widget-level concern verified manually via `quickstart.md`, consistent with Increment 1/2's UI-wiring verification approach. | PASS |
| IV. Branch & Release Discipline | Same branch/PR flow as prior increments. | PASS |
| V. Consistent State Management & Simplicity | Reuses the existing `SettingsService`/`SettingsController` flag pattern (`showOverdueOnly`) verbatim for persistence, and the existing `ScaffoldMessenger`/`SnackBar` pattern (`InboxTasksMessage`) for the message — no new state-management approach, no new package. | PASS |
| Platform & Distribution Constraints | `AnimationController`/`SnackBar`/`SharedPreferences` are all cross-platform Flutter SDK primitives; no platform-exclusive code; no interaction with the home-screen widget code paths (this never touches task data). | PASS |
| Development Workflow & Quality Gates | PR into `main`, CI (`run_tests`) must pass. | PASS |

No violations requiring the Complexity Tracking table.

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
│   │                                   # [Increment 2] also wrap TaskCards inside _createFileViews /
│   │                                   # _createCalendarViews via _wrapTaskCardWithSwipe; add caption
│   │                                   # Text to _buildSwipeBackground
│   │                                   # [Increment 3] new _SwipeHintRow StatefulWidget wraps the
│   │                                   # hint-target row's swipe wrapper; shows explanatory SnackBar
│   ├── file_view.dart                  # [Increment 2] taskCards: List<TaskCard> → List<Widget>
│   ├── calendar_view.dart              # [Increment 2] taskCards: List<TaskCard> → List<Widget>
│   └── cubit/
│       └── inbox_tasks_cubit.dart     # add postponeToTomorrowPressed, deleteTaskPressed
│                                       # [Increment 3] add swipeHintShown getter, markSwipeHintShown()
├── screens/settings/
│   ├── settings_service.dart          # [Increment 3] add swipeHintShownToday/Inbox SharedPreferences keys
│   └── settings_controller.dart       # [Increment 3] add cached bool fields + get/update, mirroring showOverdueOnly
└── widgets/
    └── task_card.dart                 # no gesture logic here; Dismissible wraps it in inbox_tasks.dart

test/
├── task_manager_unit_test.dart        # unit tests for scheduleForTomorrow, deleteTask
└── src/screens/inbox_tasks/
    └── swipe_actions_test.dart        # new: widget tests for the 4 swipe behaviors + button removal
```

**Structure Decision**: Single existing Flutter project (`lib/src/core` / `screens` / `widgets`,
mirrored under `test/`). No new module, package, or project boundary — this is additive logic
inside the existing `InboxTasks` screen and `TaskManager`/`InboxTasksCubit` layers. Increment 2
touches two additional existing files (`file_view.dart`, `calendar_view.dart`) but adds no new
file, module, or dependency. Increment 3 adds one small private widget class inside the existing
`inbox_tasks.dart` (no new file) and extends the existing `screens/settings` persistence layer with
two more boolean flags, following the same pattern as every other per-user-preference flag already
there.
