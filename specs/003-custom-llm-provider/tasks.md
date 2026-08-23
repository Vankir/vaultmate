---

description: "Task list template for feature implementation"
---

# Tasks: Custom LLM Provider & Managed DeepSeek Access

**Input**: Design documents from `/specs/003-custom-llm-provider/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Included as required tasks (not optional) — Constitution Principle III (NON-NEGOTIABLE) mandates
automated test coverage for new logic under `lib/src/core`, which is where all new provider clients live.

**Scope reminder (spec FR-018)**: This feature is client-only plus the interface contract document in
`contracts/`. No task below builds, hosts, or codes the managed-DeepSeek server.

**Architecture note (superseding research.md #1 and the original per-provider task breakdown)**: during
implementation, the design was simplified from one `AIAssistant` subclass per provider to a single
`OpenAICompatibleAssistant` class parameterized by endpoint/apiKey/model/extraHeaders — Gemini is reached
through Google's official OpenAI-compatible endpoint
(`https://generativelanguage.googleapis.com/v1beta/openai`), so every preset (Gemini, ChatGPT, custom
DeepSeek/local, and the managed-DeepSeek proxy) is served by the same class. This removed
`gemini_assistant.dart`, `chatgpt_assistant.dart`, `extended_generation_config.dart`, and the
`flutter_gemini`/`google_generative_ai` dependencies entirely (net dependency reduction, not addition).
Managed-DeepSeek quota signaling moved from a custom success-body envelope to a plain HTTP 429 with the
reset time in the error body, so `contracts/managed-deepseek-interface.md` and `data-model.md` were
updated to match — see those files for the current contract. Tasks below are annotated with what was
actually built where the original task text no longer matches.

**Organization**: Tasks are grouped by user story (spec.md priorities: US1 = P1, US2 = P2, US3 = P2) to
enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- File paths are exact, relative to the repository root

---

## Phase 1: Setup

- [X] T001 Create the `test/src/ai_assistant/` directory for this feature's new unit tests

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared data model, persistence, and provider-routing scaffolding that every user story
depends on.

