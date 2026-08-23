# Feature Specification: Custom LLM Provider & Managed DeepSeek Access

**Feature Branch**: `003-custom-llm-provider`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "There's currently functionality to connect Gemini, but I'd like the ability to connect any LLM that supports the standard OpenAI API, for example DeepSeek or any other model. In addition, I'd like premium users to be able to use my DeepSeek model, while free users get a limited number of tries per day. This needs to be implemented so that no one can steal my DeepSeek key and bankrupt me. VaultMate is currently open source and everyone can view the source code."

## Clarifications

### Session 2026-08-23

- Q: Which premium subscription tiers should get unlimited access to the managed DeepSeek option? → A: Only monthly and yearly (recurring) subscriptions; lifetime subscribers do NOT get unlimited managed DeepSeek access, since a one-time lifetime payment doesn't fund an ongoing per-request cost.
- Q: Should this spec cover building/coding the managed DeepSeek backend itself? → A: No — if any server-side coding is required, it is OUT OF SCOPE for this spec. This spec only defines the required server interface (the contract the client depends on: what the backend must accept, verify, enforce, and return); actually building, hosting, or coding that backend is separate, out-of-scope work.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Connect any OpenAI-compatible AI provider (Priority: P1)

As a user, I want to add my own API key for any AI provider that speaks the standard OpenAI API (for example DeepSeek, or any other compatible model), so I'm not limited to Gemini/ChatGPT and can use whichever provider I already trust or pay for.

**Why this priority**: This is the most directly requested capability, generalizes the app's existing "bring your own key" pattern already used for Gemini and ChatGPT, and carries zero ongoing cost or abuse risk to the app owner since the user supplies and pays for their own key.

**Independent Test**: Can be fully tested by entering a custom endpoint URL, model name, and API key in AI provider settings, then completing a conversation with the AI assistant using that provider — delivers value entirely on its own, with no dependency on the managed DeepSeek option.

**Acceptance Scenarios**:

1. **Given** no custom provider is configured, **When** the user opens AI provider settings, **Then** they see an option to add a custom OpenAI-compatible provider requiring an endpoint URL, an API key, and a model identifier.
2. **Given** valid custom provider credentials are saved and selected, **When** the user sends a message in the AI assistant, **Then** the response is produced by the configured custom provider and displayed the same way responses from Gemini/ChatGPT are.
3. **Given** an invalid API key or unreachable endpoint, **When** the user sends a message, **Then** the user sees a clear, specific error (e.g., authentication failed, endpoint unreachable) and the assistant remains usable afterward.
4. **Given** a custom provider is configured, **When** the user switches to Gemini, ChatGPT, or back, **Then** the custom provider's saved settings are preserved for later reuse.
5. **Given** the user is editing a previously saved custom provider, **When** they update or remove the endpoint/key/model, **Then** the change takes effect on the next message without requiring an app restart.

---

### User Story 2 - Try the built-in DeepSeek assistant without any setup (Priority: P2)

As a free-tier user with no AI provider of my own configured, I want to try a built-in AI assistant a limited number of times per day at no cost to me, so I can evaluate the AI feature's value before bringing my own key or subscribing to premium.

**Why this priority**: Lowers the barrier to discovering the AI assistant's value and supports premium conversion, but is not required for the app's core task-management functionality and depends on a backend that satisfies the server interface defined in this spec (building that backend is separate, out-of-scope work — see Clarifications and FR-018).

**Independent Test**: Can be fully tested end-to-end once a backend implementing this spec's server interface (built separately, out of scope) is available: using the built-in assistant up to the daily limit, confirming the next attempt is blocked with a clear explanation, and confirming the allowance resets after the reset period elapses. On the client side alone, this can be validated against a stand-in server that implements the same interface.

**Acceptance Scenarios**:

1. **Given** a free-tier user with no AI provider configured, **When** they open the AI assistant, **Then** they can chat using the built-in DeepSeek-backed assistant without entering any key.
2. **Given** a free-tier user has used the built-in assistant the maximum number of times allowed for the current period, **When** they try again, **Then** they see a message explaining the limit was reached, when it resets, and are offered the choice to add their own provider key or upgrade to premium.
3. **Given** a free-tier user reached their limit in a previous period, **When** the next period begins, **Then** they can use the built-in assistant again up to the limit.
4. **Given** a request to the built-in assistant fails due to a network or provider error, **When** the failure occurs, **Then** it is not counted against the user's daily allowance.

---

### User Story 3 - Unlimited built-in DeepSeek access for monthly/yearly premium subscribers (Priority: P2)

As a monthly or yearly premium subscriber, I want to use the built-in DeepSeek assistant without the free-tier daily limit and without configuring my own API key, so my recurring subscription includes a ready-to-use AI assistant as a paid benefit.

**Why this priority**: Adds tangible, recurring value to the paid tier and supports subscription retention, but relies on the same managed-proxy interface as User Story 2 (whose implementation is out of scope for this spec — see FR-018) and is validated after the base free/paid gating exists. This benefit is funded by recurring revenue, so it is deliberately scoped to the recurring (monthly/yearly) subscription tiers only — not the one-time lifetime tier (see Clarifications).

