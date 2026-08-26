# Yorks V1 R35 — Source of Truth and Re-baseline

Status: approved on 1 August 2026.

Product-owner change approval on 7 August 2026 adds the exact Senior Mechanical
Engineer and Project Manager roles as organization-wide Project Engineers and
makes the Delivery Order available from committed dispatch rather than waiting
for receipt review. It also approves the controlled-document legal identity,
contact footer, building number and job/contract-prefixed project name recorded
in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).

The approved R38 building-specific BOQ rule adds independent Common and
per-building worksheets. Its Overview option is read-only; it is never a
persisted scope or cross-building write/MR source. The data-preserving details
and reconciliation rule are recorded in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).

Product-owner change approval on 8 August 2026 makes BOQ folder names a
project-wide structural definition: creating a custom folder makes an empty
folder with the same name available in Common and every active building, while
rows, columns, quantities, imports, exports and MR sources remain independent
per real scope. Legacy rows are never cloned or inferred by this rule.

Product-owner change approval on 9 August 2026 grants the exact Senior
Mechanical Engineer role access to the audited User Management surface and its
protected commands. Project Manager and other engineering roles remain denied;
this grant does not provide direct commercial visibility or unrelated Admin
modules.

Product-owner change approval on 15 August 2026 adds the exact Workshop
In-Charge and Document Controller roles with the same organization-wide
Project Engineer workflow authority as Project Manager. Their distinct job
titles remain authoritative for display, controlled documents and audit.
Senior Mechanical Engineer also gains the non-commercial Browse/Inventory read
surface; every stock, category and import mutation remains limited to
Procurement/Admin.

Product-owner change approval on 23 August 2026 replaces the 29-folder BOQ
seed catalogue with one universal **Workshop Materials** folder in every new
Common/building scope. Existing BOQ history is retained: legacy template
folders with rows, columns, documents or Material Request sources stay visible,
while untouched inactive template shells are suppressed. BOQ import remains an
atomic full-snapshot replacement and must allow a revised column/row structure
after prior rows or columns were removed without reusing archived coordinates.

Product-owner change approval on 24 August 2026 adds person-specific scoped
capability administration inside User Management. The then-current eight roles remain
server-controlled job identities and baseline templates. The first deployment
must reproduce every user's current effective access, keep existing protected
workflow checks authoritative during shadow parity, and cut over one tested
server consumer at a time. Explicit grants and denies never bypass project
scope, workflow state, quantity rules, separation of duties, commercial
response shaping or immutable audit. The complete contract is
[`SCOPED_CAPABILITY_MANAGEMENT.md`](SCOPED_CAPABILITY_MANAGEMENT.md).

Product-owner approval on 25 August 2026 adds the phased R39 Accounts module
and the ninth exact `accountant` platform role. This later Accounts-only source
supersedes prior statements that Accounts is deferred, absent or permanently
unreachable. It does not supersede any non-Accounts workflow or grant
Accountant technical project membership. The T01 foundation is additive and
shadow-only, `YORKS_V1_ACCOUNTS` defaults off, and later T02–T07 surfaces cut
over only after their individual and complete acceptance gates. The normalized
Accounts authority is defined by
[`R39_ACCOUNTS_FOUNDATION.md`](R39_ACCOUNTS_FOUNDATION.md); legacy
`/admin/finance` remains non-authoritative.

## Approved source artifacts

The original review artifacts remain outside the repository. Their SHA-256
fingerprints establish exactly which versions were approved:

| Artifact | Purpose | SHA-256 |
|---|---|---|
| `Yorks_V1_SRS_and_Rapid_Development_Plan_Rev2_0.docx` | Authoritative product, workflow, data, security and acceptance baseline | `b9bd71e5474c5f09391764a294a094fc0565e1ca2d2a2d4a3ebd3fc0ffc0293d` |
| `Yorks_AC_Ref_V1_Procurement_Control_R35_Final.html` | Effective final R35 visual and interaction reference | `420436288da54dce8e3e6dc35f4c43e9e7524738d3381050a641f2912818c75c` |
| `Yorks_V1_SOL_AI_Execution_Pack.md` | Task prompts, sequencing and completion discipline | `02a25c24197ff5b0f9729aab96a0c16b1f469a1938e0f6aa966bce3f73737067` |
| `01_Yorks_Accounts_Requirements_Specification_R39.md` | Approved Accounts-only functional, non-functional, UI and acceptance authority | `31ce5163afc1aae34086560012c25471080c6ea86b7af2f623a28c2c617c514d` |
| `07_AI_Implementation_Prompt.md` (R39 package) | Accounts T00–T07 sequencing and implementation discipline | `efc142ddd5abe7eea6cb03a90e749c950b3ca2779057f7f1fc282b9294e31a3f` |
| `08_Decisions_Assumptions_and_NonRegression.md` (R39 package) | Frozen Accounts defaults and non-regression boundary | `ea25b3dcfca7411682ceb524f395ac746f3b3530660a7a474148672f50970df9` |

