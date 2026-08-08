# Yorks V1 R35 — Test and Acceptance Plan

## 1. Test layers

| Layer | Required proof |
|---|---|
| Dart unit | State derivation, decimal input normalization, canonical column mapping, reference formatting, role/capability resolution |
| Repository/controller | Draft recovery, typed RPC payload/result, connectivity, idempotent retry, conflict/error handling, notification refresh |
| Flutter widget | Four-role navigation, action visibility, forms, dynamic grid, keyboard behavior, focused mobile editor, localization and responsive layouts |
| Database/pgTAP | Constraints, RLS, RPC authority, locks, state transitions, audit attribution, protected commercial projections |
| Concurrency/integration | Competing reservations/dispatches, duplicate commands, membership revocation and six-role end-to-end flow |
| Visual/manual | Effective R35 parity, Android/web layouts, Excel round-trip, PDF/print short/multi-page output |

No screen-level success substitutes for a direct database negative test.

## 2. Golden acceptance scenarios

These are the 25 Rev 2.0 scenarios, preserved as stable IDs.

| ID | Scenario | Primary automated/manual evidence |
|---|---|---|
| AT-01 | Site Engineer creates a project, assigns a Project Engineer and multiple buildings; Procurement cannot create/edit it. | RPC/RLS/route/widget/integration |
| AT-02 | New project receives 29 independent default BOQ groups for Common and each physical building; a custom group belongs to one selected scope. | database/repository/widget |
| AT-03 | MSD worksheet imports title, seven columns and all rows into the direct-edit grid. | workbook fixture/integration |
| AT-04 | User edits/deletes a cell, row and non-protected column; export reproduces the changed worksheet. | controller/workbook round-trip |
| AT-05 | Similar Row inserts directly below and preserves configured fields with sequential S:No. | unit/widget |
| AT-06 | Whole BOQ group creates an MR draft but Procurement sees nothing until explicit Submit. | RLS/repository/integration |
| AT-07 | Engineer selects individual BOQ and custom items only from the matching Common/building scope and submits a Scheduled MR. | widget/RPC/integration |
| AT-08 | MR number is unique and project/requester/header data is automatic. | database concurrency/integration |
| AT-09 | Procurement arrangement defaults Warehouse, changes one line to supplier, partially supplies one and marks one unavailable with reason. | repository/widget/RPC |
| AT-10 | Database rejects arrangement above requested and prevents double reservation. | constraint/concurrency pgTAP |
| AT-11 | Project Engineer sees crossed unavailable line, partial line and source before approval. | widget/golden/integration |
| AT-12 | Procurement cannot approve its own arrangement or dispatch before approval. | RPC/RLS negative/integration |
| AT-13 | Dispatch cannot exceed approved outstanding quantity or warehouse availability. | RPC/concurrency |
| AT-14 | Engineer marks one line Received, one Missing and one Damaged; MR remains partially received. | controller/RPC/integration |
| AT-15 | Replacement dispatch is possible only for outstanding quantity and cannot over-supply. | RPC/concurrency |
| AT-16 | When all approved quantity is good received, MR becomes Received and dispatch action disappears. | state unit/RPC/widget |
| AT-17 | DO reference is entered at dispatch stage, dispatched quantities are immutable and PDF/print identity/footer is correct. | RPC/snapshot/PDF visual |
| AT-18 | Return autocomplete shows only eligible good-received items for the selected project/scope. | query/controller/widget |
| AT-19 | Return over eligible quantity is blocked; Procurement confirmation adds inventory once. | RPC/idempotency/concurrency |
| AT-20 | MR/Return/DO short and multi-page PDFs have no overlap; print opens content, not a blank tab. | render/visual/manual browser |
| AT-21 | Project Engineer removes Site Engineer access; old requests retain the original requester. | membership RLS/integration |
| AT-22 | MR deletion/cancel rules are enforced by state and role. | RPC/RLS matrix |
| AT-23 | Admin Configuration, Rentals, Users and Audit still load and operate. | regression/widget/smoke |
| AT-24 | Duct Sizer and ESP Calculator remain available. | widget/smoke |
| AT-25 | RLS negatives prove Procurement cannot mutate project/BOQ, unrelated assigned-role Engineers cannot access another project, and global Engineer roles receive no commercial/inventory/Admin authority. | six-role pgTAP/API |

The BOQ **All** option is a read-only overview, not the Common scope and not a
persisted scope. Common is its own real BOQ. Database coverage proves per-scope
29-folder creation, All aggregation, custom-folder isolation, Procurement
write denial, legacy assignment idempotency and save/submit MR scope negatives.

## 3. Additional production gates

Rev 2.0 is browser-first but the approved delivery target also includes
Android. Add:

- AP-01: release merged Android manifest declares Internet permission.
- AP-02: production publishing fails when the controlled signing configuration
  is absent; CI uses a clearly separate ephemeral certificate.
- AP-03: project creation, MR create/submit, approval, receipt and return pass on
  a 360px Android emulator/device with keyboard and safe-area changes.
