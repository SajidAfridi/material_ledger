# Company Use production release preparation — 27 September 2026

Status: **enablement authorized; awaiting real production policy configuration**.
No production deployment, data change, schema change or grant was performed by
this preparation. The current production release remains PR #30.

## User request and implementation

The product owner explicitly requested publishing Company Use in production.
The release removes the environment-specific frontend pause and lets the
existing `YORKS_V1_COMPANY_MATERIAL_REQUESTS` flag control production exactly as
it controls staging. The tracked default stays false. Request dependencies,
protected participant authorization, approval separation, quantity constraints
and all existing trusted commands remain unchanged. The obsolete production
pause test is replaced by a deployment-flag test.

Production base: `486fea7efbb06945e00b7e9c494f3e2e53b22da1`.
The inspected live JavaScript hash is
`15e5cdf0d48eb9d6fa0bb21d73411ed43a199f7ef573c031ff4072ff10855929`.
The isolated release branch is
`codex/yorks-company-use-production-20260927`. Unrelated primary-worktree edits
are preserved.

## Configuration required before enablement

Read-only production inspection found **zero categories, responsible units,
authorizations, approval routes and Company requests**. Staging has one visibly
labelled demo category/unit and technical-persona grants. Those demo grants
are not a production policy and must never be copied into production.

The release owner must specify real categories and responsible units plus the
people authorized as requesters, approvers, receivers and beneficiaries.
Beneficiaries require active Yorks logins. Approval requires the existing dated
category/unit grant and exact approved role; an approver cannot also receive
or benefit from that request. Permission assignments must be attributable and
must not be inferred from project membership or broad role labels.

This is the existing configuration boundary in
[T01](COMPANY_MATERIAL_REQUEST_T01_IMPLEMENTATION.md), not a request for another
deployment approval. Missing configuration remains fail-closed.

## Verification completed during preparation

- Explicit production flag on, flag off and disabled-request dependency checks
  passed. The generic flag default remains off.
- Analyzer, changed-Dart formatting and diff checks passed.
- 118 focused Company, register, repository, operation, responsive, router and
  analytics tests passed, including desktop and 360px rendering.
- Full Flutter suite: 1,666 passed, 270 failed. All failing names were present
  in the preceding production-source run; there are no new failing names. The
  obsolete production-pause test accounts for the one removed failure. The
  complete Flutter gate remains red; unrelated baselines were not rewritten.
- Dedicated staging Auth/REST lifecycle: 30 checks passed with technical
  personas, including private-draft denials, independent approval, Procurement
  revision/reapproval, external-source dispatch, receiver confirmation,
  beneficiary handover, immutable issue evidence, closure and cancellation
  retries. Synthetic records are labelled `STAGING RELEASE` and retained as
  closed/cancelled evidence. This is not named-employee/manual UAT.
- All 54 Company-related function definitions match staging and production.
  The 12 relevant migration ledger entries match. All 23 Company relations
  have RLS; ordinary client writes and anonymous reads are denied. None of the
  54 functions permits anonymous execution. No database migration is required
  for this frontend flag change.
- Company-enabled CI web build passed its startup budget: 10,354,389 raw bytes
  and 2,787,138 gzip bytes for the entry JavaScript. This uses `ci.invalid` and
  is not a hosted production artifact.

The previous PR #30 source already passed complete PostgreSQL 15 and 17.6
database suites (111 files / 3,140 assertions each). No SQL definition changes
are introduced here; that prior gate and the new live fingerprint/permission
checks have distinct evidence boundaries.

## Remaining release work and rollback

Publish only the explicitly supplied real policy, verify its effective
participant/approver resolution, and verify the final Company-enabled staging
and production artifacts before promotion. The broader
[T06](COMPANY_MATERIAL_REQUEST_T06_END_TO_END_HARDENING.md) return-register and
controlled-document acceptance boundaries remain explicit. The known Flutter
baseline failures are not a full-suite pass.

Rollback is the existing Company flag off and the preceding compatible web
artifact. Preserve all Company and Project IDs, drafts, approvals, reservations,
movements, dispatches, receipts, handovers, returns, immutable issue evidence
and audit history. Do not delete business evidence or revert schema.