If a source artifact changes hash, stop and treat it as a new product input.
Do not silently replace this baseline.

## Approved precedence

1. Rev 2.0 governs overlapping behavior, roles, scope, state, invariants and
   acceptance.
2. Effective final R35 governs visual layout and interaction where Rev 2.0 and
   security/accessibility rules do not override it.
3. The Execution Pack governs work sequencing, with dependency corrections in
   [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md).
4. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) supplies least-privilege,
   data-preserving resolutions where the approved artifacts are silent.
5. Existing V7 behavior is not carried forward merely because it is already
   implemented.
6. For Accounts-only conflicts, the approved 25 August 2026 R39 package and
   [`R39_ACCOUNTS_FOUNDATION.md`](R39_ACCOUNTS_FOUNDATION.md) supersede older
   deferred/unreachable statements. They do not alter unrelated V1 authority.

## Confirmed implementation direction

On 1 August 2026, the product owner reconfirmed that implementation follows
the Rev 2.0 SRS flows and the effective R35 HTML interaction/UI model. Legacy
V1/V7 behavior is a reuse and regression boundary only: where it conflicts
with those approved sources, replace or isolate it instead of preserving it for
backward visual or workflow compatibility.

## Explicitly superseded V7 decisions

| Topic | Historical Nexus V7 | Yorks V1 R35 decision |
|---|---|---|
| Core planning structure | Phase 1 Material Plan and Phase 2 request | Dynamic BOQ groups/rows followed by an explicit MR draft and Submit |
| Reservation timing | Phase 1 advisory; separate Phase 2 allocation | Procurement arrangement creates/replaces warehouse reservations |
| Project/platform roles | Generic Engineer plus Procurement/Admin | Project Engineer, Site Engineer, Senior Mechanical Engineer, Project Manager, Workshop In-Charge, Document Controller, Procurement, Accountant and Admin; Accountant is not technical project membership |
| Project wizard | Three stages | Effective R35 five stages |
| Procurement scope | Package, RFQ, quotations and PO | Direct line arrangement, approval, dispatch and receipt; full RFQ/PO deferred |
| Inventory | V7 multi-source/multi-warehouse direction | One warehouse in V1 |
| Project lifecycle | Draft/Planning/Active/Archived | Draft/Active/On Hold/Completed/Archived |
| MR lifecycle | Sourcing/order-oriented V7 states | Engineering request approval before Procurement arrangement, then Approved/Dispatch/Receipt/Closed states; recorded legacy post-arrangement approvals remain resolvable |
| Request exception path | Plan/over-plan/substitution approval distinction | BOQ/import/custom MR rows use one arrangement/approval path |
| MR delivery fields | Required-on-site date and explicit destination | Project plus Building/Common scope and Urgent/Normal/Scheduled; Scheduled requires a date |
| Standard rows | One frozen ten-column material grid | Dynamic BOQ worksheet; seven-column controlled MR output |
| BOQ ownership | One combined editable project plan | Independent Common/building BOQs; Overview is read-only summary only |
| Material events | Supplier/warehouse/site directions modeled separately | Dispatch plus site receipt review in V1; supplier-receipt/PO suite deferred |
| Accounts | Outside V7 transformation but existing routes could remain | R39 normalized project commercial control rolls out through T01–T07 behind a default-off flag; legacy Finance is never authority |

### R38.3 smart warehouse client review pack

The 9 August 2026 client review pack is the approved visual and interaction
reference for the existing single-warehouse V1 capability. It adds normalized
warehouse categories and aliases, item codes, minimum-stock attention levels,
locations/bins, an exact five-sheet import template, reviewed Excel/CSV import
and responsive Overview/Items/Stock Movements/Reservations surfaces. It does
not add multiple warehouses, valuation, purchase orders or incoming-stock
authority. Exact name/alias matches may map automatically; fuzzy matches are
suggestions only and require Procurement/Admin confirmation.

### R38.9 inventory supplier folders client review pack