**Independent Test**: Can be fully tested with an active monthly or yearly test subscription, against a backend implementing this spec's server interface, by exceeding the free-tier daily limit in a single day and confirming requests keep succeeding, then canceling/expiring the subscription and confirming the free-tier limit applies again. Separately, a lifetime-subscription test account confirms it does NOT receive unlimited access.

**Acceptance Scenarios**:

1. **Given** an active, verified monthly or yearly premium subscription, **When** the user uses the built-in assistant more times in a day than the free-tier limit, **Then** requests continue to succeed.
2. **Given** a subscription that has expired or been canceled, **When** the user next uses the built-in assistant, **Then** they are treated as a free-tier user subject to the daily limit going forward.
3. **Given** the backend cannot confirm a user's subscription status (e.g., verification service unavailable), **When** the user attempts to use the built-in assistant, **Then** the system fails safe by treating them as free-tier rather than granting unverified unlimited access.
4. **Given** a user holds only a lifetime subscription (no active monthly/yearly subscription), **When** they use the built-in assistant, **Then** they remain subject to the free-tier daily limit and are never granted unlimited managed DeepSeek access on the strength of the lifetime purchase alone.

---

### Edge Cases

- What happens when a technically sophisticated user reads the open-source client code, extracts the managed-proxy endpoint, and calls it directly (bypassing the app) to try to exceed their daily limit or impersonate a premium user? The backend proxy MUST reject or rate-limit such requests the same way it would from within the app, since no secret the client holds can be trusted.
- What happens when a user reinstalls the app or uses multiple devices? Free-tier usage tracking is scoped to the app installation, so a fresh install may grant a new allowance; this is an accepted limitation rather than a security hole, since the app has no account/login system to track usage more durably.
- What happens when a custom OpenAI-compatible provider's model doesn't support the response format the app relies on for task actions (e.g., structured task creation)? The assistant MUST degrade to a plain conversational reply rather than failing outright.
- What happens when the device has no network connectivity when trying the built-in assistant? The user sees a connectivity error and the attempt is not counted against their daily allowance.
- What happens if a user has both a custom provider configured AND is eligible for the built-in DeepSeek option? The user's explicitly selected active provider takes precedence; switching providers is always a manual, visible choice.
- What happens when a lifetime subscriber (with no active monthly/yearly subscription) uses the built-in DeepSeek assistant? They are treated the same as any free-tier user, subject to the standard daily limit — the lifetime purchase does not by itself unlock unlimited managed DeepSeek access (see Clarifications).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Users MUST be able to add a custom AI provider by specifying an OpenAI-API-compatible endpoint URL, an API key, and a model identifier, in addition to the existing Gemini and ChatGPT options.
- **FR-002**: The AI assistant MUST route conversations to whichever provider (Gemini, ChatGPT, custom OpenAI-compatible, or built-in managed DeepSeek) the user has currently selected as active.
- **FR-003**: Custom provider API keys MUST be stored only on the user's own device and MUST NOT be transmitted to or stored by any server the app owner operates, since they are the user's own third-party credentials.
- **FR-004**: The system MUST show a clear, specific, non-crashing error when a custom provider connection fails (invalid key, unreachable endpoint, unexpected response format).
- **FR-005**: Users MUST be able to edit or remove a previously configured custom provider's endpoint, key, and model at any time, with the change taking effect immediately.
- **FR-006**: The system MUST offer a built-in, managed DeepSeek-backed assistant option that requires no user-supplied API key.
- **FR-007**: The server interface backing the managed DeepSeek option MUST be specified such that the DeepSeek API key is held exclusively on infrastructure the app owner controls (never embedded in, bundled with, or derivable from the open-source client application) and is never observable in any network traffic the client sends or receives.
- **FR-008**: All use of the managed DeepSeek option MUST be routed through a server interface that holds the protected key and forwards requests to DeepSeek on the user's behalf; the client MUST never receive, cache, or have access to that key. This spec defines the required behavior of that interface only (see FR-018); it does not require this feature to build the server that implements it.
- **FR-009**: The server interface MUST let free-tier (non-premium) users use the managed DeepSeek option up to a limited number of times per day, after which further attempts are blocked until the allowance resets. *(exact daily limit: see Assumptions)*
- **FR-010**: The server interface MUST let verified monthly or yearly premium subscribers use the managed DeepSeek option without being subject to the free-tier daily limit; lifetime subscribers MUST NOT receive this unlimited benefit and remain subject to the free-tier daily limit unless they also hold an active monthly/yearly subscription. *(whether monthly/yearly access is fully unlimited or has a high fair-use ceiling: see Assumptions)*
- **FR-011**: The server interface MUST independently verify a user's subscription status and tier (monthly, yearly, or lifetime) before granting unlimited access to the managed DeepSeek option — it MUST NOT rely solely on a status flag reported by the client app, and MUST NOT grant unlimited access on the basis of a lifetime-only subscription.
- **FR-012**: The server interface MUST track and enforce the free-tier daily usage count itself (not the client), so the limit cannot be bypassed by modifying, patching, or replaying calls from the open-source client.
- **FR-013**: The system MUST NOT count failed attempts (network errors, provider/backend outages) against a free-tier user's daily allowance.
- **FR-014**: When a free-tier user reaches their daily limit, the system MUST inform them the limit was reached, when it resets, and offer a path to continue (configure their own provider key, or upgrade to premium).
- **FR-015**: If the server interface cannot verify a user's premium status, it MUST default that user to free-tier limits rather than granting unrestricted access.
- **FR-016**: The system MUST continue to support the existing Gemini and ChatGPT provider options unchanged.
- **FR-017**: Custom OpenAI-compatible providers MUST support the same task-oriented conversational capabilities (creating/finding tasks through the assistant) that the existing providers offer, falling back to plain conversational replies only when the connected model itself cannot produce the required structured response.
- **FR-018**: This spec's scope is limited to (a) the client-side custom-provider capability (User Story 1, fully self-contained) and (b) the required behavior/interface (contract) of the managed DeepSeek server described in FR-006–FR-015: what it must accept, verify, enforce, and return. Actually coding, hosting, or operating a backend that implements that interface — any server-side implementation work — is OUT OF SCOPE for this spec and MUST be planned/tracked as separate work.

