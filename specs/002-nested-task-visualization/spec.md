# Feature Specification: Nested Task Visualization

**Feature Branch**: `002-nested-task-visualization`

**Created**: 2026-08-20

**Status**: Draft

**Input**: User description: "Nested task visualization: parse and preserve each task's indentation level so sub-tasks (indented checkbox lines under a parent checkbox line) are recognized as children of their parent task, and render them visually nested (indented, with a small vertical depth marker) wherever parent and children are shown together in the same list — starting with the file-grouped view. See https://github.com/Vankir/vaultmate/issues/31 for the original report and example markdown structure."

## Clarifications

### Session 2026-08-23

- Q: When you collapse a group, should that hide just that one task's direct sub-tasks, only make sense at the whole-file level, or should both granularities be available? → A: Both — per-task collapse toggles, plus a way to collapse everything in a file at once.
- Q: Should collapsed/expanded state be remembered after the app restarts or the note is refreshed, or should it reset back to fully expanded each time? → A: Reset to fully expanded on every reload — no persistence.
- Q: Should the depth markers (the small vertical bars indicating nesting level) also be announced to screen readers, or is visual-only acceptable for now? → A: Visual-only for now; explicitly deferred, known gap.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - See sub-tasks nested under their parent in the grouped view (Priority: P1)

A user keeps a note with a task broken down into indented sub-tasks (e.g. a "Groceries" checklist
with sub-items under it). When they open that note's tasks in the app's file-grouped view, the
sub-tasks appear visibly indented under their parent task, instead of as an undifferentiated flat
list where a sub-task looks identical to an unrelated top-level task.

**Why this priority**: This is the entire ask in the original report — without it, users who
structure their notes with sub-tasks cannot tell which tasks belong together at a glance, which is
the reported pain point.

**Independent Test**: Open a note containing a top-level task with one or more indented sub-tasks
under it in the file-grouped view, and verify the sub-tasks render indented beneath their parent,
visually distinct from top-level tasks in the same note.

**Acceptance Scenarios**:

1. **Given** a note contains a task line followed by one or more indented checkbox lines beneath
   it, **When** the user views that note's tasks in the file-grouped view, **Then** each indented
   line renders as a visually indented child directly under its parent task.
2. **Given** a note contains only top-level tasks (no indentation), **When** the user views that
   note's tasks in the file-grouped view, **Then** every task renders exactly as it does today,
   with no indentation applied.
3. **Given** a parent task has multiple sub-tasks, **When** the user views the grouped view,
   **Then** all of that parent's sub-tasks render adjacent to it and to each other, in the same
   order they appear in the source note.

---

### User Story 2 - Distinguish multiple levels of nesting (Priority: P2)

A user's checklist goes more than one level deep (e.g. a sub-task that itself has its own
sub-items). The app shows each level progressively more indented, with a visible marker per level,
so the user can tell how deep a given task is nested, not just that it is nested at all.

**Why this priority**: Extends User Story 1 to the reporter's actual example, which nests two
levels deep ("Cookies" → "Milk"/"Chocolate Chips"/etc.). Valuable but secondary to basic one-level
nesting working correctly first.

**Independent Test**: Open a note with at least three levels of indented checkbox tasks (parent →
child → grandchild) in the file-grouped view, and verify each level is visually distinguishable
from the others (e.g. progressively more indented, with a depth marker per level).

**Acceptance Scenarios**:

1. **Given** a note has a task, a sub-task under it, and a further sub-task under that sub-task,
   **When** the user views the grouped view, **Then** all three render at three visually distinct
   indentation levels.
2. **Given** a task is indented deeper than its logical parent would suggest by skipping a level
   (e.g. a top-level task is immediately followed by a task indented as if it were a
   grandchild), **When** the user views the grouped view, **Then** the deeper task is shown as a
   direct child of the nearest preceding task with a lower indentation level (its actual parent in
   the hierarchy), not stranded at a depth with no visible parent above it.

---

### User Story 3 - Existing task actions keep working unchanged on nested tasks (Priority: P3)

A user marks a sub-task done, edits it, or (on the Today/Inbox screens) swipes it to reschedule or
delete it — the same actions available on any other task. Nesting is purely visual: acting on a
child task never changes its parent's or siblings' status, and acting on a parent never cascades to
its children.

**Why this priority**: Protects existing functionality from regressing as a side effect of this
change. Lower priority than the visualization itself because it is a "nothing broke" story rather
than new value, but it is what makes shipping User Story 1/2 safe.

**Independent Test**: With a parent task and at least one child task both visible, mark the child
done and verify only the child's status changes; separately, mark the parent done and verify the
child's status is unaffected.

**Acceptance Scenarios**:

1. **Given** a parent task and a child task are both shown, **When** the user marks the child task
   done, **Then** only the child's status changes; the parent's status and the source file's other
   lines are unaffected.
2. **Given** a parent task and a child task are both shown, **When** the user marks the parent task
   done, **Then** only the parent's status changes; the child remains in its prior state.
