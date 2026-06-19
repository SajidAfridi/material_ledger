# Yorks GodownPro — Rev 1.3 Code Change Report

Scope expansion from a procurement-only tool into a **one-panel, three-module
operations platform**: Materials & Projects, Rental Shops, People/HR, plus
Admin read-all. This report covers the **code** changes (Phases 2–6); the spec
changes (Phase 1) are recorded in the `york project` folder as
`Yorks_GodownPro_SRS_v1.3.docx` / `Yorks_GodownPro_Final_Rev1.3.docx`.

Status: `flutter analyze` clean · `flutter test` 37 passing · hot-restart with
no runtime errors after every phase.

---

## 1. Roles & access (3 roles)

`engineer · procurement · admin` — Accountant was **merged into Admin** (finance/
cost/salary/read-all; may be split out later) and **People/HR was moved to
Procurement** (kept on Admin too for now, later procurement-only). Admin is the
all-in-one office/owner role; the owner signs in via Admin. No self-signup.

- `lib/shared/models/user_role.dart` — `UserRole` enum + capability matrix:
  `canSeeCost` (admin/procurement), `canSeeSalary` (admin only),
  `canAccessRentals` / `canWriteRentals` (procurement/admin),
  `canAccessPeople` / `canWritePeople` (procurement/admin),
  `canReceiveGoods` (procurement/admin), `canViewFinance` (admin only),
  `usesAdminPanel` (every role but engineer).
- `lib/shared/providers/session_provider.dart` — `currentRoleProvider`
  (persisted) + `actorNameProvider`. Stands in for real auth; a **dev
  role-switcher** (`RolePickerSheet`) lives in both the engineer profile and the
  office settings so any role is testable.
- Routing (`lib/app/router.dart`): `_isAllowedForRole` guards every module
  route; office roles land in the admin shell, engineers in the mobile shell.

## 2. Audit trail (non-deletable)

- `lib/shared/models/audit_log.dart` + `lib/shared/providers/audit_log_provider.dart`
  — append-only `AuditEntry { action, actorName, actorRole, module, refId,
  detail, timestamp }`; `ref.logAudit(...)` one-liner wired into every mutation
  across Materials, Rentals and People. Read-only viewer at
  `lib/shared/screens/activity_log_screen.dart` (role-scoped).
- Client may only append; **edit/delete denied** (server-side in the rules).

## 3. Repository seam (Firebase swap point)

- `lib/shared/repositories/local_store.dart` — `LocalCollectionStore<T>`, a
  JSON-list collection store over `SharedPreferences`. Rentals, HR and goods
  receipts build on it; swapping in a `FirestoreCollectionStore<T>` with the
  same surface is a drop-in change with no call-site edits.
- `lib/shared/services/submit_queue.dart` — `SubmitQueue` connection-resilient
  submit seam (pass-through today; becomes the Firestore offline wrapper).

## 4. Materials gap-fixes

- **Reservation** — `MaterialItem.reservedQty` (+ derived `availableQty`);
  atomic `reserve` / `release` / `dispatch` / `receiveStock` on the inventory
  notifier. Lifecycle: reserve on request raise/submit → decrement on-hand +
  release on receipt → release on cancel.
- **Goods receipt** — `goods_receipt.dart` + provider; procurement
  `GoodsReceiptScreen` increments stock with **weighted-average** unit cost.
- **Cost roll-up** — `project_cost_provider.dart`: per-project net =
  Σ dispatched − Σ returned (valued at unit cost); accountant `FinanceScreen`
  with **CSV export** (clipboard).
- **Returns restock** — returns carry `materialId`; surplus/wrong-item restock
  inventory, damaged does not.
- **Cost visibility** — unit cost / stock value gated by `canSeeCost`
  (engineers never see it; FR-092).
- **Closeout** — `completeProject` blocked while open requests exist; "Mark
  complete" UI on active projects.

