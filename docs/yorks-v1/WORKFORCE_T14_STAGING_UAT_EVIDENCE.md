# Workforce T14 Dedicated Staging UAT Evidence

Status: **immutable staging preview deployed; manual UAT not started/not passed**
Decision date: 31 August 2026
Preflight observed at: `2026-08-31T11:18:50Z`
Latest design preview deployed at: `2026-09-01T08:38:43Z`
Approved Workforce source fingerprint:
`3914f3ec6740b5986724ae8dbc44b70f9944ec580fedfd3a526b3605866bf613`

## Decision history and boundary

The product owner initially waived T14. That earlier decision is retained as a
historical fact: no staging UAT was performed or passed under the waiver. Later
on 31 August 2026 the product owner explicitly withdrew the waiver, confirmed
T01 through T13 as independently accepted and reinstated T14 as a mandatory
pre-release gate.

Still later on 31 August 2026, after authorizing and creating the dedicated
staging project, the product owner directed that T14 UAT be set up next but
explicitly authorized production immediately. This is recorded as a release
exception. T14 remains not performed/not passed, and production smoke evidence
must not be substituted for its named-persona/manual witness.

T14 authorizes only an immutable Workforce-enabled release candidate deployed
to an unaliased non-production web URL and an explicitly configured dedicated
non-production Supabase project. It does not authorize a GitHub main commit or
push, a production Supabase migration, production flag enablement, Vercel alias
promotion or any post-T14 production release.

## Immutable candidate and staging identity

| Evidence | Result |
|---|---|
| Repository baseline | Workforce release source `a8f31d8466bc115a2fdab894f5c261381adc4a17` is committed and pushed to GitHub `main`. |
| Immutable T14 source fingerprint | **Formed locally, not pushed.** Source commit `c3065c0ef7309832d8ac8c1c50c40b665539b63e` matches the accepted daily-timesheet concept while retaining the server-confirmed roster, split-allocation and review/save boundaries. T14 authority still excludes a GitHub push. |
| Web/APK artifact hashes | **Formed.** Web `main.dart.js` SHA-256 `c15bf51c5ad095d2589f4c3be556137764f4de741712d06d48ef76ad4a4e0bb4`; manifest `21a31bb90bbe6d13de1723e7e954257ce2d8c62206ceaeb64733aae4bf90c2ff`; service worker `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c`. Android verification APK `95d7d84ca6d5387aa64eae2c3c6ab65fa28d4b985ce9c40f5824eb21d902a84f` used the explicit ephemeral CI-signing lane and is not publishable. |
| Staging Supabase project | **Prepared.** `iqltcyimlqtcwyzlemwx` (`yorks-r35-staging`), Frankfurt `eu-central-1`; distinct from rejected shared/production ref `czykuksmlwswjsgotrpo`. |
| Staging configuration | **Prepared locally.** Ignored `.r35.staging.env` resolves secrets from macOS Keychain and enables Workforce only for staging/release commands. No secret is recorded here. |
| Vercel Preview configuration | **Bound into the verified static artifact.** The ignored staging configuration enabled Workforce and Accounts and selected only staging ref `iqltcyimlqtcwyzlemwx`; remote `main.dart.js` contains that ref once and the production ref zero times. No Vercel environment secret was added. |
| Approved named personas | **Not approved for UAT.** Deterministic technical seed identities exist only for database-test execution; they are not the named human UAT persona/witness set required by T14. |
| Staging deployment URL/ID | **Ready and unaliased.** `dpl_9c8RUn2hvnGaN7KzgD7aqcnT2W7q` at `https://yorks-r35-7o0hkwejn-sajid-alis-projects-0ec775a2.vercel.app`. Root and Workforce overview/attendance/timesheets/administration deep routes returned HTTP 200. `main.dart.js`, manifest and service worker byte-matched the local build; after removing Vercel's preview-toolbar line, the served `index.html` also byte-matched. |
| Staging migration ledger | **Aligned through the current tracked ledger.** Verification on dedicated ref `iqltcyimlqtcwyzlemwx` showed every local migration through `20260831183000` present remotely. `finalize-document-upload` version 1 remains active with JWT verification and bundle hash `14a55d912fa2a416b74d6e32923ee4ee4ad5b019c72ca2febec19fd107bf7194`. |
| Production state | **Released under the explicit exception.** Production ref `czykuksmlwswjsgotrpo` is aligned through `20260831090940`; verified deployment `dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g` is promoted at `yorks-r35.vercel.app`. This is not T14 evidence. |

The local `.r35.env` is not staging authority and was not read as a credential
source. Local pgTAP fixtures and the historic shared project cannot substitute
for the dedicated hosted environment or named-persona witness.

## Required named persona matrix

