# RepairAI — Corpus of What Has Been Built

> The living inventory. Any agent finishing work MUST add to this file
> (see `AGENT_SPEC.md` §4.6). If it isn't here, it doesn't exist.

## Status snapshot (2026-10-06)

- Pages built: **1 of 30–40** (splash) + placeholder home
- Phase 0 network core: **complete** — 9 source + 9 test files,
  per-file map in `docs/phase-0.md`
- Tests: **52 passing** (45 network, 7 splash/router/theme)
- CI: green on every push so far
- APK: debug builds verified on emulator (avd `repair_phone`)

## Built so far, in order

1. **Project scaffold** (Android-only, org `com.repairai.repairai`)
   - Flutter 3.47.5 / Dart 3.13.4, Material 3, portrait-locked
   - `flutter_native_splash` + `flutter_launcher_icons` configured
2. **Brand assets** — emblem extracted from the web design (transparent
   PNG), adaptive icon foreground, legacy icon
3. **Splash page** (`lib/pages/splash_page.dart`, route `/`)
   - 5s master AnimationController; phases: emblem 0.1s, ECG sweep
     0.9–3.5s, heartbeat ring bloom 2.2s, wordmark 3.4s, tagline 4.1s
   - `EcgPulse` custom painter (`lib/widgets/ecg_pulse.dart`): SVG-path
     trace, traveling amber dash with gradient fade + glow
   - Responsive sizing mirrors the CSS clamps of the original design
4. **Dark splash retheme** (commit `6e2c610`) — black stage matching the
   official logo; white "Repair" + amber "AI"; dark native splash too.
   Product decision: **dark splash → light app**.
5. **Perf pass** (commit `79615bf`) — emblem `precacheImage` in
   `SplashGate.didChangeDependencies`, `FilterQuality.medium` downscale,
   `RepaintBoundary` around the emblem
6. **Routing** (commit `bdc4729`) — `go_router`, route table in
   `lib/core/routes.dart`; splash hands off via `pushReplacement('/home')`;
   `SplashGate` split into its own file to avoid a main↔routes cycle
7. **CI** (commit `170dff4`) — GitHub Actions: analyze + test per push/PR
8. **Docs sweep** (this commit) — dead code removed, docs/ established
9. **API coverage map** (2026-10-06) — `docs/api-coverage.md` catalogues
   the whole `repairai.co.ke` surface, the five product decisions that
   were blocking implementation, and the triage surface enumerated live
10. **Phase 0 network core** (2026-10-06) — `lib/features/network/`:
    `Result` contract, typed API failures, `TokenStorage`, single-flight
    JWT refresh, `ApiClient` (5s timeout, 401 retry), app-version health
    probe, Riverpod wiring. Deps added: `http`, `flutter_riverpod`.
    Per-file purposes and decisions in `docs/phase-0.md`.

## Lessons learned (from the failed epl_app predecessor)

The previous RepairAI-branded CHP app (`Desktop/epl_app`) shipped Jul 2026
and "died after a few weeks" in the field. Post-mortem findings from its
codebase:

- Its own `IMPLEMENTATION_COMPLETE.md` documented the gaps: **no real
  backend** (hardcoded URLs, demo-only auth), **demo heuristic triage**,
  disabled cert pinning, disabled AI fallback (`isConfigured => false`).
- Single point of failure: every feature called `https://repairai.co.ke`
  with an **8s timeout**. TLS cert boundary (90-day Let's Encrypt) aligns
  with the death window — one infra hiccup = 100% feature loss, and
  nothing failed soft.
- Sentry was installed but evidently unwatched; failures were discovered
  by users, not dashboards.

**Standing rules derived (enforced by `AGENT_SPEC.md`):** verify backend
endpoints before shipping pages against them; tune timeouts for rural
networks with visible offline states; real accounts before real users;
error reporting must be reviewed, not just installed.

## Open decisions (blockers for the next phase)

1. **Data layer** — where does health data live (local DB / cloud /
   hybrid), sync strategy, offline UX. Biggest risk; gates pages 5–15.
2. **State management** — **decided: Riverpod** (2026-10-06). Providers
   live in `features/<feature>/logic/`; pages stay dumb.
3. **Accounts/auth** — whether and how (shapes onboarding).
4. **The "AI" in RepairAI** — on-device vs cloud, provider, offline
   behavior, cost per user.
5. **The 30–40 page list** — **written: `docs/page-list.md`**
   (2026-10-06). 36-page inventory cut to a 14-page core loop, phased
   against `api-coverage.md`, plus the offline requirements it derives
   for decision 1. New pages must state which loop sentence they serve.
6. **TLS cert pinning** — deliberately deferred to **Phase 1**, when real
   credentials start crossing the wire. `package:http` has no built-in
   pinning, so it needs a custom client over a pinned `SecurityContext`.
   Logged as a choice, not an oversight: `epl_app` shipped with pinning
   disabled and its 90-day cert boundary lined up with its death window.
