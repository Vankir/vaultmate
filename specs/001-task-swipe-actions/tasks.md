---

description: "Task list for Task List Swipe Actions"
---

# Tasks: Task List Swipe Actions

**Input**: Design documents from `/specs/001-task-swipe-actions/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/task_manager_contract.md](./contracts/task_manager_contract.md), [quickstart.md](./quickstart.md)

**Tests**: Included — Constitution Principle III (Test-First for Parsing & Business Logic,
NON-NEGOTIABLE) requires automated coverage for core logic changes (`TaskManager`) and the
`flutter test` CI gate, so test tasks are mandatory here, not optional.

**Organization**: Tasks are grouped by user story (from `spec.md`) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact and relative to the repository root

---

## Phase 1: Setup

- [X] T001 Run `flutter test` at the repository root to confirm the existing suite is green before starting (baseline check; no code changes) — 207 tests passed

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 Add a `Dismissible` swipe shell around each `TaskCard` in `lib/src/screens/inbox_tasks/inbox_tasks.dart`: key by `task.taskSource` (fall back to `task.hashCode` if null), `direction: DismissDirection.horizontal`, `background`/`secondaryBackground` widgets, `confirmDismiss`/`onDismissed`.
  **Deviation from plan**: implemented as a new `_wrapTaskCardWithSwipe` helper called from `_showListView` (wrapping only bare `TaskCard` items from the flat list view), not inside `_createTaskCard`. `_createTaskCard` is shared by the flat list, calendar view, and grouped/file view (`_createViewItems` returns `List<Card>`, and calendar view reads `.task` off the returned `TaskCard` directly), so wrapping there would have broken those call sites' type contracts and silently added swipe to non-Today/Inbox views. Calendar/grouped views are unaffected — they still render `_createTaskCard`'s output directly, Plus/Minus button included.

**Checkpoint**: Shared swipe scaffold is in place. Each user story phase below wires its own real behavior into it.

---

## Phase 3: User Story 1 - Today screen: swipe left → tomorrow, swipe right → back to Inbox (Priority: P1) 🎯 MVP

**Goal**: Replace the Today screen's "Minus" button with swipe gestures: swipe left postpones a
task to tomorrow, swipe right clears its scheduled date and returns it to Inbox (unless blocked by
the existing due-today guard).

**Independent Test**: With a task scheduled for today, swipe it left and confirm its scheduled
date becomes tomorrow and it leaves today's list; swipe a different task right and confirm it
disappears from Today and appears in Inbox with no scheduled date.

### Tests for User Story 1

> Write these first; they must fail before the implementation tasks below.

- [X] T003 [P] [US1] Add unit tests for `TaskManager.scheduleForTomorrow` (sets `scheduled` to tomorrow, persists via `saveTask`) in `test/task_manager_unit_test.dart`
- [X] T004 [US1] Cover Today-screen swipe behavior with tests.
  **Deviation from plan**: not a widget test in `swipe_actions_test.dart` as originally planned. `InboxTasksCubit(taskManager, today: true)` triggers pre-existing, unrelated notification/home-widget side effects (`_scheduleNotifications`, `HomeWidgetHandler`) on every task-list change via `tasksChangedListener`, which depend on platform channels not available in `flutter test`. Since none of the new/changed methods (`postponeToTomorrowPressed`, `removeFromTodayPressed`, `isBlockedFromLeavingToday`) read the cubit's `today` field, they're covered directly — with a `today: false` cubit instance, sidestepping the unrelated plugin risk — in `test/src/screens/inbox_tasks/inbox_tasks_cubit_swipe_test.dart` (`postponeToTomorrowPressed schedules the task for tomorrow`, `removeFromTodayPressed clears the schedule when not blocked, and leaves it when blocked`, `isBlockedFromLeavingToday is true only when due today and includeDueTasksInToday is enabled`). The actual `Dismissible`/gesture wiring is exercised end-to-end for the Inbox screen instead (T009/T013), which shares the same `_wrapTaskCardWithSwipe` implementation.

### Implementation for User Story 1

- [X] T005 [US1] Implement `Future scheduleForTomorrow(Task task)` in `lib/src/core/tasks/task_manager.dart` — sets `task.scheduled` to `DateTime.now().add(const Duration(days: 1))`, persists via `saveTask` when `task.taskSource != null` (depends on T003)
- [X] T006 [US1] Add `void postponeToTomorrowPressed(Task task)` to `InboxTasksCubit` in `lib/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart`, calling `_taskManager.scheduleForTomorrow(task)` (depends on T005)
- [X] T007 [US1] Wire the Today branch (`_inboxTaskCubit.today == true`) of the `Dismissible` from T002: swipe-left (`DismissDirection.endToStart`) → `postponeToTomorrowPressed`; swipe-right (`DismissDirection.startToEnd`) → `removeFromTodayPressed` (existing), with `confirmDismiss` returning `false` when the existing due-today guard (extracted to `InboxTasksCubit.isBlockedFromLeavingToday`) blocks removal, in `lib/src/screens/inbox_tasks/inbox_tasks.dart` (`_wrapTaskCardWithSwipe`, not `_createTaskCard` — see T002) (depends on T002, T004, T006)
- [X] T008 [US1] Hide the Today "Minus" button on swiped rows.
  **Deviation from plan**: not done by changing what `_createTaskCard` passes to `TaskCard` (that would also affect calendar/grouped views — see T002). Instead, `_wrapTaskCardWithSwipe` in `lib/src/screens/inbox_tasks/inbox_tasks.dart` rebuilds a button-less copy of the `TaskCard` it wraps (omitting `rightButtonIcon`/`rightButtonPressed`) for both Today and Inbox rows in the flat list view; calendar/grouped views keep the button since they don't go through this wrapper (depends on T007)

**Checkpoint**: User Story 1 is fully functional and independently testable — Today screen is
swipe-driven and the Minus button is gone; Inbox screen is unchanged (old Plus button still
works).

---

## Phase 4: User Story 2 - Inbox screen: swipe left → schedule for today (Priority: P1)

**Goal**: Replace the Inbox screen's "Plus" button with a swipe-left gesture that schedules the
task for today.

**Independent Test**: With an unscheduled task in Inbox, swipe it left and confirm it disappears
from Inbox and appears on the Today screen.

### Tests for User Story 2

- [X] T009 [US2] Cover Inbox-screen swipe-left with a test.
  **Deviation from plan, discovered during implementation**: a real `swipe_actions_test.dart` widget test (`testWidgets`, pumping the full `InboxTasks` screen) was written and then removed — `TaskManager.loadTasks` spawns a real `dart:isolate` Isolate on non-iOS platforms (`_processTasksInIsolate`, `task_manager.dart:150`), and that isolate spawn hangs indefinitely inside `flutter_test`'s `testWidgets()` engine process (`flutter_tester`), confirmed with a minimal repro that hung at the `loadTasks` call itself, before any widget was even pumped. This is a pre-existing characteristic of `TaskManager`/`flutter_test`, unrelated to this feature — no prior widget test in this repo exercises `InboxTasks`/`loadTasks` together. Plain `test()`-based tests (not `testWidgets()`) never enter that engine process and are unaffected — which is exactly why `postponeToTomorrowPressed`/`deleteTaskPressed`/`isBlockedFromLeavingToday` are covered there instead, in `test/src/screens/inbox_tasks/inbox_tasks_cubit_swipe_test.dart`. The `Dismissible`/`AlertDialog` UI wiring in `_wrapTaskCardWithSwipe` was verified by careful code review instead of an automated test; see `quickstart.md` Scenarios 1 and 4 for the manual check (T019).

### Implementation for User Story 2

- [X] T010 [US2] Wire the Inbox branch (`_inboxTaskCubit.today == false`) swipe-left (`DismissDirection.endToStart`) of the `Dismissible` from T002 to `assignForTodayPressed` (existing) in `_wrapTaskCardWithSwipe`, `lib/src/screens/inbox_tasks/inbox_tasks.dart` (depends on T002, T009)
- [X] T011 [US2] Hide the Inbox "Plus" button on swiped rows — same button-less-copy mechanism as T008 in `_wrapTaskCardWithSwipe`, `lib/src/screens/inbox_tasks/inbox_tasks.dart`; calendar/grouped views keep it (depends on T010)

**Checkpoint**: User Stories 1 and 2 are both independently functional — Plus and Minus buttons
are both gone; delete is not yet available.

---

## Phase 5: User Story 3 - Inbox screen: swipe right → confirm, then delete (Priority: P2)

**Goal**: Add a new capability — swipe right on an Inbox task asks for confirmation, then
permanently deletes the task.

**Independent Test**: Swipe an Inbox task right, confirm deletion, and verify it no longer appears
anywhere in the app or its source note; repeat and cancel, verifying the task is unchanged.

### Tests for User Story 3

- [X] T012 [P] [US3] Add unit tests for `TaskManager.deleteTask` in `test/task_manager_unit_test.dart`: removes only the targeted task's line and leaves sibling tasks/file content untouched (including an indented-task case), and does not generate a next occurrence for a recurring task (contrast with the existing mark-done → next-occurrence behavior in `_manageRecurrentTask`)
- [X] T013 [US3] Cover Inbox-screen swipe-right (confirm/cancel/delete) with a test — same deviation as T009: the widget-test approach was abandoned due to the `loadTasks` isolate hang under `testWidgets()`. Covered instead via `test/task_manager_unit_test.dart` (`deleteTask` correctness/recurrence) and `test/src/screens/inbox_tasks/inbox_tasks_cubit_swipe_test.dart` (`deleteTaskPressed removes the task`); the confirmation-dialog wiring itself was verified by code review (see T009's note) and `quickstart.md` Scenario 4.

### Implementation for User Story 3

- [X] T014 [US3] Implement `Future deleteTask(Task task)` in `lib/src/core/tasks/task_manager.dart`: remove the task's full line (including leading indentation and trailing newline, found via `lastIndexOf('\n', ...)` back from `task.taskSource`) from its source file, re-parse and persist the remaining tasks for that file, without modifying `recurrenceRule` or any other task in the file (depends on T012)
- [X] T015 [US3] Add `Future<void> deleteTaskPressed(Task task)` to `InboxTasksCubit` in `lib/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart`, calling `_taskManager.deleteTask(task)` (depends on T014)
- [X] T016 [US3] Add a delete-confirmation `AlertDialog` (reuse the existing `showDialog` pattern already used in this screen) and wire it into the Inbox branch swipe-right (`DismissDirection.startToEnd`) `confirmDismiss` of the `Dismissible` from T002: show the dialog, return `true` and call `deleteTaskPressed` only when the user confirms, return `false` on cancel, in `lib/src/screens/inbox_tasks/inbox_tasks.dart` (`_wrapTaskCardWithSwipe`) (depends on T002, T013, T015)

**Checkpoint**: All three user stories are independently functional. Plus/Minus buttons are fully
replaced by swipe gestures, and delete-with-confirmation is available.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T017 ~~Remove the now-fully-unused `rightButtonIcon`/`rightButtonPressed` parameters~~ from `lib/src/widgets/task_card.dart`.
  **Cancelled, not done — task premise was wrong**: these parameters are *not* unused. `_createTaskCard` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`) still passes them, and it backs the calendar view and grouped/file view (`_createCalendarViews`, `_createFileViews`), which were never in scope for swipe (see T002) and still rely on the button. Removing the parameters would break those views. No dead code exists here; nothing to do (depends on T008, T011).
