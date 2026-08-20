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
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
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

## Phase 7: Cross-View Swipe Parity & Captions (FR-011, FR-012) — Increment 2

**Purpose**: `/speckit-analyze` found FR-011 (swipe must behave identically in list/grouped/calendar
view modes) and FR-012 (every swipe icon needs a text caption) were added to `spec.md` after
Increment 1 shipped, with zero task coverage — T002/T017 above explicitly scoped grouped/calendar
views *out*. This phase closes that gap. It is cross-cutting (it makes User Stories 1–3's
already-shipped swipe behaviors reach every view mode, and adds captions to all of them), so per
the task-generation rules it carries no single `[Story]` label, the same as Setup/Foundational.

**⚠️ Design correction found while generating this phase**: `research.md`'s original Increment 2
decision assumed `FileView`/`CalendarView` only read `.task` off their `taskCards` list *before*
construction. That's incorrect — both widgets' own `build()` methods read
`taskCards[0].task.taskSource?.fileName` / `taskCards[0].task.scheduled` directly off their field
at render time (`file_view.dart:25`, `calendar_view.dart:25`). Widening `taskCards` to
`List<Widget>` alone would break both lines. `research.md` and `contracts/task_manager_contract.md`
have been corrected accordingly; the tasks below reflect the corrected design (each widget gains a
new explicit field instead of reading `.task` off a list element).

