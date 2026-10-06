# RepairAI — Architecture

Android-only Flutter app. Pure Android is the ship target; no web/iOS code
paths are maintained. Target scale: 36 pages, cut to a 14-page core loop
(`docs/page-list.md`).

## Layout (feature-first)

    lib/
      main.dart            # boots RepairAiApp, which mounts ProviderScope
      core/
        theme.dart         # RepairColors, RepairText, RepairTheme (single source)
        routes.dart        # GoRouter table — every page registers here
      pages/               # top-level pages (one file per page)
        splash_gate.dart   # '/' entry host: precaches emblem, owns handoff
        splash_page.dart   # the 5s animated dark splash itself
        home_page.dart     # '/home' placeholder landing
      widgets/             # shared, reusable UI (EcgPulse, future: buttons, cards)
      features/            # feature folders own their domain
        network/           # built (Phase 0): data/ + logic/
        <feature>/
          data/            # models, repositories, API clients
          logic/           # controllers / state (Riverpod)
          ui/              # feature screens + feature-private widgets

## Navigation model

- One `GoRoute` per page in `core/routes.dart`; pages never self-navigate
  with raw Navigator APIs.
- Tabbed sections become `ShellRoute` branches (bottom nav lives in the
  shell, pages don't re-declare it).
- Guards (onboarding-first-run, auth, permissions) are `redirect`
  callbacks in `routes.dart`.
- Current routes: `/` (splash → handoff), `/home`.

## Theming

- `RepairTheme.light` is the app-wide theme; the splash opts out to its
  own dark stage by design (dark splash → light app).
- Palette lives in `RepairColors`; type styles in `RepairText`. The
  palette is pinned by `test/core/theme_guard_test.dart`.

## State management

- **Riverpod** (`flutter_riverpod`), decided 2026-10-06. Controllers live
  in `features/<feature>/logic/`; pages stay dumb. `ProviderScope` is
  mounted inside `RepairAiApp`, so any bare pump of the app reaches the
  providers.
- One pattern app-wide — introducing a second is a rejected change.

## Data layer

- **Network layer built** (Phase 0) — `features/network/`: `ApiClient`
  (5s per-attempt timeout, bearer auth, one 401 refresh-retry), `Result`
  (`Data` / `Error` / `Offline`), single-flight JWT refresh,
  `TokenStorage`. File-by-file map in `docs/phase-0.md`.
- **Not yet built: persistence, sync, offline UX.** Still the single
  biggest open risk (`corpus.md` decision 1). `docs/page-list.md`
  derives the minimum: cache 4 reads, queue 1 write, no sync engine.
- Any backend dependency must be proven live before a page ships
  against it (`AGENT_SPEC.md` §1.8).

## Splash timeline (reference)

5s master controller on `/`: emblem 0.1s, ECG sweep 0.9–3.5s, heartbeat
bloom 2.2s, wordmark 3.4s, tagline 4.1s, auto-handoff to `/home` at 5.4s
(`context.pushReplacement`). Native splash (dark #0d0d0d) is generated
from the `flutter_native_splash` block in `pubspec.yaml`.

## Testing

- Convention: every commit ships a test (repo rule).
- **Mirroring rule:** every test lives at the path its subject occupies
  under `lib/`, with `_test` appended — so the test for any file is found
  by prefixing `test/`. Tests whose subject is the whole app go in
  `test/app/`; cross-cutting tests (the live smoke probe) go in a named
  bucket rather than a mirror.

        lib/core/routes.dart     ->  test/core/routes_test.dart
        lib/core/theme.dart      ->  test/core/theme_guard_test.dart
        lib/main.dart            ->  test/app/*
        lib/features/network/... ->  test/features/network/...

- **56 tests across 14 files**: `test/core/` (2), `test/app/` (2),
  `test/features/network/` (9 — the network core), `test/smoke/` (1,
  live production probe, CI-only).
- CI (`.github/workflows/ci.yml`) runs analyze + test on every push/PR
  with `LIVE_SMOKE=1`, so a backend outage fails the build rather than
  reaching users.