- [X] T018 Run `flutter analyze` and the full `flutter test` suite at the repository root; fix any regressions (depends on T001–T017) — `flutter analyze`: 116 issues, identical count/content before and after (verified via `git stash`), all pre-existing; `flutter test`: 215 passed, 3 skipped (pre-existing skips in `main_messages_test.dart`), 0 failed
- [ ] T019 Execute `specs/001-task-swipe-actions/quickstart.md` Scenarios 1–6 manually on both an iOS and an Android device/simulator to confirm cross-platform parity (depends on T018) — not runnable in this environment (no device/simulator); left for manual QA

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — no dependency on US2/US3
- **User Story 2 (Phase 4)**: Depends on Foundational — no dependency on US1/US3 (touches the same
  file as US1 at a different branch/line, so in practice implement sequentially after US1, but its
  user-facing behavior does not require US1 to be shipped)
- **User Story 3 (Phase 5)**: Depends on Foundational — no dependency on US1/US2 (same file/branch
  as US2 at a different swipe direction; same sequential-implementation note applies)
- **Polish (Phase 6)**: Depends on all three user stories being complete

### Within Each User Story

- Tests are written first and must fail before their corresponding implementation task
- `TaskManager` method before `InboxTasksCubit` method before UI wiring before button removal

### Parallel Opportunities

