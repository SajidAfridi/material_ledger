# Backend decision — Firebase vs Supabase (Yorks GodownPro)

> **LEGACY — NOT CURRENT PRODUCT AUTHORITY.** This memo predates the approved
> Yorks V1 R35 Supabase/Postgres contract and contains superseded Firebase,
> GodownPro and residency recommendations. Keep it only as decision history.
> Use [`yorks-v1/README.md`](yorks-v1/README.md) and its linked authority
> documents for implementation.

> **Superseded decision record.** Do not use this memo to choose or implement
> the Nexus V7 backend. The approved decision is Supabase Auth/Postgres, recorded
> in [`nexus-v7/ADR-001-SUPABASE-POSTGRES-SOURCE-OF-TRUTH.md`](nexus-v7/ADR-001-SUPABASE-POSTGRES-SOURCE-OF-TRUTH.md).
> Firebase remains only the push-notification transport through FCM.

_Internal ops app for Yorks Air Conditioning & Refrigeration LLC (Abu Dhabi). Flutter +
Riverpod, offline-first with a custom sync seam already built. Audience: ~tens of staff
(engineers / procurement / admin). Holds HR (salaries, leave), financial (rentals, costs),
and audit data._

> **Recommendation: Firebase (Firestore + Auth + FCM + Remote Config)** — *provided the
> data-residency question below comes back permissive.* If UAE counsel requires data on
> UAE soil, that single finding flips the answer to **self-hosted Supabase**. Resolve it
> **before** writing backend code: Phase 1 is a one-way door.
>
> The decisive reason isn't a feature scorecard (that's nearly a tie). It's **reversibility**:
> your `SyncBackend`/repository abstraction makes "Firebase now, Supabase later" cheap *on the
> app side*, so the fast, zero-ops managed option is also the low-regret option — as long as
> residency allows it.

This memo was produced by a multi-agent analysis that read the actual seam code, then was
adversarially reviewed; the corrections from that review are folded in (notably: a cost-tier
fact fix, an honest RBAC downgrade, and two axes the first draft missed).

---

## The one question that gates everything: PDPL data residency

This is an internal tool holding **salaries, leave records, employee documents, and rent
ledgers** — exactly the data class most likely to attract a data-localization argument. So
residency isn't a footnote; it's the gate.

- **Firebase**: no self-host. You'd pin Firestore to a Middle-East region if available and
  acceptable, with Google holding the keys. "Within UAE" vs "Bahrain/Egypt is fine" is a
  **legal** call, and the *technical* ME-region availability for Firestore specifically
  (≠ Functions region ≠ FCM) must be confirmed per-product.
- **Supabase**: managed Supabase (last checked) had **no ME region** → residency means
  **self-hosting** (own cloud / on-prem) — full key control, but you own patching, backups,
  uptime.

**Action: get a written answer from UAE counsel on "must data reside on UAE soil?" before
Phase 1.** If yes → self-hosted Supabase (or Firebase + app-layer encryption + VPC Service
Controls, which erodes the zero-ops advantage). If no → Firebase.

---

## Axis-by-axis (corrected)

| Axis | Firebase | Supabase | Winner |
|---|---|---|---|
| **Data residency / PDPL** | ME region *if available*; Google-held keys; no self-host | Self-host (UAE soil / on-prem); sole key control | **Supabase** |
| **Offline-first fit w/ existing seam** | Built-in offline cache *overlaps* your outbox (coordinate carefully) | Outbox stays sole write driver; REST adapter is a clean fit | **Supabase** (narrow) |
| **Auth + 3-layer RBAC** | Custom claims + Rules; but per-user overrides + editable defaults are awkward (see risks) | RLS + SQL functions express "effective permissions" naturally | **~Tie** |
| **Push + realtime** | FCM first-party, free, maps to `PushService`/`PushMessage`→`AppNotification` | No native push → need FCM/OneSignal anyway (two backends) | **Firebase** |
| **Cost / ops at 10–20 users** | **Blaze** pay-as-you-go (near-zero, but Functions force Blaze, not Spark) | $25/mo Pro, or self-host DevOps | **Firebase** |
| **Backup / DR / point-in-time restore** | PITR is paid + recent; default is manual exports you must build | Mature Postgres PITR + `pg_dump` | **Supabase** |
| **Relational model + reporting** | NoSQL; rent-roll/aging/leave-accrual = N+1 in Dart (or BigQuery export) | SQL views/triggers/constraints native | **Supabase** |
| **Flutter velocity / lock-in** | FlutterFire very mature; backend logic (Rules/Functions/claims) is proprietary throwaway | Portable Postgres; lighter, younger SDK | **Supabase** (lock-in) |
| **Reversibility (app-side)** | Cheap to leave on the app side (adapter swap) | Cheap to leave (adapter swap) | **Tie — and the key point** |

