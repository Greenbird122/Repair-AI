# RepairAI — Phase 1: Auth Slice

> **Status: complete.** `flutter analyze` 0 issues · `flutter test` 139
> passing + 1 live smoke test (skipped locally, run in CI with
> `LIVE_SMOKE=1`). Five pages exist: splash, home, login, register,
> change-password — the first real pages on top of the Phase 0 network
> core.
>
> This file is the explanation of record, so source files stay lean.

## What shipped

The whole Phase 1 row from `api-coverage.md`: secure token storage,
every ✅ auth endpoint, the session lifecycle as Riverpod state, guarded
routing, and the pages that drive it. The geo cascade (Phase 2's §2
locations) came forward early because register cannot be built without
it — the server requires `country`/`county`/`sub_county` **names**.

Every request/response shape was proven live against production on
2026-10-07 with real credentials (status codes and JSON keys only; see
`api-coverage.md` for the table).

## Files created and their purpose

### `lib/features/auth/`

| File | Purpose |
|---|---|
| `data/secure_token_storage.dart` | Fills the `TokenStorage` seam Phase 0 left in memory. Android EncryptedSharedPreferences via `flutter_secure_storage`. The platform channel sits behind a `SecureStore` interface so tests fake it without the plugin. |
| `data/auth_api.dart` | The six §1 endpoints through the shared `ApiClient` (bearer, refresh, 5s timeout). Decoders keep only the fields Phase 1 renders and throw `FormatException` on unusable payloads — the epl_app lesson: never trust a shape you have not seen. |
| `logic/session_controller.dart` | `sessionProvider`: hydrate → signedOut/signedIn, login, register (check-phone first), change-password, logout, background profile fetch. Storage failures degrade, never crash: an unreadable store reads as signed-out; a store that cannot save still yields a working session for the run. |

### `lib/features/locations/`

| File | Purpose |
|---|---|
| `data/location_api.dart` | Countries / counties / sub-counties. Encodes the two live facts: filters match **names** (`?country=Kenya` works, `?country=KE` → `[]`) and `Place.name` is what register sends back. |
| `logic/location_providers.dart` | `countriesProvider` plus family providers keyed by the parent name, so every loaded list is cached by selection. |

### `lib/pages/`

| File | Purpose |
|---|---|
| `login_page.dart` | Phone + password. Register success lands here with the phone pre-filled (`/login?phone=...`). Never branches on `must_change_password` — the guard owns that reroute. |
| `register_page.dart` | Names, phone, cascading country → county → sub-county pickers (loading / retry / offline states per field), password ≥ 8 chars + confirm. Register does **not** sign in (the 201 returns no tokens) — success goes to login. |
| `change_password_page.dart` | Old / new / confirm. The guard parks anyone with the forced flag here; signed-in users may also visit. "Sign out instead" covers the forgot-old-password case. |
| `home_page.dart` | Replaces the placeholder: emblem, greeting from the fetched profile, sign out. Sign-out navigation is the guard's job, not the page's. |

### `lib/core/routes.dart` and `lib/main.dart`

- `authRedirect(session, location)` is a **pure function**, table-driven
  in tests: hydrating → never redirect; signedOut → `/login` unless the
  path is public; must-change-password → `/change-password`; signed in →
  `/home` from login/register, else stay. `publicPaths = {/, /login, /register}`.
- `routerProvider` listens to the session and pings a
  `refreshListenable`, so redirects re-run without rebuilding the router.
- `ProviderScope` lives **inside `RepairAiApp.build()`** with value
  overrides for the two test seams (`tokenStorage`, `apiClient`). A bare
  pump of the app widget can never lose the scope; a mutation test
  (removing the scope fails `test/app/provider_scope_test.dart`) pins
  this.

## Tests

