# Material Request Action Intelligence Evidence

Date: 2 September 2026
Scope: Material Request register intelligence, exception surfacing, trusted
line quantities and modest operational reporting

## Acceptance result

The scoped release is accepted locally. It adds no workflow writer and does
not change approval, arrangement, dispatch, receipt or return authority.

Verified behavior:

- role-aware **My Work** and protected **Exceptions** register views;
- Required-on-site date, overdue state and factual current-action age;
- Current owner and Next action on desktop and phone register cards;
- per-line Requested, Arranged, Reserved, Dispatched, Good, Missing, Damaged,
  Returned and Still Needed quantities;
- protected, project-scoped operational metrics without commercial values;
- server-derived exception clearing and authorization boundaries; and
- desktop and 360 px phone layouts for the new Insights and ledger surfaces.

An action due date remains intentionally unconfigured. Yorks has not approved
per-action SLA duration, working-calendar, pause or escalation rules. The
product reports that boundary instead of fabricating a deadline.

## Database evidence

- Clean local Supabase reset: **pass**.
- Focused action-intelligence pgTAP: **18/18 pass**.
- Complete local database suite: **80 files, 2,415 tests pass**.
- Anonymous access denial, internal-helper isolation, positive and negative
  action eligibility, exception derivation, quantity projection and
  non-commercial response shape are covered.

## Flutter evidence

- `flutter analyze`: **pass, no issues**.
- Focused model, repository, centre, mobile and trust-golden run:
  **12/12 pass**.
- Complete model, centre and trust-golden files: **63/63 pass**.
- Selected mobile register, recovery and lifecycle run: **8/8 pass**.
- Earlier command-confirmation coverage for arrangement, dispatch, receipt
  and return summaries: **8/8 pass**.
- Production-shaped Flutter web build: **pass**.
- Ephemerally signed release APK build: **pass**.

The complete repository Flutter suite was also run. It recorded **1,280
passes and 183 failures**. Those failures are wider visual-baseline drift and
existing viewport/layout failures across Projects, Inventory, User Management,
the shell and other unrelated screens, plus known small legacy Material
Request golden drift outside the intentionally changed evidence. They were not
silently accepted or regenerated. Therefore this evidence does **not** claim a
repository-wide green Flutter suite.

## Data preservation and rollback

The migration is additive and does not rewrite existing requests, lines,
arrangements, reservations, dispatches, receipts, returns or audit history.
Rollback is forward-only: restore the earlier read projections in a corrective
migration while retaining all authoritative workflow facts.
