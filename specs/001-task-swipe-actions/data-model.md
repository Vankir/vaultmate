# Phase 1 Data Model: Task List Swipe Actions

No new entity is introduced. This feature only changes how the existing `Task` entity's
`scheduled` field is written, and adds one new mutation (removal) that did not exist before.

## Entity: Task (existing — `lib/src/core/tasks/task.dart`)

Fields relevant to this feature (all pre-existing):

| Field | Type | Relevance to this feature |
|---|---|---|
| `scheduled` | `DateTime?` | Set to today / tomorrow / `null` by the four swipe actions. Determines whether the task appears on the Today screen (`scheduled` = today) or the Inbox screen (no scheduled date for today). |
| `due` | `DateTime?` | Read-only for this feature. When `due` is today and the app setting "always show due-today tasks" is on, the Today-screen swipe-right (unschedule) action is blocked — the existing guard already implemented in `InboxTasksCubit.removeFromTodayPressed`, reused unchanged for the swipe gesture. |
| `recurrenceRule` | `String?` | Read-only for this feature. Never modified or cleared by swipe actions (see `research.md` — deleting a recurring occurrence intentionally does not touch the rule). |
| `taskSource` | `TaskSource?` (`fileName`, `offset`, `length`, `fileNumber`) | Identifies exactly which line, in which file, this task came from. Required for the new delete action to know what to remove; `null` for a task with no on-disk source (should not occur for tasks reachable from Inbox/Today, which are always file-backed). |

No new field is added to `Task`. No new entity/table/model class is introduced.

## State Transitions

All transitions are driven by a swipe gesture on a `Task` row and persisted via the existing
`TaskManager.saveTask`/`saveTasks` path (see `contracts/task_manager_contract.md`).

```text
Inbox (scheduled = null or ≠ today)
   │  swipe-left on Inbox → scheduled = today
   ▼
Today (scheduled = today)
   │  swipe-left on Today  → scheduled = tomorrow  (leaves Today, not yet Inbox: reappears
   │                                                 on Today tomorrow)
   │  swipe-right on Today → scheduled = null       (back to Inbox)
   ▼
Inbox
   │  swipe-right on Inbox, confirmed → task removed entirely (see Deletion below)
   ▼
(gone)
```

Guard: swipe-right on Today is a no-op (task stays, message shown) when
`TaskManager.includeDueTasksInToday && TaskManager.sameDate(task.due, DateTime.now())` —
identical to the existing guard in `removeFromTodayPressed`.

## Deletion (new capability — no prior UI path existed)

Deleting a task removes its markdown line from its source file and drops it from the in-memory
task list. It does **not**:
- touch `recurrenceRule` or generate/suppress any other occurrence,
- touch any other task in the same file (identified precisely via `taskSource.offset`/`length`,
  the same mechanism the parser/saver already use to address individual tasks within a shared
  file).

This reuses the existing per-file rewrite approach in `TaskManager.saveTasks`: save the file's
task list with the deleted task excluded, exactly as an edit to that task's line would be saved,
just omitted instead of changed. No new persistence mechanism is introduced.
