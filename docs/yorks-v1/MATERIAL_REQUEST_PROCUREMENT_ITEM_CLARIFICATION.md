# Material Request Procurement Item Clarification

Status: implemented with Engineering reapproval checkpoint
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
- Saving corrected identity immediately sends the request to the Project
  Engineer. The arrangement stays visible but its operational fields and Save
  action are read-only until the latest correction is approved.
- Procurement may correct another ambiguous item while review is pending. The
  latest correction revision is the one Engineering must approve.
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
- A clarification atomically moves the request to
  `awaiting_request_approval`; it does not create or save an arrangement.
- Project Engineer approval records the exact clarification revision and
  returns the same working arrangement to Procurement. A returned decision
  keeps the arrangement unsaved and lets Procurement revise the item identity.
- Saving the arrangement is denied while the current clarification revision is
  newer than the approved revision. Optimistic request versions also prevent a
  correction and approval from silently overwriting one another.
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

The request root records a monotonic Procurement clarification revision and
the latest revision accepted by Engineering. Existing requests start at `0/0`,
so accepted historical work is not retroactively invalidated.

`v1_update_material_request_procurement_item` validates exact payload keys,
authorization, request version, request/line identity and unsaved working
arrangement state. It is idempotent and writes one append-only
`procurement_item_clarified` audit event containing before/after identity data.
Engineering approval or return adds a separate append-only clarification
decision and audit event. Existing Material Request notification codes carry
the handoff to Engineering and back to Procurement.

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
- Arrangement save fails after clarification and before Engineering approval.
- Procurement cannot approve its own correction; an authorized Project
  Engineer can approve the exact latest revision.
- Approval resumes the preserved working arrangement, and a later correction
  requires a new approval.
- Saving the arrangement permanently closes the clarification window.
- Desktop and 360-pixel creation/arrangement experiences stay usable and use
  the same protected search catalogue.
