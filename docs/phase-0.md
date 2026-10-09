# RepairAI — Phase 0: Network Core

> **Status: complete.** `flutter analyze` 0 issues · `flutter test` 56 passing
> + 1 live smoke test (skipped locally, green against production). No page,
> route or widget changed — this phase is plumbing only.
>
> This file is the explanation of record, so source files stay lean. If a
> file below has no purpose, it should be deleted.

## What shipped

The client half of Phase 0 from `api-coverage.md`: HTTP client, JWT store,
refresh interceptor, `Result` type, bounded timeouts, health check.
Feature pages consume this from Phase 1 onward.

## Files created and their purpose

### `lib/features/network/data/`

| File | Purpose |
|---|---|
| `result.dart` | The `Result<T>` contract every call returns: `Data`, `Error`, `Offline`. Forces consumers to handle every outcome instead of crashing on null. |
| `api_exception.dart` | Typed failure carried inside `Error`. `ApiFailureKind.http` = server rejected it (with status code); `malformed` = payload unusable. Lets pages branch on 401 vs 500 later. |
| `token_storage.dart` | `TokenStorage` contract plus `InMemoryTokenStorage`. The contract is what lets Phase 1 swap in secure persistence without touching the client. |
| `auth_authenticator.dart` | `Authenticator` contract plus `JwtAuthenticator`: exchanges a refresh token at `/api/auth/refresh/`. Refresh is **single-flight** — N simultaneous 401s cost exactly one refresh, which matters because refresh tokens rotate. |
| `api_client.dart` | JSON `get`/`post` with a 5s timeout, bearer header, one transparent refresh-and-retry on 401, and mapping to `Result`. Never throws. Holds `apiBaseUrl`, the `--dart-define` entry point. |
| `app_version.dart` | Model for `GET /api/app-version/`, decoded from the payload proven live on 2026-10-06. |
| `health_check.dart` | One function: run the app-version probe through the client. Doubles as the online/offline signal and the CI smoke endpoint. |

### `lib/features/network/logic/`

| File | Purpose |
|---|---|
| `network_providers.dart` | Riverpod wiring: one token store, one authenticator, one `ApiClient` per container, closed on dispose. Pages watch these instead of constructing networking themselves. |
| `health_controller.dart` | `healthProvider` — the backend's health as reactive state. Pages watch it and switch over `Result`. |

### `test/features/network/` and `test/smoke/`

Nine test files, one per source file, per `AGENT_SPEC` §1.1, plus the live
smoke test below. The load-bearing
cases: concurrent refresh dedupe, 401 → refresh → retry with the rotated
token, timeout → `Offline`, unreachable host → `Offline`, malformed payload →
`Error`, and every refresh failure branch.

### `.github/workflows/ci.yml` — the CI smoke test

CI now runs `flutter test` with `LIVE_SMOKE=1`, which un-gates
`test/smoke/live_api_smoke_test.dart`: a real request to production
`/api/app-version/`. Local runs skip it explicitly — reported as *skipped*,
not passed — so development stays offline. This is the "CI smoke test"
Phase 0 calls for in `api-coverage.md`, and the live proof `AGENT_SPEC`
§1.8 demands before pages ship against a backend.

## Dependencies added (AGENT_SPEC §1.5)

| Dep | Why | Why not the alternative |
|---|---|---|
| `http ^1.6.0` | The transport. Small and official; `package:http/testing` ships `MockClient`, so the whole suite runs offline with no new dep. | `dio` — interceptors are handy but the package is far heavier than a JSON REST client needs. `dart:io HttpClient` — zero deps but a lot more hand-written timeout/error code. |
| `flutter_riverpod ^3.4.3` | Mandated by `architecture.md`: one pattern app-wide, logic in `features/<feature>/logic/`, pages stay dumb. Gives DI plus reactive state. | Bloc — more boilerplate for the same job. Plain Dart — would force a rewrite of every controller once a pattern was chosen. |

Commit message for the pubspec change is kept terse per the ≤15-word rule;
this table is the written reason §1.5 asks for.

## Decisions taken

1. **Base URL** — `String.fromEnvironment('API_BASE_URL')`, defaulting to
   production. Override with
   `flutter run --dart-define=API_BASE_URL=...`. Read from `api_client.dart`
   and nowhere else (the `epl_app` hardcoded-URL lesson).
2. **Timeout: 5s**, replacing `epl_app`'s 8s cliff. A stall becomes
   `Offline`, so a slow rural connection degrades visibly instead of hanging.
3. **Tokens live in memory only.** Secure on-device persistence is deferred
   to the auth slice, deliberately: writing a JWT to disk before a login flow
   exists would be a pointless security hole. `TokenStorage` is the seam.
   *(Superseded in Phase 1: `tokenStorageProvider` now defaults to
   `SecureTokenStorage`; see `phase-1.md` §Hardening pass.)*
4. **Token clearing rule** — clear both tokens **only when the server
   definitively rejects the refresh (4xx)**. Every other failure keeps
   them: timeout, socket error, or a garbled/unexpected 200 payload
   (captive portal, CDN error page) is network flakiness, not a dead
   token, and must never log a user out. If the token really is dead,
   the next attempt comes back 4xx and clears then.
5. **`Result.loading` was cut.** It had no producer in the data layer:
   pending state is already carried by Riverpod's `AsyncValue`, so the
   variant was dead weight. `Result` is `Data` / `Error` / `Offline`.

## Known gaps

- The refresh contract was proven live (`400` on an empty body) but a real
  token pair has not been exchanged; that lands with Phase 1.
- Triage and other endpoints are mapped in `api-coverage.md`, not called
  here.

## How this was verified

```
flutter analyze   →  No issues found! (17.1s)
flutter test      →  +56 ~1: All tests passed!   (smoke skipped)
LIVE_SMOKE=1 smoke →  +1: All tests passed!       (live, 2s)
```

Run detached per `AGENT_SPEC` §2, serialized (never simultaneously). Two real
defects were caught and fixed this way:

1. `const Offline<T>()` is illegal in Dart (`const_with_type_parameters`),
   three times over.
2. `test(..., timeout:)` takes a `Timeout`, not a `Duration`.

## Not in this phase

No pages, no routes, no theme changes, no UI state. Phase 1 (auth slice:
check-phone → register → login → refresh → profile) builds on top of this.