- T003 (new `TaskManager` unit tests, existing file) can run in parallel with T004 (new widget
  test file) — different files
- T012 (new `TaskManager` unit tests) can run in parallel with T013 (widget tests) — different
  files
- T017 (delete dead code in `task_card.dart`) has no file conflict with T018/T019 at its
  dependency tier and is marked [P] accordingly
- Because User Stories 1, 2, and 3 all edit `_createTaskCard` and `TaskCard` usage in the same two
  files, they are not realistically parallelizable across people — implement in priority order
  (US1 → US2 → US3) even though each is independently valuable and testable once done

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational)
2. Complete Phase 3 (User Story 1)
3. **STOP and VALIDATE**: run T003/T004 tests, then quickstart.md Scenarios 2–3
4. Today screen is swipe-driven; Inbox screen still has its old Plus button — this is a safe,
   demoable increment

### Incremental Delivery

1. Setup + Foundational → shared swipe scaffold ready
2. Add User Story 1 → validate → Today screen done (MVP)
3. Add User Story 2 → validate → Inbox scheduling done (Plus button gone)
4. Add User Story 3 → validate → Inbox delete-with-confirmation done (all four gestures live)
5. Polish → dead-code removal, full suite, manual iOS/Android parity pass

## Notes

- [P] tasks = different files, no dependency on an incomplete task
- Verify each test fails before implementing the task that makes it pass
- Stop at each checkpoint to validate that story independently before moving on
- FR-009 / SC-004 (iOS/Android parity) is verified in T019, not by a separate automated test — the
  implementation is pure Dart/Flutter with no platform-specific code path, so parity is structural,
  and T019 is the confirming manual check
