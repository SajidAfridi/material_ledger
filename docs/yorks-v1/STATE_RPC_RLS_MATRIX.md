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
| `arranging` | Save pre-approved arrangement | `approved`, or remain `arranging` when every line is unavailable | Procurement/Admin |
| Legacy `awaiting_approval` | Return/approve saved legacy arrangement | `arranging` or `approved` | Assigned/global Project Engineer/Admin; compatibility only |
| `approved`, `partially_dispatched`, `partially_received` | Dispatch subset | `partially_dispatched` or `dispatched` | Procurement/Admin |
| `partially_dispatched`, `dispatched`, `partially_received` | Confirm receipt review | `partially_received` or `received` | Assigned Project/Site Engineer/Admin |
| `received` | Close | `closed` | Assigned Project/Site Engineer, global Senior Mechanical Engineer/Project Manager, or Admin when all committed work is resolved |
| Eligible pre-dispatch state | Cancel | `cancelled` | Policy-defined Project Engineer/Admin with reason |
| Cancelled with latest saved all-unavailable arrangement | Create linked replacement Draft | source remains `cancelled`; new request is `draft` | Authorized Engineering MR creator/Admin; never Procurement |

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
| `v1_create_project` | Project Engineer, Site Engineer, Admin | reference/template rows | yes | project, Common/buildings, initial memberships, one Workshop Materials BOQ folder per real scope, audit |
| `v1_update_project` | Active assigned Project/Site Engineer or Admin | project/version, retained building scopes | yes | project setup, parties, active/retired building scopes; each new real scope receives one Workshop Materials folder, audit |
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
| `v1_material_request_phase3_policy_projection` | Authorized request reader | current request access plus published configuration | no | role-safe published self-approval/readiness values and replacement eligibility/link only |
| `v1_create_replacement_material_request` | Authorized Engineering MR creator/Admin | cancelled source/version, latest all-unavailable arrangement, no dispatch, one-source uniqueness | yes | one private linked Draft, cloned line provenance and audit; source remains cancelled |
| `v1_decide_arrangement` | Assigned/global Project Engineer/Admin | legacy MR/current arrangement/version | yes | compatibility-only approval or return decision; retained history |
| `v1_add_material_request_comment` | Authorized request participant | MR/text/mention IDs | yes | append-only comment, validated mentions, notifications and audit |
| `v1_list_material_request_summaries` | Active role within the existing request/project read boundary | server filter/sort/limit/offset | no | lightweight authorized rows plus aggregate metrics; no lines, comments, private drafts or commercial values |
| `v1_list_material_request_comments` | Authorized request participant | request and stable cursor | no | newest/older append-only comment page without duplicate rows |
| `v1_get_material_request_work_assignment` / `v1_list_material_request_assignment_candidates` | Authorized request participant | request and current access | no | coordination marker and eligible non-commercial participant choices only |
| `v1_assign_material_request_work` | Authorized request participant | request/assignment versions and reason on reassignment | yes | claim/reassign marker, audit and assignee notification; no request state/owner/quantity mutation |
| `v1_sync_material_request_private_draft` / `v1_get_material_request_private_draft` / `v1_list_my_material_request_private_drafts` / `v1_delete_material_request_private_draft` | Active draft creator only | owner/draft/version and idempotency on writes | writes only | owner-private recovery snapshot; no submission, visibility or workflow transition |
| `v1_material_request_change_summary` | Authorized request participant | immutable Engineering revision snapshots | no | non-commercial added/removed/quantity/detail/delivery-note difference counts |
| `v1_search_material_request_candidates` | Active project-authorized Engineering/Procurement/Admin actor | project/scope/query | no | non-commercial suggestions ranked selected-scope BOQ, project BOQ, inventory; exact source IDs only for valid same-scope correlation |
| `v1_search_material_request_inventory_items` | Authorized Engineering request participant on an older client | project/query | no | retained compatibility-only inventory suggestions; current clients use ranked candidate search |
| `v1_dispatch_materials` | Procurement/Admin | MR, approved lines, reservations, inventory | yes | dispatch/lines, reservation consumption, stock movements, state, audit/notification |
| `v1_confirm_receipt` | Assigned Project/Site Engineer/Admin | dispatch/MR/receipt version | yes | review/lines, exact good/missing/damaged totals, state, audit/notification; appends receipt-reviewed Delivery Report revision when a DO exists |
| `v1_generate_delivery_order` | Assigned Project/Site Engineer, global Senior Mechanical Engineer/Project Manager, Procurement/Admin after committed dispatch | dispatch/current DO revision; optional later review link | yes | immutable dispatch-quantity revision before review, or immutable receipt-reviewed good-quantity Delivery Report revision after review; document link, audit |
| `admin-users` Edge commands | Active exact Admin or Senior Mechanical Engineer | live Auth role, active actor, stable app-user target; action-specific input | yes for mutations | Auth mutation plus safe server audit; last-active-Admin invariant retained |
| `v1_get/set_user_commercial_capability` | Active exact Admin or Senior Mechanical Engineer | live exact actor, target Auth user; reason and idempotency for writes | writes only | safe capability envelope/override plus audit; no commercial record data returned |
| `v1_submit_material_return` | Assigned Project/Site Engineer/Admin | source receipt/return/version/counter | yes | frozen return lines, number, submitted state, audit/notification |
| `v1_confirm_material_return` | Procurement/Admin | return, source lines, inventory | yes | confirmed state, stock movements once, audit/notification |
| `v1_reject_material_return` | Procurement/Admin | return/version | yes | rejected state/reason, audit/notification |
| `v1_cancel_material_request` | Project Engineer/global Engineering/Admin per policy | MR/version/reservations/current arrangement | yes | terminal cancel, retain unavailable/history, release remainder, lock Procurement editing, audit/notification |
| `v1_close_material_request` | Assigned Project/Site Engineer, global Senior Mechanical Engineer/Project Manager, or Admin | MR and all logistics rows | yes | validated closed state, audit |
| `v1_adjust_inventory` | Procurement/Admin capability | inventory item/version | yes | append-only adjustment movement and derived balance, audit |
| `v1_inventory_category_suggestions` | Procurement/Admin inventory capability | active category/alias library | no | ranked read-only canonical, alias and advisory fuzzy results |
| `v1_create_inventory_category` | Procurement/Admin inventory capability | optional active parent family, canonical name | yes | stable category ID/path plus audit; no quantity effect |
| `v1_create_inventory_item` | Procurement/Admin inventory capability | optional category decision during catalogue reconciliation, metadata, optional opening quantity | yes | categorized or truthfully uncategorized item master, balance, optional opening movement, approved alias when applicable and audit atomically |
| `v1_adjust_inventory_stock` | Procurement/Admin inventory capability | active item/balance version, action, quantity | yes | locked append-only movement, derived balance and audit; reservations remain read-only |
| `v1_import_inventory` | Procurement/Admin inventory capability | reviewed workbook/category decisions/item versions | yes | atomic items/categories/aliases/movements/import result and audit |
| `v1_supplier_directory_projection` / `v1_supplier_folder_projection` | Procurement/Admin inventory capability | exact current role plus paging/filter arguments | no | authorized supplier, receipt, document, destination and audit projections; mixed units stay separated |
| `v1_create_supplier` | Procurement/Admin inventory capability | canonical identity, explicit aliases and idempotency key | yes | one canonical supplier master plus append-only audit; Unknown Supplier is immutable |
| `v1_import_inventory_r38_9` | Procurement/Admin inventory capability | file SHA-256, strict mode, reviewed item/category/supplier decisions, receipt evidence, condition quantities and opening cutoff | yes | one atomic import result, suppliers/aliases, receipt batches/lines, movements, balances and audit; failed rows create nothing |
| `v1_prepare_supplier_document_upload` / `v1_supplier_document_workspace_projection` | Procurement/Admin inventory capability plus document classification | supplier or receipt-batch target and actor-scoped upload intent | yes / no | private verified document version/link and authorized folder projection |
| `v1_create_document_version` | Entity-authorized user | document/link target/version | yes | Storage metadata/version/link/audit after upload finalization |
| `v1_link_document` | Entity-authorized user | document/target/version | yes | classified link and audit |
| `v1_get_configuration_centre` / `v1_get_configuration_validation` | Active exact Admin | current published version plus inert shared draft | no | Admin-safe settings/master/history projection and authoritative validation |
| `v1_list_configuration_units` | Any active exact Yorks role | published active unit register | no | non-commercial unit codes for future MR and Warehouse entry |
| `v1_stage_configuration_setting` | Active exact Admin | draft revision, allowlisted setting and typed value | yes | one inert draft value and incremented draft revision |
| `v1_stage_configuration_master_action` | Active exact Admin | draft revision, normalized category/unit action and archive reason | yes | one inert create/archive action and incremented draft revision |
| `v1_discard_configuration_draft` / `v1_restore_configuration_defaults` | Active exact Admin | draft revision | yes | remove unpublished work or stage typed defaults; published values/history unchanged |
| `v1_publish_configuration` | Active exact Admin | draft revision, validation result and publication reason | yes | atomic setting/master commit, immutable publication snapshot/change rows and trusted audit event |
| `v1_list_chat_conversations` / `v1_search_chat` | Active exact role, active conversation member | current membership and server-side search scope | no | authorized conversation summaries, unread preferences and non-commercial previews only |
| `v1_get_chat_conversation` | Active conversation member with current contextual access | conversation, current project/MR access, cursor and page size | no | participant projection plus newest/older immutable message page |
| `v1_create_chat_conversation` | Any active role for direct/project/MR; Admin, Project Manager or Senior Mechanical Engineer for groups; Admin for announcements | canonical direct/context key and idempotency key | yes | conversation, controlled member set, creator ownership where applicable and system event |
| `v1_update_chat_group` | Group owner or active Admin participant | group row and active member set | yes | title/description/member reconciliation plus system event; direct/context chats rejected |
| `v1_prepare_chat_attachment` / `v1_verify_chat_attachment_upload` | Active member / service role only | actor-scoped short-lived intent, private object metadata, byte count and SHA-256 | yes | upload intent followed by server-verified attachment readiness; no message binding yet |
| `v1_send_chat_message` | Active member; announcements are Admin-send-only | conversation, reply/link/mention/verified attachment ownership and idempotency hash | yes | one append-only message, attachment binding, mentions, hidden participant push-transport rows and audit-safe context; no workflow-bell entry |
| `v1_mark_chat_read` / `v1_mark_chat_unread` | Active member | member preference row | no | authoritative cross-device Chat cursor plus exact hidden Chat transport acknowledgement; workflow notification seen state is untouched |
| `v1_set_chat_preference` | Active member | member preference row | no | pin/mute/archive preference; new unmuted activity can restore archived conversation |
| `v1_toggle_chat_acknowledgement` / `v1_toggle_chat_message_pin` | Active member | message and conversation access | no | caller acknowledgement or per-conversation pinned-message fact |
| `v1_download_chat_attachment` | Active member with current contextual access | attachment/message/conversation access | no | private bucket/path metadata for one authorized download |

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
| MR private draft recovery | own R/RPC only | own R/RPC only | — | own R/RPC only; no invisible cross-user access |
| MR work assignment marker | R/RPC when request-authorized | R/RPC when request-authorized | R/RPC after request enters Procurement visibility | R/RPC; cannot bypass workflow commands |
| Submitted MR operational data | R assigned | R assigned | R all running | R |
| MR commercial projection | only with capability | only with capability | R with capability | R with capability |
| Arrangements | R assigned; decision RPC if Project Engineer | R assigned, no decision | R; create/update through RPC | R/RPC |
| Approval decisions | R assigned; RPC if Project Engineer | R assigned | R, no write | R/RPC |
| Inventory catalogue/balances | no general inventory workspace (Senior Mechanical Engineer exception: R only) | no general inventory workspace | R/RPC manage | R/RPC |
| Inventory categories/import batches | — | — | R; create/import via idempotent RPC | R; create/import via idempotent RPC |
| Supplier masters/aliases/receipt batches/provenance | — | — | R/RPC inside Warehouse Inventory only | R/RPC inside Warehouse Inventory only |
| Supplier documents | — | — | R/RPC subject to classification capability | R/RPC subject to classification capability |
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
| Configuration settings/draft/publications | — | — | — | R/RPC through exact-Admin projection and commands; no direct table access |
| Direct Team Chat | R/RPC only as one of exactly two participants | R/RPC only as one of exactly two participants | R/RPC only as one of exactly two participants | R/RPC only when explicitly one of two participants; no invisible Admin access |
| Project/MR Team Chat | R/RPC while current project/MR access remains valid | R/RPC while current project/MR access remains valid | R/RPC for authorized running-project context | R/RPC through the same explicit/contextual membership boundary |
| Custom Team Chat groups | R/RPC as member; cannot create unless global role below | R/RPC as member; cannot create | R/RPC as member; cannot create | R/RPC create and manage when owner or active Admin participant |
| Team Chat announcements | R as member; no send | R as member; no send | R as member; no send | R/RPC create/send as active Admin |
| Team Chat attachments | R/RPC authorized private download; verified upload/send as active member | same | same | same; service-only finalization does not grant conversation access |

