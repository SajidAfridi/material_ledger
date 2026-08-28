# YRA-322 Nexus Master File Reconciliation

Status: **production applied on 28 August 2026**

Source: `Project Master File - Nexus 4 Station.xlsx`

SHA-256:
`1038f0b54c1be1473bd5160c9523532fb141988177d6555651fb795d9f061b3c`

Size: `1,961,340` bytes

## Project identity decision

The commercial summary and progress worksheets consistently identify
`YRA-322` and the `N-19957.2` Nexus Phase 1 contract. The copied Project
Details sheet identifies YRA-315 and was quarantined as a conflicting source;
it was not allowed to overwrite YRA-322 project metadata.

The typo `N-1957.2` in `Summery (Option)!D2` was normalized to the dominant
`N-19957.2` reference already held by the project and repeated throughout the
workbook.

## Applied facts

| Fact | Workbook evidence | Applied value |
|---|---|---:|
| Contract baseline | `Summery (Option)!F52` | AED 17,192,000.00 |
| Buildings | DF3W, DF4W, DF6W, DF7W | 25% each |
| Billing stages | `D53:D57` | 10% / 50% / 30% / 5% / 5% |
| DF3W Design | `H9`, `I9`, `W9`, `X9` | 100% of stage / AED 429,800.00 |
| DF4W Design | `H20`, `I20`, `W20`, `X20` | 100% of stage / AED 429,800.00 |
| DF6W Design | `H31`, `I31`, `W31`, `X31` | 100% of stage / AED 429,800.00 |
| DF7W Design | `H42`, `I42`, `W42`, `X42` | 100% of stage / AED 429,800.00 |
| Overall confirmed work | `W58`, `X58` | 10.00% / AED 1,719,200.00 |

The baseline already matched the workbook and was verified without creating a
new revision. Four Design progress rows were confirmed against the immutable
source reconciliation. Material Supply, Installation, Commissioning &
Handover and Energizing remain zero.

## Deliberate exclusions

- `YRA32201` has an amount excluding VAT of zero. No claim or invoice was
  created.
- Approval, due and paid dates are blank/zero. No certification or payment was
  created.
- `45 days PDC` is a note without a PDC instrument, amount, reference or date.
  No PDC was created and the active Accounts policy was not changed.
- Four `YRA3220X` cells are future placeholders, not transactions.
- `Summery (Option)!H5` contains a date inconsistent with the other building
  periods. It was recorded as an anomaly and not used as an historical actor
  timestamp.

These exclusions remain in the immutable source-import row so a later user can
enter a real claim, certification, PDC or payment when actual evidence exists.

## Controls and rollback

Migration:
`20260828084626_yorks_r39_accounts_yra322_master_file_import.sql`

The migration:

- verifies project, actor, baseline, building allocations and stage totals;
- records the source hash, exact extracted facts and all excluded facts;
- refuses to overwrite any existing non-zero confirmation;
- adds append-only progress revisions and audit events;
- is idempotent for the same project and workbook hash;
- denies direct source-import table access to browser clients.

Rollback is corrective, never destructive: create new progress-confirmation
revisions returning the four Design rows to the approved replacement values,
retain the source-import and audit rows, and record the correction reason. Do
not delete the import ledger or its audit history.

## Production verification

The protected project Accounts projection returned:

- confirmed progress: `10.00%`;
- confirmed eligible value: `AED 1,719,200.00`;
- four Design rows at `100.0000%`;
- claims, invoices, certifications, PDCs and payments: `0`;
- four progress-import audit events and one source-import audit event.