- [X] T002 Create `AIProviderType` enum (`gemini`, `chatgpt`, `customOpenAI`, `managedDeepSeek` — as an
      enhanced enum carrying each preset's fixed `baseUrl`/`defaultModel`) and `AIProviderConfig` model
      in `lib/src/core/ai_assistant/ai_provider_config.dart`
- [X] T003 [P] Extended `lib/src/screens/settings/settings_service.dart` to persist `providerType`,
      custom `baseUrl`/`apiKey`/`model`, and `installId` in `shared_preferences`
- [X] T004 [P] Extended `lib/src/screens/settings/settings_controller.dart` with `aiProviderConfig`,
      `updateAIProviderType`, `updateCustomProviderConfig`, and `ensureInstallId()`
- [X] T005 Replaced the dead `AIAssistant.getInstance` factory with `AIAssistant.fromConfig` in
      `lib/src/core/ai_assistant/ai_assistant.dart`, and updated `_initializeAIAssistant` in
      `ai_assistant_cubit.dart` to use it. All four provider types are wired here (not just
      gemini/chatgpt) since they're all the same class — this single task now covers what was originally
      split across T005/T014/T022.
- [X] T006 Created `lib/src/screens/settings/ai_provider_settings_view.dart` with the provider-type
      selector, registered its route in `app.dart`, and added its entry point from `settings_view.dart`
- [X] T007 [P] Unit test for `AIProviderConfig`/`AIProviderType` in
      `test/src/ai_assistant/ai_provider_config_test.dart`

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 1 - Connect any OpenAI-compatible AI provider (Priority: P1) 🎯 MVP

**Goal**: Users can add their own API key for any OpenAI-API-compatible provider (e.g. DeepSeek) and chat
through it, with the same task-oriented capabilities as Gemini/ChatGPT.

**Independent Test**: Enter a custom endpoint URL, model name, and API key in AI provider settings, then
complete a conversation with the AI assistant using that provider.

### Tests for User Story 1

- [X] T008 [P] [US1] Unit test: `OpenAICompatibleAssistant` constructs `OpenAIClient` with the configured
      `baseUrl`/`apiKey`/`model` and returns the final answer, in
      `test/src/ai_assistant/openai_compatible_assistant_test.dart` (mockito, `@GenerateMocks`)
- [X] T009 [P] [US1] Unit test: invalid key (401) and unreachable endpoint (no status code) each surface
      a specific, non-crashing `AIMessage.error` (FR-004), same file
- [X] T010 [P] [US1] Unit test: tool/action round trip via the JSON thought/actions/final_answer contract,
      plus a fallback to plain text when no structured response is returned (FR-017), same file

### Implementation for User Story 1

- [X] T011 [US1] Implemented `OpenAICompatibleAssistant` in
      `lib/src/core/ai_assistant/openai_compatible_assistant.dart` (renamed/generalized from the
      originally planned `CustomOpenAIAssistant`): builds `OpenAIClient(apiKey, baseUrl, headers)`, uses
      the JSON thought/actions/final_answer contract (not OpenAI's native `tools` param, since
      `ToolsRegistry` only exposes free-text descriptions, not a per-parameter JSON schema), executes
      tool calls via `ToolsRegistry`, falls back to plain text on unparseable responses
- [X] T012 [US1] Clear, specific error handling in `OpenAICompatibleAssistant._describeError` for
      401/403 (key rejected), no status code (unreachable), 429 (rate limit, duck-typed quota parsing —
      see US2), and generic HTTP errors — never throws uncaught (FR-004). Also added
      `AIMessageType.error` handling in `ai_assistant_cubit.dart._handleMessage` (previously errors were
      only ever thrown as `GeminiException`, which no longer exists) and removed the now-dead
      `on GeminiException` catch block from `sendMessage`.
- [X] T013 [US1] Added the "Custom OpenAI-compatible provider" endpoint/key/model fields to
      `ai_provider_settings_view.dart` (and a simpler key-only field for Gemini/ChatGPT, reusing
      `updateChatGptKey`), enforcing `AIProviderConfig.isCustomOpenAIConfigured` (FR-001)
- [X] T014 — merged into T005 (same routing switch, not a separate wiring step)
- [X] T015 [US1] `sendMessage()` now calls `_initializeAIAssistant()` on every message (re-reading
      settings), so edits take effect on the next message without a restart (FR-005); switching provider
      type preserves the other provider's saved fields via `AIProviderConfig.copyWith` (Acceptance
      Scenarios US1.4–5). Also fixed a bug this surfaced: the "type your key as first chat message"
      welcome flow (`_needsWelcomeKeyEntry`) is now scoped to Gemini/ChatGPT only — previously it would
      have misfired on every message for `managedDeepSeek`/`customOpenAI`, which don't use that flow.

**Checkpoint**: User Story 1 is fully functional and independently testable. ✅ Verified: `flutter test`
and `dart analyze` both clean.

---

## Phase 4: User Story 2 - Try the built-in DeepSeek assistant without any setup (Priority: P2)

**Goal**: Free-tier users can use a built-in DeepSeek-backed assistant a limited number of times per day
with no key of their own, per `contracts/managed-deepseek-interface.md`.

**Independent Test**: Against a contract-compliant backend/stub, use the built-in assistant up to the
daily limit and confirm the next attempt is blocked with a clear explanation.

### Tests for User Story 2

- [X] T016 — superseded: rather than a separate in-memory "stub server" file, tests mock `OpenAIClient`
      directly (same dependency the managed preset ultimately calls through) and throw
      `OpenAIClientException(code: 429, body: '{"resetAt": "..."}')` to simulate the contract's
      quota-exceeded response. This covers the same ground with less test infrastructure. No stub file
      was created; not needed.
- [X] T017 [P] [US2] Covered by T008 (same success path — `managedDeepSeek` is the same class/method as
      every other preset, just with different config)
- [X] T018 [P] [US2] Unit test: a 429 response with `{"resetAt": ...}` in the body surfaces a
      "free requests for today... resets at X" message (FR-014), in
      `openai_compatible_assistant_test.dart`
- [X] T019 [P] [US2] Implicitly covered: any non-429 `OpenAIClientException`/`FormatException` produces
      an `AIMessage.error`, not a silent retry-eligible state — there is no separate client-side quota
      counter to corrupt (FR-013 is satisfied by construction: quota tracking is entirely server-side per
      FR-012, the client never decrements anything locally)

