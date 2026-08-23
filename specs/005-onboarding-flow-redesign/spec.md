# Feature Specification: Onboarding Flow Redesign

**Feature Branch**: `005-onboarding-flow-redesign`

**Created**: 2026-08-23

**Status**: Draft

**Input**: Merged from two related requests, treated as one feature:
1. "Design a transparent, user-friendly onboarding by analyzing the current onboarding flow. In the new onboarding, add the ability to choose which task format VaultMate should work with by default: Inline tasks (the format used by the Tasks plugin), TaskNotes format (a separate file per task), or both. This choice must be saved in Settings, and the user must be able to change it later if they want. When a new task is created, the app must check this setting and use it to decide, by default, which format the task is created in."
2. "The new onboarding should consist of 3 screens: 1. a welcome screen with a list of the most valuable features (reusing content from the current onboarding), 2. a screen for choosing the default task format, and 3. a replacement for the current screen used to choose the vault folder."

*(These were originally specified as two separate features — `004-task-format-onboarding` and `005-onboarding-flow-redesign` — and have been merged into this single spec because the second request's "screen 2" **is** the first request's feature, not a separate one. `004`'s directory has been retired; nothing there is lost, it's folded in below.)*

## Clarifications

### Session 2026-08-23

- Q: When a user opens an already-existing task for editing, does the default task format preference change what format it's saved back in? → A: No. Editing and resaving an existing task keeps it in the format it already had, unless the user explicitly picks a different format for that task; the default preference only governs the format of newly created tasks (existing app behavior, unchanged by this feature).
- Q: Screen 3 (folder selection) is mandatory since the app can't function without a vault — screens 1 and 2 are informational/preference. How should "Skip" work in the new unified sequence? → A: No skip at all — every new user clicks through all 3 screens in order, every time.
- Q: Settings today has a "Show onboarding screen again" toggle that replays the intro carousel. What should replaying onboarding from Settings show in the new 3-screen flow? → A: Retire the replay toggle entirely — there is no user-facing way to re-trigger the sequence once it's complete.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Complete first-run setup in one continuous flow (Priority: P1)

A new user opens VaultMate for the first time and goes through a single, uninterrupted 3-screen sequence — welcome, task format choice, vault folder selection — ending with a working app, instead of today's experience where an informational carousel and a separate, disconnected vault-setup screen can appear at different points.

**Why this priority**: This is the structural core of the request — replacing two disconnected onboarding experiences with one coherent flow is the change that makes everything else (screens 2 and 3) meaningful as a sequence rather than isolated screens.

**Independent Test**: Can be fully tested by launching the app as a brand-new user and confirming the three screens appear back-to-back, in order, with no other setup screen appearing separately before or after.

**Acceptance Scenarios**:

1. **Given** a brand-new install with no prior app data, **When** the user opens the app for the first time, **Then** they see screen 1 (Welcome) first, and no other screen (vault setup or otherwise) appears before it.
2. **Given** the user is on screen 1, **When** they proceed, **Then** they land on screen 2 (task format choice); **When** they proceed from screen 2, **Then** they land on screen 3 (folder selection).
3. **Given** the user completes screen 3 by selecting a valid vault folder, **When** they finish that step, **Then** onboarding ends and the app opens to normal use — no further onboarding or setup screen appears on that or later launches.

---

### User Story 2 - See VaultMate's value at a glance on the welcome screen (Priority: P1)

A new user sees a single welcome screen listing VaultMate's most valuable features (reminders/notifications, the task manager and home-screen widgets, task filtering) as a scannable list, rather than having to swipe through multiple separate pages as in today's onboarding.

**Why this priority**: This is one of the three explicitly requested screens and directly replaces existing, working functionality (the multi-page intro carousel), so it must land correctly for the redesign to be a net improvement rather than a regression.

**Independent Test**: Can be fully tested by reaching screen 1 and confirming all the key feature highlights from today's onboarding are present and readable without needing to swipe between pages.

**Acceptance Scenarios**:

1. **Given** a new user reaches screen 1, **When** the screen is displayed, **Then** it presents the most valuable features (at minimum: reminders/notifications, the task manager and home-screen widgets, and task filtering) as a single list.
2. **Given** the welcome screen's content is longer than the visible area, **When** the user scrolls, **Then** they can see the rest of the list without needing pagination/swiping.

---

### User Story 3 - Choose a default task format as part of onboarding (Priority: P1)

A new user reaches screen 2 and is shown a clear, plain-language explanation of the two ways VaultMate can store tasks in their vault — as inline checklist items inside an existing note (compatible with the Tasks plugin) or as one separate note per task (TaskNotes format) — then picks which one (or both) they want VaultMate to use by default when they create new tasks.

