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

## Foundation status — 24 July 2026

Batch 0A and Batch 0B are complete:

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

No V7 domain schema or user-visible workflow has started. See
`IMPLEMENTATION_STATUS.md` for verification evidence and production operations
that require controlled infrastructure work.

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
