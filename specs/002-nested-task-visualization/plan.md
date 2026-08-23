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
│   └── inbox_tasks.dart                # _createTaskCard: accept/pass an optional depth param;
│                                        # _createFileViews: pass depth: task.depth (capped) when
│                                        # building each row; _createCalendarViews and the flat
│                                        # list-view path: unchanged, do not pass depth (FR-010)
└── widgets/
    └── task_card.dart                  # add optional `depth` param (default 0); render a small
                                         # left indent + one visual marker per depth level, capped
                                         # at a maximum visual depth

test/
├── task_manager_unit_test.dart         # or a new markdown_parser_unit_test.dart: unit tests for
│                                        # depth/parent computation (nested, skipped-level,
│                                        # no-preceding-task, mixed tabs/spaces fixtures)
└── ...                                 # existing suite otherwise unaffected
```

**Structure Decision**: Single existing Flutter project (`lib/src/core` / `screens` / `widgets`,
mirrored under `test/`). No new module, package, project boundary, or dependency — this is a
narrow, additive change: two derived fields on the existing `Task` entity, a small addition to the
existing single-pass markdown parser, and an optional visual parameter threaded through the
existing `TaskCard`/`_createFileViews` rendering path used only by the file-grouped view.
