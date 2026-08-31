# Workforce Production Release Evidence

Status: **released and independently smoke-verified on 31 August 2026**

T14 boundary: **named-persona/manual staging UAT remains deferred, not
performed and not passed.** The product owner explicitly authorized this
production release as an exception and required T14 setup/UAT next. Automated
release and live-smoke evidence below is not T14 evidence.

## Source and rollback identity

| Evidence | Value |
|---|---|
| Release source commit | `a8f31d8466bc115a2fdab894f5c261381adc4a17` |
| GitHub `main` | Exact match to the release source commit after push |
| Pre-release source commit | `eeed1a294abfd686aada03791e605ff06a58124f` |
| Production Supabase ref | `czykuksmlwswjsgotrpo` |
| Dedicated staging ref | `iqltcyimlqtcwyzlemwx` |
| Previous Vercel deployment | `dpl_9RnX6xtiLQhocA1F2xGP5Q9uMgNz` |
| Previous Vercel URL | `https://yorks-r35-8l1lh1pse-sajid-alis-projects-0ec775a2.vercel.app` |

## Technical release gates

- `flutter pub get`: passed.
- changed-Dart format gate: 55 files checked, zero changed.
- `flutter analyze`: passed with no issues.
- focused Workforce and feature-flag Flutter gate: 152 tests passed.
- clean `supabase db reset`: passed through every tracked migration and seed.
- complete local `supabase test db`: 75 files and 2,326 assertions passed.
  The 500-worker T06 validation completed in 15,100.61 ms; the T13 local wall
  observations were overview 7,185.62 ms, roster 852.26 ms and queue 2,710.46
  ms. These are observations, not newly invented product SLAs.
- production-shaped web build: passed with Accounts and Workforce enabled.
- Android release-shaped technical build: passed and produced a 101.2 MB APK
  using the explicitly CI-ephemeral certificate. This is not a claim that a
  protected store-signing artifact was published.
- credential/backend scan: the web artifact contained the production ref,
  contained neither the staging/CI refs nor a credential-shaped secret, and
  no service-role credential was introduced into tracked source.

The previously accepted T13 full-suite baseline included unrelated legacy
golden/overflow failures; this release does not relabel that global suite as
green. The focused Workforce, analyzer, database and release-build gates above
are the observed release evidence.

## Production migration evidence

Before mutation, the linked production ledger matched local history through
`20260829110327`. The reviewed dry run contained exactly these 17 additive
Workforce migrations and no seed or role operation:

- `20260829225746` through `20260830090445` — T01–T04 foundation,
  calendar/retained-history, attendance/future-date and allocation authority;
- `20260830101500` and `20260830111341` — T05 roster plus authority/aggregation
  bounds;
- `20260830120427`, `20260830140235` and `20260830150826` — T06 validation and
  retained historical/team-month corrections;
- `20260830152937` — T07 review/approval lifecycle;
- `20260830215610` — T08 collaboration/evidence/notifications;
- `20260831000752` — T09 reports/exports;
- `20260831022915` — T10 dashboards; and
- `20260831090940` — T13 query and period-authority hardening.

All 17 applied successfully to `czykuksmlwswjsgotrpo`. The post-apply ledger
matched local through `20260831090940`, and a second dry run returned no
pending migration, seed or role operation. No production seed/persona data was
created. No Edge Function source changed in this release; the existing
production `finalize-document-upload` function remained ACTIVE version 1 with
JWT verification.

## Web artifact and deployment identity

| Artifact | SHA-256 |
|---|---|
| `index.html` | `31af1b140f0dcc6925e234d36061e376be99b608225ef060c1a7bf669639afb5` |
| `main.dart.js` | `7d3f799806b2a0545770fd44403e497cedf4a6a4d3e5dfa9a64178cd82516a65` |
| `flutter_bootstrap.js` | `cd1731f91810aa4b388a18417a9d2eae70d04f07350b9bb390629f5e423f13e6` |
| `manifest.json` | `21a31bb90bbe6d13de1723e7e954257ce2d8c62206ceaeb64733aae4bf90c2ff` |
| `flutter_service_worker.js` | `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c` |
| `firebase-messaging-sw.js` | `e8151cb276b7644627e5cefc1dc5e46b69ad38f952c4a734b1f81a9795437a1e` |

