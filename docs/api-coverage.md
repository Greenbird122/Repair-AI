# RepairAI — API Endpoint Coverage Map

> **Purpose.** Catalogue the full `repairai.co.ke` backend surface (the
> source `API_Endpoint_Map.pdf`) and declare which endpoints *this Flutter
> app* will cover, which it will not, and why. No client code is written
> until this map is agreed. This is the planning artifact that precedes the
> network layer (see `AGENT_SPEC.md` §1.8, §4; `docs/corpus.md` §lessons).

## Source of truth & live-verification status

- **Backend:** Django + DRF, JWT auth (access + refresh rotation), RBAC.
- **Host:** `https://repairai.co.ke` (production). All routes under `/api/`.
- **Base URL config:** injected via `--dart-define=API_BASE_URL=...`,
  never hardcoded (epl_app lesson). Emulator → host is `10.0.2.2` only
  when pointing at a *local* server; production uses the real domain.
- **No public OpenAPI spec.** `/swagger.json`, `/redoc/`, `/api/schema/`
  all return the React SPA or 404 in prod → client is hand-written, each
  endpoint verified live before its page ships.
- **This backend == the EPL_APP backend.** `GET /api/app-version/` returns
  `release_url: github.com/Greenbird122/EPL_APP/...`. The `corpus.md`
  post-mortem (single-host SPOF, 8s timeout, no soft-fail) applies here
  directly.

### Contracts proven live on 2026-10-06 (curl, no real creds)

| Endpoint | Result | Note |
|---|---|---|
| `GET /api/app-version/` | **200** `{"status":"ok","latest_version":"1.0.0"}` | ~1.8s cold → tune timeouts, no 8s cliff |
| `POST /api/auth/login/` `{}` | **400** `{"password":["This field is required."]}` | needs phone + password |
| `POST /api/auth/check-phone/` `{}` | **400** `{"detail":"Phone number is required."}` | |
| `POST /api/auth/register/` `{}` | **400** requires `country, county, sub_county, password, password_confirm` | patient-shaped |
| `POST /api/auth/refresh/` `{"refresh":""}` | **400** `{"refresh":["This field may not be blank."]}` | |
| `GET /api/patients/my-profile/` | **401** `{"detail":"Authentication credentials were not provided."}` | JWT wall confirmed |

### Contracts proven live on 2026-10-07 (real credentials, authenticated)

Probed with curl while building Phase 1. Status codes and JSON keys
only — no token values. These are the shapes `AuthApi` and
`LocationApi` decode; a drift breaks their tests.

| Endpoint | Result | Contract facts |
|---|---|---|
| `POST /api/auth/login/` | **200** | `{access, refresh, id, user_id, username, …, must_change_password: false, role: "patient"}` — token pair + profile detail in one body |
| `POST /api/auth/change-password/` | **200** | fields are `old_password` / `new_password` / `new_password_confirm`; 200 body never observed (would rotate the test password) |
| `POST /api/auth/logout/` | **200** | `{"detail":"Logout successful. …"}` |
| `POST /api/auth/register/` | **201** | exactly 5 required fields: `country, county, sub_county, password, password_confirm` — **names, never ids**; body `{detail, user_id, username, role}`; returns no tokens (register does not sign in). Caveat: one probe created real account `user_1` (id 104), kept. |
| `POST /api/auth/check-phone/` | **200** / **400** | `200 {"detail":"…available."}` / `400 {"detail":"…already exists."}` |
| `GET/PATCH /api/auth/profile/` | **200** | GET returns the 36-key account record; PATCH accepts `{}` → 200 |
| `GET /api/patients/locations/counties/?country=Kenya` | **200** | filters match **names**: `?country=Kenya` works; `?country=KE` and `?county=13` return `[]` |

### Unauthenticated enumeration technique (how §3 was proven)

Probing works without credentials because Django resolves URLs *before*
DRF permission checks:

- `404` (Django HTML page) → no such route.
- `403` / `401` (DRF JSON) → route exists; the auth wall is hit after.
- `Allow:` reports each view's **true** methods even when auth fails.
  Calibrated: `visits/` → `POST`, `my-profile/` → `PATCH`,
  `login/` → `405` + `Allow: POST, OPTIONS`.
