# Phase 1 Data Model: Custom LLM Provider & Managed DeepSeek Access

Entities are drawn from the spec's Key Entities section. Only the **AI Provider Configuration** entity
is client-owned/persisted data; the other three describe the shape of data exchanged with (or held by)
the managed-DeepSeek server interface, whose implementation is out of scope for this spec (FR-018) —
they're modeled here only as the request/response contract the client depends on.

## AI Provider Configuration (client-owned, persisted in `shared_preferences`)

Represents which LLM the assistant is currently configured to use. Extends the existing single
`chatGptKey` string setting into a structured, provider-aware configuration.

| Field | Type | Notes |
|---|---|---|
| `providerType` | enum: `gemini`, `chatgpt`, `customOpenAI`, `managedDeepSeek` | Which preset config (endpoint/model defaults) to apply — all four are served by the same `OpenAICompatibleAssistant` class (see research.md #1), not per-provider subclasses. Defaults to the pre-existing behavior (`gemini`) for users who upgrade without reconfiguring — no migration prompt required, matches FR-016. |
| `apiKey` | `String?` | Required for `gemini`, `chatgpt`, `customOpenAI`. Not applicable for `managedDeepSeek` (FR-006). Never leaves the device except to the provider it's configured for (FR-003). |
| `baseUrl` | `String?` | Required for `customOpenAI` only; the OpenAI-compatible endpoint (e.g. DeepSeek's). Ignored for other provider types. |
| `model` | `String?` | Required for `customOpenAI`; the model identifier to send to the endpoint (e.g. `deepseek-chat`). |
| `installId` | `String` | Opaque, randomly generated per install (see research.md #2), generated once and reused for the lifetime of the install. Sent with `managedDeepSeek` requests only; not tied to `providerType` selection. |

**Validation rules** (from FR-001, FR-004, FR-005):
- `customOpenAI` requires all of `baseUrl`, `apiKey`, `model` to be non-empty before it can be selected/used.
- Editing or clearing any of `baseUrl`/`apiKey`/`model` while `customOpenAI` is active takes effect on
  the next message (no restart required) — no separate "save" step blocks usage of other providers.
- Switching `providerType` away from `customOpenAI` preserves its stored `baseUrl`/`apiKey`/`model`
  for later reuse (Acceptance Scenario US1.4) rather than clearing them.

**Lifecycle**: created on first app use with `providerType = gemini` (matches today's default);
updated whenever the user changes provider settings; `installId` is generated exactly once — eagerly,
the first time `SettingsController.loadSettings()` runs after install (a simplification of the original
"lazy on first managed-DeepSeek use" plan; behaviorally equivalent, see research.md #2) — and never
regenerated.

---

## Managed AI Proxy Request (client → server interface; contract, not a local entity)

What the client sends when the active provider is `managedDeepSeek` — a **plain OpenAI-compatible chat
completions request** (same `messages` shape as every other preset), plus two custom headers. See
`contracts/managed-deepseek-interface.md` for the full wire format.

| Field | Type | Notes |
|---|---|---|
| `X-Install-Id` header | `String` | The client's opaque per-install identifier (see above). |
| `X-Entitlement-Proof` header | `String?` | Opaque purchase-verification token forwarded as-is from `in_app_purchase`'s `PurchaseDetails.verificationData`, present only when the client believes it holds an active monthly/yearly subscription; absent for free-tier requests. The server — not the client — decides what this proves (FR-011). |
| `messages` (body) | list of chat messages | Same shape already used for every other provider (conversation history + system prompt) — this is standard `openai_dart` request, not a custom envelope. |

## Managed AI Proxy Response (server interface → client; contract, not a local entity)

Revised from the original design: rather than a custom JSON envelope with `status`/`remaining`/`limit`
fields on every response, the response is a **plain OpenAI-compatible chat completion on success**, with
quota information appearing only on the HTTP status/error path — this lets the client use the exact same
response handling for every preset (research.md #1/#4).

| Case | HTTP status | Body |
|---|---|---|
| Success (free-tier with room left, or unlimited premium, or unverified-entitlement-falls-back-to-free) | `200` | Standard OpenAI chat completion (`choices[0].message.content`) — no custom fields. |
| Free-tier daily limit reached | `429` | `{"resetAt": "<ISO-8601>"}` — the only custom field the client looks for; used verbatim in the "reached your limit, resets at X" message (FR-014). |

## Usage Allowance (server-owned; described for completeness, not implemented by this spec)

Tracks how many `managedDeepSeek` requests a given `installId` has made in the current period. Exists
only inside the (out-of-scope) backend; the client never sees or caches this count directly — it only
ever learns "blocked, try again at `resetAt`" via the 429 response above.

## Subscription Entitlement (server-owned; described for completeness, not implemented by this spec)

The backend-verified subscription tier (`free`, `monthly`, `yearly`, `lifetime`) derived from validating
`X-Entitlement-Proof` against the platform store. Per FR-010/FR-011, only `monthly`/`yearly` map to
unrestricted managed-DeepSeek access; `lifetime` and `free` are both subject to the daily limit. The
client never computes or caches this tier itself, and never even attempts to distinguish "unverified
proof" from "no proof" — both simply behave as free-tier from the client's point of view (FR-015).