Role labels never authorize Workforce commands by themselves. The release
owner must supply named non-production accounts with exact server-controlled
roles, capabilities and dated responsibility/target scopes:

| Persona class | Required authority and separation evidence |
|---|---|
| Admin configuration/reopen/dashboard | Exact active Admin plus the effective capability and organization responsibility required by each command. Creates workers/teams/calendars/assignments, observes the dashboard and performs audited reopen. |
| Site Engineer maintainer/supervisor | Exact active Site Engineer with `workforce.view`, attendance/timesheet maintain capabilities and exact worker/team/project/Building/Common/internal-location responsibility for the test dates. Prepares, corrects and submits; cannot review or approve by role alone. |
| Configured reviewer | A distinct named actor in the accepted approval chain with `workforce.timesheets.review`; controlled correction additionally requires `workforce.timesheets.correct_during_review`, and Verify & Forward requires `workforce.timesheets.verify`, all with complete dated scope. |
| Configured final approver | A distinct named Senior Mechanical Engineer or Project Manager selected in the test approval chain with `workforce.timesheets.final_approve` and complete dated scope. Must not be the maintainer or reviewer. |
| Authorized reopen actor | A different fully scoped actor with `workforce.periods.reopen`; the source's Admin reopen scenario remains explicit and audited. |
| Unauthorized/negative actors | Named Procurement role-only, Site Engineer role-only/wrong-scope, inactive identity, expired/revoked capability and expired/revoked responsibility cases. Cross-project, Building/Common and internal-location target negatives are required. |

No account names, credentials or approval-chain assignments were invented.
Concrete persona identities must be supplied and approved for the dedicated
staging project before UAT begins.

## Approved 35-scenario staging matrix

All results below are **deferred — not executed** because the owner directed
production before immutable-candidate and named-persona/manual UAT. A deferred
scenario is not a failure of product behavior and is never a pass.

| # | Required source scenario | Result |
|---:|---|---|
| 1 | Admin creates a worker without creating an Auth user. | Deferred — not run. |
| 2 | Admin creates a team and working calendar. | Deferred — not run. |
| 3 | Admin assigns workers to a Site Engineer. | Deferred — not run. |
| 4 | Supervisor opens today's roster. | Deferred — not run. |
| 5 | Supervisor marks most workers Present in bulk. | Deferred — not run. |
| 6 | Supervisor records one Absent worker. | Deferred — not run. |
| 7 | Supervisor records one Sick Leave worker with an attachment. | Deferred — not run. |
| 8 | Supervisor allocates one worker across two buildings. | Deferred — not run. |
| 9 | Supervisor allocates another worker to Warehouse/internal work. | Deferred — not run. |
| 10 | Supervisor records overtime with a reason. | Deferred — not run. |
| 11 | Daily validation detects an invalid overlap. | Deferred — not run. |
| 12 | Supervisor corrects the overlap. | Deferred — not run. |
| 13 | Worker moves to another project mid-month. | Deferred — not run. |
| 14 | Historical days retain the original assignment. | Deferred — not run. |
| 15 | Month validation detects missing days. | Deferred — not run. |
| 16 | Supervisor completes and submits the month. | Deferred — not run. |
| 17 | Supervisor cannot edit ordinary submitted records. | Deferred — not run. |
| 18 | Reviewer sees exceptions first. | Deferred — not run. |
| 19 | Reviewer returns one worker/date for correction. | Deferred — not run. |
| 20 | Supervisor corrects and resubmits. | Deferred — not run. |
| 21 | Reviewer verifies. | Deferred — not run. |
| 22 | Final approver approves and locks. | Deferred — not run. |
| 23 | Ordinary users cannot edit the locked period. | Deferred — not run. |
| 24 | Authorized Admin reopens it with a reason. | Deferred — not run. |
| 25 | Corrected period completes the approval lifecycle again. | Deferred — not run. |
| 26 | Both approved revisions remain available. | Deferred — not run. |
| 27 | Worker monthly Excel export is correct. | Deferred — not run. |
| 28 | Project workforce report is correct. | Deferred — not run. |
| 29 | PDF Preview, Download and Print match. | Deferred — not run. |
| 30 | Unauthorized users are denied by RLS. | Deferred — not run. |
| 31 | Network loss after Submit does not create a duplicate submission. | Deferred — not run. |
| 32 | Mobile daily entry works. | Deferred — not run. |
| 33 | Tablet roster works. | Deferred — not run. |
| 34 | Admin Workforce overview reports real exceptions. | Deferred — not run. |
| 35 | Audit history shows all important actions. | Deferred — not run. |

## Additional T14 acceptance matrix

The same candidate must also prove the repository-frozen boundaries below.
Every item is currently deferred/not run:

- flag-on authorized routes, flag-off and unauthorized deep-link denial;
- worker/calendar/assignment mutation authority and no Auth user coupling;
- past/current attendance plus the calendar-local denial of every future work
  date for creation and correction;