- Control: unknown `/api/triage/zzzznotareal/` returns
  `Allow: GET, HEAD, OPTIONS` (swallowed by the `{pk}` detail route), so
  any single segment answering `Allow: POST, OPTIONS` is a real
  registered action, not a detail-route catch.

Second source: the production SPA bundle `/assets/index-CFx3lrNR.js`
(3.6 MB) hardcodes **164** `api/...` route strings — the web client's
call surface. `github.com/Greenbird122/EPL_APP` is **private** (404), so
the bundle is the available source of truth. The asset hash changes on
every SPA redeploy.

## Product decisions — resolved 2026-10-06

All five questions that were blocking implementation are answered.

| # | Question | Decision |
|---|---|---|
| 1 | Patient-facing or CHP/clinician? | **Patient-facing.** The ✅/❌ columns stand as written. |
| 2 | Chat / communities in v1? | **No — deferred to post-v1.** Both chat rows → ❌. |
| 3 | Paid care card (§12)? | **Undecided — build nothing.** §12 stays 🔶 and is not implemented in v1. |
| 4 | Patient↔CHP calling (§13)? | **Yes — core.** The two call rows → ✅. The native WebRTC plugin is an **approved exception to `AGENT_SPEC.md` §1.5** (lean deps) and still needs a written reason in its commit message. |
| 5 | Full `/api/triage/` surface? | **Enumerated — 5 routes** (§3). Read-only for this app. |

Implementation may start against the ✅ set below.

## Coverage legend

- ✅ **COVER** — in scope for this Android patient app; will be implemented.
- 🔶 **MAYBE** — plausibly useful; deferred pending product decision.
- ❌ **SKIP** — out of scope (web-admin, CHP/clinician desk, external
  webhooks, or another client owns it).

> **App role: patient-facing Android companion — CONFIRMED 2026-10-06**
> (decision 1, see "Product decisions" above). The ✅/❌ columns are final
> under this role; a future CHP/clinician build would flip them.

---

## 1. Auth & RBAC — `/api/auth/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ✅ | POST | `/api/auth/check-phone/` | Pre-check phone before register/login |
| ✅ | POST | `/api/auth/register/` | Patient self-registration |
| ✅ | POST | `/api/auth/login/` | Login → JWT pair |
| ✅ | POST | `/api/auth/refresh/` | Silent token refresh (interceptor) |
| ✅ | POST | `/api/auth/logout/` | Invalidate session |
| ✅ | GET/PATCH | `/api/auth/profile/` | Account profile read/update |
| ✅ | POST | `/api/auth/change-password/` | User-initiated password change |
| 🔶 | POST | `/api/auth/set-new-password/` | Forced change on first login |
| ❌ | GET | `/api/auth/users/` | Admin user list (RBAC `users.view`) |
| ❌ | POST | `/api/auth/users/create/` | Admin create user |
| ❌ | POST | `/api/auth/users/bulk-create/` | Admin bulk create |
| ❌ | GET/PATCH/DELETE | `/api/auth/users/{id}/` | Admin user CRUD |
| ❌ | POST | `/api/auth/users/{id}/reset-password/` | Manager reset |
| ❌ | POST | `/api/auth/users/{id}/assign-roles/` | RBAC assign |
| ❌ | GET | `/api/auth/permissions/` | RBAC permission list |
| ❌ | GET/POST | `/api/auth/roles/` | RBAC role mgmt |
| ❌ | GET/PATCH/DELETE | `/api/auth/roles/{id}/` | RBAC role CRUD |
| ❌ | PUT | `/api/auth/roles/{id}/permissions/` | RBAC role perms |
| ❌ | GET | `/api/auth/admin/dashboard-stats/` | Admin dashboard |
| ❌ | POST | `/api/auth/patient-login/` | USSD patient login (not web/app) |

