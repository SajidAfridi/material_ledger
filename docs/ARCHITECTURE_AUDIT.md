# Architecture audit — findings & fix status

A multi-agent audit (10 subsystem maps → 7 domain-expert lenses → adversarial
verification of every finding) produced a 19-item backlog from 39 verified
findings. Status below. Accounting is intentionally a separate future module and
was out of scope.

## ✅ Fixed & test-covered this pass (Dart-only correctness)

| # | Sev | Area | Fix |
|---|-----|------|-----|
| 1 | P0 | Projects/Inventory | **Project delete is now guarded** — refused while open requests hold reservations (would orphan stock on the shared godown); on delete the Phase-1 plan is removed too. Requests/returns carry a stable `projectId`; open-request/closeout matching keys off it (falls back to name for legacy), so two same-named jobs no longer share state. |
| 5 | P1 | Inventory/Sync | **Reservations are now derived & self-healing** — `reservedQty` is reconciled from the sum of open-request outstanding on launch, on every edit, and after each realtime merge (`inventoryReconcilerProvider`). Fixes seed under-reservation and cross-device drift. |
| 4 | P1 | Dispatch | **Dispatch gates on _available_ stock** (on-hand minus other requests' reservations), never gross on-hand — one request can no longer consume another's reservation. |
| 3 | P1 | Requisitions | **Goods-receipt is clamped to what was dispatched** (can't receive valves that never shipped), and a request stays `partial`/queue-eligible until every line is fully dispatched instead of being silently closed. |
| 14 | P1 | Returns | **Returns are clamped to net-issued** (dispatched − already-returned) so a return can't inflate on-hand beyond what left the store; `requestId` added for traceability. |
| 7 | P1 | HR/Leave | **Year-boundary-aware leave** — a leave spanning New Year charges each calendar year only for its own days instead of dumping the whole span on the start year. |
| 11 | P1 | HR/Leave | **Tenure-based annual entitlement** (UAE Art. 29: 0 under 6 months, ~2 days/month 6–12 months, 30 from 1 year) instead of a flat 30 for everyone. |
| 6 | P1* | Security | **`schema.sql` owner-RLS aligned to `app_user_id()`** (was `auth.uid()`), matching the live DB — a re-deploy on the UAE self-host no longer locks every engineer out of their own requests/leave. |

Tests: `materials_flow_test.dart` (+3), `leave_balance_test.dart` (+2). **177 pass.**

## ▢ Remaining in-code (P1/P2, no new infra) — next pass

- **8 · P1** Enforce leave **overlap** at submit + approval (detector exists;
  nothing blocks on it → overlapping leave can double-count). Needs the
  request-sheet/approvals UI to surface the block.
- **10 · P1** Rentals: treat **occupied-but-unbilled elapsed months as
  outstanding** so rent-roll, collected, and overdue reconcile.
- **9 · P1** Rent-payment model guards: validate `periodMonth` (`YYYY-MM`), treat
  an unparseable month with a balance as overdue (not hidden), clamp
  `amountPaid ≥ 0`.
- **17 · P2** Wire the already-implemented `addEmployee()` / attendance
  `markToday()` to UI (add-employee FAB, attendance sheet), or hide the static
  "present today" cards.
- **12 · P2** Confirm dialog before the irreversible leave **Approve**; dispose
  the reject-reason `TextEditingController`.
- **13 · P2** Gate the rental payment FAB on `unit.isOccupied`.

## ⏸ Deferred — need new server infrastructure (flagged, not started)

- **2 · P0** **Salary & supplier unit-cost leak**: they ride in the synced `data`
  JSONB, so procurement can read them via the API despite the UI hiding them.
  Fix needs column/row redaction (security-definer views or a split
  salary table) + realtime respecting it. **Highest-priority next item.**
- **15 · P1** Persist & sync **inventory** (on-hand, reservations, weighted-avg
  cost) server-side with transactional deltas — today stock lives only on the
  last device that touched it and resets to seed on reinstall.
- **16 · P1** Append-only **stock-movement ledger** (depends on 15).
- **18 · P1** Propagate **Access & Roles matrix edits into JWT caps** and
  re-stamp existing users (Edge Function / trigger).
- ~~**19 · P1** UAE statutory module~~ — **DONE**, see below. (Supplier/PO
  master deferred — genuinely separate master-data work, not a calculation.)

---

# UAE statutory bundle (rank 19) — DONE

All five sub-items the audit called for, minus supplier/PO master (explicitly
deferred — it's new master-data entities, not a calculation, exactly as the
audit itself scoped it). Every money/date figure is clearly labelled an
**estimate for HR/payroll planning**, not a certified payout — real settlement
should be confirmed with HR/legal. 25 new tests (212 total).

- **EOSB gratuity** (Art. 51) — `gratuity.dart`: pure calculator (21 days/yr to
  5yr, 30 days/yr beyond, capped at 2yrs' wage). `Employee.basicWageAED` (falls
  back to `salaryAED`) drives it; `gratuityEstimateProvider` /
  `totalGratuityLiabilityProvider` (company-wide roll-up) in `hr_provider.dart`.
  Shown on the Employee Profile (admin-only). `basicWageAED` gets the same
  salary-leak treatment (stripped from sync, preserved locally).
- **Sick-leave pay tiers** (Art. 31) — `sick_leave_tiers.dart`: pure splitter
  (15 full-pay / 30 half-pay / 45 unpaid, 90-day annual cap, cumulative-aware).
  `sickLeaveTierProvider` previews the split live in both the engineer's
  self-service request sheet and the admin's record-leave sheet.
- **Document-expiry alerts** — `Employee` gained `emiratesIdExpiry` +
  `passportExpiry` (existing `visaExpiry` already tracked); a launch-time
  monitor (`document_expiry_monitor.dart`, mirrors `idle_request_monitor.dart`)
  flags any of the three expiring within 30 days (or already expired) to
  admin, deduped per-document so it never re-fires. A live banner on the
  Employee Profile shows the same warning. **New "Edit HR details" sheet**
  closes a real pre-existing gap — there was previously no UI path at all to
  set these dates after onboarding (or the wage/EID/passport fields), which
  would have made the alerts permanently inert.
- **Security deposits** — `RentalUnit.securityDepositAED`, set in the add/edit
  unit sheet, shown on the unit detail screen, and rolled up as a "Security
  deposits held" liability KPI on the Rentals dashboard (hidden when zero).
  Tracked separately from rent — never counted in the rent roll.
- **5% VAT breakdown** — `RentalUnit.vatRatePercent` (default 5%) +
  `netRentAED`/`vatAmountAED` getters, back-calculated from the existing
  VAT-inclusive `monthlyRentAED`. **Deliberately display-only**: every
  due/collected/overdue calculation already fixed earlier in this audit
  continues to use `monthlyRentAED` completely unchanged — this only adds a
  net/VAT/gross breakdown on the unit detail screen for invoicing
  transparency, with zero risk to the accrual logic. A full VAT-compliant
  tax-invoice PDF (with company TRN) would be a further step — no rent-receipt
  PDF flow exists today to extend.

**Bug fixed while building this**: `ExpiringDocument.isExpired` read the wall
clock (`DateTime.now()`) instead of the scan's injected `now`, silently
breaking the class's own documented "pure, testable" contract — caught by a
new test, fixed to compute `isExpired` from the injected time at scan time.

\* latent until the committed schema is re-deployed (e.g. UAE self-host).

---

# Robustness & foolproofing pass (for non-technical new users)

Driven by three parallel audits (two crash sweeps + one foolproofing sweep). Both
crash sweeps found the UI layer already disciplined (validators wired, `mounted`
checks, `orElse` everywhere, null-guards before `!`) — **no reproducible UI
crash**. The real risk was synced data → model decoders.

## Bulletproofing (crash-proofing)
- **Friendly crash fallback** — `ErrorWidget.builder` replaces Flutter's red/grey
  error box with a calm, fully self-contained widget (renders even without a
  theme/Material ancestor), so one failed widget can't take the app down.
- **One bad row can't wipe a collection** — `LocalCollectionStore.readAll` now
  decodes ROW BY ROW; a malformed/partial synced record is skipped, not thrown
  (which previously reset the whole provider's list to `[]`). Regression-tested
  (`local_store_test.dart`).
- **Hardened decoders** — money + likely-trigger casts made null-safe:
  `rent_payment`, `material_request` (`itemCount`), `leave_record` (`days`),
  `goods_receipt` — `as num?`/`toInt()` instead of `as int` (a synced `3.0`
  decodes as double → `as int` throws), `DateTime.tryParse` with fallback, and
  `as String? ?? ''`. Bad rows now survive with sane defaults.
- Global `FlutterError.onError` + `platformDispatcher.onError` → observability
  (already present).

## Foolproofing (mistake-proofing)
- **Stock quantity** must be strictly positive (was accepting 0/negative →
  silently corrupted on-hand); add-material qty/price get fat-finger upper bounds.
- **Salary** field validated (positive, sane ceiling).
- **Create-project** double-tap guard (was creating duplicate projects).
- **Submit-draft** now confirms (irreversible send to procurement).
- **Receive-into-inventory** surfaces an error on empty/0 qty (was silently doing
  nothing → user thought the shortfall was fixed).
- (Plus earlier guards: leave-overlap block, leave-approve confirm, rental FAB
  occupancy gate, overpay / over-return / over-dispatch caps.)

Minor remaining (low-harm, noted): edit-request per-line qty upper bound,
record-leave confirm, contract-value validator, void-payment busy guard.

---

# Stock-movement ledger (rank 16) — DONE

Append-only audit trail answering "why is on-hand 84, not 120?".

- `StockMovement` model (`materialId`, `type` receipt/dispatch/returnIn/
  adjustment/opening, signed `delta`, `resultingBalance`, `refId`, `actor`,
  `timestamp`) + `stockMovementsProvider` (record-only notifier).
- Emitted automatically from `MaterialsNotifier.adjustQuantity`/`receiveStock`
  (the two on-hand mutators) — every dispatch, return, GRN receipt, and manual
  transaction ledgers itself; callers didn't need to change.
- New **Stock History** screen (`stock_history_screen.dart`, route
  `/admin/inventory/history`, icon on the Inventory screen) — newest-first,
  colour-coded in/out, resulting balance per row.
- Synced: `stockMovements` table (read = any signed-in user, write = `goods`
  cap), realtime + launch-hydrate wired. RLS verified live (engineer reads,
  can't write; procurement writes).
- Fixed a real bug while wiring this up: `_recordMovement` wasn't awaited by its
  callers, so its internal sync write could still be in flight after a caller's
  `ProviderContainer` disposed (surfaced as a test failure — outbox used after
  dispose). Now properly awaited end-to-end.
- 4 new tests (`stock_movement_test.dart`) + updated sync-integration count.
  **187 tests pass.**
