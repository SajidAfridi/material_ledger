# Procurement simplification — staging review

Owner direction: quantity-led arrangement, shelf locations, sensible sourcing,
automatic Delivery Order numbering and gradual preparation of Scheduled work.
Scope: Project Material Requests; Engineer request/approval/receipt flows and
Company Use remain intact. Production deployment is not authorized for this slice.

## Usability decisions

Applied [Nielsen's ten usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/)
to the actual workflow:

| Heuristic | Implementation |
| --- | --- |
| Visible status | Timing/date, derived quantity state, confirmed readiness with actor/time |
| Familiar language | Quantity, shelf/bin, Ready now and Expected date |
| Control and freedom | Private recovery, preview before sharing, existing exit/retry/reconciliation |
| Consistency | Universal shell and existing seven workflow stages |
| Error prevention | Exact decimals, quantity caps, shared-stock validation and safe source matching |
| Recognition | Shelf/bin beside the selected item; ready/requested quantities beside item/unit |
| Efficiency | Automatic status, automatic DO number and preserved selections |
| Minimal design | Removed manual decision control and repeated DO reference entry |
| Error recovery | Clear failure, confirmed state retained, explicit refresh after conflict |
| Help | Short contextual explanations of preparation versus reservation |

This is a usability improvement, not a claim of perfect usability. Staff review
on staging remains the meaningful acceptance check.

## Live usage baseline

PostHog project 600792, production Procurement events, last-seven-days query
through partial 8 October UTC: 23 arrangement-start events, 17 completed
arrangement events, one arrangement-failure event, 18 completed dispatch events
and zero dispatch-failure events. These are event counts, not unique requests or
a conversion rate. They support preserving the working flow; they do not prove
satisfaction or identify the cause of repeat openings.

## Data and security

- Shared sourcing progress is a separate immutable, versioned operational
  projection. Costs, supplier free text and private editor buffers are excluded.
- Saving an update checks the actor, capability, active project, working
  arrangement, base versions, revision and every line. It performs no stock,
  reservation or workflow mutation. Warehouse readiness is checked against
  aggregate current availability; final completion checks again.
- Expected dates are planning information. External stock is ready only when
  explicitly confirmed. Scheduled completion enforces this on the server.
- Final preparation notification is informational for Engineers, distinct from
  Procurement's dispatch action; both use authorized durable notification paths.
- DO allocation is server-side, locked per project and idempotent. Existing
  references and document history remain unchanged. Concurrent new documents
  receive distinct numbers; existing historical collisions are skipped.

## Migration and rollback

Apply in order:

1. [Automatic delivery numbers](../../supabase/migrations/20261008185456_procurement_automatic_delivery_numbers.sql)
2. [Shared sourcing progress](../../supabase/migrations/20261008185725_procurement_shared_sourcing_progress.sql)

Both are additive, preserving history and identities. Client rollback uses the
preceding staging deployment. Retain additive preparation history and allocator
state; do not renumber documents, delete revisions or reverse stock movements.
Publish the matching send-push function catalogue for the informational event.

## Validation and release

- Full Flutter suite: 2,668 passed; four retained fixture skips.
- Full database reset and suite: 3,844 checks in 132 files passed before the
  final informational notification refinement; its final targeted gate is
  recorded with the release below.
- CI web startup budget and ephemeral CI APK compilation passed. The APK is
  build evidence, not a production-signed distribution.
- Final focused tests include desktop/360px editor and sharing previews, rejected
  updates, precise decimal quantities, source defaults, blank rows and recovery.
- Real two-connection tests cover DO allocation and sourcing/finalization races.
- Notification catalogue verification, 15 notification widget/domain tests and
  21 Edge payload tests passed in all configured languages.
- Physical printing, actual device push receipt, warehouse staff UAT and runtime
  checks against a large live catalogue remain review activities.


Final refinement gates: **192 database checks / 6 files**, both real concurrency
harnesses, **52 sourcing/scheduled tests**, **62 arrangement/mobile regressions**
and a clean full analyzer. Dart format: 21 changed files, zero changes needed.
Staging backend migrations: `20261008193902` automatic delivery numbers and
`20261008194515` shared sourcing progress. Direct anon/authenticated table reads
are denied; anonymous public-RPC execution and ordinary internal-helper execution
are denied. Security advisers have no ERROR findings; expected RPC-only/no-policy
notices and existing warnings remain ([adviser documentation](https://supabase.com/docs/guides/database/database-linter)).