The verified 52-file `build/web` output was copied to an isolated directory;
Vercel extracted the 51 deployable static files without discovering the
repository. The unaliased candidate was:

- deployment: `dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g`;
- URL: `https://yorks-r35-asnb696qz-sajid-alis-projects-0ec775a2.vercel.app`;
- state: `READY`, target `production`.

Before promotion, `/`, the three Workforce routes, Projects, Material
Requests, Accounts and Team Chat each returned HTTP 200 with the exact local
`index.html` hash. The five runtime/PWA assets above also returned HTTP 200 and
matched local bytes. The remote configuration scan found the production ref
and zero staging/CI/credential-shaped matches.

After those checks, the candidate was promoted to
`https://yorks-r35.vercel.app`. The same eight route and five asset checks were
repeated on the alias and matched exactly. Vercel resolved the alias to
`dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g` in `READY` state.

## Rollback and remaining work

If the client release must be contained, promote previous deployment
`dpl_9RnX6xtiLQhocA1F2xGP5Q9uMgNz`; that restores the prior static client while
retaining diagnostic evidence. The production migrations are additive and
their history must not be deleted or rewritten. Keep the Workforce UI
contained with a prior flag-off artifact, then correct any proven database
defect with a reviewed forward migration. The source rollback point is
`eeed1a294abfd686aada03791e605ff06a58124f`; do not reset or rewrite `main`.

Next work remains T14 on the dedicated staging project: approve named
non-production personas and witness, form one immutable staging candidate, and
execute the 35 manual scenarios. Production smoke checks above cannot be
credited toward that acceptance.

## Post-release Workforce access enablement recovery

Status: **released and independently verified on 31 August 2026**

### Cause and correction

Masaud Khan had effective organization grants for `workforce.view`,
`workforce.attendance.maintain` and `workforce.timesheets.maintain`, plus an
audited organization responsibility, but production had no Workforce workers,
teams, calendars or schedules. The accepted T10 overview incorrectly treated
that valid empty setup as an authorization failure and returned
`V1_WORKFORCE_T10_READ_DENIED`.

Migration `20260831142257_yorks_workforce_access_enablement_recovery.sql`
preserves the accepted T10/T13 data projection and adds a least-privilege
wrapper for only the organization-authorized empty state. It also makes the
capability/responsibility dependency explicit in User Management: reviewed
Workforce grants include visible missing prerequisites, Admin can atomically
save the dated organization responsibility, and retained half-enabled users
receive an audited recovery action. Non-Admin permission viewers receive no
responsibility metadata or organization-wide master-data counts.

| Evidence | Value |
|---|---|
| Release source commit | `023de06d8f711a20fff4a37401c22f2894c0ecb5` |
| Previous live deployment | `dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g` |
| Recovery deployment | `dpl_F6fomynrt6we4wsG85BreT93trAT` |
| Candidate URL | `https://yorks-r35-38pdwabdm-sajid-alis-projects-0ec775a2.vercel.app` |
| Production alias | `https://yorks-r35.vercel.app` |

### Verification and production proof

- changed-Dart format gate: passed with zero changed files;
- `flutter analyze`: passed with no issues;
- focused permission model/repository/UI gate: 63 tests passed;
- clean local `supabase db reset`: passed through the recovery migration;
- complete local database gate: 76 files and 2,343 assertions passed in 97
  seconds; the 500-worker observation was 14,293.25 ms and T13 observations
  were overview 5,282.12 ms, roster 786.81 ms and queue 1,886.61 ms;
- database lint introduced no new warning after removing one dead assertion
  result; retained warnings predate this recovery;
- the linked dry run contained exactly the recovery migration, the push
  applied only that migration, and the second dry run was empty;
- production-shaped web build passed with Accounts and Workforce enabled and
  the production Supabase ref; the CI/staging refs and service-role credential
  key were absent;
- Android release-shaped build passed with the explicit ephemeral CI
  certificate and produced a 101.3 MB APK. This is not a store-signing claim;
  and
- the complete Flutter suite reproduced the previously recorded unrelated
  global golden drift (206 failures). It is not relabelled as green; the
  focused Workforce, analyzer, database and release-build gates above passed.

