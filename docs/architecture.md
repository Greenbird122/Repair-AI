# RepairAI — Architecture

Android-only Flutter app. Pure Android is the ship target; no web/iOS code
paths are maintained. Target scale: 30–40 pages.

## Layout (feature-first)

    lib/
      main.dart            # MaterialApp.router bootstrap (nothing else)
      core/
        theme.dart         # RepairColors, RepairText, RepairTheme (single source)
        routes.dart        # GoRouter table — every page registers here
      pages/               # top-level pages (one file per page)
        splash_gate.dart   # '/' entry host: precaches emblem, owns handoff
        splash_page.dart   # the 5s animated dark splash itself
        home_page.dart     # '/home' placeholder landing
      widgets/             # shared, reusable UI (EcgPulse, future: buttons, cards)
      features/            # (as it grows) feature folders own their domain
        <feature>/
          data/            # models, repositories, API clients
          logic/           # controllers / state (Riverpod or Bloc — decide later)
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
  palette is pinned by `test/theme_guard_test.dart`.

## State management

- Not yet chosen. Decision is pending the data-layer design (see
  `docs/corpus.md` §open decisions). Constraint: one pattern for the
  whole app, controllers live in `features/<feature>/logic/`, pages stay
  dumb.

## Data layer

- Not yet built. On-device persistence, sync, and accounts are the
  single biggest open risk for the 30–40 page build-out. Any backend
  dependency must be verified live before pages ship against it (see
  `AGENT_SPEC.md` §1.8 and `corpus.md` §lessons).

## Splash timeline (reference)

5s master controller on `/`: emblem 0.1s, ECG sweep 0.9–3.5s, heartbeat
bloom 2.2s, wordmark 3.4s, tagline 4.1s, auto-handoff to `/home` at 5.4s
(`context.pushReplacement`). Native splash (dark #0d0d0d) is generated
from the `flutter_native_splash` block in `pubspec.yaml`.

## Testing

- Convention: every commit ships a test (repo rule).
- Current suites: `test/widget_test.dart` (splash smoke, dark-stage
  assertions, precache check), `test/routes_test.dart` (route table),
  `test/theme_guard_test.dart` (palette pin).
- CI: `.github/workflows/ci.yml` runs analyze + test on every push/PR.
