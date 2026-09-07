# Material Request Procurement Item Clarification

Status: implemented local slice
Approved: 7 September 2026

## Purpose

Engineering may know the required material without knowing the exact catalogue
name or model number. Procurement may clarify those two identity fields while
preparing the arrangement. This is a correction layer, not a second Material
Request workflow.

## User experience

- Material Request creation and Procurement clarification use the same ranked
  search sources: selected-scope BOQ, wider project BOQ, then inventory.
- Search accepts an item name, model, brand or item code. A user may keep a
  legitimate custom description when there is no catalogue match.
- Selecting a result fills the effective item name and model. Procurement may
  still refine either value before saving.
- The editor always shows the original Engineering description and original
  model, if any, as read-only history.
- Desktop uses a bounded keyboard-accessible dialog. Mobile uses a near-full
  height bottom sheet with 44-pixel minimum actions and a focused form.
- A successful command refreshes the arrangement and request projections. A
  failed or stale command never shows optimistic success.

## Authority and lifecycle

- Only an active Procurement or Admin actor with effective
  `procurement.arrange` authority for the project may execute the command.
- Clarification is available only inside the current working arrangement and
  only while `saved_at` is null.
- Saving the arrangement and clarifying an item both lock the Material Request
  root. Whichever commits first makes the other stale or ineligible.
- After arrangement save, item identity is read-only. Later dispatch, receipt,
  return and controlled-document projections use the clarified effective
  values without rewriting the original snapshot.
- Quantity, unit, brand, BOQ provenance, commercial values and arrangement
  decisions are outside this command.

## Data and audit

Each Material Request line retains immutable `requested_item_description` and
`requested_technical_attributes` snapshots. Current `item_description` and the
current technical `model` are the effective downstream values. The server also
records clarifier, timestamp and clarification version.

`v1_update_material_request_procurement_item` validates exact payload keys,
authorization, request version, request/line identity and unsaved working
arrangement state. It is idempotent and writes one append-only
`procurement_item_clarified` audit event containing before/after identity data.

## Rollback and preservation

Rollback is forward-only after the first use. Revoke the command and hide the
client action. Do not drop requested snapshots, clarification metadata or audit
events. No existing request, arrangement, quantity, reservation, document or
BOQ link is deleted or reinterpreted.

## Acceptance

- Existing rows backfill without changing their effective values.
- Procurement succeeds before save; Engineering and direct table writes fail.
- Stale versions fail without changing the line.
- Same-key retries return the first response and create one audit event.
- A different payload cannot reuse a command key.
- Saving the arrangement permanently closes the clarification window.
- Desktop and 360-pixel creation/arrangement experiences stay usable and use
  the same protected search catalogue.