After migration, a production transaction using Masaud's exact authenticated
claims returned supervisor overview schema 1 with zero teams and zero workers,
instead of access denied. The protected Admin workspace independently reported
effective operational access, the current organization responsibility and
zero active workers, teams and scheduled teams. The internal accepted overview
projection remains non-executable by `authenticated`; only the reviewed public
wrapper is callable.

The isolated candidate extracted 51 deployable files. Before and after
promotion, `/`, all three Workforce routes, Projects, Material Requests,
Accounts and Team Chat returned HTTP 200 with the exact local `index.html`
hash. Runtime/PWA assets matched local bytes:

| Artifact | SHA-256 |
|---|---|
| `index.html` | `31af1b140f0dcc6925e234d36061e376be99b608225ef060c1a7bf669639afb5` |
| `main.dart.js` | `7d872c571b29545f953f6fb56b8e24cf7c5ce5e0bd02c148ae10d2becaf6bed2` |
| `flutter_bootstrap.js` | `2060fa952cc04c6b7e0fcc8e27207e216f3a64fc31de28f4a13c5f71789673a1` |
| `manifest.json` | `21a31bb90bbe6d13de1723e7e954257ce2d8c62206ceaeb64733aae4bf90c2ff` |
| `flutter_service_worker.js` | `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c` |
| `firebase-messaging-sw.js` | `e8151cb276b7644627e5cefc1dc5e46b69ad38f952c4a734b1f81a9795437a1e` |

Rollback remains deployment promotion to
`dpl_BFzK5dURC5qvRxpatmxW5B4FuR4g`. The additive database migration and the
audited dated responsibility must be retained; any database rollback is a
reviewed forward correction. The authorized overview is intentionally empty
until real workers, teams, calendars and schedules are configured; no
production people/master data was invented during this recovery.

## Post-release Workforce Administration enablement

Status: **released and independently verified on 31 August 2026**

This follow-up closes the production configuration gap reported after the
access recovery. Login accounts remain controlled in User Management; worker
master records, teams, dated project/internal-location assignments, calendars,
shifts and team schedules now have a separate guarded Workforce
Administration workspace. Worker and login-account deletion is not introduced:
accounts are disabled, workers use retained status, and project/team changes
close the prior dated assignment before inserting its successor.

| Evidence | Value |
|---|---|
| Release source commit | `19c03a39ba0d1fd097f32cefc014ebea30ad9185` |
| GitHub `main` | Exact match to the release source commit after push |
| Production migration | `20260831155531_yorks_workforce_administration_enablement.sql` |
| Previous live deployment | `dpl_F6fomynrt6we4wsG85BreT93trAT` |
| Release deployment | `dpl_9fvVjbYeZLxLpVH6XR8GwYE6otGb` |
| Candidate URL | `https://yorks-r35-8z95brofy-sajid-alis-projects-0ec775a2.vercel.app` |
| Production alias | `https://yorks-r35.vercel.app` |

### Verification and migration proof

- `flutter pub get` passed; 16 changed Dart files passed the no-change format
  gate; `flutter analyze` passed with no issues.
- All 149 Workforce Flutter tests passed, including 360 px/mobile and desktop
  Administration evidence, guarded route/navigation, repository payloads and
  the retained read-only compact-overview boundary.
- The broad legacy Flutter suite remains non-green because of the previously
  recorded golden/layout baseline. It caught one compact action regression in
  this slice before release; that regression was corrected and the complete
  Workforce suite then passed. This release does not relabel the global suite
  as green.
- A clean `supabase db reset` applied every tracked migration and seed. The
  complete local database gate passed 77 files and 2,363 assertions in 98
  seconds. The 500-worker observation was 14,296.19 ms; T13 observations were
  overview 5,220.08 ms, roster 806.84 ms and queue 2,646.43 ms. These remain
  observations rather than product SLAs.
- Database lint found no warning in the new Administration functions after the
  configuration reader was correctly marked volatile. Retained warnings in
  unrelated pre-existing functions remain outside this change.
- The CI release-shaped web build passed. The Android release-shaped gate also
  passed with the explicit ephemeral CI certificate and produced a 98.7 MB
  APK; this is not a protected store-signing claim.
- Before production mutation, the linked ledger matched local history through
  `20260831142257`. The dry run contained exactly the one Administration
  migration and no seed or role operation. It applied successfully, and a
  second linked dry run was empty.
