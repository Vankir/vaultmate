---

description: "Task list for Nested Task Visualization"
---

# Tasks: Nested Task Visualization

**Input**: Design documents from `/specs/002-nested-task-visualization/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/depth_computation_contract.md](./contracts/depth_computation_contract.md), [contracts/collapse_render_contract.md](./contracts/collapse_render_contract.md), [quickstart.md](./quickstart.md)

**Tests**: Included — Constitution Principle III (Test-First for Parsing & Business Logic,
NON-NEGOTIABLE) requires automated coverage for core logic changes (the new depth/parent
computation in `MarkdownParser`) and the `flutter test` CI gate, so test tasks are mandatory here,
not optional.

**Organization**: Tasks are grouped by user story (from `spec.md`) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- File paths are exact and relative to the repository root

---

## Phase 1: Setup

- [X] T001 Run `flutter test` at the repository root to confirm the existing suite is green before starting (baseline check; no code changes) — 216 tests passed

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work can begin until this phase is complete. This phase delivers
the depth/parent computation every user story below depends on — see
`contracts/depth_computation_contract.md` for the exact algorithm each task below implements.

- [X] T002 [P] Add unit tests for the depth/parent-computation algorithm to a new `group('Nested Task Depth', ...)` in `test/markdown_parser_test.dart` — 8 tests covering: single child (depth 0/1); multiple children of one parent (all depth 1, in source order); three-level nesting (depths 0/1/2); the skipped-indentation-level case; an indented task as the first line in the file (no preceding task → depth 0); a non-task line between parent and child not breaking the relationship; mixed tabs/spaces comparing consistently; and a flat (unindented) note leaving every task at depth 0
- [X] T003 Add `int depth` (default `0`) and `int? parentTaskId` (default `null`) fields to `Task` in `lib/src/core/tasks/task.dart` — plain public fields with inline doc comments explaining they're derived/non-persisted; `equals()`, `update()`, and `toJsonMap()` were left untouched, so they exclude both fields automatically (depends on T002)
- [X] T004 Implement the depth/parent stack algorithm in `MarkdownParser._parseTasksByPattern` (`lib/src/core/tasks/parsers/markdown_parser.dart`), per `contracts/depth_computation_contract.md`. All 47 tests in `test/markdown_parser_test.dart` pass (39 pre-existing + 8 new from T002).
  **Deviation/decision found while implementing**: the task's depth/parent is now resolved (and the task pushed onto the depth stack) *before* the existing `taskFilter` inclusion check, not after — so a task excluded from the returned list by `taskFilter` (e.g. it lacks a required `#tag`) still correctly anchors the stack for any of its children that do pass the filter. Otherwise a filtered-out parent would silently break its children's depth calculation. This wasn't in T002's explicit test list (not one of `spec.md`'s stated edge cases) but follows directly from the same principle as FR-011 ("a task's parent being absent from the current view must not affect the task's own depth") and from the contract's "for each task, in the order it is encountered" wording — filtering doesn't remove a line from being encountered, only from being returned. No dedicated test was added for this specific interaction to keep scope tight; it falls out of the same code path T002 already exercises (depends on T003, makes T002 pass)

**Checkpoint**: Every `Task` parsed from a markdown note now carries a correct `depth` and
`parentTaskId`. Nothing renders differently yet — no UI reads these fields until User Story 1.

---

## Phase 3: User Story 1 - See sub-tasks nested under their parent in the grouped view (Priority: P1) 🎯 MVP

