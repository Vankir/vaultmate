# Phase 1 Data Model: Nested Task Visualization

## Entity: Task (extended)

`Task` (`lib/src/core/tasks/task.dart`) gains two derived, read-only-in-practice fields. Both are
computed exactly once, during parsing, and never change afterward for a given parse result.

| Field | Type | Default | Description |
|---|---|---|---|
| `depth` | `int` | `0` | Number of ancestor tasks between this task and the top level of its note. `0` means top-level (no parent). See research.md Decision 2 for the exact computation. |
| `parentTaskId` | `int?` | `null` | The `TaskSource.id` (same hash-based id already used by `getTaskByFileAndOffset` and swipe's `Dismissible` keys) of this task's parent, or `null` if `depth == 0`. Present for traceability/debugging; rendering only consumes `depth` (see below). |

**Validation rules**:
- `depth == 0` if and only if `parentTaskId == null`.
- `depth` and `parentTaskId` are only ever set by `MarkdownParser`. `TaskNoteParser`-produced
  tasks always have `depth == 0`, `parentTaskId == null` (a task note is always exactly one task
  per file — see `research.md` and `plan.md` Scope).
- Both fields are **excluded** from `Task.equals()`, `Task.update()`, and `Task.toJsonMap()` (see
  research.md Decision 4) — they are not part of a task's persisted identity or its
  home-screen-widget-synced representation.

**Relationships**:
- `parentTaskId` (when non-null) refers to another `Task` from the *same source file* only
  (`FR-007`). There is no cross-file parent/child relationship, and the model does not need to
  resolve `parentTaskId` back to a live `Task` object at render time — `depth` alone is sufficient
  for every requirement in `spec.md` (rendering indentation, and the "parent filtered out of view"
  edge case, since `depth` doesn't depend on the parent still being present in whatever list is
  currently being rendered).

**State transitions**: None. `depth`/`parentTaskId` are set once per parse and are not mutated by
any user action (marking done, editing, swipe reschedule/delete) — consistent with `FR-008`/`FR-009`
(actions never cascade to parent/children, because nothing in the action code paths reads or
writes these fields at all).

## No new persisted entities (Increment 1)

No other new entity is introduced by Increment 1. The feature is entirely a derived-attribute
addition to the existing `Task` entity plus a rendering change; it does not introduce a
"TaskGroup", "Hierarchy", or similar wrapper type — keeping with Constitution Principle V (prefer
the simplest solution that fits the existing structure).

## Increment 2: Collapse/expand state (User Story 4, FR-012–FR-016)

Not a `Task` field and not a new domain entity — a single piece of transient, session-scoped UI
state, owned by `InboxTasksCubit`:

| Field | Type | Default | Description |
|---|---|---|---|
| `_collapsedTaskIds` | `Set<int>` | `{}` (empty) | The `TaskSource.id`s of tasks whose sub-tasks are currently hidden. Membership only; a task's own id is added when the user collapses it and removed when expanded (or when the whole set is cleared). |

**Validation rules**:
- Only a task for which `hasChildren` is true (see `research.md` Decision 8) can meaningfully be
  added — the UI never offers a collapse control for a childless task (`FR-015`), but nothing
  prevents an id with no children from harmlessly sitting in the set (it would simply have no
  visible effect, since the suppress-cursor never triggers for a task with nothing to suppress).
- The set is cleared to empty inside `InboxTasksCubit.refreshTasks()` (`FR-016`) — never inside
  `tasksChangedListener()` (see `research.md` Decision 9 for why those two are different).

**Relationships**: None persisted. `_collapsedTaskIds` is read at render time by
`_createFileViews` (via `InboxTasksCubit.isCollapsed(task)`) purely to decide which rows to skip;
it is never written to `Task`, never serialized, and has no relationship to `depth`/`parentTaskId`
beyond being interpreted *using* those already-computed fields (Decision 7's suppress-cursor).

**State transitions**: `id` added on `toggleCollapsed(task)` when not already present (or removed
if already present — a toggle); `collapseAllInFile(fileName)` adds every collapsible task's id in
that file; `expandAllInFile(fileName)` removes every id belonging to that file; `refreshTasks()`
clears the entire set unconditionally.
