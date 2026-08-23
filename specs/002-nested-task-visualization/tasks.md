---

description: "Task list for Nested Task Visualization"
---

# Tasks: Nested Task Visualization

**Input**: Design documents from `/specs/002-nested-task-visualization/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/depth_computation_contract.md](./contracts/depth_computation_contract.md), [quickstart.md](./quickstart.md)

**Tests**: Included — Constitution Principle III (Test-First for Parsing & Business Logic,
NON-NEGOTIABLE) requires automated coverage for core logic changes (the new depth/parent
computation in `MarkdownParser`) and the `flutter test` CI gate, so test tasks are mandatory here,
not optional.

**Organization**: Tasks are grouped by user story (from `spec.md`) to enable independent
implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an incomplete task)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
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

### Within Each User Story

- Tests are written first and must fail before their corresponding implementation task
- Within Phase 3: `TaskCard` change (T006) before the call-site wiring that uses it (T007)
- Within Phase 4: the widget test proving the cap is missing (T008) before the clamp that fixes it (T009)

### Parallel Opportunities

- T002 (new parser tests, `test/markdown_parser_test.dart`) can be written in parallel with T003
  (new `Task` fields, `task.dart`) — different files; both are prerequisites for T004
- T005 (widget tests) and T008 (widget tests) both land in `test/src/widgets/task_card_test.dart`
  — write T005 first (Phase 3), extend the same file with T008's cases in Phase 4
- T010 and T011 are marked [P] — different test files, no shared state
- Phase 5 (User Story 3) has no file overlap with Phase 3/4 (`TaskCard`/`inbox_tasks.dart`) and
  could be implemented in parallel with them by a different contributor, once Phase 2 is done

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