3. **Given** a child task is shown on the Today or Inbox screen, **When** the user swipes it (per
   the existing swipe actions), **Then** only that child task's line is changed or removed; its
   parent and sibling tasks in the source note are unaffected.

---

### User Story 4 - Collapse and expand sub-task groups in the grouped view (Priority: P2)

A user viewing a note with many sub-tasks in the file-grouped view can collapse a specific task's
sub-tasks to reduce clutter, and expand them again; they can also collapse or expand every
sub-task group in a note at once, instead of one at a time. Reopening the note, or restarting the
app, always starts fresh with everything expanded.

**Why this priority**: Directly requested alongside the core visualization ask — once sub-tasks
are visible (User Story 1/2), a note with many of them can get long, and collapsing lets a user
focus on just the part of a checklist they are currently working on.

**Independent Test**: In a note with a task that has several sub-tasks, collapse that task and
verify its sub-tasks disappear from view while the task itself stays visible; expand it again and
verify they reappear in their original order and depth. Separately, use the note's collapse-all
control and verify every task's sub-tasks in that note hide at once; use expand-all to reverse it.

**Acceptance Scenarios**:

1. **Given** a task with one or more sub-tasks is shown in the grouped view, **When** the user
   collapses that task, **Then** its sub-tasks (and any further descendants) are hidden from the
   list, while the task itself remains visible.
2. **Given** a task's sub-tasks are currently collapsed, **When** the user expands that task
   again, **Then** its sub-tasks reappear in the same order and at the same depth as before
   collapsing.
3. **Given** a note has multiple separate tasks that each have their own sub-tasks, **When** the
   user collapses one of them, **Then** the others' sub-tasks remain visible and unaffected.
4. **Given** a note has one or more tasks with sub-tasks, **When** the user triggers collapse-all
   for that note, **Then** every task's sub-tasks in that note are hidden at once; expand-all
   reverses this for every task in that note.
5. **Given** a task has no sub-tasks, **When** the user views it in the grouped view, **Then** no
   collapse/expand control is shown for it.
6. **Given** any tasks in a note are currently collapsed, **When** the user reloads that note's
   tasks (e.g. app restart, pull-to-refresh, or reopening the screen), **Then** every task renders
   fully expanded again, regardless of its collapsed state before the reload.

---

### Edge Cases

- What happens when a non-task line (plain text, a note, a blank line) sits between a parent task
  and an indented child task line? The child is still recognized as belonging to the nearest
  preceding task line with a lower indentation level, ignoring non-task lines in between.
- What happens when an indented task line is the very first task in a file, with no preceding task
  at all? It has no possible parent, so it renders as a top-level task (no indentation), even
  though its raw markdown indentation might suggest otherwise.
- What happens when a note's sub-tasks are indented inconsistently (mixing tabs and spaces, or
  varying the number of spaces per level) within the same file? The system normalizes indentation
  so that any consistent increase in leading whitespace is treated as one additional level of
  depth; depth reflects the task's position in the resulting hierarchy, not the literal number of
  space characters.
- What happens when nesting goes deeper than can comfortably fit on a narrow phone screen? Visual
  indentation is capped at a maximum depth; tasks nested beyond that depth render at the same
  maximum indentation as the cap level rather than being pushed further off-screen.
- What happens when a child task's parent is filtered out of the currently displayed set (e.g. by
  an active search or tag filter that the parent doesn't match, but the child does)? The child
  still renders, at its recorded depth, rather than being hidden or silently promoted to
  top-level.
- What happens in the List view (flat) or Calendar view? Both continue to render every task exactly
  as they do today, with no indentation and no collapse/expand controls — nested visualization and
  collapsing are both scoped to the file-grouped view only for this feature (see Assumptions).
- What happens to an indented line that isn't a valid checkbox task (e.g. a plain sub-bullet note)?
  It is not parsed as a task today and continues not to be, exactly as before; it has no effect on
  the hierarchy of the actual tasks around it.
