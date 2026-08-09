# Mobile UI Batch 04 Evidence

Status: **verified locally**

References: **29–39**

Acceptance viewports: **390×844** and **360×800 logical pixels**

This batch implements the controller-backed operational phone flow:

1. Procurement arrangement list, focused line and review
2. Project Engineer approval and return reason
3. Dispatch entry
4. Explicit receipt review and exception detail
5. Immutable Delivery Order snapshot
6. Material Return selection and review

Every directory contains the approved 390×844 reference, deterministic
Flutter-after captures at both target viewports, a labelled 390×844
side-by-side, alpha overlay, absolute pixel diff, and a measured delta record.
The pack has no 360×800 source image, so those are adaptive captures—not a
fabricated pixel comparison. A deterministic Flutter-Before fixture was not
available for these exact authenticated states and is not represented as
evidence.

## Reference fingerprints

| Artifact | SHA-256 |
|---|---|
| `screen_manifest.json` | `7487b4233b5b7179a8cc572fc3b54068380704badf3bb464d74d69223d34c18c` |
| `design_tokens.json` | `a9e055732f548ced2f18fc6facd29c822397fe1a6985f950d5d65faae3c54694` |
| `docs/MOBILE_UI_CONTRACT.md` | `778800cb866b90693c265218be1e40c6dbf9a49ecb811d29ebd98f1cb388911c` |

## Evidence ledger

| Ref | Surface | Comparison | Functional production exception | Status |
|---:|---|---|---|---|
| 29 | Procurement arrangement | [Evidence](29_arrangement_list/deltas.md) | Real server line decisions and quantities | Verified |
| 30 | Arrangement line | [Evidence](30_arrangement_line/deltas.md) | Existing Full/Partial/Cannot Provide command shape | Verified |
| 31 | Arrangement review | [Evidence](31_arrangement_review/deltas.md) | Atomic save/reservation remains server-owned | Verified |
| 32 | Project Engineer approval | [Evidence](32_pe_approval/deltas.md) | Server capability controls approval; no Procurement self-approval | Verified |
| 33 | Return to Procurement | [Evidence](33_return_to_procurement/deltas.md) | Current command persists one required reason, not a fabricated category | Verified |
| 34 | Dispatch entry | [Evidence](34_dispatch_entry/deltas.md) | Approved outstanding and warehouse availability remain server-capped | Verified |
| 35 | Receipt review | [Evidence](35_receipt_review/deltas.md) | Every line starts Pending and requires an explicit outcome | Verified |
| 36 | Receipt exception | [Evidence](36_receipt_exception/deltas.md) | Current command supports good quantity and note; no fake photo action | Verified |
| 37 | Delivery Order | [Evidence](37_delivery_order/deltas.md) | Immutable committed-dispatch snapshot, never receipt-derived | Verified |
| 38 | New Material Return | [Evidence](38_material_return_new/deltas.md) | Only server-derived eligible good-received quantities | Verified |
| 39 | Material Return review | [Evidence](39_material_return_review/deltas.md) | Stock changes only after later Procurement confirmation | Verified |

## Functional witness checklist

- [x] Widgets remain above the existing Riverpod controller/repository boundary;
      no widget calls Supabase directly.
- [x] Arrangement decisions use the existing complete version save and decision
      commands.
- [x] Procurement cannot see an approval action unless the server projection
      supplies `canDecide`; Engineering cannot dispatch without `canDispatch`.
- [x] Dispatch and receipt retries retain one idempotency identity until the
      command is confirmed.
- [x] Receipt lines have no visually selected outcome until the user reviews
      them; the final action is disabled until all lines are explicit.
- [x] Delivery Order preview quantities come from the immutable dispatch
      revision and include no receipt status or commercial value.
- [x] Material Return quantities are bounded by server-projected eligibility;
      saving/submitting never claims warehouse stock changed.
- [x] All new presentation branches are gated at `<=720px`; the office/tablet
      paths remain on their existing widgets.

## Visual evidence result

The comparisons are evidence, not a parity assertion. Remaining differences
are recorded per surface and classified as global token, shared component,
screen-local, or intentional production exception.

## Test record

The final local commit identifies this evidence set. No deployment or
production mutation was made.

| Gate | Result |
|---|---|
| Batch 4 mobile goldens | Passed: 22 captures at 390×844/360×800 |
| Workflow/trust checks | Passed: explicit receipt outcomes plus stable dispatch, receipt and return retry identities |
| Existing arrangement/logistics desktop checks | Passed; Delivery Order desktop golden remained byte-identical |
| Complete Flutter suite | Passed: 644 tests |
| Local Supabase reset and pgTAP | Passed: 15 files / 470 tests |
| Release builds | Passed: web and CI-signed Android APK |
