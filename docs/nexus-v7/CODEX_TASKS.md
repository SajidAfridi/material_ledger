# Codex Task Pack — Yorks Nexus V7

Use one task per pull request. Start every implementation task with: “Read `AGENTS.md` and the V7 design documents before changing code.”

## Task 0 — No-code repository audit

```text
Work in SajidAfridi/material_ledger.

Read AGENTS.md, docs/nexus-v7, docs/ARCHITECTURE_AUDIT.md,
docs/supabase/PRODUCTION_STATUS.md, the router, Project/MaterialPlan/
MaterialRequest/MaterialItem models, their providers, and the relevant
Engineer and Procurement screens.

Do not modify code.

Produce docs/nexus-v7/CURRENT_TO_TARGET_GAP_ANALYSIS.md containing:
1. current flow and file map,
2. V7 target flow,
3. exact model/schema/UI/security gaps,
4. backward-compatible migration plan,
5. PR sequence,
6. risks and open decisions,
7. tests required.

Cite exact repository paths and symbols. Do not recommend rewriting the app.
```

## Task 1 — Batch 0B baseline, CI and security configuration

Status: completed and verified on 24 July 2026.

```text
Implement PR-00B only after PRODUCT_DECISIONS.md and SRS_V7_ALIGNMENT.md are
approved.

Add:
- a feature-flag configuration for V7 Projects/Requests/Procurement,
- GitHub Actions that run format check, flutter analyze, flutter test and
  flutter build web,
- generated-build analysis exclusions,
- fail-closed release backend configuration,
- strict app_metadata-only role resolution,
- credential-safe local development configuration,
- shared material payload sanitization for restricted cost.

Do not change user-visible behaviour. Do not modify unrelated modules.
Run the complete required command set and report results.
```

## Task 2 — Project model v2

```text
Implement PR-01A only: project-domain migration.

Add backward-compatible Project v2 support for:
- Yorks reference,
- optional secondary name,
- job/contract number,
- consultant,
- main contractor,
- subcontractors,
- other contractors,
- project manager,
- multiple design engineers,
- multiple ProjectBuilding records,
- optional floors,
- FRP room boolean only,
- creator/updater metadata.

Legacy Project JSON with buildingName/floorNumbers must still decode into one
building. Preserve authorityRef in legacy migration notes; do not map it to
Other Contractors.

Do not change screens yet. Add serialization, migration and provider tests.
Run format, analyze and all tests.
```

## Task 3 — Secure commercial data

```text
Implement PR-02 only.

Introduce a protected commercial-data boundary for Unit Cost and Total Cost.
The Engineer payload, local cache and CSV export must not contain cost when
the current capability denies it.

Add a `viewCommercials` capability and enforce it in:
- Supabase schema/RLS or cost-safe views,
- repositories,
- providers,
- exports.

Keep existing behaviour working for authorised Admin users. Procurement
visibility must follow Admin configuration.

Add RLS tests for positive and negative cases. Do not rely on hiding widgets.
```

## Task 4 — Project wizard

```text
Implement PR-04 only.

Replace the current single-page EngineerCreateProjectScreen with a shared,
responsive V7 ProjectCreateFlowScreen available to Engineer, Procurement and
Admin.

Steps:
1 Essentials & Responsibility
2 Buildings
3 Review & Create

Requirements:
- autosave draft,
- unique Yorks reference validation,
- multiple buildings,
- floors optional,
- FRP Yes/No only,
- optional repeatable subcontractors and other contractors,
- optional inline attachments or workspace attachments,
- role/actor/timestamp metadata,
- responsive desktop/tablet/mobile,
- no changes to unrelated modules,
- feature flag for safe rollout.

Add widget and provider tests plus screenshots.
```

## Task 5 — Material line grid spike

```text
Create an isolated implementation spike for the reusable MaterialLineGrid.

It must render the exact ten approved columns, support hidden cost columns,
keyboard navigation, Add Blank Row, Add Similar Row, size popup, validation,
CSV export and 500 rows without unacceptable input lag.

Do not integrate it into production flows yet. Include a benchmark/demo screen
behind a debug route, tests for smart-row behaviour and CSV escaping, and a
short decision note describing the chosen grid implementation.

Mobile must use compact row cards with a focused editor. Do not treat a
horizontally squeezed desktop grid as the mobile implementation.
```

## Task 6 — Phase 1 workflow

```text
Implement the V7 Phase 1 material-plan vertical slice using the approved
MaterialLineGrid and current Riverpod/Supabase patterns.

Engineer:
- creates/edits plan,
- browses all categories,
- adds catalogue or custom rows,
- submits to Procurement.

Procurement:
- sees advisory availability and proposed source,
- comments at plan and line level,
- confirms review and sends the plan Ready for Approval,
- sends response for approval.

Authorised Engineer:
- reviews differences,
- approves or requests changes.

Final approval activates the project. Preserve immutable versions and show
actor/timestamp/current action owner. Add end-to-end provider and widget tests.
Phase 1 review must not reserve warehouse stock.
```

## Task 7 — Simplified Material Request

```text
Implement the V7 execution-stage New Material Request.

Flow:
1 select Active Project and Building,
2 add materials using the same full browser and MaterialLineGrid,
3 review and submit.

Support mixed categories, custom items, Normal/Urgent, notes, drafts, smart
rows, attachments, required-on-site date and destination. A line within the
approved plan submits directly to Procurement. A new, over-plan or technically
substituted line requires an exception reason and authorized approval. Cost
visibility must follow the protected capability.

Add tests for draft recovery, validation, mixed categories, hidden prices and
notification creation.
```

## Task 8 — Procurement documents

```text
Implement the connected procurement vertical slice:

MR Line -> warehouse/external allocation -> RFQ -> supplier quotation
comparison -> Purchase Order -> partial Delivery Receipts.

Requirements:
- no re-entry of material descriptions,
- one MR can split across warehouse and multiple suppliers,
- ordered/received/outstanding quantities are derived,
- PO revisions are immutable,
- Supplier Receipt, Warehouse Issue, Site Delivery Receipt and Site Receipt
  Confirmation are distinct,
- delivered, accepted, short, damaged and rejected quantities reconcile,
- delivery documents and photos attach to the receipt,
- original MR status updates from downstream quantities,
- critical transitions are transactional and audited.

Deliver in smaller sub-PRs if necessary. Add state-machine, RLS and integration
tests before enabling the feature flag.
```

## Review prompt for every PR

```text
Review this PR against AGENTS.md and docs/nexus-v7.

Look specifically for:
- data migration loss,
- impossible workflow states,
- commercial data leakage,
- RLS gaps,
- duplicate or non-idempotent stock movements,
- missing audit events,
- responsive regressions,
- hard-coded strings,
- insufficient tests,
- changes to unrelated modules.

Return blocking issues first, with exact file and line references.
```
