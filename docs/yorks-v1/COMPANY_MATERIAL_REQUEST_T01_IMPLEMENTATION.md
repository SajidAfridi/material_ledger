# Company Material Requests T01 — protected create and submit

Status: **implementation complete; staging acceptance pending**

This is the first approved vertical slice from the Company Material Requests
[lifecycle review](COMPANY_MATERIAL_REQUEST_LIFECYCLE_REVIEW.md). It creates a
company-owned request without a project, saves it as a private draft and submits
it to one independently configured company approver. It does not alter any
project Material Request table, route, RPC or lifecycle state.

## Delivered boundary

The slice introduces a separate Company Material Request aggregate:

```text
authorized requester
  -> private draft (company category + responsible unit + beneficiary + receiver)
  -> independently resolved company approval handoff
```

The requester chooses only from server-returned effective category/unit,
beneficiary and receiver authorizations. The server, not the client, resolves
the current primary or alternate approver, rejects a requester/beneficiary/
receiver conflict and snapshots the resulting policy version and approver at
submission. `CMR-` numbering, submission event and approver notification are
created once under an idempotency key.

The desktop and mobile entry points appear only when
`YORKS_V1_COMPANY_MATERIAL_REQUESTS=true`; the flag defaults to `false`. A
configured requester without a normal project-register capability may open the
company composer, but every query and mutation remains protected by the
company-specific server authorization.

## Explicit exclusions

This is intentionally not an alternate project request or a stock shortcut.
It ships none of the following:

- approval decision, arrangement, reservation, dispatch, receipt, issue
  history, replacement, return or company register views;
- automatic role-to-company-authority grants, category/unit seeds, or an
  invented corporate approval matrix;
- project, BOQ, warehouse, commercial or project-membership access.

Company category/unit authorizations and primary/alternate approval routes must
be published by a separately authorized configuration release before the flag
is enabled. With no effective configuration the only server result is an empty
draft-option list; with a missing or conflicted route, submission fails closed
and retains the draft.

### Dedicated staging demonstration policy

`tool/seed-company-material-request-staging-demo.sh` is a repeatable,
confirmation-gated operator fixture for the dedicated technical-persona staging
project only. It publishes one visibly labelled **STAGING DEMO — Safety & PPE**
category/unit combination, named requester/beneficiary/receiver grants and an
independent Admin/Senior Mechanical Engineer approval route. It refuses
production, any unknown target and any non-technical persona dataset. It is not
a migration, it creates no Company Material Request, and it must never be used
as a production authorization matrix.

## Data and authorization contract

The additive migration
[`20260912163558_yorks_company_material_requests_foundation.sql`](../../supabase/migrations/20260912163558_yorks_company_material_requests_foundation.sql)
owns categories, responsible units, effective per-person authority, effective
approval routes, requests, lines, reference counters and append-only events.
All tables have RLS enabled and direct `anon`/`authenticated` grants revoked.
Only narrow authenticated RPCs are granted; configuration relations and helper
functions remain service-role-only.

The connected command accepts an exact payload shape, checks the authenticated
active actor and every selected authorization again, locks and versions a
private draft, and atomically creates the company approval handoff. Retrying
the same atomic command returns its original response without rewriting a
submitted record or duplicating a reference, event or notification.

Approval preflight is subject to the same effective requester, beneficiary and
receiver checks. It cannot disclose a route for a person outside the selected
policy combination; submission repeats all checks at commit time.

## Validation and rollback

`supabase/tests/database/yorks_v1_company_material_requests_foundation.test.sql`
proves requester visibility, beneficiary narrowing, independent approver
resolution, private-draft confidentiality, direct-table denial, submission
snapshots, idempotent retry and atomic rollback on a self-conflicted route.

The migration is additive and contains no seed data or project-MR rewrites. To
roll the unfinished slice back before it is enabled, keep the flag false and
remove the unreferenced T01 objects only through a reviewed corrective
migration. Once any production request exists, preserve its records and revoke
the flag/authorization route instead of deleting history.

## Completion evidence

The approved T01 implementation boundary is complete in code:

- both additive T01 migrations are present in the linked staging migration
  ledger;
- the feature-gated desktop and mobile entry points open the focused company
  composer without changing the project Material Request flow;
- the composer supports protected private-draft save and atomic submission,
  shows only server-returned authorization choices, and guards unsaved changes
  on Cancel, Back and browser/system Back;
- repository contract tests verify fail-closed rollout/connectivity behavior,
  the narrow option/preflight RPCs and the exact company-only submission
  payload; and
- desktop and 360 px visual tests cover the composer and protected-exit states.

Staging acceptance is a separate release gate, not unfinished T01 scope. It
requires an authenticated configured requester to create, save and submit a
request, followed by confirmation that the independently resolved approver can
see the resulting notification. The pgTAP suite remains the database authority;
if the local Docker-backed Supabase harness is unavailable, record that test as
unavailable rather than treating it as passed.