- [X] T020 [P] In `lib/src/screens/inbox_tasks/file_view.dart`: add a new required `String? fileName` field to `FileView`; widen the `taskCards` field type from `List<TaskCard>` to `List<Widget>`; in `build()`, replace `fileName = taskCards[0].task.taskSource?.fileName; if (fileName != null) fileName = p.basenameWithoutExtension(fileName);` with simply using the new `fileName` field (basename computed by the caller instead)
- [X] T021 [P] In `lib/src/screens/inbox_tasks/calendar_view.dart`: add a new required `DateTime? scheduledDate` field to `CalendarView`; widen the `taskCards` field type from `List<TaskCard>` to `List<Widget>`; in `build()`, replace `date = taskCards[0].task.scheduled;` with simply using the new `scheduledDate` field
- [X] T022 In `_createFileViews` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`): keep building/grouping with plain `TaskCard`s exactly as today (grouping key: `task.taskSource!.fileName`); when starting a new file group, compute `fileName` from that first plain `TaskCard` (same derivation T020 removed from `FileView.build()`); when constructing `FileView`, pass `fileName` and a list of `_wrapTaskCardWithSwipe(context, card)`-wrapped rows instead of the plain `TaskCard`s (depends on T020)
- [X] T023 In `_createCalendarViews` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`): keep building/grouping with plain `TaskCard`s exactly as today (grouping key: `task.scheduled` via `TaskManager.sameDate`); when starting a new date group, compute `scheduledDate` from that first plain `TaskCard`; when constructing `CalendarView`, pass `scheduledDate` and a list of `_wrapTaskCardWithSwipe(context, card)`-wrapped rows instead of the plain `TaskCard`s; leave `_createPremiumUpgradeCalendarView` untouched (it does not build a `CalendarView`) (depends on T021)
- [X] T024 In `_buildSwipeBackground` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`): add a `required String caption` parameter; render a `Column` (`Icon`, then `Text(caption, style: TextStyle(color: Colors.white))`) instead of a bare `Icon`; update both call sites inside `_wrapTaskCardWithSwipe` with the four captions from FR-012 — Today `background` (swipe-right) → "Inbox", Today `secondaryBackground` (swipe-left) → "Tomorrow", Inbox `background` (swipe-right) → "Delete", Inbox `secondaryBackground` (swipe-left) → "Today"
- [X] T025 Reopen T017, with a correction found while doing it.
  **Deviation from task premise**: `_createTaskCard`'s `rightButtonPressed`/`rightButtonIcon` wiring genuinely became dead code once T022/T023 routed grouped/calendar rendering through `_wrapTaskCardWithSwipe` too — removed from `_createTaskCard` and (initially) from `TaskCard` itself. But `flutter analyze` then surfaced a real regression: `lib/src/widgets/obsi_chat_bubble.dart` (the AI-assistant chat screen, unrelated to Inbox/Today) also constructs a `TaskCard` with `rightButtonPressed`/`rightButtonIcon` for its own "add this AI-suggested task" button — a third call site beyond the two (calendar/grouped) already known from Increment 1's T002/T017 investigation. Restored both fields (and the `trailing:` button render block) on `TaskCard` (`lib/src/widgets/task_card.dart`) so that call site keeps working; `_createTaskCard` in `inbox_tasks.dart` still doesn't set them (genuinely unused there now), and `_wrapTaskCardWithSwipe`'s old "rebuild a button-less copy" trick was simplified away to just use `card` directly, since `_createTaskCard`'s output never carries a button in the first place anymore. Verified via `flutter analyze` (0 errors, 115 issues total vs. the 116 pre-existing baseline — the 1-fewer is an incidental fix of an already-dead `task.dart` import in `file_view.dart`, unrelated to this task) and `flutter test` (216 passed, 3 pre-existing skips, 0 failed).

**Checkpoint**: Swipe (with captions) works identically in list, grouped, and calendar view modes
on both Today and Inbox screens; the Plus/Minus buttons are gone from every view mode, closing the
SC-003 gap. User Stories 1–3 are otherwise unchanged.

---

## Phase 8: User Story 4 - Discover swipe via a one-time onboarding hint (Priority: P3) — Increment 3

**Goal**: The first time the Today or Inbox screen loads with at least one task, one task row
nudges on its own to reveal its swipe backgrounds, paired with a screen-specific message
explaining what swipe left/right do — once per screen, ever.

**Independent Test**: With the "hint shown" state reset (fresh install, or cleared local data),
open the Today screen and confirm a task row nudges and a SnackBar appears within a few seconds
without any tap; reopen the screen and confirm neither repeats. Repeat independently for Inbox.

### Tests for User Story 4

- [X] T026 [P] [US4] Add unit tests for `InboxTasksCubit.swipeHintShown`/`markSwipeHintShown` (reads/writes the today- vs. inbox-keyed flag correctly based on the cubit's own `today` field) in `test/src/screens/inbox_tasks/inbox_tasks_cubit_swipe_test.dart` — same file/pattern as the existing `postponeToTomorrowPressed`/`isBlockedFromLeavingToday` tests from Increment 1, avoiding the `loadTasks`/isolate hang under `testWidgets()` (see T009's note)
  **Deviation from plan**: only exercises the `today: false` (Inbox) branch directly, matching this test file's established today:true avoidance (see the comment block at the top of the `group`) — constructing a `today: true` cubit risks the same unrelated notification/home-widget plugin-channel issue T004 found. Today/Inbox independence is instead verified by asserting `SettingsController.getInstance().swipeHintShownToday` stays `false` after marking the Inbox cubit's hint shown, which exercises the same two independent backing fields without needing a `today: true` cubit instance.

### Implementation for User Story 4

- [X] T027 [US4] Add `swipe_hint_shown_today` / `swipe_hint_shown_inbox` `SharedPreferences`-backed async getter/setter pair to `SettingsService` in `lib/src/screens/settings/settings_service.dart`, matching the existing `showOverdueOnly`/`updateShowOverdueOnly` shape (depends on T026)
- [X] T028 [US4] Add cached `_swipeHintShownToday`/`_swipeHintShownInbox` fields to `SettingsController` in `lib/src/screens/settings/settings_controller.dart`, loaded during its existing init sequence.
  **Deviation from plan**: implemented as two separate `bool get swipeHintShownToday`/`swipeHintShownInbox` getters and two separate `updateSwipeHintShownToday(bool)`/`updateSwipeHintShownInbox(bool)` setters, not one parameterized `swipeHintShown(bool today)` method — every existing per-screen-independent flag in this class (e.g. `showOverdueOnly`) uses plain unparameterized getters, and the test file's `MockSettingsController` pattern (`@override bool get showOverdueOnly => false;`) only works cleanly with that shape. Neither setter calls `notifyListeners()`, matching `updateShowOverdueOnly`'s no-notify pattern — `InboxTasksCubit` listens for `SettingsController` changes via `refreshTasks()` (a full task reload), which marking a hint flag should not trigger (depends on T027)
- [X] T029 [US4] Add `bool get swipeHintShown` and `Future<void> markSwipeHintShown()` to `InboxTasksCubit` in `lib/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart`, delegating to `SettingsController.getInstance()` keyed by the cubit's own `today` field — mirrors the existing `showOverdueOnly` getter (depends on T028)
- [X] T030 [US4] Create a new private `_SwipeHintRow` `StatefulWidget` in `lib/src/screens/inbox_tasks/inbox_tasks.dart` that wraps a child widget (the already-swipe-wrapped row): on `initState`, if `!_inboxTaskCubit.swipeHintShown`, after a short settle delay drive an `AnimationController` that nudges the child via `Transform.translate` (small horizontal oscillation, a couple of cycles) — purely decorative, must not call any swipe-commit callback (depends on T029)
- [X] T031 [US4] In `_SwipeHintRow`, when the nudge animation starts, also call `ScaffoldMessenger.of(context).showSnackBar(...)` with a multi-second `duration` and the screen-specific message — Today: "Swipe left to move to tomorrow, swipe right to move to Inbox"; Inbox: "Swipe left to schedule for today, swipe right to delete" (depends on T030)
- [X] T032 [US4] In `_SwipeHintRow`, call `markSwipeHintShown()` exactly once — either when the nudge animation completes normally, or immediately if the wrapped `Dismissible` reports a real drag/dismiss starting first (per FR-016) — cancelling the animation and dismissing the `SnackBar` right away in the interrupted case so the real swipe proceeds unaffected.
  **Deviation from plan**: "real drag starting" is detected two ways, not one: (1) a `Listener.onPointerDown` on `_SwipeHintRow` itself calls `_finish()` immediately if the user touches that exact row; (2) a new `onUpdate: (details) { if (details.progress > 0 && !swipeHintShown) markSwipeHintShown(); }` callback was added to the `Dismissible` in `_wrapTaskCardWithSwipe` (fires for every row, not just the hinted one), and `_SwipeHintRowState`'s `AnimationController` listener polls `widget.cubit.swipeHintShown` on every tick, stopping itself if it flips `true` from elsewhere. This covers FR-016's "swipes any task" (not just the hinted row) — a plain confirmDismiss-only hook would have only caught swipes on the hinted row itself (depends on T031)
- [X] T033 [US4] Apply `_SwipeHintRow` to exactly the first rendered row (in `_showListView`, and — via Phase 7's shared `_wrapTaskCardWithSwipe` path — in grouped/calendar views too) whenever `!_inboxTaskCubit.swipeHintShown && tasks.isNotEmpty`; every other row, and every screen once its hint has played, renders exactly as before (depends on T032, T022, T023)

**Checkpoint**: All four user stories are independently functional. A first-time user on either
screen sees a one-time nudge + message teaching the swipe gesture; returning users never see it
again; a manual swipe during the hint cancels it immediately.

---

## Phase 9: Final Polish & Cross-Cutting Concerns (Increments 2 + 3)

- [X] T034 Run `flutter analyze` and the full `flutter test` suite at the repository root; fix any regressions (depends on T020–T033) — `flutter analyze`: 115 issues (vs. 116 pre-existing baseline; 0 errors; the 1-fewer is an incidental fix of an already-dead import, not a new fix-then-hide); `flutter test`: 216 passed, 3 skipped (pre-existing), 0 failed
- [ ] T035 Execute `specs/001-task-swipe-actions/quickstart.md` Scenarios 7–9 (cross-view parity, captions, onboarding hint) manually on both an iOS and an Android device/simulator, alongside the still-open T019 (Scenarios 1–6) (depends on T034) — not runnable in this environment (no device/simulator); left for manual QA

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
- **Cross-View Parity & Captions (Phase 7)**: Depends on Phase 2's `_wrapTaskCardWithSwipe` and on
  US1/US2/US3 (Phases 3–5) already being wired into it, since Phase 7 only widens *where* that
  existing behavior renders — no dependency on Phase 6.
- **User Story 4 (Phase 8)**: Depends on Foundational (Phase 2) for `_wrapTaskCardWithSwipe`/
  `Dismissible`, and on Phase 7 (T022, T023) for the hint to reach grouped/calendar views too — but
  is otherwise independent of US1/US2/US3's specific swipe outcomes (the hint only *reveals*
  backgrounds, it never triggers a real action).
- **Final Polish (Phase 9)**: Depends on Phase 7 and Phase 8 both being complete.

### Within Each User Story

- Tests are written first and must fail before their corresponding implementation task
- `TaskManager` method before `InboxTasksCubit` method before UI wiring before button removal
- Phase 8 follows the same layering: `SettingsService` → `SettingsController` → `InboxTasksCubit` →
  UI widget (T027 → T028 → T029 → T030–T033)

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
- T020 (`file_view.dart`) and T021 (`calendar_view.dart`) are different files with no shared
  dependency — run in parallel
- T022–T025 all edit `inbox_tasks.dart` (and, for T025, `task_card.dart`) — implement sequentially,
  same reasoning as US1–US3 above
- T026 (new `InboxTasksCubit` unit tests) has no file conflict with Phase 7 — could run in parallel
  with Phase 7, but T033 (applying `_SwipeHintRow`) depends on T022/T023 from Phase 7, so Phase 8's
  UI tasks (T030–T033) are practically sequenced after Phase 7 even though T026–T029 are not

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
6. *(Increment 2, shipped separately from the above)* Cross-View Parity & Captions (Phase 7) →
   validate quickstart Scenarios 7–8 → swipe now works with captions in every view mode, Plus/Minus
   fully gone
7. *(Increment 3)* User Story 4 (Phase 8) → validate quickstart Scenario 9 → first-time users on
   either screen get a one-time discoverability hint
8. Final Polish (Phase 9) → full suite, manual iOS/Android parity pass for Scenarios 7–9

### Increments 2 & 3 Delivery Note

Unlike US1–US3 (independently valuable in isolation, deliverable one at a time), Phase 7 (cross-view
parity) and Phase 8 (User Story 4) are not required to ship together, but Phase 8's UI tasks
(T030–T033) depend on Phase 7's T022/T023 (see Dependencies above) — so in practice, ship Phase 7
first, then Phase 8. Both extend a feature that was already merged to `main` (PR #51); treat this as
a second PR/release cycle for the same feature directory, not a rewrite of the first.

## Notes

- [P] tasks = different files, no dependency on an incomplete task
- Verify each test fails before implementing the task that makes it pass
- Stop at each checkpoint to validate that story independently before moving on
- FR-009 / SC-004 (iOS/Android parity) is verified in T019, not by a separate automated test — the
  implementation is pure Dart/Flutter with no platform-specific code path, so parity is structural,
  and T019 is the confirming manual check
- FR-011/SC-005 (view-mode parity) and FR-012/SC-006 (captions) are Phase 7's purpose; SC-003
  ("Plus/Minus no longer appear anywhere") is only fully satisfied once Phase 7's T025 lands —
  before that, Increment 1 alone leaves it unmet in grouped/calendar views (see `/speckit-analyze`
  finding I1)
- FR-013–FR-017/SC-007 (onboarding hint) are Phase 8's purpose; like FR-009/SC-004, cross-platform
  behavior for the hint itself is structural (pure Dart/Flutter, no platform code) and confirmed
  manually in T035, not by a dedicated automated parity test
