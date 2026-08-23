# Quickstart: Validating Nested Task Visualization

Manual validation guide for `spec.md`'s user stories, once implementation is complete. Requires a
vault note you control (create a scratch note if you don't want to touch a real one).

## Setup

Create a note (e.g. `scratch-nested.md`) in your vault with:

```markdown
- [ ] Groceries
  - [ ] Cookies
    - [ ] Milk
    - [ ] Chocolate Chips
  - [ ] Cheese
  - [ ] Wine
- [ ] Errands
  - [ ] Pick up dry cleaning
  - [x] Drop off package
```

This mirrors the example from
[issue #31](https://github.com/Vankir/vaultmate/issues/31): two top-level tasks, one with a
second level of nesting under it ("Cookies" → "Milk"/"Chocolate Chips").

## Scenario 1 — Sub-tasks render nested in the grouped view (US1, FR-001–FR-005)

1. Open the app, switch the Today or Inbox screen to **grouped** (file-grouped) view mode, and
   locate `scratch-nested.md`'s card.
   **Expected**: "Groceries" and "Errands" render at the top level; "Cookies", "Cheese", "Wine",
   "Pick up dry cleaning", and "Drop off package" render indented directly under their respective
   parent, in the same order as the source note.
2. Compare against a note with no indentation at all.
   **Expected**: every task in that note renders exactly as it did before this feature, with no
   indentation.

## Scenario 2 — Multi-level depth is distinguishable (US2, FR-003, FR-004)

1. In the same grouped-view card, look at "Milk" and "Chocolate Chips" (children of "Cookies",
   which is itself a child of "Groceries").
   **Expected**: they render at a visibly deeper indentation level than "Cookies", with a depth
   marker distinguishing them from both "Cookies" (depth 1) and "Groceries" (depth 0).
2. Edit the note so a task is indented several levels deeper than its nearest actual parent
   task (e.g. a top-level task immediately followed by a task indented as if it were a
   grandchild, with nothing in between). Reload.
   **Expected**: the deeper task renders as a direct child (one level deeper than the task above
   it), not stranded at a depth with no visible parent line above it — see
   `contracts/depth_computation_contract.md`'s second example.

## Scenario 3 — Existing actions are unaffected (US3, FR-008, FR-009)

1. Mark "Milk" done (tap its checkbox).
   **Expected**: only "Milk"'s checkbox/strikethrough state changes; "Cookies", "Chocolate Chips",
   and every other task are unaffected. Reopen the note in Obsidian (or re-read the file) and
   confirm only Milk's line changed.
2. Mark "Cookies" (the parent) done.
   **Expected**: only "Cookies" changes; "Milk" and "Chocolate Chips" remain in their prior state.
3. On the Today or Inbox screen (list view, not grouped), swipe "Pick up dry cleaning" per the
   existing swipe actions (schedule/delete, from `001-task-swipe-actions`).
   **Expected**: only that task's line is changed or removed; "Errands", "Drop off package", and
   the rest of the note are untouched.

## Scenario 4 — List and Calendar views stay flat (FR-010)

1. Switch to **list** (flat) view mode and find any of the tasks from `scratch-nested.md`.
   **Expected**: no indentation — renders exactly as every other task in list view.
2. Give "Cookies" a scheduled date and switch to **calendar** view mode.
   **Expected**: "Cookies" renders in its date group with no indentation, same as before this
   feature.

## Scenario 5 — Nothing is dropped (SC-003)

1. Count the tasks in `scratch-nested.md` in the source note (8 tasks) versus what the grouped
   view renders for that file.
   **Expected**: all 8 appear — none hidden, merged, or silently dropped as a result of adding
   hierarchy.

## Scenario 6 — Collapse and expand a single task (US4, FR-012, FR-013, FR-015)

1. In the grouped view, find the collapse control on "Cookies" (it has children — "Milk" and
   "Chocolate Chips").
   **Expected**: tapping it hides "Milk" and "Chocolate Chips"; "Cookies" itself, "Cheese", "Wine",
   and everything in "Errands" remain visible and unaffected.
2. Tap the same control again.
   **Expected**: "Milk" and "Chocolate Chips" reappear, in the same order and at the same
   indentation as before.
3. Look at "Cheese", "Wine", "Pick up dry cleaning", and "Drop off package".
   **Expected**: none of them show a collapse control at all — they have no sub-tasks (FR-015).

## Scenario 7 — Collapse-all / expand-all for a file (US4, FR-014)

1. With "Cookies" expanded again (undo Scenario 6 if needed), use the file's collapse-all control
   (near the "File: scratch-nested.md" header).
   **Expected**: every sub-task in the file hides at once — only "Groceries" and "Errands" remain
   visible.
2. Use the file's expand-all control.
   **Expected**: all 8 tasks reappear, in their original order and depth.

## Scenario 8 — Collapse state resets on reload, never on an unrelated edit (FR-016)

1. Collapse "Cookies" again. Pull-to-refresh the screen (or fully restart the app).
   **Expected**: "Cookies" is expanded again — "Milk" and "Chocolate Chips" are visible, exactly as
   if it had never been collapsed.
2. Collapse "Cookies" once more. This time, mark "Drop off package" (an unrelated task, already
   done, in a different branch of the same file) as not-done, then done again.
   **Expected**: "Cookies" remains collapsed throughout — an ordinary task edit elsewhere must not
   reset anyone's collapse state.
