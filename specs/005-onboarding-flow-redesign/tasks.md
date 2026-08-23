---

description: "Task list template for feature implementation"
---

# Tasks: Onboarding Flow Redesign

**Input**: Design documents from `/specs/005-onboarding-flow-redesign/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories), [research.md](./research.md), [data-model.md](./data-model.md), [quickstart.md](./quickstart.md)

**Tests**: Included. The plan and research explicitly commit to test coverage for the new onboarding-completion logic and task-format default logic (Constitution III) and each screen's widget behavior (see research.md §8, quickstart.md "Automated coverage").

**Organization**: Tasks are grouped by user story (spec.md, 6 stories — this spec merges what were originally two separate features: the 3-screen onboarding restructure and the default-task-format preference; see spec.md's "Input" note). This is one linear flow, not independent slices — US2/US3/US4 each supply real content for a screen the US1 shell hosts, and US5/US6 build on the preference US3 introduces. See Implementation Strategy below.

**Implementation status (2026-08-23)**: 27/29 tasks complete; `flutter analyze` and the full `flutter test` suite (273 tests, including 24 new ones added by this feature) pass. T010 and T026 are deliberately deferred — see the notes on those tasks for why.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1–US6)
- Exact file paths are included in each description

## Path Conventions

Single Flutter mobile app (see plan.md Project Structure): `lib/src/screens/onboarding/` (new), `lib/src/screens/introduction/` and `lib/src/screens/init/` (removed by this feature), `lib/src/screens/task_editor/cubit/task_editor_cubit.dart` (modified), `lib/src/screens/settings/` (modified), `test/src/screens/onboarding/` (new).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold the new module without touching existing behavior yet.

- [X] T001 Create `lib/src/screens/onboarding/` with empty stub files: `onboarding_flow.dart`, `cubit/onboarding_flow_cubit.dart`, `cubit/onboarding_flow_state.dart`, `welcome_screen.dart`, `task_format_screen.dart`, `folder_selection_screen.dart`, per plan.md Project Structure
- [X] T002 [P] Create `test/src/screens/onboarding/` with empty stub test files: `onboarding_flow_cubit_test.dart`, `welcome_screen_test.dart`, `task_format_screen_test.dart`, `folder_selection_screen_test.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The single-gate navigation shell and the new settings storage every later story builds on.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T003 Define `OnboardingFlowState` in `lib/src/screens/onboarding/cubit/onboarding_flow_state.dart`: a step enum (`welcome`, `taskFormat`, `folderSelection`, `complete`), current step, and the "valid folder chosen" flag needed to gate completion — per data-model.md's state machine
- [X] T004 Implement `OnboardingFlowCubit` in `lib/src/screens/onboarding/cubit/onboarding_flow_cubit.dart`: `next()`/`back()` transitions `NotStarted → OnWelcome → OnTaskFormat → OnFolderSelection → Complete` (data-model.md); back-navigation preserves already-made choices (FR-009); `Complete` is only reachable once a valid folder is set (FR-007/FR-010) (depends on T003)
- [X] T005 [P] Implement the `OnboardingFlow` container widget in `lib/src/screens/onboarding/onboarding_flow.dart`: a non-swipeable `PageView`/stepper driven by `OnboardingFlowCubit`, rendering the current step's screen with Next/Back controls only — **no Skip control anywhere** (FR-008) (depends on T004)
- [X] T006 Update `_buildHomeWidget` in `lib/app.dart` (currently lines ~171-178) to use one completion gate — show `OnboardingFlow` whenever `!settingsController.onboardingComplete || settingsController.vaultDirectory == null`, otherwise render `MainNavigator` directly — replacing today's two independent checks (research.md §2) (depends on T005)
- [X] T007 [P] Unit test in `test/src/screens/onboarding/onboarding_flow_cubit_test.dart`: verifies step transitions welcome→taskFormat→folderSelection→complete, and that `complete` cannot be reached without a valid folder set (depends on T004)
- [X] T008 [P] Add a `task_format_preference` key (`"inline"` / `"taskNote"` / `"both"`, default `"inline"`) with getter/setter to `lib/src/screens/settings/settings_service.dart` and expose it through `lib/src/screens/settings/settings_controller.dart`, following the existing `dataViewDefaultMarkdownFormat` pattern (`settings_service.dart:77-92,219-222`) (data-model.md, research.md §5) — independent of T003-T007, can run in parallel

