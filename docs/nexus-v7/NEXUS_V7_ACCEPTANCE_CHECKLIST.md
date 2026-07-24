# Yorks Nexus V7 — Acceptance Checklist

## Project creation

- [x] Engineer can create project
- [x] Procurement can create project
- [x] Admin can create project
- [x] Yorks reference is unique
- [x] Secondary name is optional
- [x] New UI uses Other Contractors; legacy Authority Reference is preserved separately and never reinterpreted
- [x] Multiple subcontractors supported
- [x] Multiple buildings supported
- [x] Floors optional
- [x] FRP Room is Yes/No only
- [x] Draft autosaves
- [x] Browser uses Essentials & Responsibility → Buildings → Review & Create
- [x] Attachments are optional and do not block creation
- [x] Review page shows all entered data
- [x] Creator, role and timestamp are recorded
- [x] Attachments remain linked to project/building

## Project workspace

- [x] Shared route is available to Engineer, Procurement and Admin behind the Projects flag
- [x] Engineer cannot retrieve a project outside assigned visibility
- [x] Overview, Material Plan, Requests, Procurement, Documents and Activity remain connected
- [x] Current action and current owner are explicit
- [x] Blockers are concrete and do not duplicate normal next work
- [x] Readiness uses operational states and remains separate from weighted physical progress
- [x] Project progress stages, weights and percentages can differ by project
- [x] Progress weights must total 100 and updates retain actor/time
- [x] Progress reporting never changes lifecycle, approval, stock or procurement
- [x] Project and Material Plan status remain visible
- [x] Requests match stable project id with legacy-name fallback only
- [x] Document references retain project/building scope and audit metadata
- [x] Activity shows actor, role and timestamp
- [x] Procurement can reach the project register but cannot delete projects
- [x] RFQ and PO areas do not fabricate records before their controlled batch
- [x] Desktop uses workspace tabs and inspector
- [x] Mobile uses a dedicated section selector without squeezed desktop tabs
- [x] Disabled flag and unavailable records fail closed

## Dynamic masters and Browse Materials

- [x] Browse is available to Engineer, Procurement and Admin behind its own flag
- [x] Desktop uses a category rail, dense catalogue list and focused inspector
- [x] Mobile uses cards, a category selector and focused detail sheet
- [x] Search covers code, description, category, size, make, origin, RAL and store
- [x] All approved HVAC category groups are available
- [x] Default approved units are Nos, Meter, Cm, Length, Set, Pairs, Roll and Box
- [x] Legacy category and unit values gain deterministic stable master ids
- [x] Unmatched legacy units remain distinct pending custom units
- [x] Admin can add, edit, archive and restore categories without deleting history
- [x] Procurement can propose a custom unit but cannot approve or archive it
- [x] Only approved units appear in catalogue material forms
- [x] Catalogue and custom material paths retain stable master references
- [x] On-hand, allocated and available quantities are visible
- [x] Missing in-transit data is shown as unavailable rather than fabricated
- [x] Engineer UI and CSV contain no commercial columns or values
- [x] Authorized Admin/Procurement CSV includes protected commercial values
- [x] Browser CSV downloads a real file; unsupported platforms use a clipboard fallback
- [x] Supabase masters are realtime/bootstrap synced through the existing outbox
- [x] Supabase grants and RLS positive/negative persona checks pass
- [x] Disabled flag preserves the legacy Engineer browser

## Phase 1 material plan

- [x] Exact approved material columns only
- [x] All HVAC categories available
- [x] Catalogue and custom items can be mixed
- [x] Size popup supports rectangular, circular, linear, nominal pipe and custom
- [x] Approved units and reviewed custom units supported
- [x] Add Blank Row works
- [x] Add Similar Row copies only approved fields
- [x] Excel paste and keyboard navigation work
- [x] CSV export works
- [x] Restricted costs are absent, not merely hidden
- [x] Procurement can record a proposed warehouse/external/mixed source
- [x] Phase 1 availability review does not reserve stock
- [x] Procurement can comment at plan or line level
- [x] Engineer can approve or request changes
- [x] Versions and diffs remain traceable
- [x] Project activates only after final approval
- [x] Workspace keeps readiness separate from configurable physical progress

## Reusable material line grid spike

- [x] Exact approved ten-column order
- [x] Denied sessions receive only the eight operational columns
- [x] Operational JSON and denied CSV contain no commercial fields or values
- [x] Add Blank Row works
- [x] Add Similar Row copies only description, size, make/origin, unit and remarks
- [x] Model/Serial No., QTY and commercial values clear on Similar Row
- [x] Tab/Shift+Tab and Enter/Shift+Enter navigation work
- [x] Excel TSV paste works without retyping rows
- [x] Undo and redo restore complete grid snapshots
- [x] Validation preserves incomplete draft values
- [x] Debounced autosave callback works
- [x] Size builder supports rectangular, circular, linear, nominal pipe and custom
- [x] CSV uses the visible role-safe schema and escapes quotes/newlines
- [x] Desktop freezes S:No/header and virtualizes rows
- [x] Mobile uses cards and a focused editor instead of a squeezed grid
- [x] 500-row virtualization and edit-budget tests pass
- [x] Diagnostic route is debug-only
- [x] Spike remained isolated through Batch 7; Batch 8 reuses it in Phase 1

## Phase 2 Material Request

- [ ] Active project and building selection
- [ ] Full material browser, not MFD-only
- [ ] Three-step request flow
- [ ] Draft recovery
- [ ] Normal/Urgent
- [ ] Mixed categories
- [ ] Custom item
- [ ] Attachment support
- [ ] Required-on-site date and destination
- [ ] Planned, previously requested and remaining plan quantities are visible
- [ ] New, over-plan and substituted lines require exception reason and approval
- [ ] Within-plan lines route directly to Procurement
- [ ] Procurement receives notification
- [ ] Engineer sees current status and outstanding quantities

## Procurement

- [ ] Warehouse and external quantities can be split
- [ ] One request can split across suppliers
- [ ] RFQ generated from MR lines without re-entry
- [ ] Supplier quotations compared side by side
- [ ] Comparison includes VAT/delivery, lead time, availability, validity and technical compliance
- [ ] PO generated from selected quote
- [ ] Earlier PO revisions remain immutable
- [ ] Partial ordering supported
- [ ] Partial receipt supported
- [ ] Supplier Receipt, Warehouse Issue, Site Delivery Receipt and Site Receipt Confirmation are distinct
- [ ] Accepted, short, damaged and rejected quantities are captured
- [ ] Delivery slip photo/document supported
- [ ] Ordered, received and outstanding quantities reconcile
- [ ] Original MR status updates correctly
- [ ] Every action shows actor, role and timestamp

## Security and reliability

- [ ] Engineer cannot retrieve costs through API, local cache or CSV
- [ ] Procurement cost access follows Admin capability
- [ ] Admin can view costs
- [ ] RLS positive/negative tests pass
- [ ] Stock commands are transactional
- [ ] Idempotency tests pass
- [ ] Audit events are append-only
- [ ] Legacy data migrates without loss
- [ ] Offline draft survives reconnect
- [ ] Release build fails closed without complete Supabase configuration
- [ ] Privileged role is never inferred from email or editable user metadata
- [ ] Firebase is FCM transport only; no V7 database/auth path uses Firestore
- [ ] Existing Rentals/People/Leave modules still pass regression tests
- [ ] Desktop, tablet and mobile pass responsive review
- [ ] Flutter analyze, tests and web build pass