## 2. Patients, Visits, Communities, Chat, Locations — `/api/patients/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | GET/POST | `/api/patients/` | Patient list/create (CHP-side list; create maybe) |
| 🔶 | GET/PATCH | `/api/patients/{id}/` | Patient get/update, ANC profile |
| ✅ | GET | `/api/patients/{id}/visits/` | A patient's visits |
| ✅ | GET/POST | `/api/patients/visits/` | List / create visit (**triggers triage**) |
| ✅ | GET/PATCH | `/api/patients/visits/{id}/` | Visit get/update |
| ✅ | POST | `/api/patients/visits/{id}/add-message/` | Append message to a visit |
| 🔶 | GET/PATCH | `/api/patients/visits/{id}/case-file/` | Case file read/update |
| ✅ | GET/PATCH | `/api/patients/my-profile/` | **Patient's own profile** (core) |
| ❌ | POST | `/api/patients/ussd-register/` | USSD only |
| ✅ | POST | `/api/patients/request-patient-id/` | Request a patient ID |
| ✅ | POST | `/api/patients/lookup-identifier/` | Resolve a patient identifier |
| ❌ | GET | `/api/patients/admin-case-summary/` | Admin case summary |
| ✅ | GET | `/api/patients/dashboard-stats/` | **Patient dashboard stats** |
| ❌ | GET | `/api/patients/chp-dashboard-stats/` | CHP dashboard |
| 🔶 | POST | `/api/patients/generate-summary/` | AI case summary |
| 🔶 | GET | `/api/patients/summary-status/` | AI summary poll |
| ❌ | GET | `/api/patients/start-timer/` | Referral-timeline internal |
| ❌ | * | `/api/patients/communities/units/{id?}/` | Community unit CRUD (CHP/admin) |
| ❌ | * | `/api/patients/communities/villages/{id?}/` | Village CRUD (CHP/admin) |
| ❌ | POST | `/api/patients/communities/villages/{id}/assign-chp/`, `/remove-chp/`, `/deactivate/` | CHP admin |
| 🔶 | GET/POST | `/api/patients/communities/memberships/` | My community membership — chat-gated, do not build in v1 |
| ❌ | POST | `/api/patients/communities/memberships/{id}/approve/`, `/reject/` | CHP moderation |
| ❌ | GET/POST | `/api/patients/chat/{membershipId}/`, `/send/` | 1:1 chat — **deferred to post-v1** (decision 2) |
| ❌ | GET/POST | `/api/patients/community-chat/{villageId}/`, `/send/` | Group chat — **deferred to post-v1** (decision 2) |
| ✅ | GET | `/api/patients/locations/countries/`, `/counties/`, `/sub-counties/`, `/locations/`, `/villages/` (+`{id}/`) | **Cascading geo selects for register/profile** |
| ❌ | * | `/api/patients/admin-geography/units/` | Admin geography |

## 3. Triage & AI — `/api/triage/`