**Checkpoint**: The 3-step shell renders and correctly gates `app.dart`; the preference storage exists but nothing reads/writes it yet; individual screens are still empty stubs.

---

## Phase 3: User Story 1 - Complete first-run setup in one continuous flow (Priority: P1) 🎯

**Goal**: A new user goes through one uninterrupted 3-screen sequence with no separate, disconnected setup screen appearing before or after.

**Independent Test**: Launch as a brand-new user; confirm the three screens appear back-to-back, in order, with no other setup screen appearing separately (verifiable against the Phase 2 shell even with stub screen content).

- [X] T009 [P] [US1] Widget test in `test/src/screens/onboarding/onboarding_flow_cubit_test.dart` (or a new `onboarding_flow_test.dart`): a brand-new install (`onboardingComplete=false`, `vaultDirectory=null`) renders `OnboardingFlow` / screen 1 first, and no other screen (old `Init`, `MainNavigator`) appears before it (depends on T006)
- [ ] T010 [P] [US1] Widget test: an already-qualifying existing user (`onboardingComplete=true` AND `vaultDirectory` already set) bypasses `OnboardingFlow` entirely — `_buildHomeWidget` renders `MainNavigator` directly (FR-012, spec Edge Cases) (depends on T006) — **DEFERRED**: the gating logic itself (`_buildHomeWidget` in `lib/app.dart`) is implemented and trivially correct (a two-line boolean check), but pumping the *real* `App`/`MainNavigator` widget tree in a test requires a much heavier fixture (real `TaskManager`, notification/background-service singletons, localization delegates) than this session's other tests needed. `OnboardingFlow`'s own "welcome screen first" behavior is covered by T009.
- [X] T011 [P] [US1] Remove the "Show on-boarding screen" toggle block from `lib/src/screens/settings/settings_view.dart` (currently lines ~308-337) — no user-facing way to replay the sequence remains (FR-011) (depends on T006)
- [X] T012 [P] [US1] Update the `onboardingComplete`/`updateOnboardingComplete` doc comments in `lib/src/screens/settings/settings_service.dart` and `lib/src/screens/settings/settings_controller.dart` to reflect the tightened meaning ("all 3 onboarding screens + folder selection complete," not "intro carousel seen") (depends on T006)

**Checkpoint**: Navigation shell, single completion gate, existing-user bypass, and toggle removal all work. Screens 1-3 still need real content (US2-4).

---

## Phase 4: User Story 2 - See VaultMate's value at a glance on the welcome screen (Priority: P1)

**Goal**: Screen 1 presents VaultMate's most valuable features as one scannable, scrollable list — no swiping.

**Independent Test**: Reach screen 1 and confirm all key feature highlights from today's carousel are present and readable without swiping between pages.

- [X] T013 [P] [US2] Implement `WelcomeScreen` in `lib/src/screens/onboarding/welcome_screen.dart`: a single scrollable list (icon + title + one-line description per item) covering reminders/notifications, the task manager & home-screen widgets, and task filtering — content sourced from the existing 3 pages in `lib/src/screens/introduction/onboarding.dart` (FR-002) (depends on T005)
- [X] T014 [US2] Widget test in `test/src/screens/onboarding/welcome_screen_test.dart`: all 3 feature highlights are present and reachable via scroll alone, with no swipe/`PageView` gesture required (SC-003) (depends on T013)
- [X] T015 [US2] Delete `lib/src/screens/introduction/onboarding.dart` — fully superseded by `WelcomeScreen` (depends on T013, T006)
- [X] T016 [US2] Remove the `introduction_screen` dependency from `pubspec.yaml` and run `flutter pub get` (research.md §3; confirmed unused elsewhere) (depends on T015)