**Goal**: The file-grouped task view renders each task visually indented under its parent, so a
user can tell at a glance which tasks are sub-tasks of which — the core ask from
[issue #31](https://github.com/Vankir/vaultmate/issues/31).

**Independent Test**: Open a note with a top-level task and one or more indented sub-tasks under
it in the file-grouped view (see `quickstart.md` Scenario 1) and verify the sub-tasks render
indented beneath their parent, visually distinct from top-level tasks in the same note; a note
with no indentation renders exactly as it did before this feature.

### Tests for User Story 1

> Write these first; they must fail before the implementation tasks below.

- [X] T005 [P] [US1] Add widget tests to a new `test/src/widgets/task_card_test.dart`.
  **Deviation from task description**: wrote all four depth-rendering cases (including US2/T008's depth-2 and cap-related cases) in this single pass/file rather than splitting T005's "depth 0/1 only" from T008's "depth 2 and cap" additions across two separate edits — same file, same `group`, no reason to touch it twice. Targets a keyed design planned for T006/T009: a `Key('task_card_depth_indent')` `Padding` wrapper (absent entirely at depth 0, so depth-0 output is byte-identical to pre-feature `TaskCard`) containing `Key('task_card_depth_marker_$i')` marker widgets, one per visual depth level. All 4 tests currently fail to compile (`depth` isn't a defined parameter on `TaskCard` yet) — expected, per TDD.

### Implementation for User Story 1

- [X] T006 [US1] Add an optional `int depth` parameter (default `0`) to `TaskCard` (`lib/src/widgets/task_card.dart`); when `depth > 0`, render a left indent proportional to `depth` plus `depth` small vertical marker bars ahead of the existing card content; when `depth == 0`, render exactly as today, unchanged.
  **Deviation from task split**: implemented with the `maxVisualDepth = 5` clamp (originally slated as a distinct step in T009) from the start, not as an uncapped version first — `build()` renamed the pre-existing content builder to `_buildCardContent()` and wraps it in a keyed `Padding`+`Row` of keyed marker `Container`s only when `depth > 0`, using `depth.clamp(0, maxVisualDepth)` for both the indent amount and the marker count. Clamping inline added no real extra complexity over an uncapped version (same `for` loop, one different upper bound), so there was nothing to gain by doing it in two passes. All 4 tests in `test/src/widgets/task_card_test.dart` (including T008's depth-2 and cap cases) pass against this single implementation — see T008/T009 (depends on T005, T004)
- [X] T007 [US1] Add an optional `{int depth = 0}` parameter to `_createTaskCard` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`), forwarded to `TaskCard`'s new `depth` parameter; update `_createFileViews`'s call site only to pass `depth: task.depth` — `_createCalendarViews`'s call site (line ~587) and the flat list-view branch inside `_createViewItems` (line ~553) are left unchanged (no `depth` argument), so they keep rendering flat, satisfying FR-010. `flutter analyze` on the touched files: 0 errors, all pre-existing warnings/info (unused imports, deprecated `withOpacity`, etc.), nothing new (depends on T006)

**Checkpoint**: User Story 1 is fully functional and independently testable — the file-grouped
view shows sub-tasks nested under their parent (any depth, though not yet capped for very deep
trees); List and Calendar views are unaffected. This alone resolves the core ask in issue #31.

---

## Phase 4: User Story 2 - Distinguish multiple levels of nesting (Priority: P2)

**Goal**: A note nested more than one level deep (matching the reporter's own example — "Cookies"
→ "Milk"/"Chocolate Chips") shows each level progressively more indented and visually
distinguishable, with very deep nesting capped so it stays legible on a narrow screen.

**Independent Test**: Open a note with at least three levels of indented checkbox tasks in the
file-grouped view (`quickstart.md` Scenario 2) and verify each level is visually distinguishable
from the others, and that nesting deeper than the visual cap still renders (at the capped
indentation) rather than being hidden.

### Tests for User Story 2

- [X] T008 [P] [US2] Add widget tests to `test/src/widgets/task_card_test.dart`: `depth: 2` renders a visibly larger indent (and one more depth marker) than `depth: 1`; `depth: 9` (deeper than the cap) renders identically to `depth: 5`.
  **Deviation**: written together with T005 in the same pass (see T005's note) rather than as a separate later edit — both land in the same file/`group`, and both were already needed to pin down T006's exact keyed design before implementing it. Passing from the start, since T006 included the cap (see T009).

### Implementation for User Story 2

- [X] T009 [US2] Cancelled, not separately done — already implemented as part of T006.
  **Task premise superseded**: T006's implementation used `depth.clamp(0, maxVisualDepth)` (`maxVisualDepth = 5`) for both the indent and marker-count computation from the start (see T006's note) — there was no separate uncapped version to retrofit a clamp onto. `test/src/widgets/task_card_test.dart`'s cap test (from T008) already passes against T006's code unchanged. Nothing left to implement (depends on T008).

**Checkpoint**: Multi-level nesting — including trees deeper than the visual cap — renders
legibly and distinguishably by depth in the file-grouped view.

---

## Phase 5: User Story 3 - Existing task actions keep working unchanged on nested tasks (Priority: P3)

**Goal**: Prove that adding `depth`/`parentTaskId` did not change how any existing per-task action
behaves — marking done, deleting, and (on Today/Inbox) swipe-based reschedule/delete continue to
affect only the exact task acted on, per FR-008/FR-009. No production code changes in this phase —
it is a regression safety net over the Foundational and User Story 1/2 changes.

**Independent Test**: With a parent task and a child task both present (from a fixture with nested
checkboxes), mark the child done via `TaskManager.setStatus` and verify only the child's status
changed; separately, mark the parent done and verify the child is unaffected.

### Tests for User Story 3

- [X] T010 [P] [US3] Add regression unit tests to `test/task_manager_unit_test.dart`, new `group('nested task actions do not cascade (FR-008, FR-009)', ...)` — 4 tests: marking a child done leaves the parent `todo` (and vice versa), both checked in-memory and after a fresh `loadTasks` reparse; deleting a parent leaves the child's line intact in the file (and vice versa) — the delete-parent case additionally confirms the orphaned child reparses to `depth: 0` (no preceding task left to link to), matching `spec.md`'s "no preceding task" edge case
- [X] T011 [P] [US3] Add regression unit tests to `test/task_serialization_unit_test.dart`, new `group('depth/parentTaskId are excluded from equality and serialization', ...)`: two tasks with identical description/status/created but different `depth`/`parentTaskId` are still `Task.equals()` (a hierarchy difference alone must never look like a content change needing a save); `Task.toJsonMap()`'s output never contains a `depth` or `parentTaskId` key (protects the home-screen-widget sync contract read via `toJsonMap()` in `lib/src/core/system_widget.dart`, per `research.md` Decision 4)

**Checkpoint**: All three user stories are independently functional and regression-tested. Issue
#31 is resolved: sub-tasks are visually nested in the grouped view, multiple levels are
distinguishable, and no existing task action changed behavior.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T012 Run `flutter analyze` and the full `flutter test` suite at the repository root; fix any regressions (depends on T001–T011) — `flutter analyze`: 115 issues, identical to the pre-feature baseline, 0 errors; `flutter test`: 234 passed (216 baseline + 18 new), 3 skipped (pre-existing), 0 failed
- [X] T013 Execute `specs/002-nested-task-visualization/quickstart.md` Scenarios 1–5 manually on an Android device, using a note matching the reporter's own example from issue #31 (depends on T012).
  **Result: found a real bug**, tracked and fixed as T014 below — manual device testing (this task) is exactly what T012's `flutter test` pass didn't cover, since every widget test pumped `TaskCard` inside a plain `Material`, which gives bounded height, unlike a real `ListView` row.

---

## Phase 7: Bug Fix — ListView layout crash on nested rows (found during T013 manual QA)

**What happened**: manual testing on a real device with `- [ ] parent\n\t- [ ] child1\n\t- [ ] child2` threw a red-screen `RenderBox was not laid out: ... 'hasSize'` / `RenderRepaintBoundary` / `RenderIndexedSemantics` exception, pointing at the `ListView` in `inbox_tasks.dart:137`. Root cause: T006's `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` (wrapping the depth markers + card) was placed directly inside a `ListView` item slot. A `ListView` gives each item unbounded height, and `CrossAxisAlignment.stretch` cannot resolve "stretch to fill the cross axis" against an unbounded height — a well-known Flutter layout combination that fails this exact assertion. None of T005/T008/T009's widget tests caught this because they all pumped `TaskCard` inside a bare `Material`, which (unlike `ListView`) gives bounded height, masking the bug.

- [X] T015 [P] Add a regression widget test to `test/src/widgets/task_card_test.dart` that pumps a `depth > 0` `TaskCard` inside a real `ListView` (the actual usage context in `_createFileViews`) and asserts `tester.takeException()` is `null`. Verified this test fails (reproducing the exact crash) against T006's original code, before the fix in T014.
- [X] T014 Wrap the `Row` in `TaskCard.build()`'s depth-rendering branch (`lib/src/widgets/task_card.dart`) in `IntrinsicHeight`, which measures the row's natural height first and gives `CrossAxisAlignment.stretch` a concrete height to resolve against instead of an unbounded one. Verified against T015: fails without the wrapper, passes with it. `flutter analyze`: 5 issues on `task_card.dart`, all pre-existing (unused import, deprecated `withOpacity`, unnecessary `!`, unused `_debugInfo`) — nothing new. `flutter test`: 235 passed (234 + T015), 3 pre-existing skips, 0 failed (depends on T015).

**Checkpoint**: Nested rows render correctly inside the real `ListView`/`FileView` context, not just in isolation. This closes the gap T012's automated pass couldn't see on its own.

---

## Phase 8: User Story 4 - Collapse and expand sub-task groups in the grouped view (Priority: P2) — Increment 2

**Purpose**: Added to `spec.md` via `/speckit-clarify` after Increment 1 shipped. Lets a user hide
a task's sub-tasks (per-task) or every sub-task in a file at once (collapse-all/expand-all), per
FR-012–FR-016. See `contracts/collapse_render_contract.md` for the exact suppress-cursor algorithm
this phase implements, and `research.md` Decisions 7–10 for why collapse state lives on
`InboxTasksCubit` (not `SettingsController`) and is cleared only in `refreshTasks()`.

**Goal**: A note with many sub-tasks stays scannable — collapse the parts you're not working on,
per-task or all at once, with no persistence (always resets to fully expanded on reload).

**Independent Test**: In a note with a task that has several sub-tasks, collapse that task and
verify its sub-tasks disappear while it stays visible; expand it again and verify they reappear in
original order/depth (`quickstart.md` Scenario 6). Separately, collapse-all/expand-all a file at
once (Scenario 7), and confirm collapse state resets on reload but not on an unrelated task edit
(Scenario 8).

### Tests for User Story 4

> Write these first; they must fail before the implementation tasks below.

- [X] T016 [P] [US4] Add cubit unit tests to a new `test/src/screens/inbox_tasks/inbox_tasks_cubit_collapse_test.dart` — 5 tests: `isCollapsed` false for every task before any interaction; `toggleCollapsed` marks/un-marks; `collapseAllInFile` marks every task with children in that file, leaves a different file's tasks (and childless tasks) untouched; `expandAllInFile` clears only that file's ids; `clearCollapsedTasks()` empties everything. Uses a real `TaskManager` + `InMemoryTasksFileStorage` with `manager.loadTasks(...)` called directly (not via `cubit.refreshTasks()` — see T018's note) and `today: false`, matching `inbox_tasks_cubit_swipe_test.dart`'s established pattern. All 5 fail to compile (methods don't exist yet) — expected, per TDD.
- [X] T017 [P] [US4] Add widget tests to `test/src/widgets/task_card_test.dart`, new `group('TaskCard collapse/expand control', ...)` — 3 tests targeting a keyed `Key('task_card_collapse_toggle')` `IconButton`: `hasChildren: false` renders no control regardless of `isCollapsed`; `hasChildren: true` with a callback renders a control that invokes it on tap; `isCollapsed` true vs false render visibly different icons. All 3 fail to compile (params don't exist yet) — expected, per TDD.

### Implementation for User Story 4

- [X] T018 [US4] Add `Set<int> _collapsedTaskIds`, `bool isCollapsed(Task task)`, `void toggleCollapsed(Task task)`, `void collapseAllInFile(String fileName)`, `void expandAllInFile(String fileName)`, and `void clearCollapsedTasks()` to `InboxTasksCubit`; `refreshTasks()` now calls `clearCollapsedTasks()` as its first line, per FR-016 (`research.md` Decision 9), not inside `tasksChangedListener()`; each of the four mutating methods calls `_applySearchFilter()` afterward so the `BlocBuilder` rebuilds. `clearCollapsedTasks()` is a separate method exactly so T016 can unit-test the reset behavior directly, without calling `refreshTasks()` itself (which reassigns `taskManager.storage` to real platform storage — see the note originally on this task). All 5 tests in `test/src/screens/inbox_tasks/inbox_tasks_cubit_collapse_test.dart` pass (depends on T016)
- [X] T019 [US4] Add optional `bool hasChildren = false`, `bool isCollapsed = false`, `VoidCallback? onToggleCollapse` parameters to `TaskCard`; when `hasChildren && onToggleCollapse != null`, render one leading `Key('task_card_collapse_toggle')` `IconButton` (`chevron_right` when collapsed, `keyboard_arrow_down` when expanded) as the first item in the existing `leading` `Row`, ahead of the checkbox/play-button. All 8 tests in `test/src/widgets/task_card_test.dart` pass (depends on T017)
- [X] T020 [US4] In `_createFileViews` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`), implement the suppress-cursor algorithm from `contracts/collapse_render_contract.md`: switched to an indexed loop; compute each task's `hasChildren` via the same-file-bounded lookahead (Decision 8); maintain `int? suppressBelowDepth`, `continue`-skipping row construction entirely for any task whose `depth > suppressBelowDepth`; pass `hasChildren`, `isCollapsed: cubit.isCollapsed(task)`, `onToggleCollapse` through `_createTaskCard`; set `suppressBelowDepth = task.depth` after rendering a task that `hasChildren && isCollapsed`.
  **Note**: confirmed the cursor resets "for free" at every file boundary — a file's first task is always depth 0 (FR-002), which can never satisfy `depth > suppressBelowDepth` for any non-negative cursor value, so no separate file-boundary reset logic was needed. `flutter analyze`: 7 issues on `inbox_tasks.dart`, all pre-existing, 0 errors (depends on T018, T019, and Phase 3's T007 depth-wiring)
