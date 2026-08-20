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

## Scenario 7 — Cross-view parity (FR-011, SC-005)

1. On the Today screen, switch view mode (tap the view-mode icon in the app bar) to **grouped**.
2. Confirm the per-row Minus button is not present, and swipe a task right.
   **Expected**: same outcome as Scenario 3 (task returns to Inbox, or is blocked with a message
   if due today).
3. Switch to **calendar** view. Swipe a task left.
   **Expected**: same outcome as Scenario 2 (task postponed to tomorrow).
4. Repeat steps 1–3 on the Inbox screen using Scenario 1 (swipe left → today) and Scenario 4
   (swipe right → confirm → delete) as the reference outcomes.
5. Confirm the Plus (Inbox) / Minus (Today) buttons are absent in **all three** view modes, not
   just list — this is the SC-003 gap `/speckit-analyze` flagged.

## Scenario 8 — Swipe captions (FR-012, SC-006)

1. On any screen/view mode, begin dragging a task row left or right without releasing.
2. **Expected**: the revealed background shows both an icon and a readable text caption
   underneath it — never an icon alone. Verify the caption matches the action: "Tomorrow" (Today
   swipe-left), "Inbox" (Today swipe-right), "Today" (Inbox swipe-left), "Delete" (Inbox
   swipe-right).

## Scenario 9 — Onboarding hint repeats until dismissed, once per screen (FR-013–FR-017, SC-007)

Prerequisite: a fresh install, or clear the app's local data / use the app's "reset" path if one
exists, so `swipe_hint_shown_today` / `swipe_hint_shown_inbox` are both unset.

1. Open the Today screen for the first time, with at least one task present.
   **Expected**: within a few seconds, one task row nudges on its own (no tap/swipe from you), and
   a SnackBar appears reading something like "Swipe left to move to tomorrow, swipe right to move
   to Inbox". Neither disappears on its own — the row keeps nudging (pausing briefly between
   nudges) and the SnackBar stays up indefinitely, for as long as you leave the screen alone.
2. Tap anywhere on the screen — the app bar, empty space, or a different (non-hinted) task row, not
   the nudging row itself.
   **Expected**: the nudge animation stops and the SnackBar dismisses immediately.
3. Fully close and reopen the app, return to the Today screen.
   **Expected**: no nudge, no SnackBar this time — the tap in step 2 marked the Today hint as shown.
4. Open the Inbox screen for the first time, with at least one task present.
   **Expected**: the hint plays here too (independently of Today's hint already being shown), with
   Inbox-specific wording, e.g. "Swipe left to schedule for today, swipe right to delete", and
   likewise repeats until dismissed.
5. Reset the local state again (or fresh install once more). This time, as soon as the Today
   screen's hint starts, manually swipe any task before tapping anywhere or waiting it out.
   **Expected**: the nudge animation and SnackBar stop immediately, your real swipe's action
   completes normally (per Scenario 1–4), and reopening the screen afterward shows no further
   automatic hint on Today.
6. Reset the local state once more. Open the Today screen, let the hint start, then navigate away
   (e.g. switch tabs or background the app) without tapping the screen or swiping.
   **Expected**: reopening the Today screen shows the hint again from the start — it was never
   marked shown, since it was never actually dismissed.
7. Repeat step 1 in **grouped** and **calendar** view mode (per Scenario 7) with the hint state
   reset.
   **Expected**: the hint still targets one row and behaves the same regardless of view mode.

## Automated coverage (see `tasks.md` once generated)

This quickstart is for manual/exploratory validation. Automated coverage lives in:
- `test/task_manager_unit_test.dart` — `scheduleForTomorrow`, `deleteTask` unit tests
- `test/src/screens/inbox_tasks/swipe_actions_test.dart` — widget tests for the four swipe
  behaviors, the due-today guard, the delete-confirmation flow, and Plus/Minus button removal

Scenarios 7–9 (Increments 2 and 3) are UI-composition changes in
`file_view.dart`/`calendar_view.dart`/`inbox_tasks.dart`/`settings_controller.dart`; per the same
`testWidgets()`/`loadTasks`-isolate-hang limitation documented for T009/T013 in `tasks.md`, they
are expected to be verified manually here rather than by a new widget test, unless `tasks.md`
records a different decision when generated. `SettingsController`'s new `swipeHintShown`/
`markSwipeHintShown` delegation (Increment 3) is simple enough to unit-test directly (no
`loadTasks`/isolate involvement), similar to how `TaskManager.scheduleForTomorrow`/`deleteTask`
are unit-tested in Increment 1 — `tasks.md` should decide whether to add that coverage.