**Why this priority**: Without an informed, explicit choice here, the app keeps guessing (or silently defaulting) on the user's behalf — the "non-transparent" behavior this feature exists to fix. It's also the second of the three explicitly requested screens, positioned between welcome and folder selection.

**Independent Test**: Can be fully tested by advancing from screen 1 to screen 2, reading the explanation, selecting a format, confirming the choice is saved, and that proceeding advances to screen 3 — independent of whether task creation elsewhere in the app already uses the saved preference (see User Story 5 for that).

**Acceptance Scenarios**:

1. **Given** the user arrives at screen 2, **When** the screen is displayed, **Then** they see a plain-language description of "Inline tasks" and "TaskNotes" (what each means for how their vault files look), without needing to already know the underlying plugin names.
2. **Given** the user is on screen 2, **When** they select "Inline tasks," "TaskNotes," or "Both" and proceed, **Then** their selection is saved as their default task format preference and the flow advances to screen 3.
3. **Given** the user proceeds from screen 2 without actively changing the pre-selected option, **When** they continue, **Then** a well-defined default preference is still saved (see Assumptions), so the rest of the app behaves predictably.

---

### User Story 4 - Select the vault folder to finish setup (Priority: P1)

A new user reaches screen 3, which replaces today's separate vault-folder screen, and selects the Obsidian vault folder VaultMate will use — either an auto-detected vault or a manually chosen folder — as the final, required step before the app becomes usable.

**Why this priority**: The app cannot function without a vault folder, so this step is both explicitly requested and functionally load-bearing: onboarding cannot be considered complete without it.

**Independent Test**: Can be fully tested by reaching screen 3 and confirming the existing folder-selection capability (auto-detected vault list, manual folder picker) is present and that selecting a folder completes onboarding.

**Acceptance Scenarios**:

1. **Given** the user is on screen 3, **When** the screen loads, **Then** it offers any auto-detected candidate vaults to pick from, and a manual "select folder" option, matching today's capability.
2. **Given** the user selects a valid folder (auto-detected or manual), **When** they confirm it, **Then** the folder is saved as the active vault directory and onboarding completes.
3. **Given** the user has not yet selected a valid folder, **When** they look at the screen, **Then** there is no way to proceed past screen 3 (no skip, no bypass) until a folder is chosen.

---

### User Story 5 - New tasks default to the saved format preference (Priority: P1)

When a user creates a new task anywhere in the app — not just during onboarding — VaultMate checks the saved default task format preference and pre-selects the matching format automatically, instead of requiring the user to choose the format manually every time.

**Why this priority**: This is the payoff of User Story 3 — the onboarding choice only has value if task creation actually honors it afterward. Together they deliver the complete, independently valuable slice: "set it once, stop being asked every time."

**Independent Test**: Can be fully tested by setting a default task format preference (via onboarding or Settings), then creating a new task anywhere in the app and confirming the format shown/used matches the preference — independent of the onboarding UI itself.

**Acceptance Scenarios**:

1. **Given** the user's default task format preference is "Inline tasks," **When** they create a new task, **Then** the task is created in the inline (Tasks-plugin-compatible) format by default.
2. **Given** the user's default task format preference is "TaskNotes," **When** they create a new task, **Then** the task is created as a separate TaskNote by default.
3. **Given** the default format has been pre-selected for a new task, **When** the user wants a different format for that one task, **Then** they can still override the pre-selected format before saving it.
4. **Given** a user opens an *existing* task for editing, **When** they resave it without explicitly changing its format, **Then** it keeps the format it already had — the default preference only governs newly created tasks.

---

### User Story 6 - Change the default format later in Settings (Priority: P2)

A user who already completed onboarding decides their needs have changed (e.g., they started using the TaskNotes plugin) and updates their default task format preference from the Settings screen, without needing to redo onboarding.

**Why this priority**: Preferences change over time; requiring a full onboarding replay to update a single setting would be poor UX. This is a secondary path once the core flow (Stories 1–5) exists — and doubly so now that the full onboarding sequence has no replay affordance at all (see Story 1 / FR-011).

**Independent Test**: Can be fully tested by opening Settings, changing the default task format preference, and confirming both that Settings reflects the new value and that subsequently created tasks use it.

**Acceptance Scenarios**:

1. **Given** a user has an existing default task format preference, **When** they open Settings, **Then** they can see their current preference clearly labeled.
2. **Given** the user changes the preference in Settings, **When** they save the change, **Then** it takes effect immediately for any task created afterward.
3. **Given** the user changes the preference in Settings, **When** they look at tasks they created before the change, **Then** those existing tasks are unaffected (the setting only governs new tasks going forward).

---

### Edge Cases

