# Mobile UI Batch 03 Evidence

Status: **verified locally**
References: **22–28**
Acceptance viewports: **390×844** and **360×800 logical pixels**

> Historical visual evidence: this pack records the Batch 03 implementation at
> the time it was accepted. For the current approval-first operating sequence,
> register ownership/next-action cues and terminology, use
> [`../../CURRENT_MATERIAL_REQUEST_USER_GUIDE.md`](../../CURRENT_MATERIAL_REQUEST_USER_GUIDE.md).

This batch implements the controller-backed Material Request phone flow:

1. Material Request register
2. Request information
3. Add from BOQ
4. Custom material
5. Review and submit
6. Submitted confirmation
7. Material Request lifecycle

Every directory contains the approved 390×844 reference, deterministic
Flutter-after captures at both target viewports, a labelled 390×844
side-by-side, alpha overlay, absolute pixel diff, and a measured delta record.
The pack has no 360×800 source image, so those are adaptive captures—not a
fabricated pixel comparison. No deterministic Flutter-Before capture existed
for these exact authenticated fixtures before this batch; it is explicitly not
represented as evidence.

## Reference fingerprints

| Artifact | SHA-256 |
|---|---|
| `screen_manifest.json` | `7487b4233b5b7179a8cc572fc3b54068380704badf3bb464d74d69223d34c18c` |
| `design_tokens.json` | `a9e055732f548ced2f18fc6facd29c822397fe1a6985f950d5d65faae3c54694` |
| `docs/MOBILE_UI_CONTRACT.md` | `778800cb866b90693c265218be1e40c6dbf9a49ecb811d29ebd98f1cb388911c` |

## Evidence ledger

| Ref | Surface | 390×844 evidence | 360×800 | Functional variants | Status |
|---:|---|---|---|---|---|
| 22 | Material Requests | [Comparison](22_material_request_register/deltas.md) | Adaptive after | authorised register, state filters, create allow/deny | Verified |
| 23 | New MR — Information | [Comparison](23_mr_information/deltas.md) | Adaptive after | private draft, project/scope/timing validation | Verified |
| 24 | MR — Add from BOQ | [Comparison](24_mr_add_from_boq/deltas.md) | Adaptive after | selected real scope only, zero-row folder disabled | Verified |
| 25 | MR — Custom Material | [Comparison](25_mr_custom_material/deltas.md) | Adaptive after | controller-backed unplanned line, no BOQ write | Verified |
| 26 | MR — Review & Submit | [Comparison](26_mr_review_submit/deltas.md) | Adaptive after | confirmation, local validation, connected submit gate | Verified |
| 27 | MR Submitted | [Comparison](27_mr_submitted_success/deltas.md) | Adaptive after | confirmed server response only | Verified |
| 28 | MR Detail Lifecycle | [Comparison](28_mr_detail_lifecycle/deltas.md) | Adaptive after | truthful state/owner/next action; fail-closed primary action | Verified |

## Functional witness checklist

- [x] All feature widgets remain above the existing controller/repository/RPC
      boundary; no UI calls Supabase directly.
- [x] A new draft stays local/private until the existing connected submit
      command returns a record.
- [x] The success surface is unreachable before that command succeeds.
- [x] BOQ folders and rows are fetched through the existing repository and
      only for the draft's selected persisted scope; `Overview` is not a
      source.
- [x] Custom material adds a draft line through the existing controller and
      cannot alter a BOQ worksheet.
- [x] The lifecycle page only shows the pre-resolved action supplied by the
      existing state/capability projection; it does not invent an Arrange
      action when that workspace is absent.
- [x] The workspace shell suppresses its generic phone top bar on Material
      Request routes, retaining only the feature record header and shell
      bottom navigation.

## Visual evidence result

The comparisons are evidence, not a parity assertion. Remaining visual
differences are recorded by surface and classified in the linked delta files.
They include the production shell/authorized fixture distinction, card density,
and controls that cannot be copied where that would weaken real workflow,
state, or authorization behavior.

## Test record

The final local commit identifies this evidence set. No production deployment
was made.

| Gate | Result |
|---|---|
| Batch 3 mobile goldens | Passed: 14 captures at 390×844/360×800 |
| Batch 3 workflow/authorization checks | Passed: 3 additional MR tests |
| Existing MR/controller/detail/layout checks | Run in the complete validation gate |
| Desktop/mobile route witness | Run in the complete validation gate |
