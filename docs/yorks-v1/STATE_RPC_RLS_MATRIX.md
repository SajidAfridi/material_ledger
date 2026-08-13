# Yorks V1 R35 — State, RPC and RLS Matrix

This document is the implementation checklist for Postgres state machines,
trusted commands and access policies. Names are canonical unless a migration
records an explicit replacement.

## 1. State machines

### Project

| From | Command | To | Authority |
|---|---|---|---|
| — | Create project | `draft` | Project Engineer, Site Engineer, Admin |
| `draft` | Activate | `active` | Project Engineer/Admin; at least one active Project Engineer |
| `active` | Put on hold | `on_hold` | Project Engineer/Admin with reason |
| `on_hold` | Resume | `active` | Project Engineer/Admin with reason |
| `active`, `on_hold` | Complete | `completed` | Project Engineer/Admin; no unresolved new-work blocker |
| `completed` | Archive | `archived` | Admin with reason |
| `draft`, `active`, `on_hold`, `completed` | Safe archive | `archived` | Admin-only audited override; only when no operational Material Request remains open |

### Material Request

| From | Command | To | Authority |
|---|---|---|---|
| — | Save draft | `draft` | Assigned Project/Site Engineer |
| `draft` | Submit/resubmit | `awaiting_request_approval` | Draft creator with active project membership |
| `awaiting_request_approval` | Edit Engineering intent | `awaiting_request_approval` | Creator or assigned/global Project Engineer/Admin; versioned and audited |
| `awaiting_request_approval` | Return for changes | `draft` | Assigned/global Project Engineer/Admin; immutable returned decision/reason |
| `awaiting_request_approval` | Approve request | `approved_for_arrangement` | Assigned/global Project Engineer/Admin |
| `approved_for_arrangement` | Begin arrangement | `arranging` | Procurement/Admin |
| `arranging` | Save pre-approved arrangement | `approved` or `closed` | Procurement/Admin |
| Legacy `awaiting_approval` | Return/approve saved legacy arrangement | `arranging` or `approved` | Assigned/global Project Engineer/Admin; compatibility only |
| `approved`, `partially_dispatched`, `partially_received` | Dispatch subset | `partially_dispatched` or `dispatched` | Procurement/Admin |
| `partially_dispatched`, `dispatched`, `partially_received` | Confirm receipt review | `partially_received` or `received` | Assigned Project/Site Engineer/Admin |
| `received` | Close | `closed` | Assigned Project/Site Engineer, global Senior Mechanical Engineer/Project Manager, or Admin when all committed work is resolved |
| Eligible pre-dispatch state | Cancel | `cancelled` | Policy-defined Project Engineer/Admin with reason |

State labels are not manually editable. Aggregate state is calculated by the
trusted command from line facts inside the same transaction.

### Arrangement line

| Decision | Constraint |
|---|---|
| `full` | `arranged_qty = requested_qty` |
| `partial` | `0 < arranged_qty < requested_qty` and reason present |
| `unavailable` | `arranged_qty = 0` and reason present |

### Dispatch and receipt

Dispatch: `created -> dispatched -> receipt_pending -> partially_received -> received`

Receipt review line UI outcome is `received`, `missing` or `damaged`. Good and
exception quantities reconcile to the dispatched quantity as defined in
`PRODUCT_DECISIONS.md`.

### Return

`draft -> submitted -> confirmed | rejected`

Only `confirmed` appends an inventory movement.

## 2. Quantity invariants

| Invariant | Enforcement point |
|---|---|
| `requested_qty >= 0` and committed quantities are positive where required | checks plus submit/command validation |
| `arranged_qty <= requested_qty` | arrangement line check and save RPC |
| `approved_qty <= arranged_qty` | pre-approved arrangement save RPC |
| `good_received_qty + in_transit_qty <= approved_qty` | dispatch and receipt RPCs under locks |
| Warehouse reserved total cannot exceed available stock | arrangement save RPC under inventory locks |
| Warehouse dispatch cannot exceed on-hand/available at commit | dispatch RPC under inventory locks |
| `good + missing_or_damaged = dispatched` for each reviewed line | receipt RPC |
| Missing/damaged does not increment good received | receipt RPC and movement trigger/constraint |
| Confirmed returns do not exceed good received minus earlier confirmed returns | return submit/confirm RPC under source-line locks |
| One committed effect per idempotency key/request hash | idempotency table unique constraint and RPC helper |