- The migration promotes only `workforce.workers.manage`,
  `workforce.teams.manage` and `workforce.configuration.manage`; retains
  `workforce.view` as their dependency; replaces temporary exact-Admin checks
  only inside the accepted T01/T02 management consumers; keeps helpers private;
  and grants authenticated execution only on the two reviewed public RPCs.
- Positive/negative database evidence covers delegated Project Engineer,
  Site Engineer and Procurement managers, cross-capability denial, ordinary
  table/helper denial, safe response shapes, idempotent assignment transfer,
  stale-version protection, invalid-supervisor rollback and historical-row
  preservation.

### Production artifact and live proof

The clean production build reported Accounts and Workforce enabled, contained
the production Supabase ref exactly once, contained neither staging nor CI
refs, contained no service-role/secret marker, and included the new
`/yorks/workforce/administration` route. The isolated artifact contained 52
files; Vercel extracted 51 deployable static files. The deployment was created
with production configuration and automatic custom-domain promotion disabled,
verified in `READY` state, and only then promoted.

| Artifact | SHA-256 |
|---|---|
| `index.html` | `31af1b140f0dcc6925e234d36061e376be99b608225ef060c1a7bf669639afb5` |
| `main.dart.js` | `b4169d31938041c96fd7f018c3be79ec398d17c6bacb91eb2736e3996e8b8698` |
| `flutter_bootstrap.js` | `d01ae9748dc5baccbbe3c0504095e7e0b7c8863764fe216679c56bc795011c8d` |
| `manifest.json` | `21a31bb90bbe6d13de1723e7e954257ce2d8c62206ceaeb64733aae4bf90c2ff` |
| `flutter_service_worker.js` | `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c` |
| `firebase-messaging-sw.js` | `e8151cb276b7644627e5cefc1dc5e46b69ad38f952c4a734b1f81a9795437a1e` |

Before and after promotion, `/`, Workforce overview, Administration,
Attendance and Timesheets, User Management, Projects, Material Requests,
Accounts and Team Chat each returned HTTP 200 with the exact local
`index.html` hash. All six runtime/PWA assets above returned HTTP 200 and
matched local bytes. A final background browser load of the promoted
Administration hash route reached the Yorks Flutter runtime with the expected
title, two Flutter view roots and no captured console error.

Rollback is promotion of `dpl_F6fomynrt6we4wsG85BreT93trAT`. The database
migration is additive and must be retained; contain a client defect by
promoting the previous artifact, then use a reviewed forward migration for any
proven database correction. No production worker, user, team, schedule or
attendance record was created, changed or guessed during this release. Manual
T14 staging UAT remains outstanding and is not claimed by this evidence.

## Post-release Administration default-date hotfix

Status: **released and verified on 31 August 2026 at 22:51 PKT**

The delegated Workforce Administration route was reachable, but its initial
read sent `p_on_date: null` to the three protected read RPCs. PostgreSQL treats
an explicitly supplied null as the argument value rather than applying the
function's current-date default; the foundation reader therefore returned
`V1_WORKFORCE_FOUNDATION_FILTER_INVALID`. Production grants were independently
confirmed effective for the reported delegated manager, and the same three
RPCs succeeded under that actor when called with the server date. The client
now omits the optional parameter when no date is selected.

| Evidence | Value |
|---|---|
| Hotfix source commit | `3f598a4050bd7d26baf86ef11e779751542cd753` |
| GitHub `main` | Exact match to the hotfix source commit after push |
| Database migration | None; client parameter-shape correction only |
| Previous release deployment | `dpl_9fvVjbYeZLxLpVH6XR8GwYE6otGb` |
| Hotfix deployment | `dpl_DRvHy6UTtkzsgQ5Y1veyDNK6kjJx` |
| Candidate URL | `https://yorks-r35-o34zlw4c9-sajid-alis-projects-0ec775a2.vercel.app` |
| Production alias | `https://yorks-r35.vercel.app` |

The three focused repository/widget files passed 21 tests. The complete
Workforce Flutter set passed 151 tests, `flutter analyze` reported no issues,
the changed Dart files passed the no-change format gate and `git diff --check`
passed. A clean production web build reported Accounts and Workforce enabled
and contained the production Supabase reference.

