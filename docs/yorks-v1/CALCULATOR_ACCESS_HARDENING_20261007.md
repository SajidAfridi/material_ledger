# Calculator sharing and archived-project protection

## Findings and changes

The owner reported two code-review findings, without claiming a reproduced
production incident. Both were reproduced in targeted regression tests:

1. The combined calculator route accepted Accountant, but the shared destination
   catalogue's Accountant filter removed its menu. The filter now admits the
   calculator home when its existing feature flag is enabled. Unauthorized
   records remain absent through server filtering. No project, BOQ, MR, stock,
   user-administration, create or sharing permission is added to Accountant.
2. The project picker excluded archived projects, while `v1_save_calculator`
   checked only readability. The additive migration
   `20261006204245_calculator_archived_project_guard.sql` checks the authoritative
   project state under `FOR SHARE` before a new write. This conflicts with the
   archive command's project-row update lock, closing both race orders.

Existing authorized project calculations remain readable and exportable, with
`can_edit=false` in list/detail responses. A successful idempotent replay still
acknowledges the original save, updates edit permission from current state, and
does not add a revision or audit. New save attempts to archived projects fail
with `CALCULATOR_PROJECT_ARCHIVED`. The client clears the definitively rejected
retry, keeps local editor inputs and loaded revision, switches to read-only,
and explains the restriction in English, Arabic, Urdu and Hindi.

## Verification

- Before the fix: four desktop/mobile Accountant navigation tests failed; the
  archive regression reproduced successful unauthorized creation/update and
  writable responses.
- After the fix: four flag-enabled Accountant discovery/route tests pass at
  1366px and 360px, with Accounts enabled and disabled. Technical and user-
  administration menus remain absent. Flag-disabled navigation stays covered
  by the complete suite.
- [Desktop navigation](../../test/goldens/calculators/accountant_navigation_1366.png)
  and [360px drawer](../../test/goldens/calculators/accountant_navigation_360.png)
  are isolated widget visual evidence, not a live Accountant browser session.
- Calculator database suites: 78 assertions, including all nine exact roles,
  explicit Accountant view/edit grants, nonarchived/general positives,
  unauthorized project access, archived create/update negatives, preserved
  payload/version/audit/idempotency and successful replay after archive.
- `python3 tool/test_calculator_project_archive_concurrency.py`: two independent
  real database sessions pass both archive-first and save-first ordering. The
  disposable committed fixtures were removed by the subsequent clean local
  reset. The harness accepts no remote database URL or credentials.
- Dependencies resolved; analyzer clean; complete Flutter suite 2,498 passed
  with four retained skips. A test-only theme change initially disturbed an
  existing shell assertion; scoping the visual theme to the new Accountant
  captures restored the full pass.
- Clean local reset and full database suite: 124 files / 3,625 assertions pass.
- CI web and 111.8 MB Android APK builds pass. Android used the required
  ephemeral CI signing lane; it is not a production-signed distribution.

## Staging server witness

Target was verified as healthy `yorks-r35-staging`, project
`iqltcyimlqtcwyzlemwx`. Only the reviewed additive migration was applied; no
generic remote database push was used. Remote ledger version is
`20261006205512`, name `calculator_archived_project_guard`.

`tool/calculator_access_archive_staging_witness.sql` passed against existing
active Admin and Accountant identities, with synthetic calculations/project/
grants/audits entirely rolled back. It verified Accountant view-only and edit
grants, unchanged create/sharing authority, picker exclusion, archived-project
creation/update rejection, preserved read output and successful replay.

Post-migration checks confirm the project lock and guard exist, anonymous save
execution remains denied, authenticated save execution remains allowed, and
the internal projection remains inaccessible directly to authenticated users.
Calculator count stayed at six. Security-advisor findings were identical before
and after (510 existing findings); no new finding was introduced. Intentional
RPC-only tables retain their deny-all table access.

## Release and rollback

This fix joins the pending calculator audit candidate in draft PR #51. The
previous Astra-before-production gate remains in force. Production received
read-only inspection: its save function lacked the archive guard. It was not
mutated by this task.

No data, grants or history are rewritten or deleted by the migration. To roll
back the interface, revert the menu/client patch or disable the calculator
workspace flag; keep the server protection. Do not restore the unsafe save
function. Production deployment and applying the reviewed migration to
production remain a later approved release action.