All authoritative quantities are Postgres `numeric`. Flutter may format decimal
input but does not decide the final comparison result.

## 3. Trusted RPC command matrix

Proposed stable function names use a `v1_` prefix during coexistence with legacy
tables/functions.

| RPC | Caller | Locks/version | Idempotent | Atomic effects |
|---|---|---|---|---|
| `v1_create_project` | Project Engineer, Site Engineer, Admin | reference/template rows | yes | project, Common/buildings, initial memberships, 29 BOQ groups per real scope, audit |
| `v1_update_project` | Active assigned Project/Site Engineer or Admin | project/version, retained building scopes | yes | project setup, parties, active/retired building scopes; new real scope receives 29 groups, audit |
| `v1_archive_project` | Admin only | project/version, open MR check | yes | irreversible safe archive state, retained history, audit |
| `v1_set_project_state` | Project Engineer/Admin by transition | project/version | yes | state, owner/action, audit/notification |
| `v1_assign_project_member` | Project Engineer/Admin; creation exception for Site Engineer | project/member/version | yes | close prior membership, add membership, audit/notification |
| `v1_create_boq_group` | BOQ-authorized Engineer/Admin | project/origin scope/name | yes | same custom folder name materialized as independent empty groups in every active real scope; origin projection returned; one audit; no rows copied |
| `v1_assign_legacy_boq_group_scope` | BOQ-authorized Engineer/Admin | group/version | yes | explicit legacy group-to-real-scope reconciliation, audit; submitted/conflicting history rejected |
| `v1_submit_material_request` | Assigned Engineer draft creator | draft/project/counter/version | yes | number, snapshots, state, owner, audit/notification |
| `v1_update_material_request_for_approval` | Creator or assigned/global Project Engineer/Admin | MR/version/line set; no arrangement permitted | yes | replace Engineering snapshot, retain number/submission attribution, audit/notification |
| `v1_decide_material_request` | Assigned/global Project Engineer/Admin | MR/current Engineering version | yes | immutable approval/return decision, state/owner, exact role, audit/notification |
| `v1_begin_arrangement` | Procurement/Admin | approved MR/version | yes | current arrangement work version, `arranging`, audit |
| `v1_save_arrangement` | Procurement/Admin | MR, arrangement, inventory, reservations | yes | versioned lines, replacement reservations, approved snapshots/state, audit/notification |
| `v1_decide_arrangement` | Assigned/global Project Engineer/Admin | legacy MR/current arrangement/version | yes | compatibility-only approval or return decision; retained history |
| `v1_add_material_request_comment` | Authorized request participant | MR/text/mention IDs | yes | append-only comment, validated mentions, notifications and audit |
| `v1_search_material_request_inventory_items` | Authorized Engineering request participant | project/query | no | non-commercial descriptive item suggestions only |
| `v1_dispatch_materials` | Procurement/Admin | MR, approved lines, reservations, inventory | yes | dispatch/lines, reservation consumption, stock movements, state, audit/notification |
| `v1_confirm_receipt` | Assigned Project/Site Engineer/Admin | dispatch/MR/receipt version | yes | review/lines, good/exception totals, state, audit/notification; appends receipt-reviewed Delivery Report revision when a DO exists |
| `v1_generate_delivery_order` | Assigned Project/Site Engineer, global Senior Mechanical Engineer/Project Manager, Procurement/Admin after committed dispatch | dispatch/current DO revision; optional later review link | yes | immutable dispatch-quantity revision before review, or immutable receipt-reviewed good-quantity Delivery Report revision after review; document link, audit |
| `admin-users` Edge commands | Active exact Admin or Senior Mechanical Engineer | live Auth role, active actor, stable app-user target; action-specific input | yes for mutations | Auth mutation plus safe server audit; last-active-Admin invariant retained |
| `v1_get/set_user_commercial_capability` | Active exact Admin or Senior Mechanical Engineer | live exact actor, target Auth user; reason and idempotency for writes | writes only | safe capability envelope/override plus audit; no commercial record data returned |
| `v1_submit_material_return` | Assigned Project/Site Engineer/Admin | source receipt/return/version/counter | yes | frozen return lines, number, submitted state, audit/notification |
| `v1_confirm_material_return` | Procurement/Admin | return, source lines, inventory | yes | confirmed state, stock movements once, audit/notification |
| `v1_reject_material_return` | Procurement/Admin | return/version | yes | rejected state/reason, audit/notification |
| `v1_cancel_material_request` | Project Engineer/Admin per policy | MR, reservations, dispatch existence | yes | cancel/retain history, release remainder, audit/notification |
| `v1_close_material_request` | Assigned Project/Site Engineer, global Senior Mechanical Engineer/Project Manager, or Admin | MR and all logistics rows | yes | validated closed state, audit |
| `v1_adjust_inventory` | Procurement/Admin capability | inventory item/version | yes | append-only adjustment movement and derived balance, audit |
| `v1_inventory_category_suggestions` | Procurement/Admin inventory capability | active category/alias library | no | ranked read-only canonical, alias and advisory fuzzy results |
| `v1_create_inventory_category` | Procurement/Admin inventory capability | optional active parent family, canonical name | yes | stable category ID/path plus audit; no quantity effect |
| `v1_create_inventory_item` | Procurement/Admin inventory capability | optional category decision during catalogue reconciliation, metadata, optional opening quantity | yes | categorized or truthfully uncategorized item master, balance, optional opening movement, approved alias when applicable and audit atomically |
| `v1_adjust_inventory_stock` | Procurement/Admin inventory capability | active item/balance version, action, quantity | yes | locked append-only movement, derived balance and audit; reservations remain read-only |
| `v1_import_inventory` | Procurement/Admin inventory capability | reviewed workbook/category decisions/item versions | yes | atomic items/categories/aliases/movements/import result and audit |
| `v1_create_document_version` | Entity-authorized user | document/link target/version | yes | Storage metadata/version/link/audit after upload finalization |
| `v1_link_document` | Entity-authorized user | document/target/version | yes | classified link and audit |

