# Feature Specification: Task List Swipe Actions

**Feature Branch**: `001-task-swipe-actions`

**Created**: 2026-08-18

**Status**: Draft

**Input**: User description: "swipe to left on task on today screen means tasks scheduled date should be changed to tomorrow, swipe to right on task on today screen means scheduled date should be removed, and task should be added to inbox, if swipe to left on task on inbox screen then task is scheduled for today, if task to right on inbox screen then confirmation to delete is requested and after confirmation task should be deleted. Button "Plus" and "Minus" should be removed because this functionality is replaced by swipe."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Postpone or unschedule a task from Today via swipe (Priority: P1)

On the Today screen, swiping a task left postpones it to tomorrow; swiping it right clears its
scheduled date and returns it to the Inbox.

**Why this priority**: This is the direct replacement for the existing "Minus" button, which is
today's primary way to remove a task from the daily list. It must work before the button can be
removed.

**Independent Test**: With at least one task scheduled for today, swipe it left and verify its
scheduled date becomes tomorrow and it no longer appears on today's list; swipe a different task
right and verify it disappears from Today and appears in the Inbox with no scheduled date.

**Acceptance Scenarios**:

1. **Given** a task is shown on the Today screen, **When** the user swipes the task left, **Then**
   the task's scheduled date changes to tomorrow's date and the task no longer appears on today's
   list.
2. **Given** a task is shown on the Today screen, **When** the user swipes the task right, **Then**
   the task's scheduled date is cleared and the task appears in the Inbox list.
3. **Given** a task's due date is today and the app is configured to always show due-today tasks
   on the Today screen, **When** the user swipes the task right, **Then** the task is not removed
   from Today and the user is shown why.

---

### User Story 2 - Schedule an inbox task for today via swipe (Priority: P1)

On the Inbox screen, swiping a task left schedules it for today, moving it onto the Today screen.

**Why this priority**: This is the direct replacement for the existing "Plus" button and the other
half of the daily inbox-to-today triage loop that User Story 1 completes.

**Independent Test**: With at least one unscheduled task in the Inbox, swipe it left and verify it
disappears from Inbox and appears on the Today screen.

**Acceptance Scenarios**:

1. **Given** a task is shown on the Inbox screen, **When** the user swipes the task left, **Then**
   the task's scheduled date is set to today and the task appears on the Today screen.

---

### User Story 3 - Delete an inbox task via swipe with confirmation (Priority: P2)

On the Inbox screen, swiping a task right asks the user to confirm deletion; confirming permanently
deletes the task, cancelling leaves it unchanged.

**Why this priority**: Explicitly requested and valuable, but it is a new, destructive capability
rather than a replacement of an existing control, so it can ship right after the core triage
gestures in User Story 1 and User Story 2.

**Independent Test**: On the Inbox screen, swipe a task right, confirm deletion, and verify the
task no longer appears anywhere in the app or in its source note. Repeat and cancel instead,
verifying the task is unchanged.

**Acceptance Scenarios**:

1. **Given** a task is shown on the Inbox screen, **When** the user swipes the task right, **Then**
   a confirmation prompt is shown before anything is deleted.
2. **Given** the delete confirmation prompt is shown, **When** the user confirms, **Then** the task
   is permanently removed from the list and from its source note.
3. **Given** the delete confirmation prompt is shown, **When** the user cancels, **Then** the task
   remains unchanged in the Inbox.

---

### User Story 4 - Discover swipe via a one-time onboarding hint (Priority: P3)

The first time a user opens the Today screen or the Inbox screen, and at least one task is shown,
one task row automatically and repeatedly nudges/shakes on its own so the swipe backgrounds (icon
and caption) behind it become briefly visible, and a short message explains that tasks can be
swiped left/right and what each direction does on that screen — without the user having to swipe or
read a separate help page. The nudge keeps repeating, with the message staying visible, for as long
as the screen is open and the user has not interacted with it; it stops as soon as the user taps
anywhere on the screen or swipes any task, and — once stopped that way — never plays again on that
screen.