### Key Entities

- **AI Provider Configuration**: Represents one way the assistant can talk to an LLM — its type (Gemini, ChatGPT, custom OpenAI-compatible, or built-in managed DeepSeek), and for user-supplied types, an endpoint URL, model identifier, and API key stored locally on the user's device.
- **Managed AI Proxy**: The server interface — specified by this spec but implemented as separate, out-of-scope work — that holds the shared DeepSeek key, authenticates and authorizes each request, verifies subscription entitlement, and enforces the free-tier daily usage limit before forwarding a request to DeepSeek.
- **Usage Allowance**: Tracks how many managed DeepSeek requests a free-tier installation has made within the current day, reset on a recurring schedule.
- **Subscription Entitlement**: The backend-verified subscription status and tier (free, monthly, yearly, or lifetime) used to decide whether the Managed AI Proxy applies the free-tier daily limit or grants unrestricted access to a given request — only monthly and yearly tiers qualify for unrestricted access.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can configure a new custom OpenAI-compatible provider and receive a working AI assistant response in under 2 minutes from opening provider settings.
- **SC-002**: The managed DeepSeek API key never appears in the released client application's code, resources, local storage, or in any network traffic observable from the device — confirmed by inspecting the client and its traffic, not just trusting the design.
- **SC-003**: Free-tier users cannot obtain more managed-DeepSeek responses per day than the configured limit, even when repeatedly retrying, reinstalling within the same day, or calling the backend directly instead of through the app.
- **SC-004**: Monthly and yearly premium subscribers experience no daily-limit interruptions on the managed DeepSeek option for as long as their subscription remains verified active; lifetime-only subscribers continue to see the same daily limit as free-tier users.
- **SC-005**: When a free-tier user's daily allowance is exhausted, at least 90% of users in usability testing understand why the assistant stopped responding and what their options are, without contacting support.

## Assumptions

- Building, coding, hosting, or operating the managed DeepSeek server is OUT OF SCOPE for this spec (see Clarifications and FR-018). This spec defines what that server interface must do (FR-006–FR-015); a separate initiative is responsible for actually implementing and deploying it. User Stories 2 and 3 and their related success criteria describe the end-to-end behavior once such a backend exists, but delivering that backend is not part of this feature's scope.
- The app currently has no server-side account/login system (per the project's local-first design); the managed DeepSeek proxy identifies free-tier installations using an anonymous per-installation identifier rather than requiring a new account system. A full reinstall may therefore reset a free user's daily allowance — an accepted trade-off rather than a defect.
- Premium subscription entitlement is verified by the backend against the app store's purchase records (Apple/Google), reusing the subscription products the app already defines, rather than introducing a separate payment or account system. This closes the gap in the existing client-only subscription check, which today trusts a locally stored status flag.
- The exact free-tier daily limit is a tunable operational parameter the app owner can adjust based on actual DeepSeek cost, not a fixed number defined by this spec; a starting value will be set at launch and may change without requiring an app update.
- Premium access to the managed DeepSeek option is effectively unlimited for normal personal use for monthly and yearly subscribers only, but the backend may still apply a high fair-use ceiling well above any realistic personal-use pattern, purely as a cost-safety backstop against a compromised or shared premium credential. Lifetime subscribers are deliberately excluded from this unlimited benefit and fall back to the standard free-tier daily limit, since a one-time lifetime payment doesn't fund an ongoing per-request cost the way a recurring subscription does.
- "Any other model" is scoped to providers reachable through an OpenAI-API-compatible chat completions interface; providers that only expose a fundamentally different API shape are out of scope for this feature.
- Sending a message to any provider (custom or built-in) remains an explicit, opt-in user action; task/vault content is only sent off-device when the user actively uses the AI assistant, consistent with the project's existing privacy behavior for Gemini/ChatGPT.
- A user has at most one active/selected AI provider at a time; custom providers are additive to, not a replacement for, the existing Gemini/ChatGPT options.
