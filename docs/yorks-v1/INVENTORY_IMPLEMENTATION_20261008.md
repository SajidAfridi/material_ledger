# Inventory reliability and usability — implementation candidate

8 October 2026. First coherent implementation slice from [the audit](INVENTORY_AUDIT_20261008.md). This is a local candidate, not a production release or completion of every audit phase.

## Implemented

- Project and Company reservations appear in the authorized inventory projection. Company destinations use unit/category labels, with no additional commercial or personal fields.
- Stock creation and adjustment retain the exact payload, expected version and idempotency key after an uncertain response. Concurrent submission is blocked; definitive rejection permits correction. Navigation and editor changes are blocked until an uncertain command is resolved in the current session.
- Import navigation is blocked while committing or awaiting confirmation. The provider retains pending state, prevents edits/reset during uncertain outcomes, and refreshes stock, history and supplier reads after confirmed success.
- Negative corrections use the server's signed, nonzero delta semantics; labels follow the selected action. Existing server stock-floor, role, version and transaction checks remain unchanged.
- Inventory reads refresh on coalesced workflow signals, foreground return and a foreground 60-second interval. Providers watch the current user and role.
- Global and item movement history use authorized server search/type filters and timestamp/ID cursor pages. Item summaries no longer load all history. Old RPCs remain for older clients.
- Movement Excel exports retrieve all matching pages rather than exporting the stock register or silently stopping at 100. Stock exports follow the current stock filters. Export retrieval stops if the current user or role changes.
- Stock is the default view. Mobile has visible search, collapsed secondary filters and a section dropdown. Repeated actions were consolidated. Supplier navigation retains the parent page, and shell breadcrumbs recognize inventory subroutes. Items without a configured minimum say so explicitly.
- SQL materializes item projections once and uses grouped movement statistics instead of repeated correlated count/latest queries. Search input is debounced. This is not a measured production performance claim.

## Change boundaries

Models: reservation source kind and history query/page types. Repositories: movement-page RPC and bounded item-summary RPC. Controllers/providers: stock retry lifecycle, import retention and read invalidation. UI/routes: Inventory, import, supplier navigation and exit guards. Export service: movement workbook. Migration and database tests are additive. No unrelated feature, stock command, table RLS policy or production data was changed.

## Data preservation and rollout

Migration: [20261008062343_inventory_reliability.sql](../../supabase/migrations/20261008062343_inventory_reliability.sql).

It replaces the read projection, adds read RPCs and an index, and preserves existing rows, IDs, balances, reservations, movements and audit history. New RPCs revoke public/anonymous execution, grant authenticated execution and enforce the existing inventory read guard internally. Authorized read access does not grant stock mutation.

Apply the migration before deploying this client; the client requires the new history and item-summary RPCs. Older clients continue to use their existing RPCs. Roll back the client first if necessary; leaving the additive RPCs/index in place is safe. Any database rollback should restore the previous projection definition explicitly and must not delete inventory data or reverse committed stock movements.

## Verification

- `flutter pub get`: passed.
- `flutter analyze`: no issues.
- Full `flutter test`: 2,571 passed, four existing skips. After the final export-authority check and history invalidation, the focused Inventory suites were rerun: 71 passed.
- CI web build and startup-size budget: passed. CI APK build with ephemeral signing: passed.
- Local `supabase db reset --local`: passed, including the new migration.
- Full local `supabase test db`: 3,692 tests across 127 files passed. New coverage includes mixed Company demand, bounded/older history, stable same-timestamp paging, positive read permissions and negative stock/read permission cases.
- Desktop, tablet and 360px widget goldens updated and inspected. These are controlled widget renders, not production browser or physical-device evidence.
- Retry tests cover a lost response, replay of the exact command, offline retry, definitive rejection and concurrent clicks; widget tests also cover create/adjust retry and a negative correction.
- Export tests inspect signed movement facts and workbook cell encoding.

## Remaining audit phases and release limitations

- Pending command recovery currently survives in-app navigation guards/provider retention, **not a full browser reload or process termination**. Durable, authority-scoped recovery and reopen/reconciliation need a separate tested slice before calling reload recovery complete.
- The stock workspace still retrieves all stock; server stock/reservation paging, separate summary reads, measured large-data/import performance and privacy-safe search timing remain open.
- Movement date-range controls, a print view matching export, sticky desktop item identity, further supplier-folder simplification and explicit last-updated/stale UI remain open.
- Two-person browser refresh/reconnect tests, secondary-language/RTL visual inspection and warehouse-staff task testing remain release gates. Current local checks do not certify every flow bug-free.
- No hosted migration, staging deployment, production promotion or live stock mutation was performed. CI builds use an invalid placeholder backend; the APK uses ephemeral CI signing and is not a production distribution artifact.
