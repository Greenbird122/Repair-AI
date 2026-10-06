# RepairAI — The Page List

> **Status: written 2026-10-06.** Answers open decision 5 in `corpus.md`.
> This is the target, not a progress report — pages 1–2 are the only ones
> that exist (`corpus.md`: 1 of 30–40 built).

## The core loop

> **Register → see where your pregnancy stands → get to your next visit →
> hear back from your CHP.**

Four statements, in the user's words:

1. *"I made an account and it knows who I am."*
2. *"I can see how far along I am and whether anything is wrong."*
3. *"I know when and where my next visit is."*
4. *"Someone gets back to me."*

Anything that does not serve one of those four is staged, not core.

## The cut — core loop (14 pages)

| # | Page | Route | Endpoint |
|---|---|---|---|
| 1 | Splash | `/` | — (built) |
| 2 | Home | `/home` | — (built, placeholder) |
| 3 | Welcome | `/welcome` | — |
| 4 | Check phone | `/check-phone` | `POST /api/auth/check-phone/` |
| 5 | Register | `/register` | `POST /api/auth/register/` |
| 6 | Login | `/login` | `POST /api/auth/login/` |
| 7 | Set new password | `/set-password` | `POST /api/auth/set-new-password/` |
| 8 | My health profile | `/profile/health` | `GET/PATCH /api/patients/my-profile/` |
| 9 | Dashboard | `/dashboard` | `GET /api/patients/dashboard-stats/` |
| 10 | Visits | `/visits` | `GET /api/patients/visits/` |
| 11 | Visit detail | `/visits/:id` | `GET /api/patients/visits/:id/` |
| 12 | Appointments | `/appointments` | `GET /api/appointments/` |
| 13 | Triage result | `/triage/:id` | `GET /api/triage/:id/` |
| 14 | Notifications | `/notifications` | `GET /api/notifications/` |

That is the whole v1. Ninety seconds of reading and you can see why each
one is there; drop any row and one of the four sentences breaks.

## Full inventory — 36 pages

Grouped by area, phased per `api-coverage.md`. **C** = core loop.

### A. Entry & auth — Phase 1
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 1 | Splash | `/` | C | — |
| 2 | Home | `/home` | C | — |
| 3 | Welcome | `/welcome` | C | — |
| 4 | Check phone | `/check-phone` | C | `POST /api/auth/check-phone/` |
| 5 | Register | `/register` | C | `POST /api/auth/register/` |
| 6 | Login | `/login` | C | `POST /api/auth/login/` |
| 7 | Set new password | `/set-password` | C | `POST /api/auth/set-new-password/` |
| 8 | Change password | `/change-password` | — | `POST /api/auth/change-password/` |
| 9 | Account profile | `/account` | — | `GET/PATCH /api/auth/profile/` |
| 10 | Log out confirm | `/logout` | — | `POST /api/auth/logout/` |

### B. Status & identity — Phase 2
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 11 | My health profile | `/profile/health` | C | `GET/PATCH /api/patients/my-profile/` |
| 12 | Dashboard | `/dashboard` | C | `GET /api/patients/dashboard-stats/` |
| 13 | Patient ID | `/patient-id` | — | `POST /api/patients/request-patient-id/` |
| 14 | Look up an ID | `/lookup` | — | `POST /api/patients/lookup-identifier/` |
| 15 | Location picker | `/profile/location` | — | `GET /api/patients/locations/*` |

### C. Visits & case — Phase 3
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 16 | Visits | `/visits` | C | `GET /api/patients/visits/` |
| 17 | Visit detail | `/visits/:id` | C | `GET /api/patients/visits/:id/` |
| 18 | New visit | `/visits/new` | — | `POST /api/patients/visits/` |
| 19 | Case file | `/visits/:id/case-file` | — | `GET /api/patients/visits/:id/case-file/` |

### D. Triage & risk — Phase 3
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 20 | Triage results | `/triage` | — | `GET /api/triage/` |
| 21 | Triage result | `/triage/:id` | C | `GET /api/triage/:id/` |
| 22 | Care protocols | `/learn` | — | `GET /api/clinical/clinical/protocols/` |

### E. Appointments & ANC — Phase 3
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 23 | Appointments | `/appointments` | C | `GET /api/appointments/` |
| 24 | Appointment detail | `/appointments/:id` | — | `GET /api/appointments/:id/` |
| 25 | New appointment | `/appointments/new` | — | `POST /api/appointments/` |
| 26 | ANC requests | `/anc-requests` | — | `GET /api/appointments/anc-requests/` |

### F. Follow-through — Phase 4
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 27 | Notifications | `/notifications` | C | `GET /api/notifications/` |
| 28 | Referral timeline | `/referrals/:id` | — | `GET /api/referrals/:id/timeline/` |
| 29 | Follow-ups | `/followups` | — | `GET /api/followup/schedules/` |
| 30 | Alerts | `/alerts` | — | `GET /api/followup/alerts/` |

### G. Care network — Phase 4/6
| # | Page | Route | Core | Endpoint |
|---|---|---|---|---|
| 31 | Facilities near me | `/facilities` | — | `GET /api/facilities/nearby/` |
| 32 | Facility detail | `/facilities/:id` | — | `GET /api/facilities/:id/` |
| 33 | News & resources | `/news` | — | `GET /api/public/entries/` |

### H. Staged / gated — Phases 5+
| # | Page | Route | Gate |
|---|---|---|---|
| 34 | Calling a CHP | `/calls` | Phase 5 (decision 4: calling is core) |
| 35 | Chat 1:1 | `/chat/:id` | deferred post-v1 (decision 2) |
| 36 | Community chat | `/community/:id` | deferred post-v1 (decision 2) |

**Explicitly not pages:** trimester tracking (§5), care card / payments
(§12, decision 3 undecided), voice input (§11 — an overlay, not a screen),
settings and about (folded into Account profile until they earn a route).

## What the core loop forces (feeds open decision 1)

This is the point of the exercise: the data-layer shape now has something
concrete to be designed against.

| Statement | Needs to work offline? | Implication |
|---|---|---|
| "It knows who I am" | No — one-time | Auth is online-only; safe to fail hard |
| "I can see how far along I am" | **Yes** | Cache `my-profile`, `dashboard-stats`, last triage read |
| "I know when my next visit is" | **Yes** | Cache visits + appointments; stale-with-timestamp UI |
| "Someone gets back to me" | **Degrade** | Notifications arrive when online; queue nothing on device |

Derived requirements:
1. **Read cache for 4 entities** — profile, dashboard, visits, appointments
   (plus last triage result). Everything else can require signal.
2. **Write queue for at most one action** — `add-message` on a visit.
   Nothing else in the core loop writes.
3. **No sync engine.** Two reads cached, one write queued. That is a
   small, explicit scope — resist generalising it before pages 10–13 exist.

## Sequencing

1. **Phase 1** — pages 3–10 (auth) · **Phase 2** — 11–15 · **Phase 3** —
   16–26 · **Phase 4** — 27–33 · **Phase 5** — 34.
2. Build to the core loop first, in table order; staged pages only after
   the 14 are done and the offline model is chosen.
3. Anything added later must state which of the four sentences it serves —
   otherwise it is scope creep, not a page.
