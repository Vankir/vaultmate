# Implementation Plan: Nested Task Visualization

**Branch**: `002-nested-task-visualization` | **Date**: 2026-08-20 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-nested-task-visualization/spec.md`

## Summary

Compute each markdown checkbox task's nesting depth from its indentation relative to other tasks
in the same note, at parse time, and use that depth purely to indent rows (with a per-level visual
marker) in the file-grouped task view. Depth/parent are derived, in-memory only — never written
back to the note's markdown and never part of the task's persisted/serialized identity — so there
is no new markdown syntax, no round-trip risk, and no change to any existing save/delete/swipe
action, which continue to operate on exactly the task line they always did.

**Increment 2 (FR-012–FR-016, User Story 4 — added to spec.md via `/speckit-clarify` after
Increment 1 shipped)**: Adds per-task collapse/expand and per-file collapse-all/expand-all to the
file-grouped view. Collapse state is transient, in-memory-only `Set<int>` of `TaskSource.id`s on
`InboxTasksCubit`, deliberately never routed through `SettingsController`/`SettingsService` (no
persistence, per clarification) and explicitly cleared in `refreshTasks()` so it resets on app
resume and pull-to-refresh. Hiding a collapsed task's descendants reuses the already-computed,
already-ordered `depth` field from Increment 1 — no new tree/graph structure is built; `_createFileViews`
tracks a single "suppress rows deeper than X" cursor while it already iterates each file's tasks in
order. No `TaskManager`/parser change is needed — this is additive cubit state plus rendering logic.

## Technical Context

**Language/Version**: Dart (SDK `>=3.0.0`), Flutter 3.35.1 / Dart 3.9.0 (per CI in
`.github/workflows/main.yml`, documented in `RELEASE_PROCESS.md`)

**Primary Dependencies**: Flutter SDK only. No new third-party package is added.

**Storage**: Local markdown files in the user's Obsidian vault, read via the existing
`TaskManager`/`MarkdownParser` layer. Depth/parent are computed in memory during parsing and are
never written back to a file — N/A for persisted storage.

**Testing**: `flutter_test` (existing dev dependency): unit tests for the new indentation/depth
computation (mirroring `test/task_manager_unit_test.dart`'s fixture-based style), covering the
skipped-level and no-preceding-task edge cases from `spec.md`.

**Target Platform**: iOS and Android via Flutter (single codebase, no platform-specific code —
this is pure parsing logic plus a widget-layout change).

**Project Type**: Mobile app (existing single Flutter project — `lib/src/{core,screens,widgets}`).

**Performance Goals**: Depth computation is a single additional O(1)-per-task stack operation
already inside the existing single-pass, per-file parse loop (`MarkdownParser._parseTasksByPattern`)
— no additional pass over file content, no measurable overhead versus today.

**Constraints**: Must remain fully offline/local-first (no network call introduced); must not
change the on-disk markdown format (Constitution Principle II) — depth/parent are derived fields,
never serialized back to a note.

**Scale/Scope**: One parser (`MarkdownParser`), one model addition (`Task.depth`,
`Task.parentTaskId`), one widget (`TaskCard`) gains an optional visual parameter, one view builder
(`_createFileViews` in `inbox_tasks.dart`) passes it through. `TaskNoteParser` (the other existing
parser, one task per file, no checkboxes) is out of scope — nesting is a markdown-checkbox-only
concept. List view and Calendar view are explicitly out of scope per FR-010 — they keep calling
`_createTaskCard` without depth, so they render exactly as before with zero code path changes to
their own rendering logic.

**Increment 2 Scale/Scope**: One new in-memory field (`Set<int>` on `InboxTasksCubit`) plus three
new cubit methods (`isCollapsed`, `toggleCollapsed`, `collapseAllInFile`/`expandAllInFile`); two new
optional `TaskCard` parameters (`hasChildren`, `isCollapsed`, `onToggleCollapse`) rendering one
extra leading `IconButton` when applicable; two new optional `FileView` parameters
(`onCollapseAll`/`onExpandAll` callbacks, shown only when the file has at least one collapsible
task) rendering one extra header control. `_createFileViews` gains a single-pass suppress-cursor
(an `int?` tracking "hide rows deeper than X") and a same-file-bounded lookahead to determine
`hasChildren` per task. No `TaskManager`, parser, or `Task` model change.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status |
|---|---|---|
| I. Local-First & Privacy by Default | Purely local parsing/rendering; no analytics/telemetry/network calls introduced. | PASS |
| II. Obsidian Markdown Compatibility | No new markdown syntax invented; `depth`/`parentTaskId` are derived at parse time and never written back to a note (not part of `Task.toJsonMap()`, not touched by any saver). Existing checkbox parsing (`- [ ]`, `* [ ]`, `+ [ ]`) and its filter/tag handling are unchanged — only the previously-discarded leading-whitespace width is now also recorded. | PASS |
| III. Test-First for Parsing & Business Logic | New parsing logic (indentation-width measurement, parent/depth stack algorithm) lives in `lib/src/core` and requires unit test coverage before merge, per the spec's edge cases (skipped indentation levels, no preceding task, mixed tabs/spaces). | PASS (enforced at task-generation/implementation phase) |
| IV. Branch & Release Discipline | Work happens on `002-nested-task-visualization`, cut from `main`, merged via PR. | PASS |
| V. Consistent State Management & Simplicity | Reuses the existing `Task`/`TaskCard`/`_createFileViews` patterns; adds two plain fields to `Task` and one optional parameter to `TaskCard`, no new widget class, no new state-management pattern, no new dependency. | PASS |
| Platform & Distribution Constraints | Pure Dart/Flutter, inherently identical on iOS/Android. `depth`/`parentTaskId` are never added to `Task.toJsonMap()` (the shape read by the home-screen widget sync path), so the widget code paths are untouched by this feature. | PASS |
| Development Workflow & Quality Gates | PR into `main`, CI (`run_tests`) must pass. | PASS |

No violations requiring the Complexity Tracking table.

**Post-Design Re-Check** (after Phase 1 — `research.md`, `data-model.md`, `contracts/`,
`quickstart.md`): No new entity, dependency, or architectural layer was introduced during design.
The depth/parent computation was confirmed to fit inside `MarkdownParser`'s existing single-pass,
per-file loop with no second pass over file content, and task ordering was confirmed (by reading
`TaskManager.filterTasks`/`loadTasks`) to already preserve per-file source order with no active
re-sort — so the file-grouped view's existing adjacency-by-consecutive-filename grouping needs no
change to satisfy FR-005 (parent/children stay adjacent, in source order). All gates above still
PASS; no violations.

### Increment 2 Constitution Re-Check (FR-012–FR-016, User Story 4)

| Principle | Check | Status |
|---|---|---|
| I. Local-First & Privacy by Default | Collapse state is an in-memory `Set<int>`; no analytics, no network, no new storage of any kind. | PASS |
| II. Obsidian Markdown Compatibility | No `Task`/parser/saver interaction at all — collapse/expand never reads or writes vault content, only which already-parsed rows get rendered. | PASS |
| III. Test-First for Parsing & Business Logic | No `lib/src/core` change. The suppress-cursor/lookahead logic lives in `inbox_tasks.dart` (UI layer) and the collapse `Set` lives in `InboxTasksCubit`; both get widget/unit-level coverage in `tasks.md`, consistent with how Increment 1's `TaskCard` depth rendering was tested. | PASS |
| IV. Branch & Release Discipline | Same branch (`002-nested-task-visualization`), same PR flow. | PASS |
| V. Consistent State Management & Simplicity | Reuses the existing `InboxTasksCubit`/`emit()`-via-`_applySearchFilter()` pattern for triggering rebuilds — no new state-management approach, no new dependency, no new persistence key (the clarification explicitly rejected persisting this). | PASS |
| Platform & Distribution Constraints | Pure Dart/Flutter widget-and-cubit change; no platform-exclusive code; no interaction with the home-screen widget code paths (collapse state is never part of `Task`/`toJsonMap()`). | PASS |
| Development Workflow & Quality Gates | PR into `main`, CI (`run_tests`) must pass. | PASS |

No violations requiring the Complexity Tracking table.

## Project Structure

### Documentation (this feature)

```text
specs/002-nested-task-visualization/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/src/
├── core/tasks/
│   ├── task.dart                       # add depth (int, default 0), parentTaskId (int?, nullable)
│   │                                    # — plain fields, excluded from equals()/update()/
│   │                                    # toJsonMap() (derived, not persisted/serialized state)
│   └── parsers/
│       └── markdown_parser.dart        # _parseTasksByPattern: measure leading-whitespace width
│                                        # before it is skipped; maintain a depth stack per file
│                                        # to assign each task's depth/parentTaskId as it's parsed
├── screens/inbox_tasks/
│   ├── inbox_tasks.dart                # _createTaskCard: accept/pass an optional depth param;
│   │                                    # _createFileViews: pass depth: task.depth (capped) when
│   │                                    # building each row; _createCalendarViews and the flat
│   │                                    # list-view path: unchanged, do not pass depth (FR-010)
│   │                                    # [Increment 2] _createFileViews: add a suppress-cursor
│   │                                    # pass hiding a collapsed task's descendant rows; compute
│   │                                    # per-task hasChildren via same-file lookahead; wire
│   │                                    # TaskCard's new collapse params and FileView's new
│   │                                    # collapse-all/expand-all callbacks to the cubit
│   ├── file_view.dart                  # [Increment 2] add optional onCollapseAll/onExpandAll
│   │                                    # callbacks + whether to show them; render one small
│   │                                    # header control when the file has a collapsible task
│   └── cubit/
│       └── inbox_tasks_cubit.dart      # [Increment 2] add in-memory Set<int> _collapsedTaskIds;
│                                        # isCollapsed/toggleCollapsed/collapseAllInFile/
│                                        # expandAllInFile; clear the set inside refreshTasks()
│                                        # (not tasksChangedListener, which also fires on every
│                                        # ordinary task edit/save - see research.md)
└── widgets/
    └── task_card.dart                  # add optional `depth` param (default 0); render a small
                                         # left indent + one visual marker per depth level, capped
                                         # at a maximum visual depth
                                         # [Increment 2] add optional hasChildren/isCollapsed/
                                         # onToggleCollapse params; render one leading IconButton
                                         # (chevron) when hasChildren && onToggleCollapse != null

