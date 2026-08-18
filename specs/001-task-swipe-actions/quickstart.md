# Quickstart: Validating Task List Swipe Actions

Manual end-to-end validation once the feature is implemented. Run on both a physical/simulated
iOS device and an Android device or emulator (Constitution: iOS/Android parity is required).

## Prerequisites

- A vault directory configured in the app (Settings → vault picker), containing at least:
  - one task with no scheduled date (will show in Inbox)
  - one task scheduled for today (will show on Today)
  - one recurring task (has a recurrence rule) scheduled for today, for the recurrence edge case
- `flutter run` on the target device/simulator (see `README.md` → Building from Source)

## Scenario 1 — Inbox: swipe left schedules for today (User Story 2, FR-004)

1. Open the Inbox screen.
2. Confirm the per-row Plus button (`Icons.add`) is no longer present on any task row.
3. Swipe an unscheduled task left.
4. **Expected**: the task disappears from Inbox and appears on the Today screen.

## Scenario 2 — Today: swipe left postpones to tomorrow (User Story 1, FR-001)

1. Open the Today screen.
2. Confirm the per-row Minus button (`Icons.remove`) is no longer present on any task row.
3. Swipe a task (not due today) left.
4. **Expected**: the task disappears from today's list. Advance the device clock (or check the
   task's scheduled date in the editor) to confirm it is now tomorrow.

## Scenario 3 — Today: swipe right clears schedule, returns to Inbox (User Story 1, FR-002/FR-003)

1. On the Today screen, swipe a task (not due today) right.
2. **Expected**: the task disappears from Today and appears in Inbox with no scheduled date.
3. Repeat with a task whose *due* date is today, with the "always show due-today tasks" setting
   enabled.
4. **Expected**: swiping right does not remove the task from Today; a message explains why.

## Scenario 4 — Inbox: swipe right asks for confirmation, then deletes (User Story 3, FR-005/FR-006)

1. On the Inbox screen, swipe a non-recurring task right.
2. **Expected**: a confirmation dialog appears before anything changes.
3. Cancel the dialog.
4. **Expected**: the task is still present and unchanged in Inbox.
5. Swipe the same task right again and confirm this time.
6. **Expected**: the task disappears from the app entirely; opening its source note in Obsidian
   (or the file view in-app) shows the task's line is gone and surrounding lines are untouched.

## Scenario 5 — Recurring task delete stops the series (Edge Case, FR-010)

1. On the Inbox screen, swipe the recurring task right and confirm deletion.
2. **Expected**: the current occurrence is deleted; no new occurrence is generated (contrast with
   marking a recurring task done, which does generate the next occurrence).

## Scenario 6 — Cross-platform parity (Constitution: Platform & Distribution Constraints)

Repeat Scenarios 1–4 on the other platform (if Scenario 1–5 were run on Android, repeat key steps
on iOS, or vice versa).

**Expected**: identical outcomes for the same gesture on the same screen on both platforms.

## Automated coverage (see `tasks.md` once generated)

This quickstart is for manual/exploratory validation. Automated coverage lives in:
- `test/task_manager_unit_test.dart` — `scheduleForTomorrow`, `deleteTask` unit tests
- `test/src/screens/inbox_tasks/swipe_actions_test.dart` — widget tests for the four swipe
  behaviors, the due-today guard, the delete-confirmation flow, and Plus/Minus button removal