- AP-04: file picker, XLSX import/export, document upload/download and PDF share
  work on Android and web.
- AP-05: offline/reconnect and ambiguous-network retries show Pending/Failed and
  commit critical effects at most once.
- AP-06: web PWA has no portrait-only lock and the BOQ workspace is usable at
  1366x768.
- AP-07: unauthorized commercial values are absent from API JSON, Riverpod
  state, SharedPreferences, export bytes, PDF bytes and notifications.
- AP-08: direct/stale legacy deep links cannot reach Accounts, RFQ/PO, Material
  Plan or contradictory procurement actions.

## 4. Four-role security matrix

Every RLS/RPC change supplies positive and negative cases using representative
Project Engineer, Site Engineer, Senior Mechanical Engineer, Project Manager,
Procurement and Admin JWT claims. Global Engineer tests must prove all-project
MR approval/DO generation and negative commercial, inventory and Admin access.

Required adversarial techniques:

- direct table select/insert/update/delete;
- direct RPC call without using the Flutter screen;
- guessed project/entity/document IDs;
- unrelated and revoked membership;
- stale version and wrong state;
- caller-provided actor/role/timestamp spoof;
- stale JWT whose exact role no longer matches the protected Auth role,
  including a global-engineer-to-project-engineer demotion;
- missing/revoked commercial capability;
- Storage path/object guessing;
- repeated idempotency key with same and different payload;
- two sessions racing reservation, dispatch or return confirmation.

Tests assert both the denial and absence of partial rows/movements/audit side
effects.

## 5. Quantity and concurrency suites

Test boundary values with Postgres numeric precision:

- zero, fractional and maximum configured decimal scale;
- partial/full/unavailable arrangement;
- aggregate reservations equal/one increment above availability;
- dispatch equal/above approved outstanding and available stock;
- partial receipt followed by replacement in transit;
- good plus missing/damaged reconciliation;
- two MRs for the final available stock;
- repeated dispatch after timeout;
- concurrent return submissions for the same remaining eligible quantity;
- confirmed return retry and inventory movement uniqueness.

The result must reconcile root state, line facts, reservations, movements,
notifications and audit events.

## 6. Excel evidence

BOQ fixtures include:

- representative MSD Equipment Schedule with optional title/header rows;
- header-only workbook;
- arbitrary extra technical columns;
- duplicate/blank headings;
- mixed numeric/text quantity cells;
- long/unicode/Arabic values;
- malformed/unsupported workbook.

Prove worksheet selection, mapping preview, explicit transactional commit and
visible title/headings/row export. A failed import creates no partial schema or
rows. Import never submits an MR.

MR and Return workbook tests use their controlled canonical columns and exclude
project metadata that the application supplies.

Only licensed/sanitized fixtures are committed to the repository.

## 7. PDF and print evidence

Render and visually inspect:

- short and multi-page MR, authorized and non-commercial projections;
- long project/client/requester names;
- Arabic/English company header and logo;
- final-page-only approvals/signatures/footer;
- DO with only good quantities and multiple pages;
- Return with four signature roles and multiple pages;
- Chrome and Edge print flow with visible content/no blank tab;
- Android view/share of generated PDFs.

PDF and print use the same domain snapshot/template. Snapshot hash/reference is
asserted so later master edits cannot alter historical output.

## 8. Responsive/accessibility evidence

For each UI batch test:

- 1366x768 desktop web;
- representative tablet width;
- 360px mobile and Android emulator/device;
- text scaling and English/secondary-language copy;
- 44x44 tap targets;
- keyboard traversal/focus visibility on desktop;
- non-color status cues and semantic labels;
- loading, empty, forbidden, offline, conflict and error states;
- no overflow, covered action or unreachable control.

BOQ specifically tests 500 rows, virtualized focus, sticky identity/header,
Tab/Shift+Tab/arrows/Enter and mobile focused-row Previous/Next behavior.

## 9. Per-batch gate

Every implementation batch requires:

1. narrow unit/repository/widget/database tests for changed behavior;
2. positive and negative role tests for changed access;
3. migration idempotency and rollback notes;
4. UI evidence for changed screens;
5. `flutter pub get`;
6. formatting of changed Dart files;
7. `flutter analyze`;
8. complete `flutter test`;
9. release web build with CI Supabase placeholders;
10. release Android build with CI Supabase placeholders;
11. clean `supabase db reset` and `supabase test db` from Batch 1 onward;
12. `git diff --check` and no unrelated worktree changes.

Never waive a failed security/quantity test to meet the rapid-demo timebox.

## 10. Release evidence package

Batch 10 produces:

- scenario result matrix for AT-01–AT-25 and AP-01–AP-08;
- Flutter/database/concurrency/integration command logs;
- desktop/mobile screenshots and controlled-document renders;
- workbook round-trip fixtures/results;
- migration/reconciliation counts and quarantine report;
- staging seed/persona instructions;
- release notes, known limitations and operations/cutover runbook;
- signed artifact provenance without exposing secrets.
