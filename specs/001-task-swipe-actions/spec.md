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