test/
├── task_manager_unit_test.dart         # or a new markdown_parser_unit_test.dart: unit tests for
│                                        # depth/parent computation (nested, skipped-level,
│                                        # no-preceding-task, mixed tabs/spaces fixtures)
│                                        # [Increment 2] regression tests: collapsing/expanding
│                                        # never mutates a task's status/schedule/existence
├── src/widgets/task_card_test.dart     # [Increment 2] hasChildren/isCollapsed/onToggleCollapse
│                                        # rendering + tap-to-toggle widget tests
├── src/screens/inbox_tasks/            # [Increment 2] new or extended cubit test file:
│                                        # isCollapsed/toggleCollapsed/collapseAllInFile/
│                                        # expandAllInFile behavior, and the refreshTasks()-clears-
│                                        # collapse-state guarantee (FR-016)
└── ...                                 # existing suite otherwise unaffected
```

**Structure Decision**: Single existing Flutter project (`lib/src/core` / `screens` / `widgets`,
mirrored under `test/`). No new module, package, project boundary, or dependency — this is a
narrow, additive change: two derived fields on the existing `Task` entity, a small addition to the
existing single-pass markdown parser, and an optional visual parameter threaded through the
existing `TaskCard`/`_createFileViews` rendering path used only by the file-grouped view. Increment
2 adds one new piece of transient UI state (`InboxTasksCubit`) and two more optional widget
parameters (`TaskCard`, `FileView`); still no new file, module, or dependency.
