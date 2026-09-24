# Company use in the Material Requests workspace

Status: implementation candidate, 25 September 2026. Feature remains gated.
Source: product-owner request to bring Company use up to project-MR quality,
reduce visible content, and keep both request types in one understandable path.

## Product approach

Material Requests is the shared destination. A consistent **Project use /
Company use** control selects the operational context on desktop and mobile.
The selected context has an icon, text, selected background and checkmark.
Project-context shortcuts continue directly to their project. Company routes
remain distinct for stable links and deferred web loading, without a second
sidebar module or a fictional Company project.

| Step | Shared interaction | Company-specific meaning |
|---|---|---|
| Find work | Search, request cards, My work, pagination | Company unit, CMR reference and authorized participants |
| Create | Details, Items, Review; explicit save and submit | Category/unit, beneficiary and authorized receiver replace project/building |
| Review | Status, named responsibility and primary action first | Independent Company approver; no inherited project self-approval |
| Arrange | Review every line before saving once | Approved Company demand; shared warehouse or explicit external supplier |
| Dispatch | Review the exact selected quantities | Server-calculated outstanding supply cap |
| Receive | Review each named item before one confirmation | Designated receiver, with good and exception quantities kept separate |
| Handover | Review the beneficiary and quantities | Signed-in beneficiary acknowledgement or explicit receiver-witnessed handover |
| Return / close | Deliberate quantities and reason; server confirmation | Company custody evidence and existing closure checks |

The list is concise: reference/status, purpose, destination/item count and next
responsibility. Search, counts and 15-row pages are computed on the server over
the complete readable set. My work uses the established workflow selector and
rechecks current readability; it does not mean all Company records.

The detail emphasizes the current stage and action, followed by the materials.
Request Information, progress and decision history are disclosures. The record
retains the beneficiary, receiver, approver, decision actor/role/date and
quantity history. Additional detail is hidden by default, never discarded.

## Reproduced implementation gaps corrected

- Private drafts have no submitted number/date. The register decoder now
  handles that state without failing the entire view, and saved drafts reopen
  their protected context and lines through the existing editor.
- A late failed approval-route preflight no longer overwrites a newer result.
- Dispatch previously submitted the whole arranged amount. The protected
  projection now returns `dispatchable_qty`, capped by unused current-plan
  supply and remaining approved demand after good receipt, transit and
  withdrawal. The user reviews a full or partial selection before dispatch.
- Handover previously chose the acknowledgement basis by comparing receiver
  and beneficiary IDs. It now uses the signed-in actor; the trusted command
  still enforces direct acknowledgement versus witnessed handover.
- Returns and remainder withdrawals previously selected every eligible unit.
  They now start at zero and require deliberate quantities and a reason.
- Arrangement no longer silently chooses the first inventory item sharing a
  unit. A stock item must be selected explicitly. Unavailable lines require an
  explicit follow-up date instead of an invented date seven days later.
- Arrangement and receipt use a reviewable basket. Every line can be revisited
  before the single server commit. Receipt review names the item and dispatch.
- Repeated submission of the same operation/version/payload retains its
  idempotency key following an uncertain response.
- Company registers refresh after returning from a record and clear prior
  identity results when the authenticated user changes. A failed load of
  new-request permissions has a visible retry without losing the register.

## Architecture and preservation

UI -> Riverpod -> repository -> existing trusted commands. The additive
migration adds compatible dispatch-review data and a protected paged register;
it changes no stock transaction, approval rule, reservation, custody record,
commercial field or historical identity. Existing internal projection helpers
remain inaccessible to authenticated/anonymous callers. The new page returns
only non-commercial summary fields and rechecks active identity/readability.

Company fulfilment continues to use the shared warehouse. Project MRs retain
their own authority and document chain. Company approval, beneficiary custody
and independent closure are not collapsed into project membership.

Rollback: disable `YORKS_V1_COMPANY_MATERIAL_REQUESTS` and restore the previous
application artifact. Keep additive functions, all original IDs, approval,
reservation, movement, dispatch, receipt, handover and return history. Fix
forward; do not delete business evidence.

## Acceptance and release boundary

Focused tests cover protected-draft reopening, partial dispatch, retry identity,
beneficiary versus receiver handover, quantity limits, zero-selection returns,
reason validation, complete line review, pagination request contracts and
private-draft decoding. Readable-font visual fixtures cover desktop, 360px,
Arabic RTL and 200% text scaling. The existing Company database lifecycle tests
continue to cover approval, reservation, receipt exceptions, handover, returns,
withdrawal and closure; new SQL tests verify remaining dispatch supply and
role-safe paging.

Local automated evidence is not named-persona staging UAT. The retained
[T06 boundaries](COMPANY_MATERIAL_REQUEST_T06_END_TO_END_HARDENING.md) still apply
to workers without a login, cross-module Company returns and the complete
controlled-document set beyond immutable issue evidence. This change does not
enable Company use in production or authorize deployment.

## Verification record — 25 September 2026

| Check | Result |
|---|---|
| Dependency resolution, formatting and analyzer | Passed |
| Focused Company composer/detail/operation/repository tests | 27 passed, including retry recovery |
| Shared entry/navigation layout checks | Passed at desktop, tablet and 360px |
| Company visual fixtures | Desktop, 360px, Arabic RTL and 200% text checks passed |
| Isolated Supabase reset | Passed against the complete migration chain |
| Complete database suite | 105 files, 2,966 checks passed |
| Supabase local security advisors | No warnings or errors |
| Company-enabled CI web build | Passed; startup asset budget passed |
| Company-enabled Android CI release build | Passed with ephemeral CI signing; not a store release artifact |
| Wider Flutter suite | 1,805 passed; 274 screenshot mismatches; full gate is not green |

The screenshot failures span existing project, analytics and other fixtures;
Company fixtures passed. The arrangement-header mismatch was also reproduced
on unchanged parent commit `6010f3b` (38.45% pixel difference). These failures
are not silently accepted or regenerated in this change. The remaining release work is review of those visual-baseline failures,
named-persona staging acceptance with configured Company policies, and signed
release validation. The existing T06 scope boundaries above remain explicit.
The temporary isolated database was stopped after verification; the shared
local database and production were not changed.