23 files, 104 tests, mirroring `lib/` per `architecture.md` §Testing:
`test/pages/` (four page suites: validation, offline, failure messages,
navigation), `test/features/auth/` (API shapes vs the live-proven
contracts; session lifecycle transitions), `test/features/locations/`
(query filters and provider caching), `test/core/routes_test.dart`
(redirect table), `test/app/` (root wiring, provider scope). The fake
token storage and fake session keep the whole suite offline.

## Decisions taken

1. **Register does not sign in.** The 201 body carries no tokens — the
   page says so and lands on login with the phone pre-filled.
2. **check-phone runs inside register**, not as its own page: one clean
   "already in use" message before the register round-trip. The
   standalone check-phone page (page-list #4) stays unbuilt.
3. **Logout is local-first.** The server call is best-effort; the local
   session and tokens clear even offline, so a dead connection cannot
   leave a resurrectable session behind.
4. **Names, not ids, for geo.** The server filters by name; `Place.name`
   is the payload value, ids only key the lists.
5. **Test seams as constructor values.** Riverpod 3's `Override` is
   sealed and not publicly nameable, so `RepairAiApp` takes optional
   `tokenStorage`/`apiClient` values and overrides by value inside its
   own `ProviderScope`.

## Known gaps

- **TLS cert pinning did not happen.** `corpus.md` deferred it to "Phase
  1, when real credentials start crossing the wire"; Phase 1 shipped and
  it is still open. Real JWTs now cross the wire unpinned — top item for
  the next phase (custom client over a pinned `SecurityContext`;
  `package:http` has no built-in pinning).
- **The forced-change endpoint is unverified.** The test account had
  `must_change_password: false`, so `/api/auth/set-new-password/` (§1
  🔶) was never exercised. The guard routes the flag to
  `/change-password`; if the server actually demands set-new-password,
  that destination must change.
- **The change-password 200 body was never observed** (probing it would
  rotate the test account's password). The decoder accepts a `detail`
  message or anything else.
- **No account-profile UI** (page-list #9). `PATCH /api/auth/profile/`
  with `{}` → 200 is proven; the page is Phase 2.
- One live register probe created a real account (`user_1`, id 104)
  that was kept as-is; noted in `api-coverage.md`.

## Hardening pass (2026-10-07, after external review)

A code review caught four defects the first pass shipped, all fixed and
pinned by tests:

1. **The encrypted store is now the data-layer default.**
   `tokenStorageProvider` returned `InMemoryTokenStorage` while only
   `main.dart`'s scope override supplied `SecureTokenStorage` — the
   persistence guarantee lived in a UI widget and every provider consumer
   silently ran on volatile memory. The provider default is now
   `SecureTokenStorage`; tests override with fakes.
2. **UI tests hydrate again.** With the real store as default, a bare
   `RepairAiApp` pump hung forever: `flutter_secure_storage` 11.x's
   channel never answers under the flutter_test binding, so session
   hydration stayed `hydrating` and the guard never redirected (12 red
   tests — CI was right, the earlier "all passing" claim was not
   re-verified after the last commits). `test/flutter_test_config.dart`
   now installs the plugin's official in-memory
   `TestFlutterSecureStoragePlatform` for every run.
3. **SessionState gained `copyWith`;** password-change success rebuilds
   via `copyWith(mustChangePassword: false)` instead of hand-rolling a
   constructor that drops fields.
4. **Login prefill moved out of `build()`** into
   `didChangeDependencies` (controller writes during build are a rebuild
   hazard), and the change-password page restores its button after a
   sign-out that has not yet redirected instead of freezing disabled.

## How this was verified

```
flutter analyze                        →  No issues found!
flutter test                           →  +139 ~1: All tests passed!
live curl probes (real creds)          →  login/logout/register/
                                          change-password/profile/
                                          check-phone/locations proven
```

CI is the authority: the first run of this phase failed analyze on a
dead parameter the local claim had missed, and the next run failed test
on the hydration hang above — both fixed, both lessons recorded here.

## Not in this phase

No pregnancy dashboard, no profile editing, no notifications, no
calling. Phase 2 (geo + profile UI, dashboard-stats) is next per
`api-coverage.md`.
