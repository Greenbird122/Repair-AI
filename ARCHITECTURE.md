# RepairAI — Architecture

Android-only Flutter app. Pure Android is the ship target; no web/iOS code
paths are maintained.

## Layout (feature-first)

    lib/
      main.dart            # MaterialApp.router + SplashGate entry ('/')
      core/
        theme.dart         # RepairColors, RepairText, RepairTheme (single source)
        routes.dart        # GoRouter table — every page registers here
      pages/               # top-level pages (one file per page)
        splash_page.dart
        home_page.dart
      widgets/             # shared, reusable UI (EcgPulse, future: buttons, cards)
      features/            # (as it grows) feature folders own their domain
        <feature>/
          data/            # models, repositories, API clients
          logic/           # controllers / state (Riverpod or Bloc — decide later)
          ui/              # feature screens + feature-private widgets

## Rules that keep 30-40 pages sane

1. **Every page is one `GoRoute`** in `core/routes.dart`. No
   `Navigator.push` with `MaterialPageRoute` sprinkled around — navigate
   with `context.push('/path')`, `context.go('/path')`, `pushReplacement`.
2. **Paths are kebab-case** (`/care/checklist/:id`); **route names are
   camelCase** and used in code (`context.goNamed('home')`).
3. **Tabbed sections** become `ShellRoute` branches (bottom nav lives in
   the shell, pages don't re-declare it).
4. **Guards** (onboarding-first-run, auth, permissions) are `redirect`
   callbacks in `routes.dart` — pages never gate themselves.
5. **Theme**: pages use `RepairTheme.light` and read colors from
   `RepairColors` — never hardcode hex in pages. Splash owns its dark
   stage deliberately (dark splash → light app).
6. **Tests ship with every commit** (repo convention). Page smoke tests:
   pump the page, assert the key widget exists.
7. **Deps stay lean** — current: go_router only. Every new dep needs a
   reason; heavy UI libs are avoided to keep the APK light.

## Splash timeline (reference)

5s master controller on `/`: emblem 0.1s, ECG sweep 0.9-3.5s, heartbeat
bloom 2.2s, wordmark 3.4s, tagline 4.1s, auto-handoff to `/home` at 5.4s.
