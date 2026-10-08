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

## Follow-up: requested defaults and familiar table presentation

The owner's 9 October review supersedes the initial blank-fresh-row default:

- New editable rows propose the requested quantity automatically. Procurement
  can reduce it, enter zero or clear it; Full/Partial/Cannot Provide Now remains
  derived, and invalid/blank quantities still cannot complete the arrangement.
- Account/device progress and existing saved quantities take precedence, including
  intentionally blank, incomplete and zero input. Server projection decoding does
  not fabricate committed quantities.
- The desktop table uses aligned headings/controls and plain row backgrounds.
  Optional availability stays in the source column, and shortage reasons stay
  beside Arranged. Timing and Request Information share one header row. Sticky
  header/first-column behavior and the focused mobile editor remain.
- Selected warehouse availability and shelf/bin are rendered outside the input's
  small helper text. A missing catalogue location explicitly says Shelf / bin
  not set; selecting another item removes the old shelf information.
- This follow-up changes presentation/defaults only. Existing source selection,
  scheduled preparation, notifications, numbering, permission and transactional
  behavior remain; no new migration or remote database mutation is required.

Regression coverage includes requested defaults, derived quantities, saved raw
input restoration, shelf selection/missing-location behavior, protected cost
omission, desktop/mobile layouts and Scheduled sharing. Release evidence for
this follow-up is appended below after verification.

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

## Staging deployment and browser evidence

- Deployed source: `58effca` (9 October 2026).
- Review alias: <https://yorks-r35-staging.vercel.app>.
- Immutable preview: <https://yorks-r35-mx1nma2f1-sajid-alis-projects-0ec775a2.vercel.app>.
- Deployment ID: `dpl_8worXrmaJt66v7Y7Gy5HMbRkAvLg`.
- Isolated Flutter artifact contained 63 files. The main bundle is 9,949,651
  bytes, startup-budget gzip 2,864,745 bytes, within the unchanged 2,900,000-byte
  budget. SHA-256:
  `9dcc67450b58f75a86a2d9bd4f2d4b7ae0604c14be4e90afaaa7d6bdfe4474da`.
- All 28 route/asset checks passed against both the preview and staging alias.
  Compiled JavaScript contains the staging backend, with no production or CI
  backend reference.
- The matching `send-push` function was deployed only to staging project
  `iqltcyimlqtcwyzlemwx`; retrieved deployed source contains the new
  `arrangement_preparation_completed` event. Actual device push delivery remains
  unverified.
- Live staging verification used the existing Procurement session. MR005 opened
  with blank quantities and External Supplier selected for unmatched items.
  Entering 20 against 87 Meter showed Partial and its reason field; restoring the
  blank value returned Enter quantity. No final arrangement, stock, dispatch or
  document command was submitted during browser verification.
- At 360×800, the same request displayed a card list and focused one-item editor
  with External Supplier selected and Next item navigation. The temporary
  viewport override was reset afterwards. Captured browser error logs were empty.
- Existing MR006 Delivery Order revision 2 opened without requiring reference
  entry. The dialog was closed without creating a revision.
- Live screenshots: `/tmp/yorks-procurement-simplification-evidence/staging-desktop.png`
  and `/tmp/yorks-procurement-simplification-evidence/staging-mobile.png`.
  Scheduled sharing and automatic new-number allocation have widget/database
  and concurrency evidence; this browser session did not create a synthetic
  Scheduled request or dispatch for live end-to-end UAT.
- Production remained on `dpl_BzugN8M8Wawfa2rUU2zhdWLN9EC1`, verified before and
  after staging release. No production database, function or alias was changed.
- Staging client rollback target: `dpl_6HpsAjCpbszRbwuVs8TMuPnW5UeS`,
  <https://yorks-r35-cb6okkxb3-sajid-alis-projects-0ec775a2.vercel.app>.

Local release evidence is in `/tmp/procurement-simplification-candidate-verify.log`,
`/tmp/procurement-simplification-alias-verify.log`,
`/tmp/procurement-simplification-staging-deploy.log`,
`/tmp/procurement-simplification-staging-edge-deploy.log` and the focused/full gate
logs recorded during this task. These temporary files are local review evidence,
not durable hosted artifacts.

### Follow-up validation

- Full Flutter suite: **2,690 passed**, four retained fixture skips.
- Full clean local database reset/suite: **3,853 checks in 132 files passed**.
- Full analyzer clean; six changed Dart files passed formatting and diff checks.
- Desktop, 360px and 390px arrangement goldens were refreshed and inspected for
  the approved presentation changes. Initial suite failures were the six expected
  old mobile images; the final full suite passed after updating those images.
- A focused pointer/geometry regression verifies aligned headings, frozen item
  identity, and blocked interaction with source controls behind the pinned column.
- CI web startup budget and ephemeral-signed APK compilation passed. The native
  artifact is CI build evidence, not a production-signed release.
- No remote database or function change is part of this follow-up.
