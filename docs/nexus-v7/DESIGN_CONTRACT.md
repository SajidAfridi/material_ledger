# Yorks Nexus V7 — Approved Design Contract

This document translates the supplied client-approved prototype into rules that
production Flutter code must honour. The HTML prototype is reference material,
not a codebase to copy into Flutter.

## Required journeys

### Engineer

- Home is an action queue, not a decorative dashboard.
- Projects open a connected workspace containing overview, material plan,
  requests, documents and activity.
- Phase 1 material planning uses a controlled baseline and explicit revisions.
- Browse Materials exposes catalogue, availability, allocated quantity and
  in-transit quantity without exposing restricted cost data.
- A Phase 2 request is created in three steps: Project & Building → Materials →
  Review & Submit.
- Requests carry required-on-site date and destination. Within-plan requests
  route directly to Procurement; new, over-plan or substituted materials require
  a concise exception reason and approval.
- Mobile editing uses a focused row editor or compact grid with a persistent
  Save/Add affordance and tap targets of at least 44×44.

### Procurement

- Home is an ordered action queue.
- A request opens as a procurement package with the source request, project,
  building, current owner, urgency and fulfilment state visible together.
- Each line can split between warehouse stock and external sourcing, including
  multiple suppliers.
- Inventory auto-check proposes quantities but never allocates or reserves
  automatically.
- RFQs and quotations reuse the request lines; descriptions, sizes, units and
  quantities are never re-entered.
- Supplier quotations are compared side-by-side by price, VAT/delivery
  treatment, lead time, availability, validity and technical compliance, then
  selected per line.
- Purchase orders show ordered, received and remaining quantities, documents,
  revisions and partial receipt controls.
- Receiving distinguishes Supplier Receipt, Warehouse Issue, Site Delivery
  Receipt and Site Receipt Confirmation, including short/damaged/rejected
  quantities.

### Admin

- Admin controls cost visibility and role/capability configuration.
- Admin sees the same connected records plus governance, history and audit
  context.
- Capability changes affect backend access, payload shape and exports—not only
  widget visibility.

## Visual and interaction rules

- Calm, light workspace with a deep authoritative blue for primary actions.
- Use tonal surfaces and whitespace to establish hierarchy; do not add noisy
  decoration or gratuitous animation.
- Prefer clear status pills, action cards, related-record chains, activity
  timelines and visible owners over hidden workflow state.
- Desktop tables remain dense enough for operational work and support keyboard
  navigation.
- Mobile screens keep context at the top, use short focused steps and avoid
  forcing a desktop table into an unusable viewport.
- Preserve the existing bilingual/localisation conventions. No new hard-coded
  user-facing strings.
- Use the repository design tokens (`AppColors`, `AppSpacing`,
  `AppTypography`) and shared widgets as the Flutter implementation base.
- Browser project creation uses Essentials & Responsibility → Buildings →
  Review & Create. Attachments are optional and inline.
- Project workspace readiness is based on current action, blockers and connected
  records. The MVP does not implement arbitrary weighted completeness.

## Exact approved material columns

The standard visible material line has only these columns, in this order:

1. S:No
2. Item Description
3. Size (If any)
4. Model/Serial No.
5. Make/Origin
6. QTY
7. Unit
8. Remarks
9. Unit Cost
10. Total Cost

Unit Cost and Total Cost are capability-controlled. When a user lacks the
capability, the values must be absent from the server response, local cache and
export—not merely visually hidden.

The approved visible `Model/Serial No.` wording remains unchanged until client
sign-off, while the domain separates model/equipment tag from a serial number
captured at receipt.

## Traceability rules

Important records must show:

- who performed the action;
- the actor's role;
- when it happened;
- the current action owner;
- the current status and revision;
- the related source and downstream records;
- what changed when a revision or approval occurred.

The approved design's green connected-lifecycle panels are a product rule:
relationships are first-class data, not duplicated labels assembled only in the
UI.

## Reference assets

- Prototype: `design/Yorks_Nexus_Materials_Projects_Client_Design_v7.html`
- Client walkthrough: `design/README_CLIENT_REVIEW.txt`
- Modular source: `design/source/`
- Review images: `design/previews/desktop/` and `design/previews/mobile/`