- What happens to collapse/expand state (User Story 4) when a note is reloaded, refreshed, or the
  app restarts? Every task returns to its default expanded state — collapse/expand state is not
  remembered across reloads (see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST determine each task's indentation level from its leading whitespace
  in the source note.
- **FR-002**: The system MUST determine a task's parent as the nearest preceding task, in the
  order tasks appear in the source note, that has a strictly lower indentation level; a task with
  no such preceding task MUST be treated as top-level (no parent).
- **FR-003**: The system MUST support recognizing more than one level of nesting (a task can be the
  child of a task that is itself a child of another task), matching however deep the source note's
  indentation actually goes.
- **FR-004**: The file-grouped (per-note) task view MUST render each task visually indented
  relative to its parent, with a visible marker for each level of depth between it and the
  top-level tasks in that note.
- **FR-005**: The file-grouped view MUST keep a parent task and all of its descendant tasks
  adjacent to one another, in the same relative order they appear in the source note.
- **FR-006**: Visual indentation MUST be capped at a maximum depth on narrow screens; tasks nested
  deeper than the cap MUST still render (at the capped indentation) rather than being hidden or
  truncated from the list.
- **FR-007**: A task's parent/child relationships MUST be derived only from other tasks within the
  same source note; tasks in different notes MUST NOT be treated as related to one another.
- **FR-008**: Marking a task done or not-done, editing a task, or performing any existing per-task
  action (including the swipe-based reschedule/delete actions on the Today and Inbox screens) MUST
  continue to act only on the exact task the user acted on; the system MUST NOT automatically
  change the status, schedule, or existence of that task's parent or children as a side effect.
- **FR-009**: Deleting a task MUST remove only that task's own line from its source note; a
  deleted task's parent and any children MUST remain present and unchanged, consistent with
  today's per-line delete behavior.
- **FR-010**: The List view (flat) and Calendar view MUST continue to render every task exactly as
  they do today, with no indentation applied — nested visualization is scoped to the file-grouped
  view for this feature.
- **FR-011**: If a task's parent is not present in the currently displayed/filtered set of tasks,
  the task itself MUST still render (at its recorded depth) rather than being hidden or requiring
  its parent to also be visible.
- **FR-012**: The file-grouped view MUST allow a user to collapse a task that has one or more
  sub-tasks, hiding that task's sub-tasks (and any of their own descendants) from the rendered
  list while keeping the task itself visible.
- **FR-013**: The file-grouped view MUST allow a user to expand a previously collapsed task,
  restoring its hidden sub-tasks to view in their original order and depth.
- **FR-014**: The file-grouped view MUST provide a way to collapse every collapsible task within a
  single note at once, and a way to expand them all again, without requiring the user to toggle
  each one individually.
- **FR-015**: A task with no sub-tasks MUST NOT display a collapse/expand control.
- **FR-016**: Collapse/expand state MUST NOT be persisted; every task MUST render fully expanded
  whenever its note's tasks are reloaded (e.g. app restart, manual refresh, or reopening the
  screen), regardless of its collapsed state before the reload.

### Key Entities

- **Task**: Existing entity. Gains an implicit position in a per-note hierarchy — a reference to
  its parent task (if any) and its resulting depth — derived from its own and other tasks'
  indentation within the same source note. No new user-facing data is entered or stored beyond
  what the note's existing markdown indentation already expresses.
- **Collapse/expand state**: Transient, per-task UI state scoped to the current viewing session
  (User Story 4). Not part of the `Task` entity, not persisted, and not derived from the note's
  content — it exists only in memory for as long as the user is viewing that note's tasks, and
  always resets on reload (see FR-016).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user viewing a note with sub-tasks in the file-grouped view can visually identify
  which tasks are children of which parent, for at least three levels of nesting depth, without
  opening the note in a separate editor to check the indentation themselves.
- **SC-002**: 100% of existing single-task actions (mark done/undone, edit, and the swipe-based
  reschedule/delete actions) continue to affect only the exact task acted on; parent or child
  status is never changed as an automatic side effect.
- **SC-003**: For any note containing nested checkbox tasks, every task (the parent and all of its
  descendants) still appears in the app after this change — none are dropped, merged, or hidden as
  a result of introducing hierarchy.
- **SC-004**: A user can tell how many levels deep a given task is nested without counting
  indentation spaces in the original note themselves.
- **SC-005**: A user can hide and later restore a specific task's sub-tasks, and can collapse or
  expand an entire note's sub-tasks at once, without leaving the grouped view or needing more than
  one action per task (or one action for "all").

## Assumptions

- The file-grouped (per-note) view is the only view that renders nested indentation in this
  iteration; the List and Calendar views are unaffected and continue to render every task flat, as
  today. Extending nesting to those views is a candidate follow-up, not in scope here.
- Existing per-task actions (mark done/undone, edit, and the swipe-based reschedule/delete actions
  from the already-shipped swipe-actions feature) are unchanged by this feature: they continue to
  operate on exactly the task the user acted on. Automatically cascading an action to a task's
  parent or children (e.g. "completing all sub-tasks marks the parent done") is a distinct,
  separate capability that is out of scope here and may be considered as its own future feature.
- A task's nesting is derived purely from its indentation relative to other tasks already present
  in the same note; it does not depend on any explicit metadata (an ID, a parent-reference tag)
  the user would have to add themselves — matching the plain markdown the original report's example
  already uses, with no changes required to how users write their notes.
- Nested-task recognition only applies to properly formatted checkbox task lines; indented
  plain-text bullets or notes that are not tasks are not part of the hierarchy and continue to be
  ignored, exactly as today.
- Visual indentation is capped at a reasonable maximum depth on narrow (mobile) screens, so very
  deeply nested notes remain legible rather than being pushed indefinitely off-screen.
- Collapse/expand state (User Story 4) is transient, in-memory only, and scoped to the current
  viewing session; it is not written to any settings storage and always resets to fully expanded
  when a note's tasks are reloaded. This mirrors the app's existing lack of persistence for other
  view-only state (e.g. scroll position), and avoids this feature needing any new persisted
  storage or settings key.
- The depth markers from FR-004 are not required to be screen-reader accessible in this iteration;
  this is a known, explicitly accepted gap (visual-only), not an oversight, and may be revisited in
  a future accessibility pass.