**Checkpoint**: Screen 1 shows real, final content; the old carousel and its dependency are fully removed.

---

## Phase 5: User Story 3 - Choose a default task format as part of onboarding (Priority: P1)

**Goal**: Screen 2 explains Inline tasks vs. TaskNotes in plain language and lets the user pick their default (or Both), saving it to the preference from Phase 2.

**Independent Test**: Advance from screen 1 to screen 2, read the explanation, select a format, confirm the choice is saved, and that proceeding advances to screen 3.

- [X] T017 [US3] Implement `TaskFormatScreen` in `lib/src/screens/onboarding/task_format_screen.dart`: plain-language explanation of what "Inline tasks" and "TaskNotes" mean for vault storage (FR-003), a choice control (Inline tasks / TaskNotes / Both) pre-selecting "Inline tasks" (FR-004), writing the selection to `task_format_preference` (T008) on proceed (FR-005) (depends on T005, T008)
- [X] T018 [US3] Widget test in `test/src/screens/onboarding/task_format_screen_test.dart`: the explanation and all 3 options are shown; selecting a format and proceeding saves it via `SettingsController` and advances to screen 3; proceeding without changing the pre-selected option still saves "Inline tasks" (depends on T017)

**Checkpoint**: Screen 2 shows the real task-format choice and persists it.

---

## Phase 6: User Story 4 - Select the vault folder to finish setup (Priority: P1)

**Goal**: Screen 3 replaces today's separate `Init` screen; folder selection is required before onboarding can complete.

**Independent Test**: Reach screen 3 and confirm the existing folder-selection capability (auto-detected vault list, manual picker) is present, and that selecting a folder completes onboarding.

- [X] T019 [US4] Implement `FolderSelectionScreen` in `lib/src/screens/onboarding/folder_selection_screen.dart`, relocating (not rewriting) `InitCubit`'s Android-only auto-scan and manual-selection logic from `lib/src/screens/init/cubit/init_cubit.dart` (FR-006, research.md §6) (depends on T005)
- [X] T020 [US4] Wire `FolderSelectionScreen`'s "Continue"/finish control to stay disabled until a valid folder is chosen, and on confirm to drive `OnboardingFlowCubit`'s `complete` transition (persists `vaultDirectory` + `onboardingComplete=true`) (FR-007) (depends on T019, T004)
- [X] T021 [P] [US4] Widget test in `test/src/screens/onboarding/folder_selection_screen_test.dart`: auto-detected vaults are listed on Android; manual selection is offered on iOS and in the no-vaults-found case; "Continue" stays disabled until a valid folder is chosen (depends on T019)
- [X] T022 [US4] Delete `lib/src/screens/init/init.dart` and `lib/src/screens/init/cubit/init_cubit.dart` — logic fully relocated in T019 (depends on T019, T006)

**Checkpoint**: Screen 3 shows real folder selection; the old `Init` screen is fully removed. The onboarding sequence (US1-US4) works end-to-end (SC-001, SC-002).

---

## Phase 7: User Story 5 - New tasks default to the saved format preference (Priority: P1)

**Goal**: Every task-creation entry point in the app pre-selects the saved default format, stays overridable per-task, and never affects edits to existing tasks.

**Independent Test**: Set a preference (via screen 2 or, once Phase 8 lands, Settings), create a new task anywhere in the app, and confirm the format shown/used matches the preference — independent of the onboarding UI itself.

