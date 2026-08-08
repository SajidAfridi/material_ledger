# Yorks V1 R35 — Source of Truth and Re-baseline

Status: approved on 1 August 2026.

Product-owner change approval on 7 August 2026 adds the exact Senior Mechanical
Engineer and Project Manager roles as organization-wide Project Engineers and
makes the Delivery Order available from committed dispatch rather than waiting
for receipt review. It also approves the controlled-document legal identity,
contact footer, building number and job/contract-prefixed project name recorded
in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).

The approved R38 building-specific BOQ rule adds independent Common and
per-building worksheets. Its All option is a read-only overview; it is never a
persisted scope or cross-building write/MR source. The data-preserving details
and reconciliation rule are recorded in [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md).

## Approved source artifacts

The original review artifacts remain outside the repository. Their SHA-256
fingerprints establish exactly which versions were approved:

| Artifact | Purpose | SHA-256 |
|---|---|---|
| `Yorks_V1_SRS_and_Rapid_Development_Plan_Rev2_0.docx` | Authoritative product, workflow, data, security and acceptance baseline | `b9bd71e5474c5f09391764a294a094fc0565e1ca2d2a2d4a3ebd3fc0ffc0293d` |
| `Yorks_AC_Ref_V1_Procurement_Control_R35_Final.html` | Effective final R35 visual and interaction reference | `420436288da54dce8e3e6dc35f4c43e9e7524738d3381050a641f2912818c75c` |
| `Yorks_V1_SOL_AI_Execution_Pack.md` | Task prompts, sequencing and completion discipline | `02a25c24197ff5b0f9729aab96a0c16b1f469a1938e0f6aa966bce3f73737067` |

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
| Project roles | Generic Engineer plus Procurement/Admin | Project Engineer, Site Engineer, Senior Mechanical Engineer, Project Manager, Procurement and Admin |
| Project wizard | Three stages | Effective R35 five stages |
| Procurement scope | Package, RFQ, quotations and PO | Direct line arrangement, approval, dispatch and receipt; full RFQ/PO deferred |
| Inventory | V7 multi-source/multi-warehouse direction | One warehouse in V1 |
| Project lifecycle | Draft/Planning/Active/Archived | Draft/Active/On Hold/Completed/Archived |
| MR lifecycle | Sourcing/order-oriented V7 states | Submitted/Arranging/Awaiting Approval/Approved/Dispatch/Receipt/Closed states |
| Request exception path | Plan/over-plan/substitution approval distinction | BOQ/import/custom MR rows use one arrangement/approval path |
| MR delivery fields | Required-on-site date and explicit destination | Project plus Building/Common scope and Urgent/Normal/Scheduled; Scheduled requires a date |
| Standard rows | One frozen ten-column material grid | Dynamic BOQ worksheet; seven-column controlled MR output |
| BOQ ownership | One combined editable project plan | Independent Common/building BOQs; All is read-only overview only |
| Material events | Supplier/warehouse/site directions modeled separately | Dispatch plus site receipt review in V1; supplier-receipt/PO suite deferred |
| Accounts | Outside V7 transformation but existing routes could remain | Explicitly unavailable in the V1 experience |

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
final routes and presentation are an oracle. Hidden/dead RFQ, PO, Accounts,
Material Plan and older status paths are not requirements.

Production Flutter must reproduce the approved intent while replacing:

- client-side authentication and authorization with Supabase Auth/RLS;
- localStorage transitions with trusted RPCs;
- implicit reservations with normalized locked records;
- client-generated audit with server-generated append-only events;
- hardcoded English with centralized localized strings;
- horizontally shrunk mobile worksheets with a focused row editor;
- undersized controls and incomplete keyboard behavior with accessible widgets.

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