Every function derives actor, role and server time. User-supplied actor/role/time
is ignored as authority. The exact role in the JWT must match the current
protected Auth row before it is normalized for workflow use; stale role claims
fail closed.

## 4. RLS capability matrix

Legend: `R` read, `C` create, `U` update, `RPC` mutation only through trusted
command, `—` denied. “Assigned” always means an active relevant project
membership.

| Domain | Project Engineer | Site Engineer | Procurement | Admin |
|---|---|---|---|---|
| Own profile | R/U non-authority fields | R/U non-authority fields | R/U non-authority fields | R/U non-authority fields |
| Other profiles/team picker | R limited active directory | R limited active directory | R limited active directory | R; provision/disable via server |
| Capabilities | R own effective | R own effective | R own effective | R/RPC manage |
| Assigned projects/scopes | R/C/U assigned | R/C/U assigned | R running, no C/U | R/RPC controlled manage |
| Project memberships | R; RPC manage assigned project | R, no manage after create | R, no write | R/RPC |
| Assigned BOQ groups/columns/rows | R/C/U | R/C/U | R only | R/C/U |
| MR drafts | own R/C/U/delete | own R/C/U/delete | — | R/support per policy |
| Submitted MR operational data | R assigned | R assigned | R all running | R |
| MR commercial projection | only with capability | only with capability | R with capability | R with capability |
| Arrangements | R assigned; decision RPC if Project Engineer | R assigned, no decision | R; create/update through RPC | R/RPC |
| Approval decisions | R assigned; RPC if Project Engineer | R assigned | R, no write | R/RPC |
| Inventory catalogue/balances | no general inventory workspace | no general inventory workspace | R/RPC manage | R/RPC |
| Inventory categories/import batches | — | — | R; create/import via idempotent RPC | R; create/import via idempotent RPC |
| Reservations/movements | related non-commercial summary | related non-commercial summary | R; write only via RPC | R; write only via RPC |
| Dispatches | R assigned | R assigned | R/RPC create | R/RPC |
| Receipt reviews | R/RPC assigned | R/RPC assigned | R, no confirm | R/RPC |
| Delivery Orders | R/RPC generate after an assigned committed dispatch | R/RPC generate after an assigned committed dispatch | R/RPC generate after committed dispatch | R/RPC generate after committed dispatch |
| Returns | R/RPC create assigned | R/RPC create assigned | R/RPC confirm/reject | R/RPC |
| Operational documents | R/C through authorized links | R/C through authorized links | R/C through authorized links | R/C |
| Commercial documents | capability plus link | capability plus link | capability plus link | capability plus link |
| Notifications | own R/U seen state | own R/U seen state | own R/U seen state | own R/U seen state |
| Audit events | related read projection | related read projection | related read projection | R; no client C/U/delete |
| Idempotency/reference counters | — | — | — | no direct client access |

