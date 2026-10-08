# Procurement workspace implementation and staging release

Date: 8 October 2026
Scope: owner-authorized implementation and staging review. Production is excluded.
Source branch: `codex/procurement-workspace-staging`.

## Implemented

- Arrangement opens inside the universal office shell as a full workspace. The desktop editor uses a bounded lazy list, pinned item identity and column headers, search and decision filters, and persistent Save progress / Review arrangement actions. All lines remain part of validation even when filtered.
- Warehouse selection separates a selected catalogue item from available quantity and rejects unrelated search results. Shared-item shortages identify every affected line. Existing clarification, supplier optionality, readiness policy and commercial access rules remain in force.
- Arrangement and dispatch share private account checkpoints, raw incomplete-input recovery, explicit recovery choices and version-conflict handling. Browser recovery excludes costs and is scoped to backend, actor and editor. Account commercial progress uses a separate protected relation.
- Mobile arrangement now exposes Save progress and the same conflict, retry and recovery controls in the list, line editor and review. A focused regression verifies that an incomplete quantity such as `1.` is preserved exactly without submitting an arrangement.
- The universal Back/Forward controls and route exit share an unsaved-work guard. Desktop Ctrl/Cmd+S saves progress. Browser unload uses the standard browser warning; it does not attempt a workflow transaction.
- Final arrangement/dispatch submissions freeze the exact payload and command identity before preparation. Uncertain outcomes offer status reconciliation and exact retry. Explicit abandonment is server-fenced against a delayed commit; a confirmed command cannot be reused as editable progress.
- Dispatch preparation uses decimal-safe shared-stock suggestions and row validation, including negative, over-cap and combined stock shortages. An explicit manifest review precedes the stock command. Saved preparation moves no stock.
- Dispatch Centre uses trusted remaining-demand readiness, including replacement demand, instead of assuming readiness from aggregate workflow status.
- Delivery documents have an explicit immutable revision selector. Original dispatch snapshots and receipt-reviewed reports remain distinct. Excel, print and PDF use the selected revision.
- Bounded analytics record save/restore/failure/reconciliation outcomes without record IDs, free text, costs, quantities or command payloads.

## Backend and preservation

Apply these additive migrations in order before deploying the client:

1. [Aggregate dispatch stock protection](../../supabase/migrations/20261008162353_procurement_dispatch_aggregate_stock_guard.sql).
2. [Private progress and prepared commands](../../supabase/migrations/20261008162546_procurement_private_progress.sql).
3. [Dispatch readiness](../../supabase/migrations/20261008163612_procurement_dispatch_readiness.sql).

Project and Company dispatch both lock stock deterministically and validate the sum for each inventory item, accounting for reservations in both lanes. Existing IDs, stock movements, documents and historical workflows are preserved. Checkpoints have owner isolation and revision compare-and-swap. No ordinary authenticated or anonymous table reads are granted for progress, commercial progress or prepared intents. Public RPCs re-check authorization; internal assertion helpers are not executable by ordinary clients.

Rollback: restore the preceding client first; retain additive progress data and the stock correction. Do not delete checkpoints or reverse historical stock movements to roll back a UI release. Reconcile any prepared submission before editing it in another client.

## Verification

- Full Flutter suite: **2,613 passed**, four pre-existing fixture skips.
- Final focused dispatch suite after correcting its visual-test theme: **17 passed**.
- Mobile follow-up: **60 focused visual/flow tests**, then **47 progress, command-preparation and mobile regressions passed**; analyzer remained clean.
- Analyzer: **no issues**.
- Clean local database reset and full database suite: **3,774 tests / 130 files passed**.
- Two-connection database checks cover competing dispatches and delayed-command versus abandonment fencing in disposable local database clones.
- CI web build and startup budget passed; CI APK build passed using ephemeral CI signing. This APK is not a production distribution artifact.
- Desktop and 360px widget goldens cover arrangement, dispatch, validation and document revisions. The existing receipt and return regression flows pass.

## Staging backend

Only `iqltcyimlqtcwyzlemwx` was changed. Hosted ledger timestamps are:

| Migration | Hosted version |
| --- | --- |
| procurement_dispatch_aggregate_stock_guard | 20261008174300 |
| procurement_private_progress | 20261008174306 |
| procurement_dispatch_readiness | 20261008174309 |

Post-migration checks confirm RLS and denied direct table reads for all three new tables, denied anonymous execution for the public progress RPCs, and denied ordinary execution of the internal assertion helper. Security advisers report no ERROR findings. Their no-policy notices are expected for RPC-only tables; the authenticated security-definer notices describe deliberately authorized RPC entry points. Existing anonymous-helper notices and disabled leaked-password protection remain outside this change ([adviser guidance](https://supabase.com/docs/guides/database/database-linter)).

## Evidence boundary and next review

This implements the core stock, recovery, editing and document changes from the [approved review](PROCUREMENT_WORKSPACE_REVIEW_20261008.md). The larger proposal also described future catalogue/server pagination, richer row details and staff timing studies. Those are not claimed as completed or measured here. Project and Company backend stock protection is tested; Company Use retains its separate editor and does not acquire this Project MR progress UI.

Named Procurement-persona acceptance, physical-device/network-loss exercises, large-catalogue runtime profiling and long-running monitoring remain review activities. Automated tests are not a claim that every real user scenario has been exercised. Staging browser and deployment evidence follows below once verified.

### Startup performance correction

The first staging-configured build exceeded the unchanged 2,900,000-byte gzip startup budget by 1,692 bytes. Arrangement now loads through the existing deferred-route pattern with a retry action if its library cannot download. This avoids downloading the editor at application startup. The guarded route and domain providers are retained. The 39 routing and arrangement tests passed after this change; final staging build measurement is recorded with deployment evidence.
