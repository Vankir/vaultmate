# Contract: Collapse/Expand Rendering (Increment 2)

**Component**: `_createFileViews` (`lib/src/screens/inbox_tasks/inbox_tasks.dart`), reading
`InboxTasksCubit.isCollapsed`/`InboxTasksCubit._collapsedTaskIds`.

## Input

The same per-file, source-ordered, depth-tagged task list `_createFileViews` already consumes
(see `depth_computation_contract.md`), plus the cubit's current `_collapsedTaskIds` set.

## Output

For a given file's tasks, the subset that should actually be rendered as visible rows (in the
same relative order), and — for each rendered task — whether it has children and whether it is
currently collapsed.

## Algorithm contract

1. `suppressBelowDepth := null` (reset at the start of each file's task group).
2. For each task, in file order:
   a. `hasChildren := ` the next task in the overall list belongs to the same file and has
      `depth > task.depth` (see `depth_computation_contract.md`'s ordering guarantee).
   b. If `suppressBelowDepth != null`:
      - If `task.depth > suppressBelowDepth`: **skip** this task entirely (do not render it, do
        not add it to the file's rendered widget list). Continue to the next task.
      - Otherwise: `suppressBelowDepth := null` (we have returned to the collapsed ancestor's
        depth or shallower — this task is not inside that collapsed subtree). Fall through to (c).
   c. Render this task (pass `hasChildren`, `isCollapsed: cubit.isCollapsed(task)`, and a toggle
      callback to `TaskCard`).
   d. If `hasChildren && cubit.isCollapsed(task)`: `suppressBelowDepth := task.depth`.

## Examples (collapsed-id set → which tasks render, from the reporter's own example)

Source (depths in parens): `Groceries(0)`, `Cookies(1)`, `Milk(2)`, `Chocolate Chips(2)`,
`Cheese(1)`, `Wine(1)`, `Errands(0)`, `Pick up dry cleaning(1)`, `Drop off package(1)`.

- Collapsed = `{}` → all 9 render.
- Collapsed = `{Cookies}` → `Groceries, Cookies, Cheese, Wine, Errands, Pick up dry cleaning, Drop off package`
  render (7); `Milk` and `Chocolate Chips` are suppressed (depth 2 > 1 while `suppressBelowDepth == 1`).
- Collapsed = `{Groceries}` → `Groceries, Errands, Pick up dry cleaning, Drop off package` render
  (4); every task at depth ≥ 1 under `Groceries` is suppressed, because `suppressBelowDepth`
  doesn't reset until a task's depth drops back to ≤ 0, which only happens at `Errands`.
- Collapsed = `{Groceries, Errands}` (the result of `collapseAllInFile`) → only `Groceries` and
  `Errands` render (2) — both top-level tasks collapsed hides every descendant in the file.

## Non-goals

- Does not change `Task.depth`/`Task.parentTaskId` — collapsing is purely a rendering-time
  filter, never mutates parse results.
- Does not affect `_createCalendarViews` or the flat list-view branch — neither passes `depth` nor
  reads collapse state, so nothing in this contract applies to them (`FR-010`).
- Does not affect which tasks exist in `InboxTasksCubit._tasks` — a collapsed task's hidden
  descendants are still fully present in memory (and would still, for example, count toward
  `_taskDoneCount`/`_taskCount`), only their *rows* are withheld from `_createFileViews`'s output.
