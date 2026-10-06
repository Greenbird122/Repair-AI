# RepairAI — Phase 0: Network Core

> **Status: complete.** `flutter analyze` 0 issues · `flutter test` 52 passing
> (45 new, 7 pre-existing). No page, route or widget changed — this phase is
> plumbing only.
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
| `result.dart` | The `Result<T>` contract every call returns: `Loading`, `Data`, `Error`, `Offline`. Forces consumers to handle all four states instead of crashing on null. |
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

### `test/features/network/`

Nine test files, one per source file, per `AGENT_SPEC` §1.1. The load-bearing
cases: concurrent refresh dedupe, 401 → refresh → retry with the rotated
token, timeout → `Offline`, unreachable host → `Offline`, malformed payload →
`Error`, and every refresh failure branch.

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
4. **Token clearing rule** — clear both tokens when the server rejects the
   refresh (4xx) or returns a success payload we cannot use (not an object,
   no access token, not JSON). Keep them on network failure, so a dropped
   connection never logs a user out; the next attempt surfaces 4xx if the
   token is genuinely dead.
5. **`Result.loading` is never returned by `ApiClient`.** Its purpose is
   page-local state a screen holds before its first fetch resolves. Noted
   here because "unused by the data layer" is intentional, not an oversight —
   flag it if you'd rather cut it.

## Known gaps

- **`Loading` has no producer yet** — see decision 5.
- The refresh contract was proven live (`400` on an empty body) but a real
  token pair has not been exchanged; that lands with Phase 1.
- Triage and other endpoints are mapped in `api-coverage.md`, not called
  here.

## How this was verified

```
flutter analyze   →  No issues found! (22.0s)
flutter test      →  All tests passed!  (52)
```

Both run detached per `AGENT_SPEC` §2, serialized (never simultaneously).
One real defect was caught and fixed this way: `const Offline<T>()` is
illegal in Dart (`const_with_type_parameters`), three times over.

## Not in this phase

No pages, no routes, no theme changes, no UI state. Phase 1 (auth slice:
check-phone → register → login → refresh → profile) builds on top of this.
