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

## No new entities

No other new entity is introduced. The feature is entirely a derived-attribute addition to the
existing `Task` entity plus a rendering change; it does not introduce a "TaskGroup",
"Hierarchy", or similar wrapper type — keeping with Constitution Principle V (prefer the simplest
solution that fits the existing structure).
