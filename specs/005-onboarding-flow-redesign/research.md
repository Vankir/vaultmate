# Research: Onboarding Flow Redesign

All items below were resolved directly from the existing codebase (no external unknowns remained after `/speckit-specify` + `/speckit-clarify`); this phase records the resulting design decisions rather than open technology research.

## 1. Navigation container for the 3-screen sequence

- **Decision**: Build a small custom flow (a `PageView`/stepper driven by a new `OnboardingFlowCubit` tracking `currentStep`), with Next/Back controls only — no Skip control anywhere in the sequence.
- **Rationale**: FR-006 forbids a Skip option, and screen 3's "Continue" must stay disabled until a valid folder is chosen — the same "external validity gates progression" pattern `Init`/`InitCubit` already implements today (`lib/src/screens/init/init.dart:157-167`). The `introduction_screen` package used by the current carousel bakes in Skip/Done semantics designed for pure marketing carousels; it doesn't fit a flow whose final step is a hard, state-dependent gate.
- **Alternatives considered**: Keep `introduction_screen` for screens 1–2 and bolt `init.dart` on as an unmanaged 3rd page — rejected, it reintroduces the "two disconnected experiences" problem FR-001 exists to fix, and the package's built-in Skip button directly conflicts with FR-006.

## 2. Single onboarding-completion gate

- **Decision**: Replace `app.dart`'s two independent checks (`!_onboardingComplete` → show carousel; else `vaultDirectory == null` → show `Init`) with one gate: the app shows the new onboarding flow whenever `!onboardingComplete OR vaultDirectory == null`, and marks `onboardingComplete = true` only once screen 3 completes with a valid folder.
- **Rationale**: Matches FR-001/FR-005/FR-008 (one continuous sequence, one completion state) and requires no new `SharedPreferences` key — the existing `onboarding_complete` flag (`settings_service.dart:33,273-281`) is reused with its meaning tightened rather than replaced.
- **Consequence for FR-010 (existing users)**: A user with both `onboardingComplete == true` and `vaultDirectory` already set is treated as complete immediately — zero new prompts, satisfying FR-010 with no migration code. A user who somehow has `onboardingComplete == true` but no `vaultDirectory` (already possible today, per the current decoupled gates) falls under the *not*-exempt branch of FR-010 (it requires both conditions) and sees the new sequence from screen 1 — an explicit, already-specified consequence, not a new open question.
- **Alternatives considered**: Introduce a new key (e.g. `onboarding_v2_complete`) — rejected as unnecessary; reusing the existing flag correctly distinguishes all real user populations without extra state.

## 3. Removing the `introduction_screen` dependency

- **Decision**: Delete `lib/src/screens/introduction/onboarding.dart` and remove `introduction_screen` from `pubspec.yaml`.
- **Rationale**: Confirmed via `grep -rl introduction_screen lib/` that no other file imports it. Constitution V ("unjustified dependency" guidance) favors removing now-dead dependencies rather than leaving them.
- **Alternatives considered**: Leave it in for possible future reuse — rejected; trivially re-addable later if ever needed.

## 4. Welcome screen (screen 1) content presentation

- **Decision**: A single scrollable list (icon + title + one-line description per item), covering the same 3 messages the current carousel pages communicate: reminders/notifications, the task manager & home-screen widgets, and task filtering.
- **Rationale**: FR-002 explicitly requires "a single, scannable list... not swipeable pages," and SC-003 requires zero swiping/paging to read it.
- **Alternatives considered**: A card grid — rejected as over-designed for 3 items and not requested; a single paragraph of prose — rejected as less scannable than a list, per FR-002's own wording.

## 5. Task format screen (screen 2) — persistence and pre-selection design

