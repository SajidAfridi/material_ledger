# Workforce T13 Local Hardening Evidence

Status at evidence capture: **implemented locally; awaiting independent acceptance**
Independent audit status: **accepted on 31 August 2026**
Date: 31 August 2026
Workforce source fingerprint:
`3914f3ec6740b5986724ae8dbc44b70f9944ec580fedfd3a526b3605866bf613`

T01 through T12 remain the independently accepted implementation boundary.
This T13 slice performed no commit, push, remote Supabase migration, feature
enablement or deployment. The product owner waived dedicated T14 staging UAT;
T14 is therefore not performed and not passed, and the waiver is not release
authority.

Decision-history note: later on 31 August 2026 the product owner withdrew the
T14 waiver and reinstated dedicated staging UAT. That later decision does not
rewrite the historical fact above: T14 was not performed or passed as part of
T13, and T13 supplies no staging or production-release evidence.

## Reproduced correction

The 500-worker/50-team/30-project/two-year local fixture reproduced repeated
per-team effective-assignment and authorization scans in the protected T10
overview and approval queue. Before correction, observed local wall times were
about 29,060 ms for Management Overview, 829 ms for one 500-bound roster read
and 11,907 ms for the 24-period queue.

Additive migration
`20260831090940_yorks_workforce_t13_query_performance.sql`:

- resolves the accepted temporary-before-primary assignment order set-wise for
  prospective monthly membership and current team contexts;
- limits a team-month candidate set to workers with a dated candidate for that
  team while still ranking every competing effective assignment for those
  workers;
- short-circuits team/period checks only when one effective organization
  capability and organization responsibility cover the complete date window;
- removes the reproduced T07 Admin capability-only shortcut, applies the same
  capability-plus-responsibility rule to T07 and T10 separately, and prevents
  partial/future/expired organization windows from falling through as dated
  period authority;
- preserves the scoped worker, project, project-scope, internal-location and
  active-allocation fallback checks for every actor without complete
  organization authority, plus organization/exact-team empty-period semantics;
  and
- creates no table, grant, capability, lifecycle state or business row and
  changes no public RPC response shape.

Three isolated post-correction runs recorded:

| Run | Overview | Roster | Queue |
|---|---:|---:|---:|
| 1 | 4,990.86 ms | 807.52 ms | 1,732.62 ms |
| 2 | 5,212.36 ms | 809.13 ms | 1,755.71 ms |
| 3 | 5,313.18 ms | 818.52 ms | 2,231.95 ms |
| Audit correction | 5,540.99 ms | 844.00 ms | 1,804.88 ms |

Retained-suite runs recorded Overview at 7,164–7,348 ms, roster at 813–1,002
ms and queue at 2,719–2,813 ms before independent correction; the final
retained-fixture run recorded 7,508.33 ms, 869.69 ms and 3,519.95 ms. These are
local measurements, not a product
SLA. The database evidence also freezes the required assignment, attendance,
period, allocation and scope indexes; SQL-function entry points appear as
function scans to top-level `EXPLAIN`, so measured wall time and exact index
inventory are the repeatable evidence rather than an invented inner-plan
contract.

## Security and data-boundary evidence

`yorks_workforce_t13_hardening.test.sql` passed 20/20 and proves:

- exactly 35 Workforce relations retain RLS, no `anon`/`authenticated` direct
  CRUD and service-role-only direct administration;
- hard-delete guards remain present, with only the accepted transaction-scoped
  monthly correction-context exception;
- no Workforce relation contains payroll, salary, bank or cost fields;
- authenticated actors cannot mutate the append-only audit table;
- the exact 47 authenticated Workforce RPCs remain `SECURITY DEFINER` with an
  empty trusted search path, and internal helpers remain non-executable;
- exactly nine capabilities are operational/enforced/assignable and three
  remain planned/shadow/nonassignable; and
- both Workforce Storage buckets remain private, with canonical read and
  upload-intent insert policies and no direct update/delete policy; and
- stored T06/T07/T10 definitions contain no Admin role shortcut while retaining
  complete organization and exact-team authority semantics.

`yorks_workforce_t13_period_authority.test.sql` passed 12/12. It proves both
T07 and T10 deny Admin capability without effective responsibility and deny
future, expired and partial-month organization windows; accept complete-month
organization responsibility; give Project Manager and Senior Mechanical
Engineer the same exact scoped result; fail when either a project-scope or
internal-location target is uncovered; and preserve exact-team/organization
empty-period behavior. The fixture is isolated from arbitrary valid retained
responsibility windows.