- What happens for a user who already completed the previous (pre-redesign) onboarding and already has a vault folder configured? They MUST NOT be forced through the new 3-screen sequence again after the app updates; their existing vault configuration and task-format preference (or its fallback default) carry forward unchanged.
- What happens if the user closes or backgrounds the app partway through the sequence (e.g., between screen 2 and screen 3)? Because onboarding is not marked complete until a valid folder is selected on screen 3, relaunching the app resumes onboarding from screen 1.
- What happens if auto-detection on screen 3 finds no candidate vaults? The manual folder-selection option remains available, matching today's "no vaults found" fallback behavior.
- What happens if the user wants to change their vault folder or task-format preference later, after onboarding is long complete? These remain independently editable via their own dedicated Settings entries — this feature does not add a way to re-enter the full onboarding sequence (the replay toggle is removed, see FR-011).
- What happens when a user opens an existing task for editing and resaves it? The default task format preference MUST NOT apply — the task is resaved in whatever format it already had, unless the user explicitly chooses a different format for that task (FR-018).
- What happens when the user selects "Both" as their preference on screen 2? Task creation afterward is unaffected — no format is pre-selected, and the user chooses manually each time, exactly as it works today (FR-014).
- What happens if the user changes their default format preference in Settings while a task-creation screen is already open? The in-progress task keeps whatever format was pre-selected when it was opened; the new default only applies to tasks started afterward.
- What happens if a task is created through a quick-add entry point (e.g., a home-screen widget) rather than the main task editor? The same saved default preference MUST apply consistently across every task-creation entry point in the app, not just the primary in-app editor.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST present onboarding to a new user as a single continuous sequence of exactly 3 screens — Welcome, Task Format Choice, Folder Selection — replacing today's two separate experiences (the multi-page intro carousel and the standalone vault-folder screen).
- **FR-002**: Screen 1 (Welcome) MUST present VaultMate's most valuable features as a single, scannable list (scrollable if needed) rather than requiring the user to swipe through multiple pages; content MUST cover, at minimum, what today's onboarding carousel communicates: reminders/notifications, the task manager and home-screen widgets, and task filtering.
- **FR-003**: Screen 2 (Task Format Choice) MUST explain, in plain, non-technical language, what "Inline tasks" and "TaskNotes" mean for how tasks are stored in the user's vault (e.g., inline checklist items within a note vs. one note per task), so users can make an informed choice without prior knowledge of the underlying community plugin formats.
- **FR-004**: Screen 2 MUST let the user choose their default task format: "Inline tasks," "TaskNotes," or "Both." A sensible option ("Inline tasks") MUST be pre-selected so the user can proceed without actively deciding, consistent with there being no Skip control anywhere in the sequence (FR-008).
- **FR-005**: The user's default task format preference MUST be persisted so it survives app restarts and remains in effect until the user changes it.
- **FR-006**: Screen 3 (Folder Selection) MUST let the user select the Obsidian vault folder VaultMate will use, preserving today's existing capability to auto-detect candidate vaults, pick one, or manually select a folder.
- **FR-007**: The app MUST treat folder selection on screen 3 as a required step: onboarding is not complete, and the app MUST NOT proceed to normal use, until a valid vault folder has been selected.
- **FR-008**: The onboarding sequence MUST NOT offer a "Skip" option on any of the 3 screens; a new user progresses through all three, in order (Welcome → Task Format Choice → Folder Selection), on every first run.
- **FR-009**: Users MUST be able to navigate back to a previous screen in the sequence to change an earlier choice before folder selection completes onboarding.
- **FR-010**: Once onboarding completes (folder selected on screen 3), the app MUST record onboarding as complete so the full 3-screen sequence is not shown again on subsequent launches.
- **FR-011**: The existing Settings option to manually replay onboarding ("Show onboarding screen again") MUST be removed; there is no user-facing way to re-trigger the full 3-screen sequence once onboarding has completed.
- **FR-012**: Existing users who already completed the previous onboarding AND already have a vault folder configured MUST NOT be forced through the new 3-screen sequence after this change ships; their existing vault configuration and task-format preference (or its fallback default) carry forward unchanged.
- **FR-013**: Users MUST be able to view and change their default task format preference at any time from Settings, independent of onboarding, and independent of the vault-directory setting — both remain their own dedicated Settings entries now that the onboarding replay toggle (FR-011) is gone.
- **FR-014**: When a user creates a new task anywhere in the app (the main task editor and any quick-add or widget-based creation flow), the app MUST use the saved default task format preference to pre-select the format for that task: if the preference is "Inline tasks" or "TaskNotes," that format is pre-selected; if the preference is "Both," no format is pre-selected and the user chooses manually for that task, matching today's behavior.
- **FR-015**: Regardless of the pre-selected default, users MUST still be able to override the task format on a per-task basis at the moment of creating that task.
- **FR-016**: If a user has never actively changed the pre-selected default on screen 2 (or, for pre-existing users, never had a chance to choose one at all), the app MUST fall back to a single, well-defined default format ("Inline tasks") rather than an undefined or inconsistent state.
- **FR-017**: Changing the default task format preference MUST NOT alter the format of tasks that already exist; it only affects tasks created after the change.
- **FR-018**: The default task format preference MUST only apply when a *new* task is created. Opening an existing task for editing and resaving it MUST preserve its original format unless the user explicitly chooses a different format for that task — this matches the app's existing behavior and is unaffected by this feature.

