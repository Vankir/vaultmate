# Phase 0 Research: Custom LLM Provider & Managed DeepSeek Access

All Technical Context fields were resolvable from the existing codebase and dependency set — no
`NEEDS CLARIFICATION` markers remain from the plan template.

> **Post-implementation update**: Decision #1 below was revised mid-implementation after a design
> review concluded that per-provider subclasses (`GeminiAssistant`, `ChatGptAssistant`,
> `CustomOpenAIAssistant`, `ManagedDeepSeekAssistant`) were unnecessary duplication. The revised
> decision — one class for every provider — is recorded below in place of the original; see git
> history for the superseded version if needed. Decision #5's contract format also shifted from a
> custom success-body envelope to a plain 429 error body for quota signaling (see the contract file).

## 1. How to support every provider — Gemini, ChatGPT, DeepSeek, local models, and the managed proxy — through one class

**Decision**: A single `OpenAICompatibleAssistant` class, parameterized by `baseUrl`, `apiKey`, `model`,
and `extraHeaders`, serves every preset:
- **Gemini**: `baseUrl = https://generativelanguage.googleapis.com/v1beta/openai` (Google's official
  OpenAI-compatible endpoint), user's Gemini API key as `apiKey`.
- **ChatGPT**: `baseUrl = null` (the client SDK's own default, `https://api.openai.com/v1`), user's
  OpenAI key.
- **Custom (DeepSeek, local model, etc.)**: user-supplied `baseUrl`/`apiKey`/`model`.
- **Managed DeepSeek**: app-owner-deployed proxy URL, no user key, `X-Install-Id` (+ conditionally
  `X-Entitlement-Proof`) as `extraHeaders` instead of a bearer token.

**Rationale**: `openai_dart`'s `OpenAIClient` already exposes both a `baseUrl` override and a `headers`
map for custom headers (`openai_dart-0.4.5/lib/src/generated/client.dart`), and Google publishes an
official OpenAI-compatible endpoint for Gemini with full chat-completions, function-calling, and JSON
mode support ([Gemini API OpenAI compatibility](https://ai.google.dev/gemini-api/docs/openai),
[Gemini is now accessible from the OpenAI Library](https://developers.googleblog.com/en/gemini-is-now-accessible-from-the-openai-library/)).
Once every provider speaks the same wire format, there is no remaining reason for separate Dart classes
per provider — doing so would just be duplicated request-building, error-handling, and tool-calling
logic that has to be kept in sync four times instead of once (Constitution Principle V: prefer the
simplest solution, avoid unjustified duplication). This also let the `flutter_gemini` and
`google_generative_ai` dependencies be removed entirely (net dependency reduction).

Errors are classified by HTTP status/shape alone (401/403 → key rejected, no status → unreachable, 429
→ rate-limited/quota — see `contracts/managed-deepseek-interface.md`), never by "which provider is
this," so the same error-handling path covers every preset including the managed proxy's quota-exceeded
response.

**Alternatives considered**:
- One subclass per provider (the original decision) — rejected once it became clear all four presets
  speak the identical wire protocol; would have meant four copies of the same request/error/tool-calling
  logic to maintain.
- A raw `http`/`dio` client hand-rolling the OpenAI request format — rejected, duplicates what
  `openai_dart` already does correctly and would need to be kept in sync with the spec independently.
- A different Dart OpenAI-compatible SDK — rejected, no reason to add a second dependency doing the
  same job the existing one already does (Constitution Principle V: unjustified new dependencies).

## 2. How the client identifies itself to the managed-DeepSeek interface without an account system

**Decision**: Generate a random 128-bit identifier on first launch using `dart:math`'s
`Random.secure()`, store it in `shared_preferences` (same mechanism as every other local setting),
and send it as an opaque per-installation identifier with each managed-DeepSeek request.

**Rationale**: Per spec Assumptions, the app has no account/login system and this feature must not add
one. `Random.secure()` is part of the Dart SDK — no new dependency (a `uuid` package would add one for
no real benefit; a raw secure-random hex string serves the same purpose as an opaque identifier). The
identifier is not a secret and grants no elevated access by itself — the server interface's job
(out of scope here, but constrained by FR-011/FR-012) is to rate-limit per identifier and never trust
it as a substitute for verified purchase/entitlement data.

**Alternatives considered**:
- `package_info_plus`'s app/build info — rejected as an identifier source; it doesn't uniquely and
  stably identify an *installation*, only the app build.
- Platform-provided advertising/device IDs — rejected: unavailable/discouraged on iOS without
  additional permission prompts, and would conflict with Constitution Principle I (no tracking SDKs).

## 3. How premium entitlement is proven to the managed-DeepSeek interface

**Decision**: The client attaches the same `PurchaseDetails.verificationData` it already receives from
`in_app_purchase` (see `SubscriptionManager._verifyPurchase`, currently only checked client-side) to
requests aimed at unlocking unlimited managed-DeepSeek access. The interface contract (Phase 1) defines
this as an opaque token the client forwards as-is; validating it against Apple/Google is the receiving
server's job, not the client's.

**Rationale**: This closes the exact gap already flagged as a TODO in `subscription_manager.dart`
("Implement server-side purchase verification") without requiring a new payment system — `in_app_purchase`
is already a dependency and already produces this verification data today; the client was simply never
sending it anywhere for independent verification (FR-011).

**Alternatives considered**:
- Introducing a full account/login system so the server can look up entitlement by user ID — rejected
  as disproportionate scope creep; contradicts the project's local-first, no-login design and isn't
  needed since the store receipt itself is sufficient proof.

## 4. How the client behaves when it doesn't yet know the free-tier daily limit or remaining count

**Decision** (revised): The client never hardcodes or caches a limit value, and — per the revised
contract (decision #5) — never receives one on the success path either. A successful managed-DeepSeek
response is a plain chat completion, with no `limit`/`remaining` fields to track between messages. Only
when a request is actually blocked does the server return `429` with a `resetAt` field in the body,
which the client surfaces directly in the error message (FR-014's "reset time" requirement) without
needing any running local counter.

**Rationale**: Per spec Assumptions, the daily limit is an operational parameter the app owner can tune
server-side without an app release; the client never needing to know the numeric limit at all (only
"blocked, retry at X" when it happens) achieves that with less surface area than threading
`limit`/`remaining` through every successful response. This also means the same generic 429-handling
code path (decision #1) naturally covers quota messaging with no managed-DeepSeek-specific branch.

**Alternatives considered**:
- Hardcoding the limit as a Dart constant — rejected; would require an app store release every time the
  app owner wants to tune the free-tier allowance to actual DeepSeek cost.
- Returning `remaining`/`limit` on every successful response (the original decision) — rejected during
  implementation as unnecessary: FR-014 only requires messaging when the limit is *reached*, not a
  running counter on every message, so there was no requirement actually motivating the extra fields.

## 5. Format for the managed-DeepSeek interface contract (Phase 1 deliverable)

**Decision**: Document the contract as a plain-language + JSON-schema Markdown file under `contracts/`
(request/response shape, headers, status codes, and field semantics), rather than a full OpenAPI YAML
document or any server-side code/config.

**Rationale**: FR-018 scopes this spec to *defining* the interface, not implementing or even fully
formalizing it as machine-executable tooling (which would itself start to look like backend scaffolding).
A Markdown contract is unambiguous enough for a separate backend implementation effort to build against,
consumable by both engineers and this feature's own client-side tests (which will exercise the client
against a hand-written stub honoring the same contract), and avoids implying that OpenAPI tooling,
codegen, or any particular server framework is part of this feature's scope.

**Alternatives considered**:
- Full OpenAPI 3.x YAML spec — rejected for this feature; it's a reasonable input to the *separate*
  backend implementation effort, but authoring it here risks scope creep into backend design decisions
  (framework, validation library, etc.) that FR-018 explicitly puts out of bounds.
