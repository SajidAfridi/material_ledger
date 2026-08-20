# Yorks R38.9 — Inventory Supplier Folders and Receipt Provenance

Status: **approved implementation scope**

Approved by the product owner on 20 August 2026. This contract extends the
single-warehouse R38.3 inventory workspace. It does not introduce RFQ,
quotation comparison, Purchase Orders, supplier portals, valuation/general
ledger, or multiple warehouses.

## Information architecture and access

- Suppliers remain nested at `Warehouse Inventory -> Suppliers`.
- Procurement and Admin may read and manage supplier identities, aliases,
  receipt batches, receipt evidence, documents and imports.
- Senior Mechanical Engineer retains the separately approved read-only
  Browse/Inventory projection and receives no supplier-folder, receipt,
  document or commercial payload.
- All other engineering roles are denied supplier routes, RPCs, tables,
  Storage objects and exports. UI hiding is not an authorization control.

## Unknown Supplier decision

Supplier identity is optional during this rollout. A blank, whitespace-only,
`Unknown` or `N/A` supplier value resolves to one protected system identity
named **Unknown Supplier**.

- The system identity has a stable ID and cannot be renamed, aliased,
  deactivated, merged or deleted.
- The original supplier cell remains preserved, including null/blank, and the
  resolution method is recorded as `unknown_missing`.
- Unknown external receipts remain grouped by reference, received date and
  warehouse location so unrelated receipts never coalesce.
- External Supplier rows still require a supplier reference/Delivery Note and
  Received Date. Opening Balance rows may omit those fields and remain clearly
  labelled Opening Balance; the server supplies a controlled batch reference
  and uses the operator-confirmed as-of date without fabricating an external
  delivery.
- This release keeps Unknown Supplier evidence report-only. It exposes the
  source-line count that still needs identity review, but does not silently
  reassign, merge or mutate historical receipt evidence. A future reassignment
  command would require a separately approved, version-checked and audited
  workflow; fuzzy matching can never perform that change.

## Import and quantity authority

The controlled import has five stages: Upload File, Map Columns, Review &
Validate, Supplier & Receipt, and Import Summary. Stages 1-4 are quantity
neutral. Only a successful trusted server commit can create suppliers,
receipt batches, receipt lines, movements or balances.

- Strict, all-or-nothing import is the default.
- Exact supplier names and approved aliases may auto-resolve. Similar names
  are suggestions only and require an explicit decision.
- Accepted quantity enters usable On Hand. Damaged quantity is quarantined.
  Rejected quantity creates receipt evidence but no stock.
- Delivered must equal Accepted + Damaged + Rejected.
- Every retry uses the same idempotency identity and authoritative stored
  result; clients never reconstruct a success from local state.
- Raw file fingerprint, source sheet/row, original values, cleaning decisions
  and exclusions are retained as audit evidence.

The import boundary does not bypass an existing operational workflow. Material
Return quantities still enter stock only through the confirmed Return command,
and Internal Transfer remains outside this single-warehouse release. Correction
and stock-removal inputs must use the separately authorized inventory-adjustment
path until an equally strong import command is approved. A workbook carrying
those source/action values is blocked in Review with no write; it is never
silently rewritten into an external receipt.

## Workbook safety

The pack's 1,240-row Opening Balance workbook and the separately supplied
`Yorks_Warehouse_Inventory_Master_Import_PERFECT (1).xlsx` are not equivalent
and must never both be committed. The latter includes reconciliation and
quarantine evidence and is the preferred migration candidate only after its
20-column schema, categories and units are explicitly mapped to the controlled
22-column R38.9 contract.

No production opening balance is authorized by this UI implementation. A
signed inventory cutoff, staging rehearsal, duplicate-fingerprint check and
the reconciliation equation `source = committed + quarantine/exclusions` are
required before production stock activation.

An Opening Balance import requires an explicit as-of date. The server claims
that cutoff as part of the atomic import result so a second opening-balance
workbook for the same cutoff cannot be committed as an ordinary retry or an
alternative master file. Legacy workbooks without a Source Type can be treated
as Opening Balance only through an explicit mapping decision; the application
must never infer that decision from a file name.

## Release control

`YORKS_R38_9_INVENTORY_SUPPLIERS` is the client rollout flag. Its effective
value also requires the complete controlled-document chain, so supplier
folders cannot appear without private receipt-evidence storage. The canonical
`tool/r35.sh` launcher enables the accepted R38.9 slice for local, CI and
release builds; ad-hoc Flutter commands are not a supported release path.

Deploying the application and migration does **not** authorize or automatically
run either supplied stock workbook. Production import remains a separate,
explicit Procurement/Admin action after staging reconciliation and cutoff
approval.

## Rollback and preservation

R38.9 schema changes are additive. Rollback revokes new grants and redeploys
the prior approved application while retaining supplier, alias, receipt,
import, document and audit records. A committed physical quantity is reversed
only through an authorized compensating movement, never by deleting provenance
or copying a stale balance.
