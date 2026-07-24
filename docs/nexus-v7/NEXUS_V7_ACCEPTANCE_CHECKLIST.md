# Yorks Nexus V7 — Acceptance Checklist

## Project creation

- [ ] Engineer can create project
- [ ] Procurement can create project
- [ ] Admin can create project
- [ ] Yorks reference is unique
- [ ] Secondary name is optional
- [ ] New UI uses Other Contractors; legacy Authority Reference is preserved separately and never reinterpreted
- [ ] Multiple subcontractors supported
- [ ] Multiple buildings supported
- [ ] Floors optional
- [ ] FRP Room is Yes/No only
- [ ] Draft autosaves
- [ ] Browser uses Essentials & Responsibility → Buildings → Review & Create
- [ ] Attachments are optional and do not block creation
- [ ] Review page shows all entered data
- [ ] Creator, role and timestamp are recorded
- [ ] Attachments remain linked to project/building

## Phase 1 material plan

- [ ] Exact approved material columns only
- [ ] All HVAC categories available
- [ ] Catalogue and custom items can be mixed
- [ ] Size popup supports rectangular, circular, linear, nominal pipe and custom
- [ ] Approved units and custom unit supported
- [ ] Add Blank Row works
- [ ] Add Similar Row copies only approved fields
- [ ] Excel paste and keyboard navigation work
- [ ] CSV export works
- [ ] Restricted costs are absent, not merely hidden
- [ ] Procurement can record a proposed warehouse/external source
- [ ] Phase 1 availability review does not reserve stock
- [ ] Procurement can comment
- [ ] Engineer can approve or request changes
- [ ] Versions and diffs remain traceable
- [ ] Project activates only after final approval
- [ ] Workspace shows current action and blockers without arbitrary weighted completeness

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