## 5. Rental Shops module (new)

- Models: `rental_unit.dart` (shop/workshop, tenant, lease, status),
  `rent_payment.dart` (period `YYYY-MM`, due/paid, **derived** Paid/Partial/Due/
  Overdue status).
- `rentals_provider.dart` — units + payments (on `LocalCollectionStore`),
  per-unit status, dashboard summary (rent roll, collected this month, overdue).
- Screens: dashboard (`/rentals`), unit detail + payment history (`/rentals/:id`),
  add-unit & record-payment sheets. Access: read = procurement/accountant/admin;
  write = procurement/admin. Every change audited.

## 6. People / HR module (new)

- Models: `employee_record.dart` (roster Employee; salary + IDs restricted),
  `attendance_record.dart`, `leave_record.dart`.
- `hr_provider.dart` — employees, attendance, leave; **leave balance =
  30 − approved annual days this calendar year**; HR summary (total / present /
  on-leave / absent today).
- Screens: People dashboard (`/people`), employee profile (`/people/:id`) with
  **salary/documents restricted to admin/accountant**, record-leave sheet.
  Access: read = accountant/admin; write = admin.
- The existing engineer self-service card (`/me`, `EmployeeProfile`) is retained
  unchanged.

## 7. Security rules

- `firestore.rules` (repo root) — authoritative role × collection × op matrix
  mirroring the capability helpers. Engineers can't read cost (cost in a
  protected `inventoryCosts` collection); only admin/accountant read salary
  (`employeePrivate`); procurement/admin write rentals; admin writes HR;
  **`activityLog` denies all client writes/deletes** (server-written);
  deactivated users denied; default-deny catch-all.

## 8. Tests (`test/`, 37 passing)

- `roles_test.dart` — capability matrix for all four roles.
- `materials_flow_test.dart` — reservation lifecycle, stock-restore-on-return,
  cost roll-up, weighted-average cost, closeout enforcement.
- `hr_test.dart` — leave-balance calc (annual vs sick vs pending), attendance
  summary.
- `rentals_test.dart` — rent-status derivation, rent roll, record-payment.
- `materials_notifier_test.dart` — existing (unchanged, still green).

---

## New Firestore collections (for the migration)

`goodsReceipts`, `inventoryCosts` (protected cost), `rentalUnits`,
`rentPayments`, `employees`, `employeePrivate` (protected salary/IDs),
`attendance`, `leaveRecords`, `activityLog`. Added field on `inventory`:
`reservedQty`. Cost on dispatch/returns valued via the inventory unit cost.

## Seeding / migration notes

