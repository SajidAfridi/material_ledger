# Yorks Nexus V7 — Implementation Source of Truth

This folder is the working contract for the Yorks Nexus transformation. The
approved V7 design is the experience target; the existing Flutter application,
Riverpod state, GoRouter navigation, local outbox and Supabase/Postgres seam are
the implementation boundary.

## Authority order

When documents disagree, resolve them in this order:

1. `AGENTS.md` — repository-wide implementation and safety rules.
2. `PRODUCT_DECISIONS.md` — frozen workflow, quantity, approval and receipt
   semantics.
3. `SRS_V7_ALIGNMENT.md` — explicit resolution of legacy SRS conflicts.
4. `design/` — approved V7 visual target, subject to the frozen product
   decisions above.
5. `NEXUS_V7_IMPLEMENTATION_PLAN.md` — domain and delivery direction.
6. `CODEX_TASKS.md` — one scoped implementation task at a time.
7. `NEXUS_V7_ACCEPTANCE_CHECKLIST.md` — release acceptance gates.
8. `CURRENT_TO_TARGET_GAP_ANALYSIS.md` — evidence from the current repository.
9. `ADR-001-SUPABASE-POSTGRES-SOURCE-OF-TRUTH.md` — backend decision and guardrails.
10. `TEST_STRATEGY.md` — required proof for models, workflows, security and UI.

The existing SRS and legacy module behaviour remain compatibility constraints.
They do not override a frozen V7 decision. Every known conflict is recorded in
`SRS_V7_ALIGNMENT.md`; implementation must stop if a new conflict is found.

## Controlled implementation status — 24 July 2026

Batch 0A, 0B, 1, 2, 3, 4, 5, 6, 7 and 8 are complete:

- approved implementation pack copied into this folder;
- approved HTML prototype, source files and desktop/mobile previews copied into
  `design/`;
- repository-level `AGENTS.md` added;
- current-to-target audit completed;
- Supabase/Postgres source-of-truth decision recorded;
- test and verification strategy recorded;
- CI quality gate and generated-build analysis exclusion added;
- V7 flags added with all modules off by default;
- production backend startup, trusted role resolution, local credentials and
  legacy sensitive-payload paths fail closed.
- Project v2 supports stable parties, multiple buildings and backward-compatible
  legacy migration.
- commercial records are separated and protected through Flutter payload
  boundaries plus live Supabase RLS/triggers.
- a live Procurement identity now has canonical role/capability claims.
- the approved V7 tokens, responsive page shell and reusable
  status/action/audit components are implemented with desktop/mobile goldens.
- the shared three-stage Project creation flow now provides per-user draft
  recovery, explicit responsibility, multiple physical buildings, a common
  project scope, optional document metadata and role-aware creation behind its
  default-off flag.
- the feature-flagged Project workspace now connects Overview, Material Plan,
  Requests, Procurement readiness, document metadata and Activity while showing
  current owner, concrete blockers and unweighted readiness.
- the feature-flagged HVAC catalogue now uses Admin-managed categories and
  approved units, deterministic legacy master IDs, role-safe stock/cost
  visibility, responsive Finder-style browsing, custom-unit review and CSV
  download.
- the isolated reusable MaterialLineGrid now enforces the exact column
  contract, protected commercial payload, smart rows, keyboard/Excel paste,
  structured HVAC sizes, role-safe CSV, 500-row virtualization and a separate
  mobile editor behind a debug-only diagnostic route.
- the Phase 1 vertical slice now connects Engineer planning, Procurement
  advisory source review, comments, immutable versions, Engineering
  approval/changes and atomic project activation through normalized,
  project-scoped Supabase tables.
- project-specific physical progress stages can now be configured and audited
  without changing operational readiness or workflow state.

No transformed V7 workflow is enabled by default. See
`IMPLEMENTATION_STATUS.md` for verification evidence, rollout controls and
production operations that require controlled infrastructure work.

Legacy architecture notes outside this folder may still describe Firebase or
Firestore. They are historical records, not implementation authority. Supabase
Auth/Postgres are the application backend; Firebase is FCM transport only.

## Product north star

Nexus should feel calm and obvious at the surface while remaining strict and
traceable underneath:

- reduce stress before adding cleverness;
- show information before decoration;
- use familiar, Excel-like material rows and predictable actions;
- make actor, role, timestamp, revision and current owner visible;
- keep one connected lifecycle from project and request through receipt;
- enforce commercial visibility and workflow authority server-side;
- preserve offline drafts and legacy records without silently discarding data.

## Approved experience map

The prototype defines role-aware experiences for Engineer, Procurement and
Admin. The central connected chain is:

`Project → Building → Material Plan / Material Request → Procurement Package → RFQ → Supplier Quotation → Purchase Order → Delivery Receipt`

The Engineer experience is mobile-friendly and action-led. Procurement receives
an information-dense desktop workspace for fulfilment, sourcing, quote
comparison, order creation and receiving. Admin controls capabilities,
reference data and oversight. Downstream records must carry links to their
source records rather than asking users to type the same material lines again.

## How to use this folder

Every implementation task must:

1. name the exact V7 task or PR slice being attempted;
2. read `AGENTS.md` and the relevant design and acceptance sections;
3. identify model, provider/repository, Supabase/RLS and UI impact before code;
4. add tests with the change, including negative permission tests when access
   is involved;
5. run the required checks and record migration/rollback notes;
6. leave unrelated modules unchanged.

Batch 0A freezes the product contract. Batch 0B establishes CI, feature flags,
fail-closed production configuration and immediate security guards. Domain
schema changes start only after both batches pass their verification gate.