- [X] T021 [US4] Add optional `VoidCallback? onCollapseAll`, `VoidCallback? onExpandAll` parameters to `FileView`; render two small `Key('file_view_collapse_all')`/`Key('file_view_expand_all')` `IconButton`s (`unfold_less`/`unfold_more`) in the existing "File: X" header row, after a `Spacer()`, only when both callbacks are non-null.
  **Note**: `_createFileViews` decides non-null vs. null via a small pre-pass (`filesWithCollapsibleTasks`, a `Set<String>` of file names built with the same lookahead as `hasChildren`) computed *before* the main loop — `FileView`'s fields are immutable, so (unlike `fileTaskWidgets`, which is mutated in place after being handed to `FileView`) whether to show the header control can't be decided progressively while still discovering later tasks in the same file; the pre-pass avoids that ordering problem at the cost of one extra O(n) scan. `flutter analyze` on all 4 touched files: 13 issues total, all pre-existing (unused imports, deprecated `withOpacity`, a pre-existing `use_build_context_synchronously` info on an untouched line, etc.), 0 errors. Full `flutter test`: 243 passed (235 + 8 new), 3 pre-existing skips, 0 failed (depends on T020)

**Checkpoint**: A user can collapse/expand a single task's sub-tasks, or every sub-task in a file
at once, in the grouped view; state always resets on reload and is never disturbed by an unrelated
task edit elsewhere.