- Local prototype seeds: rentals (3 units, 3 payments incl. one overdue), HR
  (5 employees, today's attendance, 3 leave records), audit (3 entries),
  inventory `reservedQty` defaults to 0 (old persisted items load cleanly).
- Persistence keys are versioned (`*_v1`); a Firestore migration imports each
  `LocalCollectionStore` collection 1:1, then moves cost → `inventoryCosts` and
  salary/IDs → `employeePrivate` to satisfy the field-level read rules.

## Post-review fixes (Rev 1.3.1 / 1.3.2)

- **Role consolidation (1.3.2)** — Accountant merged into Admin (finance, cost,
  salary, read-all now sit with Admin) and People/HR moved to Procurement (Admin
  retains it for now). Result: three roles — engineer · procurement · admin.
  Salary/documents stay Admin-only even though Procurement now runs HR
  operations. Updated `user_role.dart`, `firestore.rules`, `roles_test.dart` and
  all capability doc-comments; the dev role-switcher list updates automatically.
- **iOS Print/Download receipt** — root cause: the `printing` native plugin was
  added to `pubspec` but never linked, so `Printing.layoutPdf`/`sharePdf` threw
  `MissingPluginException`, and the call sites were fire-and-forget (errors
  swallowed). Fixes: refreshed plugin resolution (SPM now lists `printing`);
  every Print/Download handler now `await`s with try/catch + an error SnackBar;
  the receipt PDF loads a Unicode font (graceful offline fallback) so bilingual
  content can't crash generation; `sharePdf` gets an iPad popover anchor; and the
  secondary action button's dead `onTap: () {}` was wired up. **Requires a full
  rebuild** (native plugin can't hot-load); on the simulator "Print" shows
  "no printers" (expected) while "Download/Share" works.
- **Engineer self-profile** — removed the fabricated "Training for promotion"
  courses, grade/promotion progress, and the decorative Agenda strip (and the
  two dead "Request leave"/"Request permission" pills). Replaced with an
  **Employment** card (Employee ID, Department, Role) and a **Quick links** card
  (New request, My projects, My requests). `TrainingCourse` + the
  course/promotion fields were dropped from `EmployeeProfile` and its seed.
- **Role switcher** — now hidden in release builds (`kDebugMode`); it is a
  test-only tool. In production the role comes from the signed-in user's
  credentials and the existing role-based routing already lands each user in the
  correct shell automatically (office → admin panel, engineer → mobile).

## Post-review fixes (Rev 1.3.3)

- **Procurement role built out to the SRS** — the procurement operational app was
  missing. Added a **Procurement workspace** (`/admin/procurement`) with the two
  SRS work queues: Phase-1 **plans to review** and Phase-2 **requests to
  dispatch**. New screens: plan-review (arrange each item, comment thread, "Mark
  Done" → back to engineer for approval) and dispatch (full/partial per line, or
  on-hold with note). New provider methods: `setItemStatus`/`markAllArranged`/
  `markPlanDone` on plans; `dispatch`/`putOnHold` on requests. **Stock timing
  corrected to the SRS**: dispatch now decrements on-hand + frees the
  reservation (partial leaves the remainder reserved/open); receipt only records.
  Added `RequestLineItem.qtyDispatched`. Routes guarded to office roles; every
  action audited + fires an engineer notification. Tests updated + a new
  partial-dispatch test (38 passing).
- **Engineer profile ↔ home unified** — the Profile tab now reads the same
  `employeeProvider` as the home "My data" card and the `/me` detail, and tapping
  the profile header opens that same employee-data screen.
- **"New Request" moved into the bottom bar** — a centred, popped-out docked
  button replaces the floating CTA. The new-request flow gained recovery
  affordances: a mobile **priority (Normal/Urgent)** selector (previously
  desktop-only), **undo** on item removal, a **discard-draft** action with
  confirmation, and a hardened, double-submit-guarded submit that awaits the
  stock reservation before navigating.
- **Notifications simplified to the SRS §4.6** — removed the stats row, health
  banner, search, four filter tabs, urgency tier, initiator cards and
  action-button columns. Now a single read/unread list (plan / request / stock /
  info categories) with mark-all-read, tap-to-read and swipe-to-dismiss.

## Post-review fixes (Rev 1.3.4 — Admin panel per SRS §4.7)

- **User management & access control (the core admin gap)** — new `AppUser`
  model + `usersProvider` (on the `LocalCollectionStore` seam) and a **User
  Management** screen (`/admin/users`, admin-only, reached from Settings):
  create accounts (name, email, role, initial password — no self-signup),
  assign roles, **deactivate/reactivate**, **reset password**, and **grant/revoke
  per-engineer inventory access** (FR-086/089/095/098/104/308/311/332). Every
  action is audited with the SRS-mandated entries (user created, user
  deactivated, access granted/revoked, password reset — FR-348). `firestore.rules`
  gains a `users` collection (admin-write only, self-read, never delete).
- **Audit trail CSV export (FR-326)** — the Activity Log now has an admin-only
  **Export CSV** action (Timestamp, Action, Actor, Role, Module, Detail) on top
  of the existing module filter and role-scoped visibility.
- Tests: added `users_test.dart` (seed/create/deactivate/access-toggle) — 42
  passing.
- Already present and SRS-aligned: cost report (Finance), read-only audit trail
  (Activity Log), inventory add/edit/delete + manual adjust, admin read-all.
- Follow-ups for the admin panel: enforce per-engineer inventory-access at the
  engineer browse screen (modelled + audited now; enforcement is a Firebase-era
  binding to the signed-in user); full audit filtering by user/action/date
  (FR-323) beyond the current module filter + CSV; admin override to
  delete any project / any request (FR-314/317).

## Post-review fixes (Rev 1.3.5 — store stock-list columns)

Driven by the client's signed stock list (`SIGN STOCK LIST 31.12.2025`) and the
column spec for Air Inlet & Outlet items:

- **`MaterialItem` gained the store stock-list columns** — `brand` (Brand /
  Supplier), `countryOfOrigin`, `size`, and `ralColour` — alongside the existing
  description, quantity, unit and cost. JSON, `copyWith`, and a `specSummary`
  helper updated; persistence key bumped to `materials_list_v3` (clean reseed).
- **New `Air Inlet & Outlet` material category** (grilles, diffusers, dampers),
  seeded with realistic items (Supply/Return grilles, ceiling & linear
  diffusers, door transfer grille) carrying brand, country, size and RAL — e.g.
  *Return Air Grille · TROX · 600x600mm · RAL 9010 · Germany*.
- **Add/Edit Material sheet** now captures Brand/Supplier, Country of Origin,
  Size and RAL Colour (a "Stock details" group). The **inventory card** shows
  the spec line; cost stays Admin/Procurement-only as before.
- Engineer browse "Pipes & Ducts" filter now includes Air Inlet & Outlet so the
  new items are reachable; `materials_notifier_test` updated for the v3 key
  (42 tests passing). The engineer plan item already carried brand/country/size/
  RAL, so the planning ↔ store columns now line up end to end.
- Per the client, other materials may need different measuring units later —
  units (`MaterialUnit`) already model that; deferred for a focused pass.

## Post-review fixes (Rev 1.3.6 — Admin Panel consolidated to SRS §4.7)

The admin functions were scattered across dashboard header icons and Settings.
Consolidated into one control centre and closed the remaining SRS gaps:

- **Admin Panel hub** (`/admin/panel`, admin-only) — a single, polished control
  centre: a read-all **overview** (active users, active projects, open requests,
  stock value, employees, overdue rent) plus organised **Management** (User
  Management, Projects, Requests, Procurement, Inventory) and **Oversight** (Cost
  Report, Audit Trail, People, Rentals) cards. Reached from a prominent gradient
  card on the office dashboard.
- **Projects oversight** (`/admin/projects`, FR-123/317) — admin views every
  project and can **delete any** (with confirmation + audit). Fills a real gap:
  the office shell had no project view.
- **Requests oversight** (`/admin/requests`, FR-314) — admin views every request
  and can **reject** (cancel, releasing the reservation) or **delete any**,
  regardless of status; both audited.
- **Audit trail search** (FR-323) — the Activity Log gains a search box filtering
  by actor / action / detail, on top of the module filter and CSV export.
- All admin routes guarded to `isAdmin`; all overrides write audit entries.
  42 tests still passing; analyze clean.

## Post-review fixes (Rev 1.3.7 — data layer unified & backend-portable)

Hardening for a future move to Firebase **or** a custom server (ASP.NET / etc.)
without app-wide churn — see the new **`docs/ARCHITECTURE.md`**.

- **One persistence boundary.** Added `CollectionStore<T>` (abstract port) with
  `LocalCollectionStore<T>` as the local adapter, and a `Storage` factory exposed
  as **`storageProvider` — the single line to swap the whole backend.**
- **Every domain collection now goes through it.** Migrated the providers that
  still hand-rolled `SharedPreferences` — materials, transactions, requests,
  plans, returns, notifications, audit — onto the store (the newer modules —
  users, HR, rentals, goods-receipt — were moved to it too). No provider imports
  `SharedPreferences` any more; only per-device settings/session and the storage
  adapters do. This removed ~7 copies of duplicated load/persist code.
- **Behaviour-preserving.** Same versioned keys and identical JSON
  (`toJson`/`fromJson`), so existing data and all tests are unaffected (42
  passing); the materials test was moved onto `ProviderContainer` to exercise the
  wired store path.
- **`docs/ARCHITECTURE.md`** documents the layering, the swap point, and concrete
  recipes for Firestore and a REST/ASP.NET backend (per-collection endpoints,
  JWT role claims, server-written audit log), plus the sync→async migration path
  and performance notes.

## Post-review fixes (Rev 1.3.8 — bulletproof offline-first sync)

Never-lose-data sync for unreliable site connectivity, **applied to every
critical write across all roles**. New layer in `lib/shared/sync/`; backend-
agnostic so it drops onto Firestore (or REST) with a one-line provider swap. Full
design in **`docs/ARCHITECTURE.md` §8**.

- **Durable outbox.** Every critical write enqueues a persisted `MutationOp`
  (client-generated `docId`, deterministic `idempotencyKey`, record `toJson()`
  payload) through `ref.enqueueSync(...)`. Wired into all eight flows for all
  roles: request create/submit/status/hold, **dispatch**, **receipt
  confirmation**, **returns**, **goods receipts**, **rent payments**,
  **attendance**, **leave** (plus rental-unit & employee records).
- **Zero duplicates.** Idempotent backend `set` on the client id + queue-level
  **coalescing**: a repeat write to the same record updates the queued op's
  payload to the latest snapshot instead of appending — so two partial dispatches
  never double-apply or lose the later quantity.
- **Zero loss.** Ops persist via `storageProvider` (survive restart); transient
  failures retry with exponential backoff (cap 64s) forever; permanent failures
  (permission denied) are **dead-lettered, never dropped**, and surfaced with
  Retry.
- **Atomic stock/balance.** Stock- and money-moving ops carry `isTransactional`;
  the Firestore adapter applies them in a `runTransaction` (scaffolded).
- **Honest UX.** `SyncStatusBanner` at the top of both shells
  (Syncing / Offline·queued / Needs-attention + Retry-all);
  `PendingSyncBadge` on request rows; success toasts softened via `showSyncSnack`
  — no "success" is claimed until the server confirms. A dev **"Simulate
  offline"** toggle (Settings) demos the offline→queued→synced flow.
- **DI.** Connectivity, backend, outbox and engine are all providers; notifiers
  enqueue via a `Ref` extension — the engine starts once in `app.dart`.
- **Tests (50 passing).** `test/sync_test.dart` proves the engine guarantees
  (offline→reconnect in order, dedupe, coalescing/partial-dispatch, mid-write
  transient retry-to-success, permanent dead-letter+retry);
  `test/sync_integration_test.dart` drives the **real notifiers across roles**
  offline → reconnect and asserts each op applies exactly once (zero loss, zero
  duplicates). `flutter analyze` clean; live hot-restart shows no runtime errors.

## Follow-ups (out of scope this revision)

- Wire Firebase at the repository layer; deploy `firestore.rules`; replace the
  dev role-switcher with real Auth custom-claim roles (routing already keys off
  the role, so this is a drop-in). Sync drops in at `syncBackendProvider` +
  `connectivityProvider` (see ARCHITECTURE §8).
- Audit entries to be written by Cloud Functions triggers (rules already deny
  client writes); FCM push per v1.2.
- Procurement dispatch UI (today stock leaves the store at site-receipt
  confirmation); tenant & staff self-service apps (roadmap).
- For fully offline receipts, bundle a Noto TTF as an asset instead of the
  network `PdfGoogleFonts` fetch.