Senior Mechanical Engineer, Project Manager, Workshop In-Charge and Document
Controller follow the Project Engineer column across all projects without
dated membership. They remain denied Procurement, commercial and Admin-only
cells, except for the separately approved Senior Mechanical Engineer User
Management capability and non-commercial inventory read-only projection.

For Team Chat only, Senior Mechanical Engineer, Project Manager, Workshop
In-Charge and Document Controller may create custom groups. They do not thereby
gain access to Direct conversations, muted or archived conversations,
attachments, or announcements unless the relevant membership/policy
independently permits it. These roles cannot send announcements.

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
| Team Chat attachment | Current active conversation membership plus any current project/MR context access; object must be bound to an append-only message after server verification |

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
- configuration publication with exact Admin, reason, affected areas and immutable version.

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
10. Storage path knowledge does not bypass document/link access;
11. non-Admin exact roles cannot read, stage, restore, discard or publish
    organization configuration, and ordinary clients cannot mutate its tables.
12. non-members, revoked contextual members and an uninvited Admin cannot read
    a conversation, message, member list, search preview or attachment path;
13. unverified, expired, wrong-hash, wrong-size or wrong-content-type chat
    uploads cannot be bound to a message;
14. Procurement, Project Engineer and Site Engineer cannot create custom chat
    groups, while only Admin can create or send an announcement;
15. non-Procurement/non-Admin roles cannot open supplier/import RPCs, tables,
    private objects or exports, including Senior Mechanical Engineer's
    separately allowed non-commercial inventory catalogue read;
16. a missing supplier maps only to immutable Unknown Supplier, similar names
    never merge automatically, duplicate file/cutoff/idempotency identities do
    not duplicate stock, and any failed strict row leaves no partial supplier,
    receipt, movement, balance, document or audit result.