Before and after promotion, `/`, Workforce overview, Administration,
Attendance and Timesheets, User Management, Projects, Material Requests,
Accounts and Team Chat each returned HTTP 200 with the local `index.html`
hash. The promoted domain resolved to the new READY deployment. Runtime/PWA
hashes were:

| Artifact | SHA-256 |
|---|---|
| `index.html` | `31af1b140f0dcc6925e234d36061e376be99b608225ef060c1a7bf669639afb5` |
| `main.dart.js` | `fe9a84777464d4f7d4316e789ca5c2d3483143373530ad120bb07f271b6c6cbc` |
| `flutter_bootstrap.js` | `2f5a8d3abe96a072d4f060c91705badece7e5d30ecc102f9df91853b95668b49` |
| `manifest.json` | `21a31bb90bbe6d13de1723e7e954257ce2d8c62206ceaeb64733aae4bf90c2ff` |
| `flutter_service_worker.js` | `a131df5ca46154cc4eb79044f7f5a14029c2f8bfccf8cef34e3ec3b5a9f5a88c` |
| `firebase-messaging-sw.js` | `e8151cb276b7644627e5cefc1dc5e46b69ad38f952c4a734b1f81a9795437a1e` |

Rollback is promotion of `dpl_9fvVjbYeZLxLpVH6XR8GwYE6otGb`. No production
worker, login user, permission, team, schedule, assignment, timesheet or
attendance record was changed by this hotfix.

## Post-release Administration identity-option hotfix

Status: **released and verified on 31 August 2026 at 23:49 PKT**

The exact Admin account could reach Workforce Administration, but its protected
options projection included two preserved login profiles whose legacy app-user
IDs remained populated while their server-controlled exact roles were empty.
Those identities are not valid supervisor or linked-user assignment targets.
The strict schema-v1 client therefore rejected the complete options response
instead of accepting an ambiguous identity.

Migration
`20260831183000_fix_workforce_administration_identity_options.sql` replaces
only the protected choices reader. It excludes identities without a current
exact server-controlled role rather than inferring a role or altering the
preserved Auth/profile rows. Project/scope choices, capability checks,
ordinary table denial and the non-commercial response shape are unchanged.

| Evidence | Value |
|---|---|
| Source commit | `9f19e38830cd70c4448f0dc555dcb6782842c8e2` |
| GitHub branch | `main` pushed before remote migration |
| Production migration | `20260831183000_fix_workforce_administration_identity_options.sql` |
| Migration SQL SHA-256 | `0308f8a03242e8346a519f819c780713284133a9d0fa09df7f257333dc9d5994` |
| Web deployment | Unchanged: `dpl_DRvHy6UTtkzsgQ5Y1veyDNK6kjJx` |
| Production alias | Unchanged: `https://yorks-r35.vercel.app` |

The focused regression passed 7 assertions; the complete Administration pair
passed 27 assertions. A clean local reset applied the complete ledger through
the hotfix, and the full database gate passed 78 files and 2,370 assertions in
102 seconds. The 500-worker observation was 14,753.44 ms; T13 observations
were overview 7,125.18 ms, roster 823.04 ms and queue 2,659.04 ms. These are
observations rather than product SLAs.

Staging was aligned through the two already-reviewed enablement migrations and
this hotfix. Exact SQL hashes were checked before reconciling their generated
apply timestamps to the tracked versions. The staging exact-Admin response
returned `enforced_administration`, seven valid login choices, zero invalid
roles and no email/commercial key.

Production received only the pending hotfix. Its exact SQL hash was checked
before the migration ledger was reconciled to tracked version
`20260831183000`. Under the reported owner's exact authenticated claims, all
three initial Administration readers returned `enforced_administration`. The
combined live response contained 25 valid login choices, nine projects and 36
project scopes, with zero invalid exact roles and no email/commercial key. No
production worker, login user, permission, team, schedule, assignment,
attendance or timesheet row was inserted, updated, deleted or reinterpreted.

This was database-only; rebuilding or promoting an identical Flutter artifact
would add no corrective behavior. Rollback is a reviewed forward replacement
of the choices function from migration `20260831155531`; the existing web
deployment remains the application rollback point.