On raw axis count Supabase actually leads. The recommendation overrides that because the
axes aren't equally weighted **for this app**: the Firebase wins (push, gates, low-ops,
reversibility) are needs you have *today*; several Supabase wins are either neutralized by
your own architecture (the outbox is your sync layer regardless) or are real-but-deferrable.

---

## Why Firebase (when residency permits)

1. **Push + remote gates are needs you have now, bundled free.** Your `PushService` and
   `appConfigProvider.bindRemoteConfig` seams are *waiting* for FCM + Remote Config. Supabase
   has no push — you'd run Supabase **plus** FCM/OneSignal (two backends) to get what Firebase
   bundles. Leave approvals, dispatch alerts, rent reminders → decisive simplification.
2. **The Firestore adapter is already scaffolded.** `sync_backend.dart` contains a
   `FirestoreSyncBackend` stub: `set(payload, merge:true)` for idempotent writes,
   `runTransaction` for `isTransactional` ops, `permission-denied`→`PermanentSyncException`
   else transient. The app was architected Firebase-leaning.
3. **Lowest ops weight for a team with no backend staff.** ~15 collections, tens of users,
   small data. Managed, serverless, no infra to run.
4. **Reversible.** The seam means starting on Firebase and migrating later is cheap on the
   app side — so picking it now is low-regret, not a lock-in gamble (caveat: the *backend
   logic* you write — Rules/Functions — is not portable; see risks).

---

## What you give up (honest)

- **Data sovereignty** (the gate above).
- **SQL reporting.** Rent-roll, overdue aging, leave-balance accrual are one SQL query in
  Postgres and N+1 Dart loops in Firestore. Not "speculative" — these are the obvious next
  reports for modules you already ship. Mitigation: the Firestore→BigQuery export extension
  for analytics, or compute client-side at your scale.
- **You own your backup story.** "Zero-ops" also means no automatic point-in-time recovery
  unless you build scheduled exports. For payroll/rent/audit data, define this on day one.
- **Backend-logic lock-in.** Security Rules, Cloud Functions, and the custom-claim model are
  Firebase-proprietary with no Postgres equivalent — a rewrite, not a port, if you ever leave.
  The abstraction protects the Dart app, not the backend logic.

---

## Engineering risks to handle (not optional — the draft over-smoothed these)

1. **Transactional idempotency on resend.** The outbox's core promise is "a resend never
   duplicates" (`mutation_op.dart`). Plain `set(merge:true)` is idempotent ✓. But a
   `runTransaction` that *increments* stock/balance is **not** idempotent on resend — a
   partial-success retry double-applies. For an inventory + rent-payment app, double-counted
   stock or payments is the worst-case bug. **Fix:** make `payload` carry the **target
   absolute state**, or guard the transaction body with a version/idempotency check on the
   doc. Decide this before Phase 1.
2. **Offline-write coordination (two sync brains).** If `SyncBackend.apply()` ever runs while
   offline, Firestore silently accepts the write into its own cache and the `Future` may not
   resolve — the outbox never gets its success/failure signal. **Rule:** `apply()` runs only
   when connectivity is up (the SyncEngine already gates on this — keep it), enable Firestore
   persistence for **reads/cache only**, and **all writes go through `enqueueSync` — never a
   direct `doc.set`** (worth a review/lint guard, since the SDK tempts direct writes).
3. **RBAC is close, not a clean Firebase win.** Custom claims are capped at **1 KB** and
   refresh only on token refresh (**up to ~1 hr stale**). Your model is 3 roles × capabilities
   **plus per-user overrides plus editable role defaults** — encoding per-user, runtime-editable
   permissions in `firestore.rules` needs `get()` calls on a config doc (read cost + depth
   limits). Verify the override matrix fits in 1 KB and that up-to-1hr staleness on permission
   changes is acceptable; otherwise lean on a Firestore config-doc + rules `get()` (or
   reconsider RLS, which does this naturally).