### Implementation for User Story 2

- [X] T020 — superseded by T011: `managedDeepSeek` is the `AIProviderType.managedDeepSeek` case in
      `AIAssistant.fromConfig`, constructing an `OpenAICompatibleAssistant` pointed at
      `AIProviderConfig.managedDeepSeekBaseUrl` (a `String.fromEnvironment` build-time constant — see
      that field's doc comment) with `X-Install-Id` header. No separate `ManagedDeepSeekAssistant` class.
- [X] T021 [US2] Implemented in `SettingsController.ensureInstallId()`: generates a 128-bit random ID via
      `dart:math Random.secure()`, persisted via `SettingsService`. Simplified from "lazy on first
      managed-DeepSeek use" (research.md #2) to "eager on `loadSettings()`" to keep `fromConfig`
      synchronous — this is a pure implementation simplification, not a behavior change users would
      notice (still generated once per install, still no account system).
- [X] T022 — merged into T005/T011 (same routing switch)
- [ ] T023 [US2] **Simplified, not built as originally scoped**: the plan called for a persistent
      remaining/limit counter in the chat UI. The revised contract (see architecture note above) only
      surfaces quota state on the 429 response via `AIMessage.error`'s text (T018) — there is no
      proactive "3 of 5 remaining" indicator between messages. This satisfies FR-014's literal
      requirement (inform the user when the limit is reached, with a path to continue) but is a smaller
      UI than originally envisioned. Revisit if product feedback wants a persistent counter.

**Checkpoint**: User Story 2's client-side behavior is implemented and tested against a mocked contract.
**Not yet validated end-to-end** — no real managed-DeepSeek backend exists to point at (FR-018: building
it is separate, out-of-scope work); `AIProviderConfig.managedDeepSeekBaseUrl` must be supplied via
`--dart-define=MANAGED_DEEPSEEK_BASE_URL=...` at build time once that backend is deployed.

---

## Phase 5: User Story 3 - Unlimited built-in DeepSeek access for monthly/yearly premium subscribers (Priority: P2)

**Goal**: Verified monthly/yearly subscribers use the built-in DeepSeek assistant without the free-tier
daily limit; lifetime-only subscribers do NOT get this benefit.

### Tests for User Story 3

- [ ] T024 [P] [US3] **Not built**: no dedicated `test/src/subscription/subscription_manager_test.dart`.
      `SubscriptionManager.recurringEntitlementProof`/`hasRecurringSubscription` are new, small, pure
      getters over `_purchases` — low risk, but untested in isolation. Recommended follow-up.
- [X] T025 [P] [US3] Unit test: `AIAssistant.fromConfig`'s `managedDeepSeek` case attaches
      `X-Entitlement-Proof` only when the (injectable) `entitlementProofResolver` returns one, and omits
      it otherwise, in `openai_compatible_assistant_test.dart`
- [X] T026 [P] [US3] N/A under the revised contract: there is no distinct `entitlementUnverified` status
      to test — an unverified/lifetime-only proof simply isn't attached (T025 covers "omitted"), and the
      server treating an attached-but-invalid proof as free-tier (FR-015) is server-side behavior out of
      this spec's scope (FR-018) to test client-side beyond "the client never assumes success".

### Implementation for User Story 3

- [X] T027 [US3] Added `recurringEntitlementProof`/`hasRecurringSubscription` to
      `lib/src/core/subscription/subscription_manager.dart`, scanning `_purchases` for the
      monthly/yearly product IDs only — a lifetime-only purchase yields `null` (Clarifications,
      FR-010/FR-011)
- [X] T028 [US3] `AIAssistant.fromConfig`'s `managedDeepSeek` case attaches `X-Entitlement-Proof` from
      `entitlementProofResolver` (defaulting to `SubscriptionManager.instance.recurringEntitlementProof`
      in production; tests inject a fake resolver to avoid touching the real `in_app_purchase` platform
      channel — this was a real test-environment bug caught and fixed during implementation)
- [X] T029 [US3] No dedicated code path needed: an unlimited/successful response is just a normal `200`
      chat completion (no `remaining`/`limit` fields to suppress under the revised contract — see
      architecture note), so there is nothing that could show a limit-reached message on that path.
      Covered by the same success-path tests as T008/T017.

**Checkpoint**: US3's client-side entitlement logic is implemented and tested. Same end-to-end caveat as
US2 — needs a real backend to validate against.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T030 [P] Audited `lib/src/core/ai_assistant/` and `subscription_manager.dart` for `Logger()` calls
      that could leak an API key or entitlement token — none found; only response content/metadata is
      logged, never request credentials or headers
- [X] T031 [P] Ran the full `flutter test` suite: 269 tests pass, 0 failures, 0 regressions
- [ ] T032 Manual `quickstart.md` Scenarios 1–3 on iOS and Android — **not run**: no device/emulator
      available in this environment. Needs manual execution before release.
- [X] T033 [P] `pubspec.yaml` dependency check: removed `flutter_gemini` and `google_generative_ai`
      (confirmed fully unused after the rewrite); added `build_runner` as a **dev-only** dependency
      (needed for `mockito`'s `@GenerateMocks` to mock `OpenAIClient` for T008–T010/T018/T025 — it does
      not ship in the built app). Net effect on the shipped app: two dependencies removed, zero added.

---

## Post-implementation fixes (found via manual testing)

- **Truncated-response bug**: `GeminiAssistant` used to set a large `maxOutputTokens` (80192); this was
  dropped when generalizing to `OpenAICompatibleAssistant`, so with no cap, a long `"thought"` (observed
  in practice with verbose non-English reasoning) could exhaust the provider's own default token budget
  and get cut off mid-JSON, throwing `FormatException: Unterminated string` and surfacing as a generic,
  unhelpful error. Fixed by (1) setting `maxTokens: 8192` on every request, (2) instructing the model to
  keep `"thought"` to 1–2 sentences, and (3) detecting the truncation case specifically for a clearer
  error message. Covered by two new tests in `openai_compatible_assistant_test.dart`.
- **Stale default Gemini model**: the default Gemini model, `gemini-2.0-flash-exp`, was retired by
  Google on 2026-06-01 — every default-provider request would have failed regardless of setup. Updated
  `AIProviderType.gemini.defaultModel` to `gemini-3.5-flash` (no announced shutdown as of this writing).
  Worth periodically re-checking against Google's changelog.

## Post-implementation scope addition (user request)

- [X] **FR-019**: Moved the pre-existing "show reasoning" / "always allow tools" toggles out of the AI
  assistant chat screen (`lib/src/screens/ai_assistant/ai_assistant.dart`) and into AI provider settings
  (`ai_provider_settings_view.dart`), and made them persist via `SettingsService`/`SettingsController`
  (new keys `ai_show_reasoning`/`ai_always_allow_tools`) instead of resetting every session.
  `AIAssistantCubit._syncBehaviorSettings()` re-reads them into `lastMessages` at startup and on every
  `sendMessage()`, matching the existing "takes effect on next message" pattern used for provider
  config (FR-005). The now-dead `AIAssistantCubit.setShowReasoning`/`setAlwaysAllowTools` methods were
  removed. `flutter test`: 270 pass, `dart analyze`: clean.

## Outstanding follow-ups (not blocking, tracked here for visibility)

1. **T024**: add `test/src/subscription/subscription_manager_test.dart` covering
   `recurringEntitlementProof`/`hasRecurringSubscription` directly.
2. **T023**: decide whether a persistent "N of M free requests remaining" indicator is wanted, or
   whether the current "told only when blocked" UX is sufficient.
3. **T032**: run the quickstart scenarios manually on both platforms before shipping.
4. **Deployment**: the managed-DeepSeek backend itself (FR-018, separate work) must be built and its URL
   supplied via `--dart-define=MANAGED_DEEPSEEK_BASE_URL=...` before the `managedDeepSeek` preset is
   usable in a release build.

---

## Notes

- No task in this file builds, hosts, or deploys a server — `contracts/managed-deepseek-interface.md` is
  the deliverable a separate initiative implements against (FR-018).
- This file was updated post-implementation to reflect what was actually built after a mid-implementation
  architecture simplification (one class instead of four); see the architecture note near the top.