**Why this priority**: Swipe replaces controls (Plus/Minus) that were always visible, so a returning
user has no visual cue that the gesture exists. This is a discoverability aid, not core
functionality — User Stories 1-3 must work correctly whether or not a user ever sees the hint.

**Independent Test**: On a fresh install (or with the "hint shown" state reset), open the Today
screen and verify a task row nudges on its own within a few seconds of the list appearing and keeps
nudging repeatedly, without any tap or swipe from the user. Tap anywhere on the screen and verify the
nudging and message stop immediately. Close and reopen the screen and verify the nudge does not
happen again. Repeat independently for the Inbox screen.

**Acceptance Scenarios**:

1. **Given** the Today screen has never shown the swipe hint before and at least one task is on the
   list, **When** the screen finishes loading, **Then** one task row automatically animates to
   partially reveal both of its swipe backgrounds (icon and caption) and then settles back, without
   requiring the user to touch it, and repeats this animation continuously rather than stopping
   after one cycle.
2. **Given** the Today or Inbox screen's hint is playing for the first time, **When** the nudge
   animation starts, **Then** a short, screen-specific text message is also shown explaining what
   swipe left and swipe right do on that screen (e.g., on Today: "Swipe left to move to tomorrow,
   swipe right to move to Inbox"; on Inbox: "Swipe left to schedule for today, swipe right to
   delete"), and that message remains visible for as long as the animation keeps repeating.
3. **Given** the swipe hint has already been dismissed once on a screen (by a tap or a swipe, per
   Scenarios 6 and 7), **When** the user opens that screen again (including after restarting the
   app), **Then** neither the nudge animation nor the explanatory message plays again on that
   screen.
4. **Given** the Today screen's hint has already been dismissed, **When** the user opens the Inbox
   screen for the first time, **Then** the Inbox hint (animation and message) still plays,
   independently of the Today screen's hint having already been shown.
5. **Given** a screen has no tasks when it first loads, **When** the screen loads, **Then** no hint
   animation or message plays (there is no row to animate); the hint MAY still play the next time
   that screen loads with at least one task, if it has not been dismissed yet.
6. **Given** the hint animation and message are repeating, **When** the user taps anywhere on the
   screen (not necessarily on the animated row), **Then** the animation stops and the message
   dismisses immediately, and the hint is treated as already shown.
7. **Given** the hint animation and message are repeating, **When** the user swipes any task before
   or during a repeat cycle, **Then** the animation stops and the message dismisses immediately, and
   the hint is treated as already shown.

---

### Edge Cases

- Swiping right on a Today task that is blocked from leaving Today by the due-today rule (see
  User Story 1, Scenario 3): the task stays and the user is told why.
- A task with an active recurrence rule is deleted or rescheduled via swipe: the swipe action
  affects only the current occurrence; the recurrence rule itself is never modified or removed by a
  swipe action. Because the next occurrence is only generated when an occurrence is marked done (not
  when it is deleted), deleting a recurring task's current occurrence via swipe stops the series —
  no further occurrences will be generated. This is expected behavior, not a defect: a user who
  wants to stop a recurring series can do so by deleting its current occurrence via swipe, and a
  user who wants the series to continue must complete (not delete) the occurrence.
- What happens when a swipe gesture is released before completing far enough to trigger the action
  (partial swipe)? The task snaps back and nothing changes.
- What happens when the user swipes another task while an earlier swipe's confirmation prompt (User
  Story 3) is still open? The confirmation prompt must be resolved (confirmed or cancelled) before
  another destructive swipe action can be started.
- What happens when a task is displayed in the grouped (file-grouped) or calendar view instead of the
  list view? The same swipe gesture on the same task produces the same outcome, with the same
  icon-plus-caption indicator, as in the list view.
- What happens if the user deletes/uninstalls-and-reinstalls the app, or clears its local data?
  The "hint already shown" state is local to the app installation, so the onboarding hint (User
  Story 4) is expected to play again after a reinstall or data clear, the same as any other
  first-run behavior.