**Surface fully enumerated 2026-10-06 (decision 5).** Exactly 5 routes
exist; each was verified live with the `Allow` technique above.

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ✅ | GET | `/api/triage/` | List triage results (patient's own) — `Allow: GET, HEAD, OPTIONS` |
| ✅ | GET | `/api/triage/{id}/` | Triage detail — `Allow: GET, HEAD, OPTIONS` |
| ❌ | POST | `/api/triage/run/` | Executes triage — **not called directly**: `POST /api/patients/visits/` triggers triage (§2) |
| ❌ | POST | `/api/triage/deepseek-analyze/` | AI re-analysis — clinician-side |
| 🔶 | POST | `/api/triage/transcribe/` | Voice input into triage — ties to §11 accessibility, defer |

> Triage is **read-only for this app**: list + detail only. The PDF
> truncation no longer blocks anything. The endpoint *shape* is proven;
> the response *body schema* is not — inspect one authenticated
> `/api/triage/{id}/` payload before rendering any risk level (epl_app
> shipped "demo heuristic triage" — do not repeat).

## 4. Referrals & Admissions — `/api/referrals/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | GET/POST | `/api/referrals/` | List (patient's own referrals) / createManual |
| 🔶 | GET | `/api/referrals/{id}/` | Referral detail |
| ❌ | POST | `/api/referrals/generate/` | GIS smart referral (CHP/clinician) |
| ❌ | POST | `/api/referrals/recommend/` | Ranked facilities (CHP) |
| ❌ | PATCH | `/api/referrals/{id}/update-status/` | Clinician status change |
| ❌ | PATCH | `/api/referrals/{id}/` | Update |
| 🔶 | GET | `/api/referrals/{id}/timeline/` | Referral timeline (patient view) |
| ❌ | POST | `/api/referrals/{id}/assign-staff/` | Clinician |
| ❌ | POST | `/api/referrals/{id}/admit/` | Clinician |
| ❌ | POST | `/api/referrals/{id}/upload-report/` | Clinician |
| ❌ | GET | `/api/referrals/admissions/`, `/{id}/` | Admissions desk |
| ❌ | POST | `/api/referrals/admissions/{id}/attend/`, `/release/`, `/discharge/`, `/complete-discharge/` | Admissions workflow |
| ❌ | POST | `/api/referrals/admissions/receptionist-checkin/` | Reception desk |
| ❌ | GET | `/api/referrals/admissions/doctor-performance/`, `/facility-overview/` | Clinician dashboards |

## 5. Clinical & Trimesters — `/api/clinical/`

> Note the double segment `clinical/clinical/` (ViewSet at app root).

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ❌ | GET/POST | `/api/clinical/clinical/` | Clinical decisions list/create (clinician) |
| ❌ | GET/PATCH | `/api/clinical/clinical/{id}/` | Decision get/update |
| 🔶 | POST | `/api/clinical/clinical/guidance/` | Claude AI guidance (if patient-safe) |
| 🔶 | GET | `/api/clinical/clinical/protocols/` | Care protocols (read-only patient ed.) |
| ❌ | GET/POST | `/api/clinical/clinical/prescriptions/` | Prescriptions (clinician) |
| ❌ | * | `/api/clinical/trimesters/{id?}/` | Trimester definitions (admin) |
| ✅ | GET | `/api/clinical/patient-trimesters/{id?}/` | **My trimester tracking** (read; write maybe) |
| ✅ | GET | `/api/clinical/patient-trimesters/patient-summary/{patientId}/` | My trimester summary |

## 6. Appointments & ANC Requests — `/api/appointments/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ✅ | GET/POST | `/api/appointments/` | **My appointments** list/create |
| ✅ | GET/PATCH/DELETE | `/api/appointments/{id}/` | Appointment get/update/cancel |
| ✅ | GET/POST | `/api/appointments/anc-requests/` | **ANC visit requests** list/create |
| ✅ | GET/PATCH | `/api/appointments/anc-requests/{id}/` | ANC request get/update |
| 🔶 | POST | `/api/appointments/anc-requests/{id}/assign-facility/`, `/fill-anc-data/`, `/complete/` | Mostly clinician-side; `complete` maybe patient |

## 7. Facilities, Capacity, Duty, Resources — `/api/facilities/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | GET | `/api/facilities/` | Facility list (patient browse) |
| 🔶 | GET | `/api/facilities/{id}/` | Facility detail |
| ✅ | GET | `/api/facilities/nearby/` | **Nearby facilities** (patient locate care) |
| ❌ | POST | `/api/facilities/` + `{id}` PATCH/DELETE | Admin facility CRUD |
| ❌ | GET/POST | `/api/facilities/{id}/capacity/`, `/capacity/update/`, `/capacity/` | Capacity mgmt (facility staff) |
| ❌ | GET | `/api/facilities/{id}/marketing-stats/` | Facility marketing |
| ❌ | POST | `/api/facilities/import/` | Admin import |
| ❌ | GET/PATCH | `/api/facilities/{id}/profile/` | Hospital profile (staff) |
| ❌ | * | `/api/facilities/staff-duty/{id?}/` | Duty roster (staff) |
| ❌ | GET/POST | `/api/facilities/resource-requests/` + `/{id}/reply/` | Resource requests (staff) |

## 8. Follow-ups & Alerts — `/api/followup/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | GET | `/api/followup/schedules/` | My follow-up schedule (read) |
| ❌ | POST | `/api/followup/schedules/` + `{id}` PATCH | Create/edit schedule (CHP) |
| ❌ | POST | `/api/followup/schedules/trigger-send/` | CHP trigger |
| 🔶 | GET | `/api/followup/alerts/`, `/active/`, `/{id}/` | My alerts (read) |
| ❌ | POST | `/api/followup/alerts/` | Create alert (CHP) |
| ❌ | PATCH | `/api/followup/alerts/{id}/resolve/` | CHP resolve |

## 9. Analytics & MoH / DHIS2 — `/api/analytics/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ❌ | GET | `/api/analytics/metrics/`, `/{id}/` | Metrics (admin/MoH) |
| ❌ | GET | `/api/analytics/metrics/national-breakdown/` | National breakdown (MoH) |
| ❌ | POST | `/api/analytics/metrics/compute/` | Compute (admin) |

> §9 PDF text truncated after `metrics/compute/`. Entire section is
> admin/MoH analytics → **SKIP** for the patient app regardless.

## 10. Notifications — `/api/notifications/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ✅ | GET | `/api/notifications/badge/` | **Unread badge count** |
| ✅ | POST | `/api/notifications/mark-read/` | Mark read |
| 🔶 | POST | `/api/notifications/send/` | Send (likely staff; patient maybe not) |
| ✅ | GET | `/api/notifications/` | **List notifications** — verified live 2026-10-06 (`403`, `Allow: GET, HEAD, OPTIONS`) |

## 11. Transcription (Google STT/TTS) — `/api/transcription/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | POST | `/api/transcription/speech-to-text/` | Voice input (accessibility/low-literacy) |
| 🔶 | POST | `/api/transcription/text-to-speech/` | Read-aloud (accessibility) |
| 🔶 | POST | `/api/transcription/translate/` | Localisation of content |

> Strong accessibility fit for a maternal-health app with low-literacy
> users; deferred only because it's not core-loop. Revisit early.
> `speech-to-text/` and `translate/` verified live 2026-10-06 (both
> `401` + `Allow: POST, OPTIONS`).

## 12. Payments — `/api/payments/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | GET | `/api/payments/card/` | My care card |
| 🔶 | POST | `/api/payments/card/topup/` | Top up (Paystack) |
| 🔶 | GET | `/api/payments/card/transactions/` | My transactions |
| ❌ | GET | `/api/payments/card/list-all/` | Admin list all cards |
| ❌ | POST | `/api/payments/card/approve/` | Admin approve |

> Payments depend on a product decision (is there a paid care card for
> patients?). Entire section gated on that; `list-all`/`approve` are admin.

## 13. CHP Browser Calls (WebRTC) — `/api/calls/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ❌ | GET | `/api/calls/chps/` | CHP directory (web desk) |
| ❌ | POST | `/api/calls/desk/` | CHP presence heartbeat |
| ✅ | POST | `/api/calls/` | Start a call (patient→CHP) — needs native WebRTC |
| ✅ | GET/POST | `/api/calls/{uuid}/` | WebRTC signaling |

> Browser-WebRTC built for the web desk. A Flutter equivalent needs a
> native WebRTC plugin (heavy dep — conflicts with §1.5 "lean deps").
> **Decision 4 (2026-10-06): calling IS core for v1**, so the plugin is
> an approved exception to the lean-deps rule. `chps/` and `desk/` stay ❌
> (web-desk only). Spike the plugin before writing UI — the signalling
> contract at `/api/calls/{uuid}/` has not been exercised live yet.

## 14. AI Provider Control — `/api/ai/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ❌ | GET/PATCH | `/api/ai/settings/` | Admin: switch provider (`ai.manage`) |
| ❌ | POST | `/api/ai/preview/` | Admin: preview model |

## 15. Public Website Content — `/api/public/`

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| 🔶 | GET | `/api/public/entries/` | Published news/resources (patient reading) |
| 🔶 | POST | `/api/public/contact/` | Contact form |
| ❌ | * | `/api/public/manage/entries/` | Admin CMS (`content.manage`) |
| ❌ | * | `/api/public/manage/messages/` | Admin inbox |

## 16. Voice IVR — `/api/voice/` — ❌ ENTIRE SECTION SKIP

External Africa's Talking webhooks (`/incoming/`, `/recording/`,
`/callback/`, `/events/`, `/beep/`, `/audio/{filename}/`,
`/session/{session_id}/`). Called by the telco, never by any app client.

