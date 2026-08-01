# Yorks V1 R35 — Implementation Source of Truth

Status: **approved re-baseline**
Approved: 1 August 2026
Current delivery stage: **Batch 4 complete; Batch 5 — Material Request vertical
slice — is the next dependency under the Rev 2.0/R35 authority**

This folder is the repository-local contract for the Yorks V1 Procurement
Control and Inventory turnaround. Rev 2.0 supersedes the overlapping Nexus V7
product workflow. The existing V7 implementation remains valuable evidence and
a reuse source, but it no longer defines V1 behavior.

## Authority order

1. Yorks V1 SRS and Rapid Development Plan, Rev 2.0
2. Effective final R35 HTML behavior for non-conflicting UI and interaction
3. Yorks V1 Sol AI Execution Pack for delivery sequencing
4. [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) for resolved ambiguities
5. Current repository implementation as the reuse and migration boundary
6. `docs/nexus-v7/` as historical evidence and inherited non-conflicting
   security, migration, localization and non-regression safeguards

See [`SOURCE_OF_TRUTH.md`](SOURCE_OF_TRUTH.md) for source fingerprints and the
explicit V7-to-V1 conflict resolution.

## Mandatory documents

| Document | Purpose |
|---|---|
| [`SOURCE_OF_TRUTH.md`](SOURCE_OF_TRUTH.md) | Authority, source fingerprints and superseded rules |
| [`PRODUCT_DECISIONS.md`](PRODUCT_DECISIONS.md) | Frozen workflow, data and ambiguity resolutions |
| [`CURRENT_TO_TARGET_GAP_ANALYSIS.md`](CURRENT_TO_TARGET_GAP_ANALYSIS.md) | Exact current code reuse, gaps and risks |
| [`ARCHITECTURE_AND_SECURITY_CONTRACT.md`](ARCHITECTURE_AND_SECURITY_CONTRACT.md) | Flutter/Supabase boundary and trusted data flow |
| [`STATE_RPC_RLS_MATRIX.md`](STATE_RPC_RLS_MATRIX.md) | States, server commands, locks, idempotency and access |
| [`R35_UI_CONTRACT.md`](R35_UI_CONTRACT.md) | Role navigation, screens, components and responsive behavior |
| [`MIGRATION_AND_ROLLBACK_PLAN.md`](MIGRATION_AND_ROLLBACK_PLAN.md) | Additive migration, reconciliation, quarantine and rollback |
| [`TEST_AND_ACCEPTANCE_PLAN.md`](TEST_AND_ACCEPTANCE_PLAN.md) | Test layers, 25 scenarios and web/Android evidence |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | Dependency-ordered Batches 0–10 |
| [`BATCH_00_COMPLETION.md`](BATCH_00_COMPLETION.md) | Re-baseline changes, verification and known blockers |
| [`BATCH_02_COMPLETION.md`](BATCH_02_COMPLETION.md) | Identity, projects, audit/RLS hardening and verification |
| [`BATCH_03_COMPLETION.md`](BATCH_03_COMPLETION.md) | Editable BOQ groups, responsive spreadsheet and verification |
| [`BATCH_04_COMPLETION.md`](BATCH_04_COMPLETION.md) | Excel BOQ round-trip, protected import command and verification |

## Product north star

- Calm before clever.
- Information before decoration.
- Speed through familiarity.
- Confidence through transparency.
- Precision over personality.
- One source of truth.
- Familiar spreadsheet behavior for engineers without weakening server rules.

## Canonical operational chain

`Project -> BOQ -> MR Draft -> Submit -> Arrange/Reserve -> Project Engineer Approval -> Dispatch -> Receipt Review -> Delivery Order -> Return`

Accounts and the full RFQ/quotation/PO suite are not part of V1. Configuration,
Rentals, User Management, Audit Trail, Duct Sizer and ESP Calculator remain in
place and receive regression coverage rather than redesign.

## How to execute a batch

1. Name the exact batch and acceptance slice.
2. Read `AGENTS.md` plus this README, source-of-truth and product decisions.
3. Read the task-relevant architecture/UI/migration/test sections.
4. Audit exact current files and symbols before editing.
5. Implement only the approved slice behind a default-off rollout boundary.
6. Add migration/rollback notes, negative RLS tests and idempotency proof where
   applicable.
7. Run narrow checks and the complete applicable gate.
8. Report files, migrations, commands, evidence and limitations.

The rapid three-day grouping is a client-testable demo target. It is not a
waiver for RLS, transaction, migration, Android or production hardening.