- What happens if the task row selected for the onboarding hint is the one blocked from leaving
  Today by the due-today rule? The hint still plays on it — it only reveals the swipe backgrounds
  briefly, it does not perform a real swipe/dismiss, so the due-today guard is not relevant to the
  hint itself.
- What happens if the user navigates away from a screen (or the app) while its hint is still
  repeating, without ever tapping the screen or swiping a task? The hint is not treated as dismissed
  or shown; it resumes repeating (animation and message) from the start the next time that screen is
  opened with at least one task present.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Today screen MUST let a user swipe a task left to change that task's scheduled
  date to tomorrow.
- **FR-002**: The Today screen MUST let a user swipe a task right to clear that task's scheduled
  date and move it to the Inbox list.
- **FR-003**: The Today screen MUST NOT remove a task via right-swipe when existing today-visibility
  rules require it to stay (e.g., the task is due today and due-today tasks are configured to always
  show on Today), and MUST inform the user why the task stayed.
- **FR-004**: The Inbox screen MUST let a user swipe a task left to set that task's scheduled date
  to today, moving it to the Today screen.
- **FR-005**: The Inbox screen MUST let a user swipe a task right to request confirmation before
  deleting that task.
- **FR-006**: The system MUST permanently delete a task, including removing it from its source note,
  only after the user explicitly confirms; cancelling the confirmation MUST leave the task
  unchanged.
- **FR-007**: The Inbox screen's standalone "Plus" button MUST be removed, as its function is
  replaced by swipe-left.
- **FR-008**: The Today screen's standalone "Minus" button MUST be removed, as its function is
  replaced by swipe-right.
- **FR-009**: All swipe actions defined above MUST be available and behave identically on both iOS
  and Android.
- **FR-010**: Deleting or rescheduling a recurring task via swipe MUST affect only the current
  occurrence; the recurrence rule itself MUST NOT be modified or removed by a swipe action. Users
  MUST NOT be blocked from deleting the current occurrence of a recurring task via swipe, even
  though doing so stops the series from generating further occurrences (see Edge Cases).
- **FR-011**: All swipe actions defined above (FR-001, FR-002, FR-004, FR-005) MUST be available and
  MUST behave identically on the Today and Inbox screens regardless of the active view mode — list,
  grouped (file-grouped), or calendar.
- **FR-012**: Every swipe action's icon indicator MUST be shown together with a text caption
  describing the destination or action it performs (for example, "Tomorrow" for the postpone swipe,
  "Inbox" for the unschedule swipe, "Today" for the schedule-for-today swipe, and "Delete" for the
  delete-confirmation swipe). An icon MUST NOT be shown without its caption.
- **FR-013**: The Today screen and the Inbox screen MUST each, independently, automatically and
  repeatedly animate one task row, starting the first time that screen is opened with at least one
  task present, briefly and partially revealing that row's swipe backgrounds (icon and caption)
  without requiring the user to touch or swipe the row. This animation MUST keep repeating
  continuously — not stop after a single cycle — until it is dismissed per FR-016.
- **FR-014**: The system MUST NOT play the onboarding hint (animation and message together, see
  FR-013 and FR-017) on a screen again after it has been dismissed on that screen per FR-016; once
  dismissed, that "shown" state MUST persist locally across app restarts for that screen. If the
  hint began repeating on a screen but was not dismissed before the user left that screen (see Edge
  Cases), it MUST NOT be treated as shown, and MUST resume repeating the next time that screen is
  opened with at least one task present.
- **FR-015**: The onboarding hint, including while its animation is repeating, MUST NOT block,
  delay, or intercept the user's ability to swipe, tap, or scroll the task list.
- **FR-016**: If the user taps anywhere on a screen, or manually swipes any task on that screen,
  while that screen's onboarding hint is repeating, the system MUST stop the automatic animation
  immediately and dismiss the explanatory message immediately, and MUST treat that screen's hint as
  shown (see FR-014).
- **FR-017**: Alongside the repeating nudge animation, the onboarding hint MUST show a short text
  message explaining what swipe left and swipe right do on that specific screen (distinct wording
  for Today vs. Inbox, matching each screen's actual swipe actions and captions from FR-001,
  FR-002, FR-004, FR-005, and FR-012); this message MUST remain visible for as long as the animation
  keeps repeating, until dismissed per FR-016.