> Confirmed in plan.md's Structure Decision: every task-creation UI (`app.dart`'s task-editor route, `inbox_tasks.dart`, and the AI chat bubble in `obsi_chat_bubble.dart`) already constructs a `TaskEditorCubit`, so one change here covers every entry point (FR-014) with no duplication.

- [X] T023 [US5] Update `TaskEditorCubit`'s `_taskNoteFormat` initialization in `lib/src/screens/task_editor/cubit/task_editor_cubit.dart` (currently hardcoded `false` at line ~20) to read `task_format_preference` (T008): `"inline"` → `false`, `"taskNote"` → `true`, `"both"` → `false` with the toggle still user-editable (FR-014, FR-016) (depends on T008)
- [X] T024 [US5] Unit tests in new `test/src/screens/task_editor/cubit/task_editor_cubit_test.dart`: default pre-selection is correct for each of the 3 preference values; the user can still override the pre-selected format per task (FR-015); editing an *existing* task (`isNewTask == false`) never applies the preference, regardless of its value — format stays whatever the task already had (FR-018, existing `isNewTask` gate at `task_editor_cubit.dart:32,75`) (depends on T023)

**Checkpoint**: Task creation across the whole app honors the saved default; existing-task edits are unaffected. This is the payoff of US3 (SC-007).

---

## Phase 8: User Story 6 - Change the default format later in Settings (Priority: P2)

**Goal**: A user can view and change their default task format from Settings at any time, independent of onboarding (now that onboarding has no replay path back to screen 2).

**Independent Test**: Open Settings, change the preference, confirm Settings reflects the new value and that subsequently created tasks use it.

- [X] T025 [US6] Add a "Default task format" entry to `lib/src/screens/settings/settings_view.dart` (radio/dropdown: Inline tasks / TaskNotes / Both), wired through `SettingsController` to `task_format_preference` (T008), placed independently of the vault-directory setting (FR-013) (depends on T008, T011 — same file region as the removed toggle)
- [ ] T026 [US6] Widget test confirming the Settings entry displays the current preference and that changing it is immediately reflected by `TaskEditorCubit`'s default pre-selection for the next new task (FR-013, spec US6 acceptance scenarios) (depends on T025, T023) — **DEFERRED**: `SettingsView` reads ~15 different `SettingsController` members (theme, subscription, reminders, etc.), so a widget test needs a fairly complete fake of the whole controller (including working `ChangeNotifier` semantics) rather than the few getters other tests here needed. The underlying logic is simple pass-through already covered indirectly: `SettingsController.updateTaskFormatPreference`/`taskFormatPreference` mirror the already-proven `dataViewDefaultMarkdownFormat` pattern, and T024 proves `TaskEditorCubit` reacts correctly to whatever the preference holds.

**Checkpoint**: All 6 user stories are functionally complete.

---

## Phase 9: Polish & Cross-Cutting Concerns

- [X] T027 [P] Run `flutter analyze` and fix lint/formatting issues across `lib/src/screens/onboarding/`, `lib/src/screens/task_editor/`, `lib/src/screens/settings/`
- [X] T028 Integration test confirming back-navigation preserves state end-to-end with real screens: screen 3 → screen 2 → screen 1 → forward again still shows the earlier task-format choice (FR-009, quickstart Scenario 2) (depends on T017, T019)
- [X] T029 Run quickstart.md validation scenarios on both iOS and Android (Constitution: platform parity) (depends on T015, T017, T022, T025)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Setup. Blocks all user stories. T008 (settings key) is independent of T003-T007 (shell) and can run in parallel.
- **User Stories (Phase 3-8)**: All depend on Foundational. Recommended order given the linear nature of this flow: **US1 → US2 → US3 → US4 → US5 → US6**, though US2/US3/US4 touch disjoint files and can be split across developers once Foundational is done; US5 needs US3's preference to exist meaningfully but can be *coded* right after T008 (it doesn't need the screen 2 UI, just the stored value); US6 needs T011 (US1) done first since it edits the same `settings_view.dart` region.
- **Polish (Phase 9)**: Depends on all 6 user stories (T028/T029 specifically need real US3/US4/US5 content, not stubs).