The 20 August 2026 product-owner instruction approves supplier receipt folders
as a controlled extension of the existing single-warehouse inventory workspace.
The reviewed R38.9 pack defines the responsive hierarchy, five-stage import,
supplier directory/folders and provenance presentation. Repository security,
transaction, migration, bilingual-copy and accessibility rules remain higher
authority than the standalone HTML prototype.

Supplier identity is optional for this rollout. Missing supplier values resolve
to one protected system `Unknown Supplier` folder and remain visible warnings;
they are not blockers and never create one supplier per row. External receipts
still require reference and received date. Opening Balance evidence remains
distinct and cannot be silently reclassified as an external supplier receipt.
The complete frozen behavior is in
[`R38_9_INVENTORY_SUPPLIER_FOLDERS.md`](R38_9_INVENTORY_SUPPLIER_FOLDERS.md).

## V7 safeguards that remain mandatory

- Supabase Auth/Postgres are authoritative; Firebase is FCM transport only.
- Release configuration fails closed.
- Privileged roles come only from server-controlled `app_metadata`.
- UI hiding never substitutes for RLS or trusted RPC authorization.
- Commercial fields are absent from unauthorized responses, caches and exports.
- Critical transitions are transactional, idempotent and server-audited.
- Existing JSON keeps decoding; unknown or invalid legacy data is quarantined,
  never silently discarded.
- IDs, timestamps, attribution and `authorityRef` meaning are preserved.
- Mobile targets are at least 44x44; desktop grids are keyboard operable;
  mobile material editing uses a focused row editor.
- User-facing strings remain centralized and bilingual-capable.
- Rentals, People/HR, Leave, authentication, sync and Inventory history are
  protected from unrelated redesign/regression.

## Prototype interpretation

The R35 HTML is an accretive localStorage proof-of-concept with older R24–R34
implementations still present underneath final overrides. Only the effective
final routes and presentation are an oracle. Hidden/dead RFQ, PO, Material
Plan, older status paths and the prototype's legacy Accounts implementation are
not requirements. Accounts requirements come only from the approved R39
package and the repository-local R39 foundation contract.

Production Flutter must reproduce the approved intent while replacing:

- client-side authentication and authorization with Supabase Auth/RLS;
- localStorage transitions with trusted RPCs;
- implicit reservations with normalized locked records;
- client-generated audit with server-generated append-only events;
- hardcoded English with centralized localized strings;
- horizontally shrunk mobile worksheets with a focused row editor;
- undersized controls and incomplete keyboard behavior with accessible widgets.

## Approved Material Request flow revision — 13 August 2026

The product owner approved a forward-only revision for new Material Requests:

1. a submitted request is editable by its creator and authorized Project
   Engineers until Engineering approval;
2. Engineering approves the request before Procurement can arrange it;
3. normalized request comments, authorized mentions and mention notifications
   are available from the first server-backed request stage;
4. Engineering item entry may search a deliberately non-commercial inventory
   projection and copy descriptive fields into a request row;
5. assigned Project/Site Engineers and organization-wide Senior Mechanical
   Engineers/Project Managers can read every authorized server-backed stage and
   discussion without inheriting Procurement, stock or commercial authority;
6. MR status, owner and next action are explicit; and
7. confirmed receipt reviews may have authorized site photographs linked
   through the controlled document pipeline.

The same product-owner revision also permits an actively assigned Site
Engineer to close a fully resolved `received` request through the trusted
command. Tablet and mobile request projections re-fetch when the app returns
to the foreground and use a low-frequency authorized safety refresh in
addition to Realtime; the current projection stays visible during refresh.

Product-owner Phase 1-3 approval on 21 August 2026 keeps independently
authorized non-Site-Engineer creator self-approval enabled during adoption,
keeps external-source readiness advisory until Admin publishes enforcement,
and keeps all-unavailable requests editable by Procurement until Engineering
explicitly cancels them. Phase 3 implements both policies as protected
published Configuration values and adds a one-time linked replacement Draft
only after that terminal cancellation. It does not reopen the source, grant
Procurement Engineering authority or fabricate downstream workflow history.

The detailed transition, migration and rollback contract is
`MATERIAL_REQUEST_FLOW_REVISION_2026-08-13.md`. Existing in-flight Procurement
arrangements are not rewritten or given synthetic request approvals.

## Change control

Any later requirement that changes a frozen decision must update, in one
coherent review:

1. this authority record;
2. `PRODUCT_DECISIONS.md`;
3. affected state/RPC/RLS and migration documents;
4. the acceptance scenario(s);
5. `AGENTS.md` if the repository-wide rule changes.

Never amend only a UI label or enum when the underlying transaction semantics
also change.