## Non-app / Infrastructure

| Status | Method | Endpoint | Purpose |
|---|---|---|---|
| ✅ | GET | `/api/app-version/` | **Mobile update check + health probe** (CI smoke test) |
| ❌ | GET | `/swagger/`, `/redoc/`, `/swagger.json` | API docs (not in prod anyway) |
| ❌ | — | `/admin/` | Django admin |
| ❌ | — | `/ai/` (`/ask`, `/health`, `/stats`) | Separate FastAPI RAG service, NGINX-proxied |

---

## Coverage summary (patient-app assumption)

| Section | ✅ Cover | 🔶 Maybe | ❌ Skip |
|---|---|---|---|
| 1 Auth/RBAC | 7 | 1 | 12 |
| 2 Patients/Visits/Geo | 9 | 6 | 11 |
| 3 Triage | 2 | 1 | 2 |
| 4 Referrals | 0 | 3 | 11 |
| 5 Clinical/Trimesters | 2 | 2 | 4 |
| 6 Appointments/ANC | 4 | 1 | 0 |
| 7 Facilities | 1 | 2 | 7 |
| 8 Follow-up | 0 | 2 | 4 |
| 9 Analytics | 0 | 0 | 3 |
| 10 Notifications | 3 | 1 | 0 |
| 11 Transcription | 0 | 3 | 0 |
| 12 Payments | 0 | 3 | 2 |
| 13 Calls (WebRTC) | 2 | 0 | 2 |
| 14 AI control | 0 | 0 | 2 |
| 15 Public content | 0 | 2 | 2 |
| 16 Voice IVR | 0 | 0 | 7 |
| Infra | 1 | 0 | 3 || **Total** | **31** | **27** | **72** |