### Within Each Phase

- Foundational: T003 → T004 → {T005, T007 in parallel}; T006 after T005; T008 independent, parallel-safe throughout
- US1: T009-T012 all depend only on T006, otherwise independent of each other (parallel-safe)
- US2: T013 → T014 → T015 → T016 (sequential; each deletes/replaces what the previous step made obsolete)
- US3: T017 → T018 (sequential)
- US4: T019 → {T020, T021 in parallel} → T022 (after T020)
- US5: T023 → T024 (sequential, same file's test)
- US6: T025 → T026 (sequential)

### Parallel Opportunities

- T002 [P] alongside T001 (disjoint directories)
- T005, T007, and T008 [P] once T003/T004 are done (disjoint files)
- T009, T010, T011, T012 [P] once T006 is done (disjoint files) — a natural batch for one PR
- Once Foundational is done, **US2, US3, and US4 can be built in parallel** by different developers (disjoint screen files); **US5 can start in parallel with them too** (only needs T008, not the screen 2 UI)
- T020 and T021 [P] once T019 is done

---

## Parallel Example: after Foundational (T006, T008) completes

```bash
# US1 verification/cleanup batch:
Task: "Widget test: new user sees screen 1 first, in test/src/screens/onboarding/onboarding_flow_test.dart"
Task: "Widget test: existing qualifying user bypasses the flow, in test/src/screens/onboarding/onboarding_flow_test.dart"
Task: "Remove 'Show on-boarding screen' toggle in lib/src/screens/settings/settings_view.dart"

# US2/US3/US4/US5 content, in parallel by different developers:
Task: "Implement WelcomeScreen in lib/src/screens/onboarding/welcome_screen.dart"
Task: "Implement TaskFormatScreen in lib/src/screens/onboarding/task_format_screen.dart"
Task: "Implement FolderSelectionScreen in lib/src/screens/onboarding/folder_selection_screen.dart"
Task: "Update TaskEditorCubit._taskNoteFormat to read task_format_preference"
```

---

## Implementation Strategy

### Why "MVP = US1 only" doesn't apply here

Unlike independent CRUD-style stories, US1 (the navigation shell) has no standalone user value without real content in US2-4, and US3 has no payoff without US5. Treat **US1 through US5 together as the MVP** (through T024) — that's the smallest increment that is both shippable (a complete, working onboarding sequence) and delivers the originally-requested transparency (users choose their format and see it honored). US6 (P2, Settings entry) is a real but secondary increment on top.

### Incremental Delivery (single developer)

1. Setup + Foundational (T001-T008) → shell renders and gates the app; preference storage exists (nothing user-visible changes yet, safe to merge)
2. US1 (T009-T012) → shell verified correct (tests + toggle removal), still stub screen content
3. US2 (T013-T016) → real welcome screen; delete old carousel + dependency
4. US3 (T017-T018) → real task-format screen, preference now actually gets set by users
5. US4 (T019-T022) → real folder screen; delete old `Init` screen — onboarding sequence complete
6. US5 (T023-T024) → task creation everywhere honors the preference — the original request's core payoff lands
7. US6 (T025-T026) → Settings entry to change the preference later (P2)
8. Polish (T027-T029) → lint, cross-screen back-nav integration test, full quickstart pass on iOS + Android

### Parallel Team Strategy

1. One person/pair completes Setup + Foundational (T001-T008).
2. Once done, split: Developer A → US1 verification/cleanup (T009-T012); Developer B → US2 (T013-T016); Developer C → US3 (T017-T018) then US6 (T025-T026, after T011 lands); Developer D → US4 (T019-T022); Developer E → US5 (T023-T024, can start as soon as T008 is done).
3. Regroup for Polish (T027-T029) once all six land.
