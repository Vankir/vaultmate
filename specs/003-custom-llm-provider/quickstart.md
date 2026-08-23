# Quickstart: Validating Custom LLM Provider & Managed DeepSeek Access

This guide validates the feature end-to-end on a running app. It covers only client-side behavior;
the managed-DeepSeek backend is out of scope for this feature (FR-018) — where a real backend isn't
available yet, use a local stub that implements `contracts/managed-deepseek-interface.md`.

## Prerequisites

- A working VaultMate dev build (`flutter run`) on iOS or Android, per the project's existing setup.
- For User Story 1: an API key for any OpenAI-compatible provider (e.g. a DeepSeek API key from
  https://platform.deepseek.com, or any other OpenAI-compatible endpoint you have credentials for).
- For User Stories 2 & 3: a stand-in server implementing `contracts/managed-deepseek-interface.md`
  (a minimal script that returns the fixed responses from that contract's "What the client relies on"
  section is sufficient), reachable from the device/emulator, and a sandbox/test purchase for a
  monthly or yearly subscription product (see `SubscriptionManager`) to exercise the premium path.

## Scenario 1 — Connect a custom OpenAI-compatible provider (User Story 1)

1. Open the app → Settings → AI provider settings.
2. Choose "Custom OpenAI-compatible provider" and enter an endpoint URL, API key, and model
   identifier (e.g. DeepSeek's `https://api.deepseek.com`, your key, `deepseek-chat`).
3. Open the AI assistant and send a message.
   - **Expected**: a response appears, produced by the configured endpoint (verify via the endpoint's
     own request logs/dashboard, or by asking a question only that model would answer distinctly).
4. Edit the endpoint/key/model to an invalid value and send another message.
   - **Expected**: a clear, specific error is shown (not a crash), per FR-004.
5. Switch the active provider to Gemini or ChatGPT, then switch back to the custom provider.
   - **Expected**: the previously saved endpoint/key/model are still there, unchanged (FR-005).

## Scenario 2 — Free-tier trial of the built-in DeepSeek assistant (User Story 2)

Point the app's managed-DeepSeek endpoint at your contract-compliant stub configured with a small
limit (e.g. `limit: 2`) for this run.

1. On a fresh install (or after resetting local settings), open the AI assistant with no provider
   configured.
   - **Expected**: the built-in DeepSeek-backed assistant is usable immediately, no key prompt.
2. Send messages until the stub returns `429` with `{"resetAt": "..."}` (2 messages, per the stub's
   configured limit).
   - **Expected**: the next attempt shows a clear "daily limit reached, resets at `resetAt`" message
     with options to add a custom provider key or upgrade to premium (FR-014).
3. Reconfigure the stub to simulate the next day (fresh quota), or advance the stub's clock.
   - **Expected**: the assistant is usable again up to the limit (Acceptance Scenario US2.3).
4. Point the app at an unreachable URL temporarily and send a message.
   - **Expected**: a connectivity error is shown, distinct from the 429 message, and the attempt has no
     effect on the server-side allowance since the client never got a response to count (FR-013).

## Scenario 3 — Unlimited access for monthly/yearly premium (User Story 3)

1. Complete a sandbox/test purchase of the monthly (or yearly) subscription product via
   `SubscriptionManager`.
2. Open the AI assistant (still on the built-in DeepSeek option) and send more messages than the
   stub's configured free-tier limit.
   - **Expected**: every request keeps succeeding (plain `200` responses) — the stub's contract-compliant
     behavior for a valid monthly/yearly `X-Entitlement-Proof` is to never return `429` regardless of
     volume.
3. Cancel/expire the test subscription (or configure the stub to reject its verification token) and
   send another message.
   - **Expected**: the assistant reverts to standard free-tier limiting (Acceptance Scenario US3.2).
4. Repeat steps 1–2 with a **lifetime** test purchase instead of monthly/yearly.
   - **Expected**: requests are still subject to the free-tier limit — a lifetime purchase alone MUST
     NOT unlock unlimited access (Acceptance Scenario US3.4, FR-010).

## Automated coverage

`test/src/ai_assistant/openai_compatible_assistant_test.dart` covers the client-side behaviors behind
Scenarios 1–3 (success, 401/unreachable/429 error classification, tool round-trip, entitlement-proof
attachment) by mocking `OpenAIClient` directly, without requiring a live device or a real
DeepSeek/backend deployment. Scenarios 1–3 above remain the manual, on-device confirmation that the
wiring through Settings → cubit → UI actually works end-to-end — run them before shipping (see
`tasks.md` T032, not yet executed in this environment).