---

## Phase 9: Final Polish & Cross-Cutting Concerns (Increment 2)

- [X] T022 Run `flutter analyze` and the full `flutter test` suite at the repository root; fix any regressions (depends on T016–T021) — `flutter analyze`: 115 issues repo-wide, identical to the pre-Increment-2 baseline, 0 errors; `flutter test`: 243 passed (235 baseline + 8 new), 3 pre-existing skips, 0 failed
- [ ] T023 Execute `specs/002-nested-task-visualization/quickstart.md` Scenarios 6–8 (collapse/expand a single task, collapse-all/expand-all, reload-resets-but-edits-don't) manually on an Android device, alongside the still-open T013 follow-up for Scenarios 1–5 if not already covered (depends on T022) — not runnable in this environment (no device/simulator); left for manual QA

---

## Phase 10: Bug Fix — FileView header overflow with collapse-all/expand-all (found during manual use, post-T022)

**What happened**: real-device use (before T023's formal manual QA pass) hit a `RenderFlex overflowed by 61 pixels on the right` exception pointing at the header `Row` in `file_view.dart:44`. Root cause: T021 added the collapse-all/expand-all `IconButton`s and a `Spacer()` after the file-name `GestureDetector`, but that `GestureDetector` had no flex/shrink behavior of its own — it always claimed its full natural width for the (potentially long) file name, leaving nothing for the trailing icons and `Spacer` to fit into once one existed. T022's `flutter analyze`/`flutter test` pass didn't catch it because no existing or new test pumped `FileView` at a narrow width with a long file name.

- [X] T024 [P] Add a regression widget test to a new `test/src/screens/inbox_tasks/file_view_test.dart`: pumps a `FileView` with a long file name and non-null `onCollapseAll`/`onExpandAll` inside a narrow (340px) `SizedBox`, asserts `tester.takeException()` is `null`; a second test confirms no collapse-all/expand-all controls render when both callbacks are `null`. Verified the first test fails (reproducing the exact overflow) against T021's original code, before the fix in T025.
- [X] T025 In `FileView.build()` (`lib/src/screens/inbox_tasks/file_view.dart`), wrap the file-name `GestureDetector` in `Expanded` (removing the now-unnecessary `Spacer()`) so it shrinks to leave room for the trailing icons instead of claiming its full natural width; add `overflow: TextOverflow.ellipsis` (`RichText`) / `overflow: TextOverflow.ellipsis, maxLines: 1` (`Text`) to the two file-name renderers so a long name truncates instead of overflowing on its own. Verified against T024: fails without the `Expanded` wrapper, passes with it. `flutter analyze` on `file_view.dart`: 1 issue, the same pre-existing `use_build_context_synchronously` info already present before this fix. `flutter test`: 245 passed (243 + T024's 2 tests), 3 pre-existing skips, 0 failed (depends on T024)

**Checkpoint**: The file header (with or without collapse-all/expand-all controls) never overflows, regardless of file name length or screen width.

---

## Phase 11: Refinement — Single two-state toggle instead of two separate buttons (user-requested, post-T025)

**What changed**: FR-014 only requires *a way* to collapse and a way to expand every collapsible task in a file at once — it doesn't mandate two separate controls. Replaced the two `IconButton`s (`file_view_collapse_all`/`file_view_expand_all`) with one `Key('file_view_collapse_toggle')` button whose icon/tooltip reflects whether the file is currently fully collapsed (`unfold_more`/"Expand all") or not (`unfold_less`/"Collapse all"), and whose single tap does whichever action currently makes sense.

- [X] T026 [P] Add `bool hasCollapsibleTasks(String fileName)` and `bool allCollapsedInFile(String fileName)` to `InboxTasksCubit` (`lib/src/screens/inbox_tasks/cubit/inbox_tasks_cubit.dart`) — the latter true only when every collapsible task in that file is currently in `_collapsedTaskIds`; add `void toggleCollapseAllInFile(String fileName)` that calls `expandAllInFile` when `allCollapsedInFile` is already true, otherwise `collapseAllInFile` (so a file with *some* but not all sub-tasks collapsed toggles to fully collapsed first, not fully expanded). New unit test in `test/src/screens/inbox_tasks/inbox_tasks_cubit_collapse_test.dart` covers all three methods, including the "partially collapsed toggles to fully collapsed" case
- [X] T027 [P] In `FileView` (`lib/src/screens/inbox_tasks/file_view.dart`), replace `onCollapseAll`/`onExpandAll` with `bool? allCollapsed` + `VoidCallback? onToggleCollapseAll`; render one `Key('file_view_collapse_toggle')` `IconButton` (icon/tooltip driven by `allCollapsed`) when both are non-null, instead of the two-button pair. Updated `test/src/screens/inbox_tasks/file_view_test.dart` (the T024 regression test plus two new tests for icon/tap behavior) accordingly
- [X] T028 In `_createFileViews` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`), removed the local `filesWithCollapsibleTasks` pre-pass entirely — `FileView` construction now calls `_inboxTaskCubit.hasCollapsibleTasks(fileName)`/`allCollapsedInFile(fileName)`/`toggleCollapseAllInFile(fileName)` directly, delegating fully to the cubit's own `_tasks`-based state instead of a locally-recomputed approximation over the (possibly search-filtered) `tasks` parameter (depends on T026, T027)

**Checkpoint**: One button per file toggles between "collapse all" and "expand all", reflecting the file's actual current state; behavior verified via `flutter analyze` (8 issues across the 3 touched files, all pre-existing, 0 errors) and `flutter test` (248 passed — 245 + 3 new: 1 cubit test, 2 widget tests — 3 pre-existing skips, 0 failed).

---

## Phase 12: Refinement — Move the per-task collapse toggle under the checkbox (user-requested, post-T028)

**What changed**: the per-task collapse/expand `IconButton` (T019) moved from beside the checkbox (in a horizontal `Row`, widening the leading area and eating into space for the task title) to stacked below it (in a vertical `Column`), so the leading area stays narrow and the title/content gets more horizontal room.

- [X] T029 In `TaskCard._buildCardContent` (`lib/src/widgets/task_card.dart`), changed `ListTile.leading` from a `Row` (checkbox/play-button beside the collapse toggle) to a `Column` (checkbox/play-button above, collapse toggle below).
  **Deviation found while implementing**: `ListTile` caps `leading`'s height to the tile's own computed height (56px for this two-line tile) and does not grow the tile to fit a taller `leading` — simply stacking a default `Checkbox` (large default accessibility tap-target padding) above even a size-constrained `IconButton` overflowed that budget by up to 24px, reproduced by the *existing* T017 widget tests (no new test needed; a plain `Material`-wrapped `TaskCard` already reproduces it, since the overflow is internal to `ListTile`'s own height math regardless of the outer container). Tried shrinking each widget individually first (`Checkbox(materialTapTargetSize: shrinkWrap)`, tight `IconButton` constraints/padding/`visualDensity: compact`) - still overflowed, because ambient theme sizing wasn't fully overridden by per-widget constraints. Settled on wrapping the whole `Column` in `FittedBox(fit: BoxFit.scaleDown)`, which guarantees the stacked pair always fits whatever height `ListTile` actually grants it, regardless of exact ambient theme sizing - a more robust fix than chasing exact pixel budgets. `flutter analyze`: 5 issues on `task_card.dart`, all pre-existing. `flutter test`: 248 passed (no new tests needed - existing T017 tests already cover this combination and now pass), 3 pre-existing skips, 0 failed.

**Checkpoint**: A task row with sub-tasks shows its collapse toggle stacked under the checkbox, narrower than before, with the same tap behavior; a task row without sub-tasks is completely unaffected (checkbox alone, unchanged from before Increment 2).

---

## Phase 13: Bug Fix — T029's FittedBox shrank the checkbox itself (found via user feedback)

**What happened**: the user noticed the checkbox on a parent (has-children) task rendered visibly *smaller* than on a childless task. Root cause: T029's `FittedBox(fit: BoxFit.scaleDown)` wraps the *whole* leading `Column` uniformly — whenever the stacked checkbox+toggle combination didn't fit `ListTile`'s fixed leading-height budget, `FittedBox` scaled the entire column down (checkbox included) to make it fit, rather than only shrinking the toggle. `minVerticalPadding` was tried as a fix (on the theory that a taller `ListTile` would need no scaling at all) and empirically confirmed to have **zero effect** on `leading`'s height cap in this Flutter version — `ListTile` derives that cap from title/subtitle content only, never from `leading` itself, confirming this is architecturally not fixable by adjusting `ListTile`'s own padding/theming knobs at all.

- [X] T030 Replaced `ListTile` in `TaskCard._buildCardContent` (`lib/src/widgets/task_card.dart`) with a manual `InkWell` + `Padding` + `Row` (leading column, then `Expanded` title/subtitle column, then optional trailing button) that reproduces the same visual layout without any framework-imposed height cap on the leading area — the checkbox now always renders at its natural, unscaled size (no `FittedBox`, no `shrinkWrap`, no `minVerticalPadding` hack) regardless of whether the collapse toggle is present below it. Added a regression test to `test/src/widgets/task_card_test.dart` asserting `tester.getSize(find.byType(Checkbox))` is identical with and without `hasChildren`. Confirmed no other file references `ListTile` from `TaskCard` (`grep` across `test/` and `lib/`), so no other tests or call sites depended on `ListTile`-specific behavior. `flutter analyze`: 5 issues, all pre-existing. `flutter test`: 249 passed (248 + 1 new), 3 pre-existing skips, 0 failed, including every pre-existing test elsewhere in the suite (no regressions from replacing `ListTile`).

**Checkpoint**: The checkbox is pixel-identical in size whether or not the task has sub-tasks; only the toggle's presence/absence differs, exactly as requested.

---

## Phase 14: Bug Fix — Task attributes (priority/scheduled/due) sometimes wrapped onto separate lines (user-reported, pre-existing, unrelated to Increment 2)

**What happened**: the user noticed that priority, scheduled date, and due date sometimes rendered stacked in a column instead of inline. Root cause, found while investigating: `TaskCard._getSubtitle` (`lib/src/widgets/task_card.dart`) built its subtitle string with literal `"\n"` characters between the priority marker and the scheduled/due segments whenever more than one was present — this predates Increment 2 entirely (confirmed: `_getSubtitle` itself was never touched by any nested-task-visualization or collapse/expand task; only the `ListTile` → manual `Row` replacement in T030 changed how the *already-existing* `_getSubtitle()` widget is *placed*, not what it renders).

- [X] T031 [P] In `TaskCard._getSubtitle`, replaced the two `"\n${...}"` concatenations with a plain `" "` separator (only when `subtitle` is already non-empty, avoiding a leading space); added `maxLines: 1` + `overflow: TextOverflow.ellipsis` to both the plain-`Text` and tag-bearing-`RichText` render paths so a long combined line truncates with an ellipsis instead of ever wrapping to a second line. Added two regression tests to `test/src/widgets/task_card_test.dart` (scheduled+due with no tags via `Text`, and the same with a tag via `RichText`) asserting the rendered text contains no `\n` and both `maxLines`/`overflow` are set correctly. Verified both tests fail (reproducing the original stacked-column rendering) when the `"\n"` separators are reintroduced, confirming they actually catch this regression. `flutter analyze`: 115 issues repo-wide, identical to baseline, 0 errors. `flutter test`: 251 passed (249 + 2 new), 3 pre-existing skips, 0 failed.

**Checkpoint**: Priority, scheduled date, and due date always render on a single line (truncating with `…` if truly too long for the available width), regardless of how many of them are present on a task.

---

## Phase 15: Refinement — Large visible gap between the checkbox and the collapse toggle (user-reported, post-T030)

**What happened**: after T030 replaced `ListTile` with a manual `Row`/`Column`, the checkbox and the stacked collapse toggle below it had a noticeably large gap between them. Root cause: `Checkbox`'s default `MaterialTapTargetSize.padded` reserves a large invisible tap-target area around its small visual glyph — invisible and harmless when the checkbox was ListTile's sole `leading` content, but now directly adjacent (in a tight `Column`) to another control, that padding read as a big empty gap.

- [X] T032 [P] Added `materialTapTargetSize: MaterialTapTargetSize.shrinkWrap` and `visualDensity: VisualDensity.compact` to the `Checkbox` in `TaskCard._buildCardContent` (`lib/src/widgets/task_card.dart`) — safe now that `ListTile`'s leading-height cap no longer applies (T030), unlike the earlier attempt at `shrinkWrap` back when it was still constrained by `ListTile` (T029). Applied unconditionally (both the has-children and childless branches), so the checkbox-size-consistency guarantee from T030's regression test still holds — it shrinks uniformly for every task, not just parent ones. `flutter analyze`: 5 issues on `task_card.dart`, all pre-existing. `flutter test`: 251 passed (no count change — existing T030 checkbox-size test and all others still pass unmodified), 3 pre-existing skips, 0 failed.

**Checkpoint**: The checkbox sits directly above the collapse toggle with no more visible gap between them than between any other adjacent compact controls in the app.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — delivers the MVP (issue #31's core ask)
- **User Story 2 (Phase 4)**: Depends on Foundational and on User Story 1 (extends the same
  `TaskCard` depth-rendering code added in T006; not meaningfully separable into a different file
  or code path)
- **User Story 3 (Phase 5)**: Depends on Foundational (needs real `depth`/`parentTaskId` values to
  test against) but not on User Story 1/2's rendering work — could run in parallel with Phase 3/4
  if staffed separately, since it only touches `TaskManager`/`Task` test coverage, not
  `TaskCard`/`inbox_tasks.dart`
- **Polish (Phase 6)**: Depends on all three user stories being complete
- **User Story 4 (Phase 8)**: Depends on Foundational (Phase 2) for `depth`, and on Phase 3's T007
  (the `_createFileViews`/`_createTaskCard` depth-wiring T020 extends) and Phase 7's bugfix (T014)
  being in place — not on User Story 2/3's own work otherwise
- **Final Polish (Phase 9)**: Depends on Phase 8 (and, transitively, everything before it)

### Within Each User Story

- Tests are written first and must fail before their corresponding implementation task
- Within Phase 3: `TaskCard` change (T006) before the call-site wiring that uses it (T007)
- Within Phase 4: the widget test proving the cap is missing (T008) before the clamp that fixes it (T009)
- Within Phase 8: `InboxTasksCubit` changes (T018) and `TaskCard` changes (T019) before the
  `_createFileViews` wiring that uses both (T020), before `FileView`'s collapse-all header (T021)

### Parallel Opportunities

- T002 (new parser tests, `test/markdown_parser_test.dart`) can be written in parallel with T003
  (new `Task` fields, `task.dart`) — different files; both are prerequisites for T004
- T005 (widget tests) and T008 (widget tests) both land in `test/src/widgets/task_card_test.dart`
  — write T005 first (Phase 3), extend the same file with T008's cases in Phase 4
- T010 and T011 are marked [P] — different test files, no shared state
- Phase 5 (User Story 3) has no file overlap with Phase 3/4 (`TaskCard`/`inbox_tasks.dart`) and
  could be implemented in parallel with them by a different contributor, once Phase 2 is done
- T016 (new cubit test file) and T017 (extends `task_card_test.dart`) are marked [P] — different
  files, both prerequisites for T018/T019 respectively

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup) and Phase 2 (Foundational)
2. Complete Phase 3 (User Story 1)
3. **STOP and VALIDATE**: run T002/T005, then `quickstart.md` Scenario 1
4. The file-grouped view now shows sub-tasks nested under their parent — issue #31's core ask is
   resolved; multi-level legibility polish (Phase 4) and the regression safety net (Phase 5) can
   follow separately

### Incremental Delivery

1. Setup + Foundational → depth/parent computation ready and unit-tested
2. Add User Story 1 → validate → grouped view shows basic nesting (MVP)
3. Add User Story 2 → validate → deep/multi-level nesting stays legible and distinguishable
4. Add User Story 3 → validate → existing actions proven unaffected
5. Polish → full suite, manual iOS/Android parity pass
6. *(Increment 2, added via `/speckit-clarify` after the above shipped)* User Story 4 (Phase 8) →
   validate `quickstart.md` Scenarios 6–8 → collapse/expand available, per-task and per-file
7. Final Polish (Phase 9) → full suite, manual QA pass covering Scenarios 6–8

## Notes

- [P] tasks = different files, no dependency on an incomplete task
- Verify each test fails before implementing the task that makes it pass
- Stop at each checkpoint to validate that story independently before moving on
- FR-007 (no cross-file parent/child relationships) is structural, not a separate task — the
  depth/parent stack in T004 is local to a single `internalParseTasks` call by construction, so
  there is nothing to test beyond T002's existing per-file fixtures
- FR-010's "list view/calendar view stay flat" scope boundary is enforced entirely by which call
  sites pass a `depth` argument in T007 — `_createCalendarViews` and the flat list branch simply
  never do
- FR-016's "resets on reload" guarantee is unit-tested at the `clearCollapsedTasks()` level (T016),
  not by calling `refreshTasks()` end-to-end (see T018's note on the `TasksFileStorage.getInstance()`
  hazard) — that `refreshTasks()` actually calls `clearCollapsedTasks()` first is a one-line,
  code-reviewed fact rather than something a unit test exercises directly
