<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Rationale: MINOR — materially expanded guidance in Platform & Distribution Constraints requiring
  cross-platform (iOS + Android) feature parity; no principle was redefined or removed.
- Modified principles: none
- Modified sections: Platform & Distribution Constraints (strengthened to a hard parity requirement)
- Added sections: none
- Removed sections: none
- Templates checked for alignment:
  - .specify/templates/plan-template.md — generic Constitution Check gate, no updates needed
  - .specify/templates/spec-template.md — no constitution-specific references
  - .specify/templates/tasks-template.md — no constitution-specific references
  - .claude/skills/speckit-*/SKILL.md — read constitution at runtime, no hard-coded principle names to sync
- Follow-up TODOs: none

Previous entry (v1.0.0):
- Version change: (template, unratified) → 1.0.0
- Rationale: Initial ratification — no prior constitution existed, so this is a MAJOR (1.0.0) baseline rather than an amendment.
- Added sections:
  - Core Principles: I. Local-First & Privacy by Default; II. Obsidian Markdown Compatibility;
    III. Test-First for Parsing & Business Logic; IV. Branch & Release Discipline;
    V. Consistent State Management & Simplicity
  - Platform & Distribution Constraints
  - Development Workflow & Quality Gates
  - Governance
- Follow-up TODOs: none — all placeholders resolved from repo context (README.md, RELEASE_PROCESS.md,
  pubspec.yaml, lib/ and test/ layout); ratification date set to the date this document was authored,
  not the project's original creation date, per Spec Kit convention.
-->

# VaultMate Constitution

## Core Principles

### I. Local-First & Privacy by Default (NON-NEGOTIABLE)
User data (tasks, notes) MUST remain in the user's local Obsidian vault as plain markdown; the
app MUST NOT require or introduce a proprietary database as the source of truth. No analytics,
telemetry, or tracking SDKs may be added. Any feature that transmits vault content off-device
(sync, AI assistant) MUST be opt-in and clearly disclosed to the user.
Rationale: Local-first, privacy-first, no-vendor-lock-in is the core value proposition advertised
to users and the project's main differentiator from proprietary task managers.

### II. Obsidian Markdown Compatibility
Task and note parsing/writing MUST remain compatible with the plain-text conventions used by the
Obsidian Tasks, NoteTask, and Reminder community plugins (e.g. `- [ ]` checkboxes, `#tags`,
priority/date metadata). Changes to the parser or serializer MUST be validated against fixtures
covering these plugin formats before merging, and MUST NOT silently reformat or corrupt markdown
the user did not intend to change.
Rationale: Compatibility with the existing Obsidian plugin ecosystem is an advertised feature;
breaking it silently corrupts users' vaults, which is the worst possible failure mode for a
local-first app.

### III. Test-First for Parsing & Business Logic (NON-NEGOTIABLE)
Core logic under `lib/src/core` (task parsing, recurrence, scheduling) MUST have automated test
coverage under `test/`, and `flutter test` MUST pass before a PR merges into `develop` or `main`,
matching the `run_tests` CI gate. Bug fixes MUST include a regression test that fails before the
fix and passes after.
Rationale: Parsing and recurrence bugs directly corrupt user data. CI already runs `flutter test`
on every push/PR; this principle makes passing tests and regression coverage non-negotiable at
review time, not just a CI formality.

### IV. Branch & Release Discipline
`develop` is the integration branch; `main` is release-only and reflects a stable `develop` state.
Feature and bugfix work happens on branches cut from `develop` (`feature/*`, `bugfix/*`) and merges
back via pull request. Releases follow RELEASE_PROCESS.md: a version bump in `pubspec.yaml`
(`MAJOR.MINOR.PATCH+BUILD`, with a monotonically increasing build number) lands on `main`, tagged
`vX.Y.Z`, which triggers the automated build/release workflow.
Rationale: Encodes the project's existing, working release process so it is not bypassed ad hoc as
the team or contributor base grows.

### V. Consistent State Management & Simplicity
New features MUST use the project's established patterns (`flutter_bloc`/`bloc` for feature state,
`provider` where already used) rather than introducing a new state-management paradigm. Prefer the
simplest solution that fits the existing `lib/src` structure (`core`, `screens`, `widgets`) over new
abstractions. Adding a new third-party dependency requires a clear justification tied to a real,
current requirement — not a speculative future one.
Rationale: A small mobile app benefits from one consistent pattern; unjustified new dependencies or
abstractions increase app size, review burden, and long-term maintenance cost.

## Platform & Distribution Constraints

The app MUST be compatible with both iOS and Android. A user-facing feature MUST work on both
platforms before it is considered done; platform-exclusive features are permitted only when a
capability is genuinely unavailable on the other platform (e.g. an OS-level API), and MUST be
called out explicitly in the PR description along with the fallback/degraded behavior on the
platform that lacks it. Platform-specific implementation code (e.g. `android/`, `ios/`, home-screen
widget native code) MUST be kept behind a common Dart-level interface so the two platforms stay
interchangeable from the app's perspective. Home-screen widgets (Android and iOS) are a
first-class surface and MUST stay in sync with in-app task state — a change to task read/write
logic MUST consider its effect on both widget code paths. The project is licensed GPLv3;
contributions and any bundled dependency MUST be license-compatible with GPLv3.

## Development Workflow & Quality Gates

All changes MUST go through a pull request; there are no direct pushes to `main`. PRs into `main`
or `develop` MUST pass CI (`run_tests`) before merge. Commit messages SHOULD follow the
`feat:` / `fix:` / `chore:` / `docs:` convention already used in this repository's history and
documented in RELEASE_PROCESS.md.

## Governance

This constitution supersedes ad hoc practice for the areas it covers. Amendments are made by
editing `.specify/memory/constitution.md`, incrementing the version per semantic versioning
(MAJOR: incompatible principle removal or redefinition; MINOR: a new principle or materially
expanded guidance; PATCH: clarification or wording), and recording the change in the Sync Impact
Report comment at the top of this file. PRs that touch core parsing, the release process, or
state-management patterns MUST verify compliance with the relevant principle above; any deviation
MUST be called out and justified in the PR description. Use RELEASE_PROCESS.md for release-runtime
procedural detail this document does not restate.

**Version**: 1.1.0 | **Ratified**: 2026-08-18 | **Last Amended**: 2026-08-18
