# Quickstart: Validating the Onboarding Flow Redesign

Manual/scripted validation scenarios proving the feature works end-to-end. See [data-model.md](./data-model.md) for the state shape and [spec.md](./spec.md) for full acceptance criteria.

## Prerequisites

- A local Flutter dev build of VaultMate running on an iOS simulator/device and an Android emulator/device (Constitution: iOS/Android parity — validate both).
- A test device/simulator with app data reset (fresh install), and a second with pre-existing app data (`onboarding_complete=true`, `vault_directory` set) to exercise the existing-user path.
- At least one Obsidian-style vault folder (a directory containing `.obsidian/`) available on the Android test device, to exercise auto-detection.

## Setup

```bash
flutter pub get
flutter run   # select target device/simulator when prompted
```

To reset onboarding state on a device between runs (Android):

```bash
adb shell pm clear com.<app-id>   # clears SharedPreferences, forcing first-run state
```

On iOS, uninstall/reinstall the app on the simulator to reset local storage.

## Scenario 1 — New user completes the full sequence (SC-001, SC-002)

1. Launch the app on a fresh install.
2. **Expect**: Screen 1 (Welcome) appears immediately; no other screen appears first.
3. Confirm the feature list is fully readable via scrolling alone — no swipe/page gesture needed (SC-003). Confirm there is no Skip control (FR-006).
4. Tap Next → **Expect**: Screen 2 (task format choice) appears, per feature `004`'s UI.
5. Make a format choice, tap Next → **Expect**: Screen 3 (folder selection) appears.
6. Confirm the "Continue"/finish control is disabled until a folder is chosen (FR-005).
7. On Android: confirm auto-detected vaults are listed if present. On iOS: confirm manual selection is offered (existing platform asymmetry, preserved per research.md §6).
8. Select/confirm a valid vault folder.
9. **Expect**: Onboarding ends, the app opens directly to normal use (main task list) — no further onboarding/setup screen appears on this or later launches (SC-002).
10. Time the whole sequence — **expect** under 60 seconds under normal conditions (SC-001).

## Scenario 2 — Back navigation preserves earlier choices (FR-007)

1. From screen 3, tap Back.
2. **Expect**: Returns to screen 2 with the previously made task-format choice still selected.
3. Tap Back again → **Expect**: Returns to screen 1.
4. Tap Next twice → **Expect**: Screen 3 is reached again with the same task-format choice still in effect (not reset).

## Scenario 3 — Existing (already-onboarded) user sees no new prompt (FR-010, SC-005)

1. On a device/build with pre-existing app data where `onboarding_complete=true` and a vault folder is already configured, launch the updated app.
2. **Expect**: The app opens directly to normal use. The new 3-screen sequence does NOT appear.

## Scenario 4 — No vaults found still allows manual selection (Edge Case)

1. On Android, with no `.obsidian`-containing folders reachable, reach screen 3.
2. **Expect**: A "no vaults found" message and a manual folder-selection option are shown (existing fallback behavior, preserved).

## Scenario 5 — Settings no longer offers an onboarding replay (FR-009)

1. Complete onboarding, then open Settings.
2. **Expect**: The previous "Show on-boarding screen" toggle is gone. Vault directory and default task format (feature `004`) each remain editable via their own separate Settings entries.

## Automated coverage (for CI, per Constitution III)

- `OnboardingFlowCubit` unit tests: step transitions 1→2→3→Complete, back-navigation preserves state, screen-3 "Continue" stays disabled until a valid folder is set.
- Widget tests: screen 1 has no Skip/swipe affordance; an already-qualifying user's `_buildHomeWidget` renders the main app directly, bypassing the flow.

Run with:

```bash
flutter test test/src/screens/onboarding/
```