The client hardening test passed 5/5: only the Workforce repository imports
Supabase/calls RPCs; no service-role credential is embedded; critical write
controllers expose explicit loading/success/offline/conflict/uncertain/denied/
session/unavailable/failure states; roster/controller creation stays bounded;
and localized critical copy is non-empty in English, Arabic, Urdu and Hindi.
Artifact scanning found no JWT, `sb_secret_` value or service-role key pattern
in `lib`, `web`, the web release artifact or the Android APK.

## Concurrency and retained-state database evidence

Every repository-local two-session harness passed:

- T03 attendance create and same-version correction races;
- T04 allocation-set create and correction races;
- T05 atomic daily-roster create and correction races;
- T06 monthly-period initialization race;
- T07 lifecycle verification race;
- T09 report generation/issuance identical-retry races; and
- T10 concurrent read stability and read-only side-effect boundary.

Each mutation harness observed one authoritative winner/effect and a stable
`40001` loser where competing payloads were expected. The T09 identical retries
converged on one artifact/receipt. The T10 two-session projections matched
after excluding `generated_at`, and audit/notification/transition/report counts
did not change.

Before independent audit, the focused T01–T13 database lane passed 659/659
across 14 files without clearing retained fixtures. After correcting the T07
shortcut, a clean replay completed and the focused T07/T10/T13 lane passed
147/147 across five files. The affected real T07 lifecycle race and T10
concurrent-read harnesses then passed. Without clearing their retained rows,
the complete database suite passed 2,326/2,326 across 75 files. T07/T10/T13
fixtures now coexist with valid pre-existing capability and responsibility
records rather than assuming an empty database.

Local database lint exited successfully with 44 existing warnings across 34
functions. Two belong to the accepted T02
`v1_get_workforce_configuration` volatility classification; there are no T13
correction-function findings. No warning was widened or suppressed.

## Flutter, responsive and build evidence

The focused Workforce suite passed 143/143 before the independent correction;
the affected T07/T10/T13 client rerun passed 28/28. The six surface widget lanes cover
1440x900, 1366x768, 1180x820, 1024x768, 820x1180, 768x1024, 430x932, 390x844
and 360x800 across English plus Arabic/Urdu/Hindi representation and RTL. The
expanded surface-only widget run passed 34/34 with no overflow. Static T13
checks additionally prove virtualized rows, bounded controller creation and
controller disposal.

`flutter analyze`, Dart formatting, `git diff --check`, Bash syntax and
ShellCheck all passed. The repository-wide Flutter snapshot is intentionally
not claimed green: 1,226 passed and 206 failed, dominated by unrelated existing
golden pixel drift and the known 139-pixel 1024px shell overflow. No unrelated
golden was rewritten.

With `YORKS_V1_WORKFORCE=false` explicitly set:

- the production-shaped web build passed; `build/web/main.dart.js` is
  9,229,861 bytes; and
- the ephemeral-signed Android release build passed; the APK is 98,644,356
  bytes (98.6 MB), with only the existing future Gradle/AGP/Kotlin support
  warnings.

These artifacts are local release-shaped evidence only. They were not
published or promoted.

## Files owned by T13

- the seven governing `docs/yorks-v1` authority/plan files and this evidence;
- `supabase/migrations/20260831090940_yorks_workforce_t13_query_performance.sql`;
- `supabase/tests/database/yorks_workforce_t13_hardening.test.sql`;
- `supabase/tests/database/yorks_workforce_t13_period_authority.test.sql`;
- `supabase/tests/database/yorks_workforce_t13_scale.test.sql`;
- the retained-data corrections in the T07 and T10 database tests;
- the T07 lifecycle and T10 concurrent-read harness fixture corrections;
- `test/yorks_workforce_t13_hardening_test.dart`; and
- the T05–T10 Workforce widget-test viewport matrices.

## Preservation and rollback

The migration patches function definitions only and writes no retained row.
Rollback is forward containment: keep `YORKS_V1_WORKFORCE=false` and, if later
required, restore the accepted T06/T07/T10 definitions through a new migration.
Never delete or reinterpret T01–T12 attendance, allocation, monthly, lifecycle,
document, notification, audit or idempotency history.