### Key Entities

- **Task**: Existing entity. This feature reads and writes its scheduled date and observes which
  list (Today or Inbox) it currently belongs to; both are changed as a direct result of a swipe
  action.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can move a task from Inbox to Today, or from Today back to Inbox/tomorrow, in
  a single gesture with no intermediate menu or dialog.
- **SC-002**: 100% of task deletions are preceded by an explicit confirmation step; a swipe-right
  gesture on Inbox never deletes a task without confirmation.
- **SC-003**: After this feature ships, the "Plus" and "Minus" buttons no longer appear anywhere in
  the task list UI.
- **SC-004**: The same swipe gesture on the same screen produces the same outcome on iOS and
  Android.
- **SC-005**: The same swipe gesture on the same screen produces the same outcome regardless of
  whether the screen is displayed in list, grouped, or calendar view.
- **SC-006**: Every swipe icon a user can see is accompanied by a readable text caption; no swipe
  indicator is icon-only.
- **SC-007**: A user opening the Today or Inbox screen for the first time (with at least one task
  present) sees an automatic hint — both the nudge animation and a screen-specific explanatory
  message — within a few seconds of the screen loading, with no tap required, and that hint keeps
  repeating until the user taps the screen or swipes a task; on every later visit to that screen
  (after the hint has been dismissed that way), neither the animation nor the message occurs again.

## Assumptions

- "Swipe left" means dragging the task row from right to left; "swipe right" means dragging from
  left to right — consistent with the existing Plus/Minus buttons being on the trailing edge of the
  row.
- Deletion has no separate "undo" mechanism beyond the confirmation prompt; the confirmation step is
  the safety net, consistent with standard swipe-to-delete patterns.
- The existing due-today visibility guard on the "Minus" button (a task due today is not removable
  from Today when "always show due-today tasks" is enabled) carries over unchanged to the
  swipe-right gesture on Today.
- Swiping left on Inbox reuses the existing "schedule for today" behavior, including overwriting any
  previously set scheduled date.
- A task shown on the Today screen because it is due (rather than because it is scheduled for today)
  can still be swiped left to be scheduled for tomorrow.
- "List", "grouped" (file-grouped), and "calendar" refer to the three existing view modes a user can
  switch between on the Today and Inbox screens. Swipe support previously existed only in list view;
  grouped and calendar views still showed the old Plus/Minus buttons. This feature extends swipe (and
  removes Plus/Minus) in those views too, per FR-011.
- The onboarding hint's "shown" state (FR-014) is stored locally on-device (e.g., alongside other
  app settings), consistent with this app's local-first, no-analytics design — it is not synced or
  tracked server-side, and naturally resets on reinstall or local-data clear (see Edge Cases).
- "One task row" for the hint (FR-013) means exactly one visible row per screen, chosen by the
  implementation (e.g., the first row); the spec does not require animating every row, only enough
  to make the gesture discoverable without being intrusive.
- The exact animation style (a small side-to-side nudge/shake, a brief partial slide-and-settle, or
  similar) is an implementation detail; the requirement is that it makes the swipe backgrounds
  (icon + caption) become briefly visible on both sides of the row without a real swipe/dismiss
  being triggered.
- The exact presentation of the explanatory message (FR-017) — e.g., a snackbar, a small banner
  near the animated row, or similar transient UI — is an implementation detail; the requirement is
  that it is a short, non-blocking text message, not a modal dialog the user must read and dismiss
  via a specific "got it" button. It stays on screen for as long as the animation repeats, and is
  dismissed by the same generic interactions that stop the animation (any tap on the screen, or a
  swipe, per FR-016) rather than by its own timeout.
- There is no maximum repeat count or timeout on the onboarding hint (FR-013): it keeps repeating
  indefinitely while the screen remains open and untouched, until the user taps the screen or swipes
  a task (FR-016). It is not expected to be intrusive because it is a small, partial, non-blocking
  animation, per FR-015.
