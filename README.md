# RepairAI

**Heal · Support · Hope** — an Android maternal-health companion.

RepairAI supports women through pregnancy and postpartum: see where you
are, know when your next visit is, and hear back from your community
health promoter (CHP).

> **Android only.** That is a deliberate product decision, not a TODO
> (`docs/AGENT_SPEC.md` §1.2). There is no iOS, web, or desktop target,
> and none should be added.

## Where the project stands

| | |
|---|---|
| Pages built | **5 of 36** — splash, home, login, register, change-password |
| Network core | **Complete** (Phase 0): JWT auth, silent refresh, timeouts, health check |
| Auth slice | **Complete** (Phase 1): secure token store, session, guarded routes, sign-up/sign-in/change-password |
| Tests | **104 passing**, plus 1 live smoke test |
| CI | analyze + test + live backend probe on every push |
| Release signing | **Debug keys only** — `android/app/build.gradle.kts` |

Most of the app is still a plan, not a build. The plan is in
[`docs/page-list.md`](docs/page-list.md) and the phase order is in
[`docs/api-coverage.md`](docs/api-coverage.md).

## The core loop

Everything built from here has to serve one of these four sentences:

1. *"I made an account and it knows who I am."*
2. *"I can see how far along I am and whether anything is wrong."*
3. *"I know when and where my next visit is."*
4. *"Someone gets back to me."*

If a new screen does not serve one of them, it is scope creep.

## Requirements

- Flutter **3.47.5** / Dart **3.13.4**
- Android SDK
- JDK 21 (Gradle)

## Getting started

```bash
git clone https://github.com/Greenbird122/Repair-AI.git
cd Repair-AI
flutter pub get
flutter run
```

The app points at production by default. To use a different backend:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000    # local, emulator
flutter run --dart-define=API_BASE_URL=https://repairai.co.ke   # production
```

`API_BASE_URL` is the only configuration value. It is read in exactly one
place — `lib/features/network/data/api_client.dart` — and never hardcoded
anywhere else.

## Project layout

```
lib/
  main.dart                 entry point; ProviderScope lives inside the app widget
  core/
    routes.dart             every page registers here (GoRouter + auth guard)
    theme.dart              all colors and text styles
  features/
    auth/
      data/                 AuthApi (live-proven shapes), secure token storage
      logic/                SessionController — the auth lifecycle
    locations/
      data/                 country/county/sub-county lookups (name filters)
      logic/                Riverpod providers for the geo cascade
    network/
      data/                 ApiClient, JWT refresh, Result, models
      logic/                Riverpod providers
  pages/                    screens
  widgets/                  shared widgets (EcgPulse)

test/
  app/                      whole-app tests (root wiring, provider scope)
  core/                     mirrors lib/core/
  features/                 mirrors lib/features/ (auth, locations, network)
  pages/                    mirrors lib/pages/
  smoke/                    live probe of production (CI only)
```

Business logic belongs in `features/<feature>/logic/`. Pages render UI
and emit callbacks; navigation guards live in `routes.dart`.

Tests mirror `lib/` — the test for any file lives at `test/` + its path,
with `_test` appended. Whole-app tests go in `test/app/`.

## Testing

```bash
flutter analyze     # must report 0 issues
flutter test        # 104 tests, runs offline
```

CI runs both, plus a live probe of `GET /api/app-version/`, so a backend
outage fails the build instead of reaching users. That probe is skipped
locally unless you opt in:

```bash
LIVE_SMOKE=1 flutter test test/smoke/live_api_smoke_test.dart
```

> On this dev machine long commands can wedge the shell — run them
> detached and poll the log. See `docs/AGENT_SPEC.md` §2.

## Building for Android

```bash
flutter build apk --debug
flutter build appbundle --release
```

Release builds are currently **signed with debug keys**. A real signing
config is required before any Play Store submission.

## Documentation

| File | What it answers |
|---|---|
| [`docs/AGENT_SPEC.md`](docs/AGENT_SPEC.md) | Rules every contributor follows |
| [`docs/architecture.md`](docs/architecture.md) | How the code is laid out |
| [`docs/api-coverage.md`](docs/api-coverage.md) | Which endpoints we use, and the phase order |
| [`docs/page-list.md`](docs/page-list.md) | The 36-page plan and the core loop |
| [`docs/phase-0.md`](docs/phase-0.md) | What the network layer does, file by file |
| [`docs/phase-1.md`](docs/phase-1.md) | What the auth slice does, file by file |
| [`docs/corpus.md`](docs/corpus.md) | What has actually been built |

Read `AGENT_SPEC.md` first. If it is not in `corpus.md`, it does not exist.

## Contributing

- Small commits; **one file per commit**
- **Every commit ships a test**
- Messages are short and imperative, with **no bot or co-author footers**
- `flutter analyze` must report 0 issues before you push
- Android only — never add another platform target

## Contact

https://repairai.co.ke
