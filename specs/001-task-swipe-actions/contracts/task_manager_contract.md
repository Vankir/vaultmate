# Contract: TaskManager swipe-action methods

This app has no external/network API. The contract that matters here is the internal boundary
between the UI layer (`inbox_tasks.dart`, wrapped in `Dismissible`) and the business-logic layer
(`InboxTasksCubit` → `TaskManager`), the same boundary the existing Plus/Minus buttons already
cross via `assignForTodayPressed` / `removeFromTodayPressed`.

## `TaskManager.scheduleForTomorrow(Task task) → Future<void>`

- **Preconditions**: `task` is a valid, previously-loaded `Task`.
- **Effect**: Sets `task.scheduled` to tomorrow's date (today + 1 day, same time-of-day handling
  as the existing `scheduleForToday`). If `task.taskSource != null`, persists via `saveTask`.
- **Postconditions**: Task no longer appears on today's Today-screen list; it will appear on the
  Today screen tomorrow. `recurrenceRule` is unchanged. Callers are notified via the existing
  `TaskManager` → `ChangeNotifier` → `notifyListeners()` path (inherited from `saveTask`).
- **Errors**: None beyond what `saveTask` already raises (e.g. underlying file write failure);
  no new error handling is introduced.

## `TaskManager.deleteTask(Task task) → Future<void>`

- **Preconditions**: `task.taskSource != null` (a file-backed task; this is always true for tasks
  reachable from the Inbox/Today screens).
- **Effect**: Removes the task's line from its source file (via `taskSource.offset`/`length`) and
  drops it from the in-memory task list. Does not modify `recurrenceRule` or any other task in the
  file.
- **Postconditions**: Task no longer appears anywhere in the app. If the task had an active
  recurrence rule, no further occurrences will be generated (documented, intentional — see
  `research.md`).
- **Errors**: None beyond what the underlying file write already raises.

## `InboxTasksCubit.postponeToTomorrowPressed(Task task) → void`

- Thin pass-through to `TaskManager.scheduleForTomorrow(task)`, mirroring the existing
  `assignForTodayPressed`/`removeFromTodayPressed` shape.
- Only wired on the Today screen (swipe-left).

## `InboxTasksCubit.removeFromTodayPressed(Task task) → void` (existing, reused)

- Already implements the due-today guard required for Today-screen swipe-right (see
  `data-model.md`). No behavior change — only its trigger changes, from a Minus button tap to a
  `Dismissible` swipe-right.

## `InboxTasksCubit.assignForTodayPressed(Task task) → void` (existing, reused)

- No behavior change — only its trigger changes, from a Plus button tap to a `Dismissible`
  swipe-left on Inbox.

## `InboxTasksCubit.deleteTaskPressed(Task task) → Future<void>`

- Pass-through to `TaskManager.deleteTask(task)`. Called only after the UI-layer confirmation
  dialog (triggered from `Dismissible.confirmDismiss` on Inbox swipe-right) resolves to confirmed;
  the cubit method itself does not show UI and assumes confirmation already happened.

## UI contract: `Dismissible` wiring in `_createTaskCard` (`inbox_tasks.dart`)

- **Today screen** (`_inboxTaskCubit.today == true`):
  - `direction: DismissDirection.horizontal`
  - swipe-to-left (`DismissDirection.endToStart`) → `postponeToTomorrowPressed(task)`
  - swipe-to-right (`DismissDirection.startToEnd`) → `removeFromTodayPressed(task)`, gated by the
    existing due-today guard (which returns a message + does not remove the row when blocked, so
    `confirmDismiss` must return `false` in that case to snap the row back)
- **Inbox screen** (`_inboxTaskCubit.today == false`):
  - swipe-to-left (`DismissDirection.endToStart`) → `assignForTodayPressed(task)`
  - swipe-to-right (`DismissDirection.startToEnd`) → `confirmDismiss` shows the delete
    confirmation `AlertDialog`; only on explicit confirm does it return `true` and call
    `deleteTaskPressed(task)`; on cancel it returns `false` and the row snaps back unchanged.
- The per-row `rightButtonIcon`/`rightButtonPressed` on `TaskCard` (currently `Icons.add` on
  Inbox rows, `Icons.remove` on Today rows, set in `_createTaskCard`) is removed once the
  corresponding swipe path is implemented. This is the row-level Plus/Minus button being
  replaced — **not** the screen's `FloatingActionButton` (`_showActionButton`, `Icons.add`), which
  creates a brand-new task and is out of scope for this feature.
