# Implementation Plan: Custom LLM Provider & Managed DeepSeek Access

**Branch**: `003-custom-llm-provider` | **Date**: 2026-08-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-custom-llm-provider/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Generalize VaultMate's AI assistant beyond Gemini/ChatGPT so users can connect any OpenAI-API-compatible
provider (e.g. DeepSeek) with their own key, and add a built-in, no-setup DeepSeek option backed by a
server the app owner controls — free of charge to try a limited number of times per day, unlimited for
monthly/yearly premium subscribers (explicitly not lifetime subscribers). **Implemented design (revised
mid-implementation from the original per-provider-subclass plan — see research.md #1)**: a single
`OpenAICompatibleAssistant` class, parameterized by endpoint/apiKey/model/extraHeaders, serves every
preset — Gemini (via Google's official OpenAI-compatible endpoint), ChatGPT, custom DeepSeek/local
models, and the managed-DeepSeek proxy — replacing the previously separate `GeminiAssistant` and
`ChatGptAssistant` classes and removing the `flutter_gemini`/`google_generative_ai` dependencies
entirely. Per FR-018, actually building/hosting the managed-DeepSeek backend is out of scope for this
feature — `contracts/managed-deepseek-interface.md` defines the interface contract that backend must
satisfy, so client work could proceed (and was validated) against a mocked HTTP client while the real
backend is implemented as a separate initiative.

## Technical Context

**Language/Version**: Dart (Flutter SDK `>=3.0.0`, project's existing stable channel)

**Primary Dependencies**: `openai_dart` (existing — `OpenAIClient(baseUrl:, headers:)` supports both
arbitrary OpenAI-compatible endpoints and custom headers, which is what makes one shared class possible
for every preset including the managed proxy's `X-Install-Id`/`X-Entitlement-Proof`), `flutter_bloc`/`bloc`
(existing `AIAssistantCubit` pattern), `shared_preferences` (existing local key-value storage),
`in_app_purchase` (existing subscription purchase records, reused as proof sent to the managed-DeepSeek
interface for server-side verification). **Removed**: `flutter_gemini` and `google_generative_ai` — fully
unused once Gemini was reached through its OpenAI-compatible endpoint instead of its native SDK (net
dependency reduction). **Added (dev-only)**: `build_runner`, needed for `mockito`'s `@GenerateMocks` to
generate a proper null-safe mock of `OpenAIClient`; it does not ship in the built app.

**Storage**: `shared_preferences`, matching the existing `chatGptKey` pattern in `SettingsService` —
stores the selected provider type, custom provider endpoint/key/model, and a locally generated
anonymous per-install identifier (random hex string via `dart:math Random.secure()`, no new dependency),
generated eagerly the first time `SettingsController.loadSettings()` runs after install. No new local
database. Server-side storage (usage counters, entitlement cache) is inside the managed DeepSeek
backend, which is out of scope for this spec (see FR-018) — only its interface is defined here.

**Testing**: `flutter_test` + `mockito` (+ `build_runner` for mock generation, dev-only) for
provider-routing, request-building, and error/quota-handling logic under `lib/src/core/ai_assistant/`,
consistent with Constitution Principle III. 269 tests pass as of this implementation, 0 regressions.

**Target Platform**: iOS 15+ and Android, matching the app's existing cross-platform target — this
feature is pure Dart/HTTP with no platform-specific API, so parity is automatic.

**Project Type**: Mobile app (single Flutter project, existing `lib/src` structure) plus one
implementation-free interface contract document for the managed-DeepSeek backend.

**Performance Goals**: No new client-side performance budget beyond the existing AI assistant paths —
message latency is dominated by the third-party/managed provider's own response time, outside this
feature's control. Provider configuration (User Story 1) must be usable in under 2 minutes (SC-001).

**Constraints**: The DeepSeek API key MUST NOT be embedded in or derivable from the client (FR-007);
custom provider keys MUST stay device-local (FR-003); all new code must fit GPLv3 licensing (no new
dependency is introduced, so no new license to vet).

**Scale/Scope**: Client-side change only — one user's device-local configuration, no multi-tenant
concerns in this codebase. Managed-DeepSeek server-side scale (concurrent free/premium request volume,
quota storage) is the responsibility of the separate backend work that will implement the interface
contract produced in Phase 1; it is out of scope for this plan (FR-018).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Local-First & Privacy by Default (NON-NEGOTIABLE) | PASS. Custom-provider keys stay device-local (FR-003). Sending a message to any provider — custom or managed DeepSeek — remains an explicit, opt-in user action, same disclosure pattern as today's Gemini/ChatGPT integration (spec Assumptions). No analytics/telemetry added. |
| II. Obsidian Markdown Compatibility | N/A — this feature does not touch task/note parsing or serialization. |
| III. Test-First for Parsing & Business Logic (NON-NEGOTIABLE) | Applies to new logic under `lib/src/core/ai_assistant/` (provider selection, request building, quota/error handling). Tasks phase MUST include unit tests under `test/` before merge; no violation, just a gate to satisfy during implementation. |
| IV. Branch & Release Discipline | PASS — work proceeds on `003-custom-llm-provider` per standard flow; no release-process changes needed. |
| V. Consistent State Management & Simplicity | PASS. Reuses the existing `AIAssistant`/`AIAssistantCubit` (bloc) abstraction and `SettingsController`/`SettingsService` pattern. No new dependency is introduced (custom-provider support reuses `openai_dart`'s existing `baseUrl` parameter; the anonymous install ID needs only `dart:math`, already available). |
| Platform & Distribution Constraints | PASS — pure Dart/HTTP, no platform-specific API, so iOS/Android parity holds without extra work. |

No violations identified. Complexity Tracking table is not needed.

**Post-Phase-1 re-check**: Design artifacts (research.md, data-model.md, contracts/, quickstart.md)
introduced no new dependency, no backend/server project in this repository, and no change to task/note
parsing. The table above still holds unchanged after design — PASS.

## Project Structure

### Documentation (this feature)

```text
specs/003-custom-llm-provider/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command) — interface contract only, no server code
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

This is the existing single-project Flutter app (`lib/src/core`, `lib/src/screens`, `lib/src/widgets`).
No `backend/`, `api/`, or server project is added to this repository — per FR-018, implementing the
managed-DeepSeek backend is separate, out-of-scope work; this feature only adds client code plus the
interface contract document under `specs/003-custom-llm-provider/contracts/`.

```text
lib/src/core/ai_assistant/
├── ai_assistant.dart                # existing abstract AIAssistant — AIAssistant.fromConfig factory added
├── openai_compatible_assistant.dart # NEW — the ONE class serving every preset (gemini/chatgpt/custom/managed)
└── ai_provider_config.dart          # NEW — provider type enum (with per-preset baseUrl/model) + config (data-model.md)
# gemini_assistant.dart, chatgpt_assistant.dart, extended_generation_config.dart — REMOVED (superseded)

lib/src/core/subscription/
└── subscription_manager.dart      # extended — recurringEntitlementProof/hasRecurringSubscription (monthly/yearly only)

lib/src/screens/settings/
├── settings_service.dart          # extended — persists provider type + custom endpoint/key/model + installId
├── settings_controller.dart       # extended — aiProviderConfig, updateAIProviderType, ensureInstallId
└── ai_provider_settings_view.dart # NEW — UI to pick/configure a provider (custom or managed DeepSeek)

test/
└── src/
    └── ai_assistant/
        ├── ai_provider_config_test.dart
        └── openai_compatible_assistant_test.dart  # covers every preset + tool round-trip + error/quota parsing
```

**Structure Decision**: Single existing Flutter project, extended in place — no new top-level project
or backend directory. The provider client lives alongside the removed `GeminiAssistant`/`ChatGptAssistant`'s
old location, under `lib/src/core/ai_assistant/`, following the same `AIAssistant` abstraction and the
existing `flutter_bloc`/`SettingsController` patterns (Constitution Principle V). The managed-DeepSeek server
itself is intentionally not represented as a directory in this repository's structure — its required
behavior is captured only as the interface contract in `specs/003-custom-llm-provider/contracts/`.

## Complexity Tracking

*No Constitution Check violations were identified — this section is not needed.*