4. **Read/listener cost.** Firestore bills **per document read on every listener fire**. An
   "all open requests" live view across collections can quietly become the dominant cost line
   and undercut "near-free." Decide which screens need live `snapshots()` vs pull-to-refresh.
5. **Concurrent distinct edits.** `merge:true` is last-write-wins at field level — fine for
   resends, but two admins editing the same `RolePermissions` config doc → one edit silently
   dropped. Neither backend solves this for free; add a version check if it matters.
6. **You will write & own backend code either way.** Firebase: claim-provisioning Function +
   push-trigger Functions + Security Rules. Supabase: RLS policies + migrations + maybe edge
   functions. "Zero backend code" is not real for either.

---

## Migration path (mapped onto the existing seam)

**Phase 0 — Resolve residency (blocking).** Counsel answer + confirm Firestore ME-region
availability. Don't start Phase 1 until this is settled — it's a one-way door.

**Phase 1 — Data writes (the core swap).**
- Add `firebase_core` + `cloud_firestore`. Promote the `FirestoreSyncBackend` scaffold in
  `sync_backend.dart` to a real class; point `syncBackendProvider` at it. Nothing else in the
  app changes.
- Mapping: `MutationOp.collection` → collection; client-generated `docId` → `doc(docId)` so a
  resend `set`s the same document (structural idempotency, no header needed unlike REST);
  `payload` → `set(payload, merge:true)`; `isTransactional` → `runTransaction` **with the
  idempotency fix from risk #1**; `permission-denied`/`invalid-argument` → `PermanentSyncException`,
  else transient. Outbox backoff/dead-letter/retry stays as-is.
- One-time seed: import current SharedPreferences collections into Firestore.

**Phase 2 — Auth + roles server-side.**
- Swap the `AuthService`/`AuthController.signIn` body for Firebase Auth email/password; UI
  still calls the same `signIn`/`signOut`. `currentUserProvider`/`currentRoleProvider` read the
  role from the **custom claim** (the code already anticipates this).
- Build the claim-provisioning Cloud Function (role, active, per-user overrides) on user
  create/update — your one genuinely new backend component.
- Port the role×capability matrix into `firestore.rules`; gate sensitive fields (cost, salary,
  documents). Mind the 1 KB / staleness limits (risk #3).

**Phase 3 — Gates + push.**
- Implement `bindRemoteConfig(...)` against Remote Config or a Firestore config-doc listener
  so `appConfigProvider` (force-update / maintenance) updates live with no app release.
- FCM implementation of `PushService`: `register()` → token; `onMessage` → `PushMessage` →
  `notificationsProvider.add(...)`; taps deep-link via the stored `route` (plumbing exists).
  Trigger from Cloud Functions on domain events (leave approval, dispatch, rent due). Upload
  the APNs key for iOS (needs a paid Apple Developer account — gating prerequisite, not a
  differentiator).

Phase 1 alone gets you a real backend; 2 and 3 follow without touching the sync engine.

---

## Open questions to verify (all ~12–18 months stale as of mid-2026 — re-confirm)

1. **PDPL: must data reside on UAE soil?** (legal) — the decision-flipper.
2. **Firestore ME-region availability + data-location commitments** (per-product, not just GCP).
3. **Managed Supabase ME-region availability** — if it now exists, Supabase gives residency
   *and* zero-ops, which would re-open the whole decision. Treat as co-#1 with PDPL.
4. **Current Firebase Blaze rates + free quotas**, and a real Blaze-vs-Supabase-Pro number at
   your volume (don't trust the qualitative "cheaper").
5. **Data volume** under Blaze assumptions (audit + history < ~100 MB?).
6. **Apple Developer account / APNs key** available, if iOS push is in scope.

---

## When to pick Supabase instead

Any one of these → Supabase (self-hosted):

- Counsel rules data must be on UAE soil, or you want sole key control.
- Rich operational reporting (rent-roll, aging, leave accrual) is a recurring first-class need.
- You have/want Postgres in-house and value a portable, self-hostable, zero-lock-in stack —
  and have the ops appetite to run it.

Absent those, Firebase serves the needs this app has today, honors the seams already in the
code, and is the reversible (low-regret) choice.