*(This section originally described screen 2 as depending on a separate feature, `004-task-format-onboarding`. That feature has been merged into this spec — see spec.md's "Input" note — so the design below is now native to this plan, not an external dependency.)*

- **Decision**: Add one new `SharedPreferences`-backed key, `task_format_preference` (values: `inline` / `taskNote` / `both`), read/written via new `SettingsService`/`SettingsController` methods following the exact pattern of the existing `dataViewDefaultMarkdownFormat` getter/setter (`settings_service.dart:77-92,219-222`). Screen 2 writes this preference; `TaskEditorCubit` reads it.
- **Decision**: `TaskEditorCubit._taskNoteFormat` (`task_editor_cubit.dart:20`, currently hardcoded to `false`) is initialized from the saved preference instead: `inline` → `false` (pre-select inline), `taskNote` → `true` (pre-select TaskNote), `both` → `false` with no forced pre-selection semantics changed (matches today's default-off toggle, satisfying FR-014's "Both = no pre-selection, user chooses manually").
- **Rationale**: Reusing the existing settings-persistence pattern and the single `TaskEditorCubit` choke point (confirmed in plan.md's Structure Decision to be shared by every task-creation entry point) satisfies FR-014 with a one-line initialization change, not a new architecture.
- **Decision**: No new logic needed for FR-018 (editing an existing task preserves its format) — `_taskNoteFormat`'s toggle UI is already gated by `isNewTask` (`task_editor_cubit.dart:32,75`; `task_editor.dart:75-90`), so existing-task edits never see or apply the preference. This is confirmed by a regression test, not new production code.
- **Alternatives considered**: A new `TaskFormatPreference` enum type mirroring `TaskType` — rejected as unnecessary indirection; three string values via the same pattern as `dataViewDefaultMarkdownFormat` is simpler and consistent with Constitution V.

## 6. Folder selection screen (screen 3) — relationship to today's `Init`/`InitCubit`

- **Decision**: Relocate (not rewrite) `InitCubit`'s vault auto-scan and manual-selection logic (`lib/src/screens/init/cubit/init_cubit.dart`) into the new flow's folder-selection step, preserving today's Android-only auto-scan / iOS-manual-only behavior unchanged.
- **Rationale**: FR-004 requires preserving existing capability exactly; the Platform & Distribution Constraints section of the constitution requires any existing platform asymmetry to stay intentional and disclosed, not expand.
- **Alternatives considered**: Rewrite scanning logic — rejected as unnecessary scope creep for what is fundamentally a UI-repositioning feature.

## 7. Settings screen changes

- **Decision**: Remove the "Show on-boarding screen" toggle block (`settings_view.dart:308–337`) entirely, per FR-011. Add a new, independent "Default task format" entry to `settings_view.dart` (radio/dropdown over Inline tasks / TaskNotes / Both, writing through `SettingsController` to the `task_format_preference` key from §5) so the choice remains changeable after onboarding, per FR-013.
- **Rationale**: FR-011 is explicit; a toggle that can no longer safely replay a now-mandatory, state-gated sequence would be misleading if left in place, even as a no-op. FR-013 requires the format preference to stay independently editable now that there's no onboarding replay path back to screen 2.
- **Alternatives considered**: Keep the toggle as a no-op — rejected as misleading UI. Route format changes only through re-onboarding — rejected, directly contradicts FR-011/FR-013.

## 8. Test coverage approach

- **Decision**: Add Cubit unit tests for the new onboarding-completion state machine (step transitions, back-navigation, screen-3 gating until a folder is valid), `TaskEditorCubit` tests for the default-format pre-selection (`inline`/`taskNote`/`both` → correct `_taskNoteFormat` initial value; existing-task edits unaffected regardless of preference), and widget tests confirming: new users see screen 1 first with no skip control; already-qualifying existing users bypass the sequence entirely; the welcome screen requires no swipe/page gesture to read all content.
- **Rationale**: Constitution III commits the project to test coverage for logic that governs correctness of user-facing flows; this specific gate determines whether a user can reach the app at all, making regressions high-severity even though `lib/src/screens` sits outside the constitution's NON-NEGOTIABLE `lib/src/core` mandate.
- **Alternatives considered**: Manual QA only — rejected as insufficient given the severity of a regression here (a broken gate can strand every new user before the app becomes usable).