### Key Entities

- **Onboarding Progress**: Represents whether a user has completed the unified 3-screen onboarding sequence. Replaces today's separate "intro carousel seen" and "vault folder chosen" states with a single completion state gated on all 3 screens being finished.
- **Default Task Format Preference**: A per-user setting representing which task format(s) VaultMate should default to when creating a new task — one of "Inline tasks," "TaskNotes," or "Both." Lives alongside the user's other app settings (chosen on screen 2 or changed later in Settings) and is independent of any single vault or task.
- **Task**: An existing concept (a to-do item stored in the user's vault). Each task has a format (inline vs. TaskNote) determined at creation time; this feature changes how that format is *defaulted* at creation, not how a task itself is structured, and does not affect how already-existing tasks are read, recognized, or resaved.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new user can complete the entire onboarding sequence — all 3 screens, ending with a selected vault folder — in under 60 seconds under normal conditions (a vault already exists on the device).
- **SC-002**: 100% of new users who finish onboarding have a valid vault folder selected and a default task-format preference in effect (explicit choice or fallback default) — the app is immediately usable afterward with no additional required setup screens.
- **SC-003**: All key feature highlights from today's multi-page intro carousel are readable on the new welcome screen via scrolling alone, with zero swiping/paging required.
- **SC-004**: The existing, working ability to auto-detect and manually select a vault folder is fully preserved on screen 3 — zero loss of current folder-selection capability.
- **SC-005**: Existing users (already onboarded before this change ships) see no unexpected re-onboarding prompt after updating the app.
- **SC-006**: A user can read the task-format explanation and make (or knowingly leave) a default choice on screen 2 in under 20 seconds, without needing to consult external documentation.
- **SC-007**: After a default task format preference is set, 100% of newly created tasks across every task-creation entry point in the app start out in the format matching that preference, unless the user manually overrides it for that task.
- **SC-008**: A user can locate and change their default task format preference from Settings in 2 taps or fewer from the Settings screen.
- **SC-009**: Users who leave screen 2's pre-selected default unchanged experience no errors — task creation continues to work correctly using the well-defined fallback default.
- **SC-010**: In a usability check, users who complete screen 2 can correctly describe, in their own words, the practical difference between "Inline tasks" and "TaskNotes" for their vault.

## Assumptions

- If the user proceeds through screen 2 without actively changing the pre-selected option, the default task format preference is "Inline tasks," matching the app's current default behavior, so existing users see no surprise change. The user can change this later in Settings at any time (addresses FR-016).
- Screen 3's folder-selection functionality (auto-scan for candidate vaults, list results, manual folder picker) keeps its existing behavior and capabilities unchanged; "replacement" refers to its position and integration as the final step of one unified onboarding sequence, not a functional redesign of how folders are found or chosen.
- Screen 1's feature list is a condensed, single-screen restatement of the existing 3-page carousel's content (notifications/reminders, task manager & home-screen widgets, task filtering) rather than newly authored marketing copy; exact wording/visual layout is a content and design decision made during implementation.
- "Transparent" onboarding, per the original request, means the format-selection step explains the practical, user-facing consequence of each choice (how tasks will look/be stored) rather than exposing internal technical details or plugin implementation names beyond what's needed for users already familiar with the Tasks/TaskNotes community plugins to recognize their format.
- The scope of the task-format preference is the *default* format used when a new task is created; it does not change how the app reads/recognizes existing tasks already in a user's vault (format detection for existing tasks is unaffected).
- "Both" as a preference means the user wants access to both formats and does not want to commit to a single default in advance; when set, new-task creation behaves exactly as it does today (no format pre-selected, user chooses manually each time).
- Because there is no skip option and folder selection is mandatory, a new user always passes through all 3 screens on first run; there is no partial-completion state exposed to the user beyond simply continuing the sequence later if the app was closed mid-flow.
- Removing the "Show onboarding screen again" Settings toggle (FR-011) is acceptable because the two settings a user would realistically want to revisit — vault folder and default task format — remain independently accessible in Settings without needing to replay the whole sequence.
