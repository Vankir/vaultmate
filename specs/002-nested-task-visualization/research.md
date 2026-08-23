# Phase 0 Research: Nested Task Visualization

No items in the plan's Technical Context were left as `NEEDS CLARIFICATION` — the codebase
investigation below resolved every open question with a reasonable, low-risk default. This
document records those decisions for traceability.

## Decision 1: Where depth/parent are computed

**Decision**: Compute `depth` and `parentTaskId` inside `MarkdownParser._parseTasksByPattern`
(`lib/src/core/tasks/parsers/markdown_parser.dart`), as part of its existing single left-to-right
pass over a file's content — not as a separate post-processing pass, and not in `TaskManager`.

**Rationale**: `_parseTasksByPattern` already walks the file character-by-character in source
order and already discards leading whitespace via `_skipSpaces()` before recording `taskOffset`
(`markdown_parser.dart:67-68`). The only change needed is to measure that whitespace's width
*before* skipping it, and maintain a small stack of `(indentWidth, Task)` pairs as tasks are
appended to the per-file `tasks` list the method already builds. Since the method is called once
per file (via `internalParseTasks`), the stack naturally resets per file with no extra state to
manage, and per-file source order — which the stack algorithm depends on — is exactly what this
loop already produces.

**Alternatives considered**:
- *Separate post-processing pass over `TaskManager._tasks`*: would need to re-derive "same file, in
  source order" groupings that the parser already has for free while parsing, and would need
  access to each task's raw indentation, which is discarded today and would have to be
  re-extracted from the file content a second time. Rejected as strictly more work for the same
  result.
- *Compute depth in the UI layer from raw indentation stored on `Task`*: would require storing raw
  indentation and re-deriving the parent-chain (stack) logic again at render time, on every
  rebuild, in `inbox_tasks.dart` instead of once at parse time. Rejected — parsing is the natural,
  one-time place for this, and keeps `TaskCard`/`_createFileViews` simple (they just read an `int`).

## Decision 2: Depth is a parent-chain count, not raw indentation ÷ step size

**Decision**: A task's `depth` is `0` if it has no preceding task (in file order) with strictly
less indentation width; otherwise it is `parent.depth + 1`, where `parent` is the nearest such
preceding task. This is computed with a stack: pop while the stack's top has `indentWidth >=`
the current task's, then the (possibly now-empty) top is the parent.

**Rationale**: This is standard outliner/list-nesting behavior (the same algorithm Markdown list
renderers and outliner tools use) and is exactly what `spec.md`'s Edge Case 2 requires: a task
indented as if it were a grandchild, immediately after a top-level task with nothing indented
between them, must render as a direct child (depth 1), not stranded at depth 2 with no depth-1
task above it. Using raw indentation directly (e.g. `indentWidth ~/ 2`) would violate that edge
case whenever a note's indentation isn't perfectly uniform.

**Alternatives considered**:
- *`depth = indentWidth ÷ fixed step size`*: simpler, but breaks on any inconsistent indentation
  (common in hand-edited markdown) and fails Edge Case 2 above. Rejected.

## Decision 3: Indentation width normalization (tabs vs. spaces)

**Decision**: Count each space as 1 column and each tab as 4 columns when computing a task line's
`indentWidth`, purely for comparing indentation levels against each other within the stack
algorithm.

**Rationale**: `spec.md`'s edge cases require tolerating a note that mixes tabs and spaces across
its tasks without breaking the hierarchy. A fixed tab-stop-like conversion (4, matching common
markdown/editor conventions) gives consistent, comparable widths without requiring any
configuration. Since `depth` is a parent-chain count (Decision 2), not the raw width itself, the
exact constant only affects *which* preceding task counts as "less indented" in ambiguous
mixed-whitespace cases — it does not need to be pixel-perfect.

**Alternatives considered**: Treating tabs and spaces as incomparable (reject/ignore
mixed-indentation files) — rejected as unnecessarily strict for a real-world markdown vault where
this is common and harmless today (the existing parser already accepts either via `_skipSpaces`
treating `' '` and `'\t'` identically).

## Decision 4: Derived fields are not persisted or serialized

**Decision**: `Task.depth` and `Task.parentTaskId` are excluded from `Task.equals()`,
`Task.update()`, and `Task.toJsonMap()`.

**Rationale**: These fields are recomputed fresh every time a file is parsed; they are a function
of the file's current content, not user-entered data. Including them in `equals()` (used to detect
whether a task actually changed for save purposes) or in `toJsonMap()` (the shape read by the
home-screen widget sync path, confirmed via `task.dart`) would be incorrect — there is no markdown
syntax for "depth" to round-trip, and the widget surface has no use for it. This also means no
saver (`task_saver.dart`, `task_note_saver.dart`) needs to change at all — confirmed by inspection,
they operate purely on `taskSource.offset`/`length` and never touch these new fields.

## Decision 5: Visual depth cap

**Decision**: Track true, unlimited depth during parsing (so `SC-003` — no task is ever dropped —
holds regardless of how deep a note nests), but cap the *visual* indentation applied in
`TaskCard` at a fixed maximum level (5 levels), with anything deeper rendering at that same
maximum indent rather than continuing to shift further right.

**Rationale**: Directly satisfies `spec.md`'s edge case about narrow phone screens without ever
hiding or truncating a task. Five levels comfortably exceeds the reporter's own example (two
levels) while still leaving reasonable card width on a typical phone screen at the deepest level.

## Decision 6: Task ordering already satisfies adjacency (FR-005)

**Finding** (not a design decision, a verification): `TaskManager.filterTasks`
(`task_manager.dart:496-503`) filters with `.where(...).toList()`, preserving input order; no
`sortMode`-driven sort is wired to the task list anywhere in the codebase today (`sortMode` is
read/written via `SettingsController`/`SettingsService` but has zero call sites that reorder a
task list — the one UI reference in `inbox_tasks.dart` is commented out). `_createFileViews`
(`inbox_tasks.dart:700-737`) already groups strictly by "is this task's filename the same as the
previous task's filename", relying on same-file tasks being contiguous and in source order — which
`_parseTasksByPattern`'s single top-to-bottom pass already guarantees per file. This means no
sorting/grouping change is needed anywhere to satisfy FR-005 (parent and descendants stay
adjacent, in source order) — it is already true today for the existing flat rendering and remains
true unchanged once each task also carries a `depth`.