Of the full surface, **31 rows are core-cover** and 27 are candidates —
the patient app consumes well under a third of the backend. The rest is
web-admin, CHP/clinician desk, MoH analytics, or external webhooks.
(Counts are table rows; one row may cover several paths. Recomputed
against the section tables on 2026-10-06 — the old `§2 ✅ 7` was a
miscount of 9, which also made the previous total wrong.)

## Phased implementation order (proposed — no code yet)

1. **Phase 0 — Network core + health.** Client, JWT store, refresh
   interceptor, `Result` type (data/error/offline), bounded
   timeouts, `/api/app-version/` health check + CI smoke test.
   **Done 2026-10-06.**
2. **Phase 1 — Auth slice (§1).** check-phone → register → login →
   refresh → profile. Fully tested end-to-end. **Done 2026-10-07**
   (`docs/phase-1.md`), with the §2 geo cascade pulled forward from
   Phase 2 because register cannot exist without it.
3. **Phase 2 — Geo + profile (§2 locations, my-profile).** Cascading
   location selects feed register/profile.
4. **Phase 3 — Core patient loop (§2 visits + §3 triage + §6
   appointments/ANC).** Triage surface already enumerated — only the
   authenticated payload schema is outstanding.
5. **Phase 4 — Notifications (§10) + dashboard-stats.**
6. **Phase 5 — Calling (§13).** Spike the native WebRTC plugin first
   (approved §1.5 exception), then `/api/calls/` + `/api/calls/{uuid}/`.
7. **Later / gated spikes:** trimester tracking (§5), nearby facilities
   (§7), transcription accessibility (§11), payments (§12, gated on
   decision 3), chat (§2, deferred to post-v1 by decision 2).

## Open questions — RESOLVED

All five were answered on 2026-10-06; the record lives under
**Product decisions** above. Nothing blocks `lib/` changes any more —
implement against the ✅ rows in the phase order.

Non-blocking follow-ups:

1. Inspect one authenticated `/api/triage/{id}/` payload before
   rendering any risk level (shape proven, schema not seen).
2. Spike the native WebRTC plugin before writing calling UI (§13).
3. Reopen decision 3 (payments) before Phase 6 planning.
4. **TLS cert pinning** — slipped past Phase 1; real credentials now
   cross the wire unpinned. See `corpus.md` open decision 6.
5. Verify the forced-change endpoint (`/api/auth/set-new-password/`)
   — the test account had `must_change_password: false`, so the flag's
   true server-side flow has never been exercised.
