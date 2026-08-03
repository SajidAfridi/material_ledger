# Yorks AC. & Ref. V1 R35 — Batch 8 Completion

> **HISTORICAL BATCH EVIDENCE — NOT CURRENT BUILD CONFIGURATION.** Read the
> canonical build section in `README.md` and `TERRA.md` for current defaults.

Status: **passed** on 2 August 2026.

## Delivered

> **CURRENT-AUTHORITY ERRATUM — 4 August 2026.** The historical delivery note
> below predates the approved post-receipt receiver action. The current R35
> contract in `PRODUCT_DECISIONS.md` and `STATE_RPC_RLS_MATRIX.md` allows an
> assigned Project/Site Engineer to generate the immutable Delivery Order only
> after receipt review. It does not broaden stock, arrangement or return
> confirmation authority.

- A protected Delivery Order model with one current revision pointer per
  dispatch and append-only revision/line snapshots. An assigned receiving
  Engineer, Procurement or Admin can create a DO only after receipt review;
  every snapshot contains only good received quantity and exactly `S:No`,
  `Item Description`, `Qty` and `Unit`.
- A protected material-return state machine:
  `draft -> submitted -> confirmed | rejected`. Return eligibility is derived
  from receipt good quantity minus earlier confirmed returns, with no client
  stock calculation authority.
- Return submission freezes its project, scope, receipt/dispatch/request links
  and line snapshots. Procurement/Admin confirmation requires external-source
  material to map to an existing active inventory item or create a controlled
  new item. Confirmation appends each stock movement exactly once; rejection
  requires a reason and never changes stock.
- Default-off `YORKS_V1_RETURNS_DOCUMENTS` routing, role-safe repository and
  responsive Yorks screen. Desktop shows spreadsheet-like four-column Delivery
  Orders; mobile return editing uses a focused row editor. The Material Request
  detail links to the new workspace only when the flag is enabled.
- Cost-free DO and return Excel/PDF/print services. The document data types do
  not contain commercial values, so output cannot reconstruct them locally.

## Migration and rollback

`20260802050000_yorks_v1_batch8_delivery_orders_returns.sql` is additive and
idempotent. It retains all dispatch, receipt, inventory and audit history.
Disable the default-off `returnsDocuments` flag to remove the routes and UI;
do not delete an issued DO, return, stock movement or audit event. Correct an
operational error through a new DO revision, a return rejection or an audited
compensating stock event.

## Verification

- Batch 8 pgTAP has positive and negative proofs for RLS/direct-write denial,
  no pre-review DO, reference normalization, retry-safe immutable revisions,
  good-quantity-only DO rows, return caps, authority separation, supplier item
  mapping, idempotent stock posting and rejection without stock movement.
- Responsive widget coverage verifies the 360px focused mobile return editor.
- Document service tests verify the exact four Delivery Order Excel columns and
  a generated printable PDF snapshot.

## Known limitation

The local offline-demo login rejected the deterministic seeded Procurement
persona during visual smoke testing. This is outside the Batch 8 server/RPC
path and does not affect the local Supabase migration or pgTAP workflow proof.
The Batch 8 screen is still default-off and fully covered by responsive widget
and document tests; an authenticated local/staging Supabase walkthrough should
be repeated before pilot rollout.
