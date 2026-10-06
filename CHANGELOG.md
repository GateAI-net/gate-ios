# Changelog

All notable changes to the Gate/AI iOS SDK are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] - Unreleased

### Added
- **OpenAI Realtime voice.** `client.createRealtimeCall(offerSDP:session:)` exchanges a WebRTC
  SDP offer for OpenAI's answer through the gate and returns the call ID. Audio flows directly
  between the device and OpenAI while the gate meters each model turn and applies usage limits
  for the whole call. Bring your own WebRTC library.

### Changed
- Align the native SDK version with Android at 1.2.0. This version bump does not change iOS runtime behavior.

## [1.1.0] - 2026-08-31

### Added
- **Usage limits & quotas.** `client.quotaAnchorDay` (1–31, validated with a one-time
  warning) is sent as `X-Quota-Anchor-Day` so per-device budgets can follow each user's
  billing cycle. `client.userTier` is sent as `X-User-Tier` and is the exact,
  case-sensitive key for per-tier limits configured in the Portal; `userStatus` stays a
  free-form analytics segment.
- `GateAIQuotaStatus` — remaining device quota parsed from the `X-Quota-Requests-*` and
  `X-Quota-Tokens-*` response headers (remaining, limit, and per-metric reset dates),
  exposed as `HTTPURLResponse.gateAIQuotaStatus`. Includes `requestsUsed` / `tokensUsed`
  and `requestsUsedFraction` / `tokensUsedFraction` helpers for rendering usage meters.
- `GateAIRateLimitInfo` — structured details for `429 rate_limited` responses (code,
  message, window, limit, used, resetsAt) with an unknown-safe `Window` enum, reachable via
  `GateAIError.rateLimitInfo`.
- Analytics: `client.userIdentifier` (`X-User-Identifier`) and `client.appFeature`
  (`X-App-Feature`) developer-set properties, plus automatic `X-Environment`
  (development / testflight / production), `X-Device-Model`, and `X-SDK-Version` headers.
  Per-request `additionalHeaders` take precedence over client-level analytics defaults.
- `GateAIVersion.current` — the SDK version string.
- README and INTEGRATION sections on usage limits, quotas, and analytics headers.
- Tests for quota header parsing, 429 body parsing, anchor-day validation, analytics
  headers, and ISO 8601 date parsing.

### Security
- Logged request and response bodies redact `dev_token`, `access_token`, `refresh_token`,
  `dpop`, and `client_secret`, and debug payloads use `%{private}@` so they are not persisted
  in the clear by the unified log / sysdiagnose.
- A 2xx decode failure now logs only the error and byte count, not the raw body (which on
  `/token` contained the access token).
- `GateAIConfiguration` requires an `https` base URL (`http` is allowed only for localhost)
  so bearer tokens and DPoP proofs are never sent in cleartext.

### Fixed
- `GateAIConfiguration` validates `teamIdentifier` again (exactly 10 alphanumeric
  characters). The check had been dropped when development tokens moved to the
  environment, so malformed Team IDs were accepted and failed later at attestation.

## [1.0.5] - 2026-08-26

### Fixed
- iOS 27 beta changed the device attestation flow, producing a DeviceCheck key that would
  never authenticate. New App Attest keys are now attested proactively instead of probed
  with `generateAssertion`.

[1.1.0]: https://github.com/GateAI-net/gate-ios/releases/tag/1.1.0
[1.0.5]: https://github.com/GateAI-net/gate-ios/releases/tag/1.0.5
