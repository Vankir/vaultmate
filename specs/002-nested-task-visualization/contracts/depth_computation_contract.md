# Contract: Task Depth Computation

**Component**: `MarkdownParser._parseTasksByPattern` (`lib/src/core/tasks/parsers/markdown_parser.dart`)

## Input

A markdown file's content, parsed top-to-bottom exactly as today (unchanged tokenization of
`- [ ]`/`* [ ]`/`+ [ ]` checkbox lines). The only new input actually *used* (it already exists in
the content, it just wasn't measured before) is each task line's leading whitespace, up to but not
including the task marker (`-`/`*`/`+`).

## Output

Every `Task` returned by `internalParseTasks` for that file additionally carries:
- `depth: int` (≥ 0)
- `parentTaskId: int?` (the `TaskSource.id` of another `Task` in the same returned list, or `null`)

## Algorithm contract

1. For each task line, compute `indentWidth` = (count of leading spaces) + 4 × (count of leading
   tabs), measured over exactly the whitespace `_skipSpaces` already consumes before the task
   marker.
2. Maintain a stack of `(indentWidth, Task)`, initially empty, scoped to the current file only.
3. For each task, in the order it is encountered:
   a. Pop the stack while it is non-empty and `stack.top.indentWidth >= indentWidth`.
   b. If the stack is now empty: `depth = 0`, `parentTaskId = null`.
   c. Otherwise: `depth = stack.top.task.depth + 1`, `parentTaskId = stack.top.task.taskSource.id`.
   d. Push `(indentWidth, thisTask)`.
4. Non-task lines (including indented plain-text/non-checkbox lines) never enter the stack and
   have no effect on it — exactly as today, they are simply not tasks.

## Examples (input → expected `depth` per task, in order)

```markdown
- [ ] Cookies
  - [ ] Milk
  - [ ] Chocolate Chips
- [ ] Cheese
```
→ Cookies: 0, Milk: 1, Chocolate Chips: 1, Cheese: 0

```markdown
- [ ] Top level
    - [ ] Skips visually to "grandchild" indentation, but has no depth-1 task above it
```
→ Top level: 0, second task: **1** (its nearest less-indented preceding task is "Top level" at
depth 0 — see `research.md` Decision 2; it is never assigned depth 2)

```markdown
    - [ ] Indented, but it's the very first line in the file
- [ ] Then a top-level task
```
→ first task: 0 (no preceding task exists at all, so it cannot have a parent regardless of its own
indentation), second task: 0

```markdown
- [ ] Parent
  Some plain note text, not a checkbox
  - [ ] Child
```
→ Parent: 0, Child: 1 (the plain-text line is not a task, is never pushed to the stack, and has no
effect on Child's parent resolution)

## Non-goals (explicitly not covered by this contract)

- `TaskNoteParser` output is untouched — always `depth: 0`, `parentTaskId: null` (out of scope,
  see `plan.md`).
- No markdown is rewritten; this is a pure read-side computation. `task_saver.dart` and
  `task_note_saver.dart` are not touched by this feature.
- Cross-file parent/child relationships are impossible by construction (the stack is local to a
  single `internalParseTasks` call).