- roster reads with no write effect and atomic Save Day conflict/idempotency;
- allocation target redaction and exact project/Building/Common/internal target
  authorization;
- monthly validation, warnings/blockers and stale/concurrent revalidation;
- submit/return/correct/verify/final-approve/lock/reopen separation of duties;
- discussion, mentions, controlled evidence and durable notifications;
- protected Excel/PDF generation and issue receipts with identical Preview,
  Download and Print bytes;
- Supervisor, Management and Admin dashboards with no unauthorized detail;
- desktop/tablet/mobile, English/Arabic/Urdu/Hindi, RTL, keyboard/focus,
  semantics, reduced motion, text scaling and non-color state cues;
- offline draft versus server-confirmed transitions, lost-response retry,
  stale/conflict/uncertain outcomes and cache purge after capability,
  responsibility or identity revocation;
- no payroll, salary, bank, commercial-value, service-role or credential leak;
  and
- non-regression of People/HR, Leave, Auth, Projects, BOQ, Material Requests,
  Inventory, Returns, Accounts, Team Chat, Rentals, Configuration, User
  Management and Audit.

## Findings and witness status

| Category | Result |
|---|---|
| P0 product defects | Not assessed; hosted UAT did not start. |
| P1 product defects | Not assessed; hosted UAT did not start. |
| Release-blocking prerequisite `T14-ENV-001` | Resolved: dedicated staging project/config and full migration/Function baseline exist. |
| Release-blocking prerequisite `T14-ID-001` | Approved named non-production personas and approval chain are absent. |
| Release-blocking prerequisite `T14-RC-001` | Resolved: local immutable source, staging-bound web/APK hashes and an unaliased Ready preview are recorded above. |
| Human witness | Not started. Automation cannot waive the required manual scenarios. |

## Staging demonstration fixture — 1 September 2026

At the owner's request, a clearly labelled, non-production demonstration
dataset was added only to dedicated staging project
`iqltcyimlqtcwyzlemwx`. The guarded operator fixture is
`tool/workforce-staging-demo.sql`, invoked through
`tool/seed-workforce-staging-demo.sh`. Both the shell boundary and SQL guard
refuse the production/shared project and any database that is not the exact
seven-persona technical staging target.

The committed staging result contains:

- 2 `STAGING DEMO` projects with Common and Building scopes;
- 3 `STAGING DEMO` teams covering project and internal Workshop work;
- 10 `DEMO-W###` workers across Yorks employee, temporary, agency and
  subcontractor worker types;
- 1 Asia/Dubai six-day calendar and one 06:30 day shift;
- 270 server-confirmed attendance days, including Present, Absent, Sick Leave,
  Annual Leave and Official Leave examples;
- 266 current allocation sets with project, Building, internal Workshop,
  overtime and one split project/Workshop example; and
- 6 immutable August/September monthly validation runs in
  `ready_for_review`, including retained warnings suitable for review testing.

Protected projection checks then proved:

- Admin: 10 workers, 1 calendar, 1 shift and 2 administration projects;
- Site Engineer: 10 workers, 10 current-day entries and the affirmative
  `can_complete_today_attendance` action flag;
- Project Manager: 10 workers and 2 active demo projects in the management
  overview; and
- 36 effective Workforce grants plus three explicit organization
  responsibilities across the Project Engineer, Site Engineer and Project
  Manager technical personas.

Running the seed command a second time retained the exact same 2/3/10/270/266/6
counts. This proves the operator fixture is repeat-safe and does not overwrite
subsequent UI edits because critical facts replay through their original
idempotency keys.

This demonstration fixture is technical staging evidence only. The technical
personas are not approved named users, no human scenario was witnessed, and
none of the 35 deferred T14 scenarios is reclassified as passed.

## Required owner inputs to resume

1. Provide and approve named non-production accounts for every persona class above,
   including concrete reviewer/final-approver selection and negative actors,
   without placing passwords or service-role credentials in Git or evidence.
2. Name the required human UAT witness/release owner.

After these inputs exist, T14 continues on the recorded immutable preview with
the named-persona/manual scenario matrix. No result from the deferred UAT may
be treated as production evidence or vice versa.

## Containment and rollback

Staging rollback is containment: the dedicated project is isolated and has no
production alias or production data. If a later T14 deployment fails, stop the
unaliased preview, retain diagnostic evidence and reset/discard only the
approved dedicated staging project. The separately authorized production
release must use its own recorded rollback point and is not T14 evidence.
That release and rollback evidence is recorded in
[`WORKFORCE_PRODUCTION_RELEASE_EVIDENCE.md`](WORKFORCE_PRODUCTION_RELEASE_EVIDENCE.md).
