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

## UI contract: `Dismissible` wiring in `_wrapTaskCardWithSwipe` (`inbox_tasks.dart`)

*(Corrected from the original plan: the wiring below actually lives in a dedicated
`_wrapTaskCardWithSwipe` helper called from `_showListView`, not inside `_createTaskCard` — see
`research.md` "Outcome (superseded by Increment 2)" for why.)*

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

## UI contract addendum (Increment 2 — FR-011, FR-012)

- **View-mode parity**: `_wrapTaskCardWithSwipe` (above) MUST also be applied to each `TaskCard`
  rendered inside `_createFileViews` (grouped view) and `_createCalendarViews` (calendar view) in
  `inbox_tasks.dart`, immediately before that card is added to the list passed into `FileView`/
  `CalendarView`. `FileView.taskCards` and `CalendarView.taskCards` widen from `List<TaskCard>` to
  `List<Widget>` to accept the wrapped rows. Since `FileView.build()`/`CalendarView.build()` read
  `taskCards[0].task.taskSource?.fileName` / `taskCards[0].task.scheduled` directly off their own
  field (not just at construction — see `research.md`'s Increment 2 correction), each widget also
  gains a new required field — `FileView.fileName` (`String?`), `CalendarView.scheduledDate`
  (`DateTime?`) — computed by `_createFileViews`/`_createCalendarViews` from the still-unwrapped
  `TaskCard` group and passed in alongside the wrapped `taskCards` list; `build()` uses the new
  field instead of reading `.task` off a list element. The Plus/Minus button removal (previous
  section) MUST happen in grouped/calendar views too, once their rows go through the same
  button-less-copy mechanism `_wrapTaskCardWithSwipe` already applies in the list view.
- **Captions**: `_buildSwipeBackground` MUST render a caption `Text` under its `Icon` — "Tomorrow"
  (Today, swipe-left/`secondaryBackground`), "Inbox" (Today, swipe-right/`background`), "Today"
  (Inbox, swipe-left/`secondaryBackground`), "Delete" (Inbox, swipe-right/`background`) — in every
  view mode, since all view modes share the same `_wrapTaskCardWithSwipe`/`_buildSwipeBackground`
  call.

## `SettingsController.swipeHintShown(bool today) → bool` / `markSwipeHintShown(bool today) → Future<void>` (Increment 3)

- **Preconditions**: `SettingsController` has completed its init load (same precondition as every
  other cached setting, e.g. `showOverdueOnly`).
- **Effect**: `swipeHintShown` reads the cached `_swipeHintShownToday`/`_swipeHintShownInbox` field
  (selected by `today`); `markSwipeHintShown` sets the field to `true`, persists it via
  `SettingsService.updateSwipeHintShown(today, true)` (new `SharedPreferences` keys
  `swipe_hint_shown_today` / `swipe_hint_shown_inbox`), and calls `notifyListeners()` — same shape
  as `updateShowOverdueOnly`.
- **Postconditions**: Once `true`, stays `true` across app restarts until local app data is cleared
  or the app is reinstalled (see `data-model.md` Addendum, Increment 3).
- **Errors**: None beyond what `SharedPreferences` itself can raise; no new error handling.

## `InboxTasksCubit.swipeHintShown → bool` / `InboxTasksCubit.markSwipeHintShown() → Future<void>` (Increment 3)

- Thin pass-through to `SettingsController.getInstance()`'s methods above, selecting
  today-vs-inbox via the cubit's own `today` field — same delegation shape as the existing
  `showOverdueOnly` getter.

## UI contract addendum (Increment 3 — FR-013–FR-017, User Story 4)

- **Trigger**: On the first `_showListView`/`_createViewItems` build for a screen where
  `!_inboxTaskCubit.swipeHintShown` and `tasks.isNotEmpty`, the first rendered row is wrapped in a
  new `_SwipeHintRow` (`StatefulWidget`) instead of being rendered plain. All other rows are
  unaffected. In every subsequent build (hint already shown, or the row is not the first), rows
  render exactly as before — `_SwipeHintRow` is purely additive and never changes swipe behavior
  itself.
- **Animation**: After a short settle delay, `_SwipeHintRow` drives an `AnimationController` that
  nudges the wrapped row via `Transform.translate` (small horizontal oscillation, both directions,
  a couple of cycles) — this is a decorative overlay, not a real `Dismissible` drag, so it MUST NOT
  call any of the swipe-commit callbacks in the UI contract above.
- **Message**: At the same time, `_SwipeHintRow` calls
  `ScaffoldMessenger.of(context).showSnackBar(...)` with the screen-specific message text
  (Today: "Swipe left to move to tomorrow, swipe right to move to Inbox"; Inbox: "Swipe left to
  schedule for today, swipe right to delete") and a multi-second `duration` so it self-dismisses.
- **Completion / cancellation**: `_SwipeHintRow` calls `markSwipeHintShown()` exactly once — either
  when the nudge animation finishes normally, or immediately if the wrapped `Dismissible` reports a
  real drag/dismiss starting first (per FR-016), in which case the nudge animation and `SnackBar`
  are both cancelled/dismissed right away and the real swipe proceeds unaffected.