Senior Mechanical Engineer and Project Manager follow the Project Engineer
column across all projects without dated membership. They remain denied the
Procurement, inventory, commercial and Admin-only cells.

Direct Procurement inserts/updates/deletes on project, scope, membership and BOQ
tables must fail even when a route or stale client attempts them.

Inventory category, alias and import-batch relations also deny ordinary table
access. `v1_create_inventory_category`, `v1_create_inventory_item`,
`v1_adjust_inventory_stock`, the compatibility `v1_adjust_inventory`, and
`v1_import_inventory` are the smart-warehouse write boundaries;
`v1_inventory_category_suggestions` is read-only. The import command validates
the whole workbook and commits or rolls back as one transaction.

The All BOQ overview is read-only. It cannot be represented by a `scope_id`,
used as a mutation target or used as an MR source; BOQ-derived MR lines must
match the request's one persisted Common/building scope at save and submit.

## 5. Storage policy matrix

| Classification | Additional requirement |
|---|---|
| `operational` | Access to every current linked entity |
| `commercial` | Every-linked-entity access plus `view_commercials` |
| `admin_restricted` | Admin |

Upload uses a short-lived authorized path/operation. The final document row and
link are committed by a trusted function after object metadata/hash validation.
Object-path guessing never grants read.

## 6. Server-generated audit events

At minimum, append events for:

- project create/state/member changes;
- BOQ import commit and destructive column/row operations;
- MR submit/cancel/close;
- arrangement begin/save/replace and reservation release;
- approval/return-for-changes;
- inventory adjustment;
- dispatch and movement creation;
- receipt confirmation;
- DO generation/supersession;
- return submit/confirm/reject;
- document version/link change;
- Admin user/capability change and override.

Audit tables deny client insert, update and delete. Corrections append a new
event referencing the original.

## 7. Required negative proofs

Every relevant migration/test must prove at least:

1. unrelated Engineers cannot read or mutate another project;
2. Site Engineer cannot manage team or approve;
3. Procurement cannot create/edit project or BOQ, raise an Engineering MR, or
   approve its arrangement;
4. an Engineer without commercial capability receives no cost schema/value;
5. direct table writes cannot bypass each critical RPC;
6. stale versions fail without partial effects;
7. competing reservations/dispatches cannot oversubscribe;
8. repeated idempotency keys do not duplicate effects;
9. revoked membership blocks future actions but preserves historical reads and
   attribution;
10. Storage path knowledge does not bypass document/link access.
