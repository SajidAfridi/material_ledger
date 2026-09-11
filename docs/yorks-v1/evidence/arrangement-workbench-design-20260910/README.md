# Arrangement workbench — visual references

Status: generated design concepts, not implemented UI or acceptance evidence.

- [Desktop arrangement workbench](desktop-arrangement-workbench.png)
- [Mobile focused line flow](mobile-arrangement-line-flow.png)
- [Integration SRS](../../ARRANGEMENT_WORKBENCH_SRS.md)
- [Implementation and acceptance plan](../../ARRANGEMENT_WORKBENCH_IMPLEMENTATION_PLAN.md)

Use the Yorks shell, restrained navy/blue palette, aligned item/source/quantity
layout, inline shortage treatment and focused mobile editing as direction.
Use actual AppColors, AppSpacing, AppTypography and shared controls in Flutter;
do not copy raster text sizes or invent a second design system.

## Corrections required before implementation

1. The desktop illustrative total of four items does not match its three
   displayed rows. Render counts from the complete real line set and disclose
   filtering. Full/Partial/unavailable counts and reviewed/valid counts are
   different facts.
2. A “Reserved” label before final arrangement confirmation must become
   “Will reserve on save” or “Planned”. Previously committed reservations must
   be shown separately. Arrangement save reserves; dispatch changes on-hand.
3. A selected warehouse match/checkmark must not imply sufficient stock.
   Compare the aggregate planned quantity against effective availability.
4. A Partial line without its mandatory reason cannot count as ready. Keep
   the inline reason, validation summary and exact-field focus destination.
5. Mobile “Save line & continue” is not final arrangement save. Use Continue
   with independent device/account save status, plus explicit Save progress.
6. Add the safe Back to request / Save progress / resume behaviors in the SRS.
   A screenshot does not specify exit, crash, conflict or uncertain-save behavior.
7. Do not remove controls absent from these sample images: authorized cost,
   external readiness/date/reference, Clarify item, original item evidence,
   inventory creation, Request Information, reasons, note and history remain.
8. Retain approval-first behavior, latest-clarification Engineering reapproval,
   all-unavailable and actual legacy review lanes. Do not implement an invented
   second approval after every new arrangement.

The SRS governs behavior and copy. Actual desktop/360px/RTL renders and
interactive evidence must be produced from the implemented app before release.
