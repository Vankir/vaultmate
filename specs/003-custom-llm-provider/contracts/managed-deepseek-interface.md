# Interface Contract: Managed DeepSeek Server

**Status**: This document specifies the interface the VaultMate client depends on for the built-in,
managed DeepSeek assistant (spec User Stories 2 & 3). Per spec FR-018, **implementing, hosting, or
coding a server that satisfies this contract is out of scope for this feature** — this document exists
so a separate initiative can build that server, and so the client can be developed and tested against
a mocked HTTP client honoring the same contract in the meantime. Nothing here mandates a language,
framework, or hosting platform; only the wire behavior below is required.

> **Revision note**: this contract was simplified during client implementation. The original draft used
> a custom JSON envelope (`status`/`remaining`/`limit`/`resetAt`) on every response. The client turned
> out to need none of that on the success path — only a way to know *when blocked* and *when it resets*
> — so the contract below is a **plain OpenAI-compatible chat completions endpoint**, with quota
> information carried only on the HTTP 429 error path. This lets the client handle every provider
> (Gemini, ChatGPT, custom, and this managed endpoint) through one identical response-parsing path.

## Non-goals of this document

- Does **not** specify how the server stores usage counts or verifies purchases internally.
- Does **not** specify the server's technology stack, deployment target, or scaling approach.
- Does **not** specify how the server obtains or rotates its own DeepSeek API key.

These are implementation details left entirely to whoever builds the server; this contract only
constrains what the client sends and what it can rely on getting back.

## Endpoint

`POST {base}/chat/completions` — i.e., this MUST be a drop-in OpenAI-compatible chat completions
endpoint (the exact shape `openai_dart`'s `OpenAIClient.createChatCompletion` sends/expects), reachable
at whatever `{base}` URL the app is built with (`AIProviderConfig.managedDeepSeekBaseUrl`, supplied via
`--dart-define=MANAGED_DEEPSEEK_BASE_URL=...` at build time — see `ai_provider_config.dart`).

All requests and responses use `application/json` over HTTPS. Any transport that is not TLS-encrypted
MUST be rejected by the server — the client MUST NOT be required to send this over plaintext HTTP,
since these requests carry the entitlement proof described below.

### Request headers

| Header | Required | Description |
|---|---|---|
| `X-Install-Id` | Yes | The client's opaque, randomly generated per-installation identifier. Not a secret; used only for free-tier rate limiting. |
| `X-Entitlement-Proof` | No | Present only when the client believes it holds an active monthly/yearly subscription. Opaque token forwarded as-is from the platform store's purchase verification data (`in_app_purchase`'s `PurchaseDetails.verificationData`). The server is solely responsible for validating this against Apple/Google — the client makes no claims about its validity (FR-011). |

### Request body

Standard OpenAI chat-completions request body — the client sends exactly what `openai_dart` produces,
e.g.:

```json
{
  "model": "deepseek-chat",
  "messages": [
    { "role": "system", "content": "..." },
    { "role": "user", "content": "..." }
  ],
  "temperature": 0.3,
  "response_format": { "type": "json_object" }
}
```

- `model`: sent by the client but MAY be ignored/overridden by the server, which decides what DeepSeek
  model it actually calls.
- `messages`: the full conversation (system prompt + history + latest user message).

### Response: success

`200 OK` — a standard OpenAI chat-completions response body:

```json
{
  "id": "...",
  "object": "chat.completion",
  "created": 0,
  "model": "deepseek-chat",
  "choices": [
    {
      "index": 0,
      "message": { "role": "assistant", "content": "..." },
      "finish_reason": "stop"
    }
  ]
}
```

This is returned identically whether the request was granted under the free-tier allowance, granted
unlimited access under a verified monthly/yearly subscription, or fell back to free-tier because
`X-Entitlement-Proof` couldn't be verified (FR-015) — the client cannot and does not need to distinguish
these cases; the server applies them all identically on the success path.

### Response: free-tier limit reached

`429 Too Many Requests`

```json
{ "resetAt": "2026-08-24T00:00:00Z" }
```

- MUST be returned instead of `200` once the caller (identified by `X-Install-Id`, absent a verified
  monthly/yearly entitlement) has exhausted the day's allowance (FR-009).
- `resetAt` (ISO-8601) is the only field the client looks for; when present, the client surfaces
  "you've used all your free requests for today, resets at `resetAt`" (FR-014). When absent or
  unparseable, the client falls back to a generic rate-limit message — so a minimal/compliant server
  can omit it, but including it gives users a much better message.
- MUST NOT be counted as a failure the client needs to retry — this is an expected, terminal outcome
  for the current period.
- This status MUST NOT be returned for reasons other than quota (e.g., must not be reused as a generic
  "something went wrong" code), so the client can trust it to always mean "come back later."

### Response: malformed request / server error

`4xx`/`5xx` per standard HTTP semantics for anything not covered above (e.g., `400` for a malformed
body, `500` for an unexpected server fault). The client treats any of these as a transient failure and
does not retry automatically or count it against any allowance.

## Security requirements the server MUST satisfy

- The DeepSeek API key MUST NEVER appear in any response body, header, or error message returned by
  this interface, under any status code — this is the entire point of routing through a server instead
  of shipping the key in the client (spec FR-007/SC-002).
- The server MUST perform its own rate-limiting/quota enforcement keyed on `X-Install-Id` — it MUST NOT
  trust any client-supplied claim about remaining quota or subscription tier (FR-012). A modified or
  patched client, or a direct call to this endpoint bypassing the app entirely, MUST be subject to the
  exact same limits as a call made through the official app.
- The server MUST reject or ignore any `X-Entitlement-Proof` that does not independently verify against
  the platform store as an active monthly or yearly subscription; a lifetime-only purchase MUST NOT be
  treated as granting unlimited access (FR-010/FR-011).

## What the client relies on (verified by `openai_compatible_assistant_test.dart`)

1. A request with no `X-Entitlement-Proof` and remaining quota > 0 returns `200` with a normal chat
   completion.
2. A request with no `X-Entitlement-Proof` and remaining quota = 0 returns `429` with a `resetAt` body,
   and the client surfaces that reset time in its error message.
3. A `429` with a body the client doesn't recognize (missing/malformed `resetAt`) still produces a
   generic "rate-limited, try again shortly" message rather than crashing or hanging.
4. A request with a valid monthly/yearly `X-Entitlement-Proof` (as decided by whatever the server does
   with it) returns `200`, indistinguishable on the wire from case 1.
5. Any network-level failure (timeout, connection refused, non-JSON body) is treated by the client as
   "try again later," never as case 2.
