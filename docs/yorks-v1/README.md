# Yorks V1 R35 — Implementation Source of Truth

Status: **approved re-baseline**
Approved: 1 August 2026
Current delivery stage: **Batches 0–9 complete; Batch 10 local release
evidence passed. Staging acceptance, protected Android signing and deployment
remain release-owner activities.**

> **HISTORICAL BATCH MATERIAL — NOT THE CURRENT BUILD CONFIGURATION.** The
> batch-completion files record the original incremental rollout and therefore
> may say that an individual flag was default-off. The canonical R35 build
> configuration below is current: the accepted, complete Yorks chain is on by
> default and legacy Nexus flags are disabled.

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
| [`R38_UI_CONTRACT.md`](R38_UI_CONTRACT.md) | Rendered R38 visual contract and approved production exceptions |
| [`V01_VISUAL_EVIDENCE.md`](V01_VISUAL_EVIDENCE.md) | Workspace shell, empty Overview and Project Creation convergence evidence |
| [`MOBILE_UI_IMPLEMENTATION_GUIDE.md`](MOBILE_UI_IMPLEMENTATION_GUIDE.md) | Mobile-only authority split, guard, state/permission checklist and evidence workflow |
| [`MOBILE_UI_SCREEN_LEDGER.md`](MOBILE_UI_SCREEN_LEDGER.md) | Delivery state for all 52 mobile design references |
| [`FIREBASE_MESSAGING_SETUP.md`](FIREBASE_MESSAGING_SETUP.md) | Firebase Cloud Messaging client, web worker and operator credential setup |
| [`evidence/mobile-batch-02/README.md`](evidence/mobile-batch-02/README.md) | Verified local evidence index for mobile references 12–21 |
| [`MIGRATION_AND_ROLLBACK_PLAN.md`](MIGRATION_AND_ROLLBACK_PLAN.md) | Additive migration, reconciliation, quarantine and rollback |
| [`TEST_AND_ACCEPTANCE_PLAN.md`](TEST_AND_ACCEPTANCE_PLAN.md) | Test layers, 25 scenarios and web/Android evidence |
| [`IMPLEMENTATION_PLAN.md`](IMPLEMENTATION_PLAN.md) | Dependency-ordered Batches 0–10 |
| [`BATCH_00_COMPLETION.md`](BATCH_00_COMPLETION.md) | Re-baseline changes, verification and known blockers |
| [`BATCH_02_COMPLETION.md`](BATCH_02_COMPLETION.md) | Identity, projects, audit/RLS hardening and verification |
| [`BATCH_03_COMPLETION.md`](BATCH_03_COMPLETION.md) | Editable BOQ groups, responsive spreadsheet and verification |
| [`BATCH_04_COMPLETION.md`](BATCH_04_COMPLETION.md) | Excel BOQ round-trip, protected import command and verification |
| [`BATCH_08_COMPLETION.md`](BATCH_08_COMPLETION.md) | Delivery Orders, returns and verification |
| [`BATCH_09_COMPLETION.md`](BATCH_09_COMPLETION.md) | Controlled documents, audit and retained-module coverage |
| [`BATCH_10_RELEASE_READINESS.md`](BATCH_10_RELEASE_READINESS.md) | Local release evidence, staging matrix and controlled-cutover runbook |
| [`R35_STAGING_DEPLOYMENT.md`](R35_STAGING_DEPLOYMENT.md) | Dedicated staging deployment and controlled-document witness |
| [`RELEASE_NOTES_DRAFT.md`](RELEASE_NOTES_DRAFT.md) | Release content and conditions for the staging sign-off |

## Product north star

- Calm before clever.
- Information before decoration.
- Speed through familiarity.
- Confidence through transparency.
- Precision over personality.
- One source of truth.
- Familiar spreadsheet behavior for engineers without weakening server rules.

## Canonical R35 build configuration

Yorks V1 is the production experience by default. Supabase targets are
explicit: an unconfigured build stops rather than falling back to a shared
remote project. Configure the intended local, staging or production backend
once in an ignored file, then use the launcher without manual dart-defines:

```bash
cp tool/r35.env.example .r35.env
# Edit .r35.env with the chosen target's HTTPS URL and publishable key.
./tool/r35.sh run
./tool/r35.sh build-web
./tool/r35.sh build-apk
```

Use a separately named ignored configuration file for staging/production via
`R35_CONFIG_FILE=.r35.staging.env` or `.r35.production.env`. The tracked
`../../tool/r35.sh` launcher always supplies the complete R35 flags; do not add
legacy `NEXUS_V7_*` flags to an R35 command.

## Canonical operational chain

`Project -> BOQ -> MR Draft -> Submit -> Arrange/Reserve -> Project Engineer Approval -> Dispatch -> Receipt Review -> Delivery Order -> Return`

Accounts is part of the current Yorks target subject to role permissions. The
full RFQ/quotation/PO suite is not part of V1. Configuration, Rentals, User
Management, Audit Trail, Duct Sizer and ESP Calculator remain in place and
receive regression coverage rather than redesign.

## How to execute a batch

1. Name the exact batch and acceptance slice.
2. Read `AGENTS.md` plus this README, source-of-truth and product decisions.
3. Read the task-relevant architecture/UI/migration/test sections.
4. Audit exact current files and symbols before editing.
5. Implement only the approved slice. Keep new work guarded until its
   acceptance gate passes; once accepted into the complete R35 chain, the
   canonical build configuration controls its default state.
6. Add migration/rollback notes, negative RLS tests and idempotency proof where
   applicable.
7. Run narrow checks and the complete applicable gate.
8. Report files, migrations, commands, evidence and limitations.

The rapid three-day grouping is a client-testable demo target. It is not a
waiver for RLS, transaction, migration, Android or production hardening.
