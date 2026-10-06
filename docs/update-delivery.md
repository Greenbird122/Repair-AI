# RepairAI — Update Delivery (OTA) — Parked Decision

> **Status: PARKED / not started.** Captured so it isn't lost (per
> `AGENT_SPEC.md` §4.6 "if it isn't here, it doesn't exist"). No code until
> the direction below is chosen and its backend dependency is verified live
> (§1.8).

## The ask (in the user's words)

> "An update triggered by every change I push so that people don't have to
> redownload it every time."

i.e. **over-the-air (OTA) updates** — push a change, users get it without a
full manual reinstall.

## The honest constraint

A native Android/Flutter app **cannot** freely hot-push arbitrary compiled
Dart/native code to installed apps. Android + Google Play policy only allow
executable code changes to ship as a real app update (new APK/AAB). So a
blanket "no one ever redownloads" is **not achievable for native code**
within platform rules. What *is* achievable is below.

## Options (what each actually delivers)

| Option | What updates OTA | What it costs | Verdict |
|---|---|---|---|
| **Play in-app updates** (`in_app_update` / Play Core) | New release installs in-place (flexible/immediate) — user barely acts | Play distribution; one dependency (weigh vs §1.5) | **Recommended** — closest legitimate "auto-update" for native code |
| **Server-driven UI / remote content** | Text, config, feature flags, news/resources, changelogs, layout *data* — instant, zero reinstall | Backend endpoints (e.g. `/api/public/entries/`, notifications) must be verified (§1.8) | **Recommended** — handles the stuff that changes often |
| **Code-push (Shorebird / CodePush-style)** | Actual Dart code patched OTA | Heavy external dependency + always-on remote reliance; cost/ops; Play-policy care | **Avoid for v1** — conflicts with §1.5 lean-deps and §1.8; repeats the single-host SPOF that killed epl_app (`corpus.md` §lessons) |

## Clarification on "trigger on every push"

The app can't push itself a new APK per code change. The real mechanism:
the **backend publishes `latest_version`**, the app **compares** its
built-in version on launch/open and surfaces a prompt if behind. The
"trigger" is the version mismatch, not the git push. CI/release bumps
`latest_version`; the app reacts.

## Recommended direction

1. **Play in-app updates** for real releases — version bumps auto-prompt and
   install in-place with minimal user effort. Backed by the already-verified
   `GET /api/app-version/` as the "is there a newer version?" signal.
2. **Server-driven content/config** so frequently-changing material (copy,
   resources, flags, what's-new) updates instantly with no reinstall.

Together ≈ most of the felt benefit ("people don't constantly redownload")
while staying inside platform rules, honoring lean-deps, and not repeating
the single-point-of-failure mistake.

## Buildable-now slice (safe today)

An **update-check page** against `GET /api/app-version/` — the only endpoint
proven live (200, `{"status":"ok","latest_version":"1.0.0"}`, ~1.8s;
`api-coverage.md`). States: "up to date" / "update available". Later wire
Play in-app updates to kick off the in-place install. This is §1.8-clean
because the endpoint is already verified.

## Blockers / dependencies before anything ships

- Touches the open **data-layer** decision (`corpus.md` §open decisions).
- Anything beyond `/api/app-version/` needs **live endpoint verification**
  (§1.8).
- Play in-app updates requires Play distribution + a new dependency — needs
  a written reason in the commit (§1.5).

## Open questions

1. Play in-app updates vs. Shorebird code-push vs. server-driven content —
   which direction? (Recommended: Play in-app updates + server-driven
   content.)
2. Is the app distributed via Play Store (required for in-app updates)?
3. Scope of server-driven content for v1 (which `/api/public/*` + which
   endpoints get verified first).
