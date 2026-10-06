# Agent Spec — Rules of Engagement for RepairAI

> **Any agent (or human) working in this repo MUST follow this contract.**
> This file exists because context gets lost. The repo, not memory, is the
> source of truth. Read this, then `docs/architecture.md`, then
> `docs/corpus.md` before writing a line of code.

## 0. The one-line mission

RepairAI is an **Android-only** maternal-health companion app
("Heal · Support · Hope") targeting **36 pages, 14 of them the core
loop** (`docs/page-list.md`). No web, no iOS —
that is a hard product decision, not a TODO.

## 1. Non-negotiables (violating these = a rejected change)

1. **Every commit ships with a test.** Small, targeted commits. Commit
   messages: short, imperative, no AI co-author footers of any kind.
2. **Android-only.** Never add ios/web/macos/linux/windows targets, never
   add platform plugins that don't build for Android.
3. **All colors/styles via `lib/core/theme.dart`** (`RepairColors`,
   `RepairText`, `RepairTheme`). Hardcoding hex in pages is a bug.
   The splash's dark stage is intentional: dark splash → light app.
4. **All navigation via the GoRouter table in `lib/core/routes.dart`.**
   No raw `Navigator.push(MaterialPageRoute(...))` in pages. Paths
   kebab-case, names camelCase, navigate by name where possible.
5. **Deps stay lean.** Runtime deps: `go_router`, `http`,
   `flutter_riverpod`, `flutter_secure_storage`. Every new dep needs a
   written reason — in the commit message, or in the doc it ships with
   when messages are capped short. No heavy UI kits.
   **Approved exception (2026-10-06):** a native WebRTC plugin for
   patient↔CHP calling (Phase 5; `api-coverage.md` decision 4).
6. **Lint-clean.** `flutter analyze` must report 0 issues. Deprecated API
   (e.g. `withOpacity`) is not shipped; use the modern equivalent
   (`withValues(alpha:)`).
7. **Pages are dumb.** A page renders UI and emits callbacks. Business
   logic goes to controllers in `lib/features/<feature>/logic/`.
   Guard/redirect logic goes in `routes.dart`, never in pages.
8. **No unverified external dependency ships.** If a page needs a backend
   endpoint, that endpoint must be proven live with a real request (or a
   CI smoke test) before the page lands. Lesson inherited from the
   failed epl_app predecessor (see `docs/corpus.md` §lessons).

## 2. Machine-specific execution rules (this dev box is unusual)

These are measured facts, not preferences. Ignoring them wedges the box.

- **Env vars are required per command.** System `ANDROID_HOME` is wrong.
  Use: `ANDROID_HOME="C:\Users\HomePC\AppData\Local\Android\Sdk"`
  `JAVA_HOME="C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot"`
- **Never run `flutter run`.** It never exits and eats the command timeout.
- **Long commands must be detached + polled.** The runner kills commands
  at timeout, which orphans dart processes and can wedge the machine.
  Pattern that works:
  `nohup env JAVA_HOME=... flutter test > test_log.txt 2>&1 & disown`
  then poll `tail test_log.txt`. `process_type: BACKGROUND` is NOT
  available in this environment. `cmd //c start //b` is unreliable here.
- **Never run analyze + test + build simultaneously** — the box chokes.
  Serialize them. Typical warm durations: analyze 20–65s, tests 2–4min,
  debug APK ~4.5min.
- **After Gradle builds, clear daemons:** `taskkill //IM java.exe //F`.
  Same for orphaned `dart.exe`/`dartvm.exe` if a command was killed.
- **Emulator:** AVD `repair_phone` (Pixel 6, android-34 x86_64), adb id
  `emulator-5554`. Install/run:
  `adb install -r build/app/outputs/flutter-apk/app-debug.apk` then
  `adb shell am start -n com.repairai.repairai/.MainActivity`.
- **Network is flaky.** Git pushes occasionally stall or die silently.
  Detached push + poll `git status -sb` (look for `ahead N`). One retry
  usually lands it. Big SDK downloads: use `curl -C -` resume loops
  (non-resumable sdkmanager downloads lost 29min once).
- **Log files (`*_log.txt`) are gitignored.** Keep them that way.

## 3. Verification ladder (cheapest first)

1. `flutter analyze` — must be 0 issues, always.
2. `flutter test` — full suite must pass; add your test before running.
3. For UI-visible changes: build + install + launch on the emulator and
   `pidof` the app after the splash (5.4s) to confirm no crash.
4. Let GitHub CI (`.github/workflows/ci.yml`) be the final gate; do not
   treat local skips as permission to push red.

## 4. Workflow per task

1. Read `docs/corpus.md` → find where the new work fits.
2. Implement per `docs/architecture.md` (feature-first layout).
3. Add the smoke test (and deeper tests only for risky logic).
4. Verify per ladder above — batch several pages before one test cycle
   when the work is UI-only.
5. Commit small + push (detached pattern). Check CI goes green.
6. **Update `docs/corpus.md`** with what you built. A page that isn't in
   the corpus does not exist.

## 5. Known trap doors (learned the hard way)

- `Text.rich` wraps your span in a fresh root: `root → "Repair" → "AI"`.
  Test against that shape, not the span you wrote.
- `ImageCacheStatus.none` doesn't exist; use
  `cache.pendingImageCount + cache.liveImageCount`.
- `precacheImage` in `initState` throws (inherited-widget access); use
  `didChangeDependencies` with a done-guard.
- AnimatedBuilder `child` requires `(_, _)` named params (Dart 3.13
  wildcard lint), not `(_, __)`.
- `flutter_native_splash` config lives at the bottom of `pubspec.yaml`;
  regenerate with `dart run flutter_native_splash:create` after changes.
- The smoke test asserts tagline text even mid-fade (Opacity keeps the
  widget in the tree) — don't "fix" that.
- XML files: prefer `write_file` over multi-match string replacement.
