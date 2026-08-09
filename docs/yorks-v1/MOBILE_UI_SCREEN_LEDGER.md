# Yorks Mobile UI Screen Ledger

Status: **active implementation ledger**
Pack inventory: **52 references**
Reference viewport: **390×844 logical pixels**

This ledger prevents a visual reference from being mistaken for implemented
production behavior. “Verified” means the mobile production surface was
connected to existing functionality and accepted with evidence at the named
commit. “Deferred — no production surface” means the reference remains in the
pack but must not become reachable UI until its underlying product surface is
implemented and authorized.

Batch 1 verification commit: `3bb8d3b7259347fa07eefca16dc110d6d5a8cc76`
(`3bb8d3b`). Batch 2 evidence is tracked under
[`evidence/mobile-batch-02/`](evidence/mobile-batch-02/README.md). Batch 3
evidence is tracked under
[`evidence/mobile-batch-03/`](evidence/mobile-batch-03/README.md). Batch 4
evidence is tracked under
[`evidence/mobile-batch-04/`](evidence/mobile-batch-04/README.md). Batch 5
evidence is tracked under
[`evidence/mobile-batch-05/`](evidence/mobile-batch-05/README.md).

| Ref | Screen | Domain | Delivery slice | State | Evidence / production note |
|---:|---|---|---|---|---|
| 01 | Splash | Global | Batch 1 | Verified | Verified at `3bb8d3b`; branded launch only, no operational shortcut |
| 02 | Login | Global | Batch 1 | Verified | Verified at `3bb8d3b`; real Supabase Auth remains authoritative |
| 03 | Forgot Password | Global | Deferred | Deferred — no production surface | Do not add a decorative or disconnected recovery flow |
| 04 | Home Overview | Global | Batch 1 | Verified | Verified at `3bb8d3b`; role-aware production data/actions |
| 05 | Notifications | Global | Batch 1 | Verified | Verified at `3bb8d3b`; related-record navigation remains authorized |
| 06 | More Menu | Global | Batch 1 | Verified | Verified at `3bb8d3b`; only implemented destinations are exposed |
| 07 | Projects List | Projects | Batch 1 | Verified | Verified at `3bb8d3b`; lifecycle and access filters remain production-driven |
| 08 | Create Project — Details | Projects | Batch 1 | Verified | Verified at `3bb8d3b`; responsive dates are a production exception to clipping |
| 09 | Create Project — Parties & Access | Projects | Batch 1 | Verified | Verified at `3bb8d3b`; protected team directory and role rules retained |
| 10 | Create Project — Buildings | Projects | Batch 1 | Verified | Verified at `3bb8d3b`; Common and physical scopes remain independent |
| 11 | Create Project — Attachments | Projects | Batch 1 | Verified | Verified at `3bb8d3b`; optional upload remains tied to the real draft flow |
| 12 | Create Project — Review | Projects | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/12_project_create_review/deltas.md); final create remains server-authoritative |
| 13 | Project Overview | Projects | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/13_project_overview/deltas.md); loading/error remains distinct from zero; no weighted progress |
| 14 | Project Details & Team | Projects | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/14_project_details_team/deltas.md); membership history/global-role authority retained |
| 15 | BOQ Scope Overview | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/15_boq_scope_overview/deltas.md); Overview is summary-only; Common/buildings are real scopes |
| 16 | Building BOQ Folders | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/16_boq_building_folders/deltas.md); folder shells align without implicit row copying |
| 17 | BOQ Materials | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/17_boq_materials/deltas.md); dynamic/capability-safe compact list |
| 18 | Add / Edit Material | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/18_boq_material_editor/deltas.md); dynamic editor, conflict and dirty-exit handling retained |
| 19 | Excel Import — Upload | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/19_excel_import_upload/deltas.md); local reversible selection, no server mutation |
| 20 | Excel Import — Map Columns | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/20_excel_import_map/deltas.md); arbitrary mappings preserved and protected costs classified |
| 21 | Excel Import — Review | BOQ | Batch 2 | Verified | [Evidence](evidence/mobile-batch-02/21_excel_import_review/deltas.md); only final Import invokes the trusted command |
| 22 | Material Requests | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/22_material_request_register/deltas.md); authorized status-led register and create capability |
| 23 | New MR — Information | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/23_mr_information/deltas.md); scope-first private draft and production timing validation |
| 24 | MR — Add from BOQ | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/24_mr_add_from_boq/deltas.md); selected real scope only; Overview is never a source |
| 25 | MR — Custom Material | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/25_mr_custom_material/deltas.md); controller-backed unplanned item never mutates BOQ |
| 26 | MR — Review & Submit | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/26_mr_review_submit/deltas.md); explicit confirmation and connected server submit |
| 27 | MR Submitted | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/27_mr_submitted_success/deltas.md); success only after committed response |
| 28 | MR Detail Lifecycle | Material Requests | Batch 3 | Verified | [Evidence](evidence/mobile-batch-03/28_mr_detail_lifecycle/deltas.md); truthful state, owner and fail-closed action |
| 29 | Procurement Arrangement | Procurement | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/29_arrangement_list/deltas.md); real decision counts/lines and capability-safe save |
| 30 | Arrangement Line Detail | Procurement | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/30_arrangement_line/deltas.md); Full/Partial/Cannot Provide fields use the current command semantics |
| 31 | Arrangement Review | Procurement | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/31_arrangement_review/deltas.md); complete version/reservation command remains atomic |
| 32 | Project Engineer Approval | Approval | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/32_pe_approval/deltas.md); server capability only; no Procurement self-approval |
| 33 | Return to Procurement | Approval | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/33_return_to_procurement/deltas.md); required persisted reason and preserved history |
| 34 | Dispatch Entry | Logistics | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/34_dispatch_entry/deltas.md); server-capped approved outstanding and stock quantities |
| 35 | Receipt Review | Logistics | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/35_receipt_review/deltas.md); every line begins Pending and requires an explicit outcome |
| 36 | Receipt Exception | Logistics | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/36_receipt_exception/deltas.md); good quantity, required note and replacement eligibility |
| 37 | Delivery Order | Logistics | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/37_delivery_order/deltas.md); immutable committed-dispatch snapshot, never receipt-derived |
| 38 | New Material Return | Returns | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/38_material_return_new/deltas.md); only server-derived eligible good-received quantities |
| 39 | Material Return Review | Returns | Batch 4 | Verified | [Evidence](evidence/mobile-batch-04/39_material_return_review/deltas.md); draft/submit remain explicit and stock waits for Procurement confirmation |
| 40 | Documents | Documents | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); authorized classification, real link filters and immutable versions retained |
| 41 | Document Viewer | Documents | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); PDF bytes use the existing authorized reader; non-PDF files remain download-only |
| 42 | Accounts Overview | Accounts | Deferred | Deferred — no production surface | No Accounts navigation or sample commercial values until implemented |
| 43 | Billing Progress | Accounts | Deferred | Deferred — no production surface | Reference retained for future authorized Accounts work |
| 44 | Client Invoices | Accounts | Deferred | Deferred — no production surface | Reference retained; no disconnected invoice register |
| 45 | Client Invoice Detail | Accounts | Deferred | Deferred — no production surface | Reference retained; no fake certification/payment facts |
| 46 | Supplier Bills | Accounts | Deferred | Deferred — no production surface | Reference retained; no inferred Procurement finance authority |
| 47 | Supplier Bill Detail | Accounts | Deferred | Deferred — no production surface | Reference retained; no disconnected approval command |
| 48 | Duct Sizer | Tools | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); retained calculation and local persistence commands unchanged |
| 49 | ESP Calculator | Tools | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); retained row calculation and local persistence commands unchanged |
| 50 | Profile & Settings | System | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); only existing profile, preference, route and session controls are shown |
| 51 | Offline & Conflict State | System | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); real connectivity/outbox status and retry; record conflict reconciliation stays record-local |
| 52 | Empty States | System | Batch 5 | Verified | [Evidence](evidence/mobile-batch-05/README.md); Documents zero state exposes one real authorized action |

## Ledger rules

- A state changes from Planned/In progress to Verified only after the evidence
  set, focused tests and full applicable gate identify a commit.
- A reference with no production surface stays deferred even if its HTML is
  complete.
- Visual work does not authorize schema, RLS, RPC, workflow or permission
  changes.
- No weighted progress, fake statuses, invented activity or placeholder counts
  may be added for visual completeness.
- Dynamic and commercial-capability-safe field shapes always override static
  reference columns.
- Accounts references remain deferred until a separate product slice supplies
  real routes, repositories, server rules and acceptance tests.
