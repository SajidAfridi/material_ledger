# PR-06 — Dynamic Masters and Browse Materials

Status: complete and verified on 24 July 2026.

## Scope

This slice implements only the V7 dynamic material masters and Browse Materials
experience. It does not add the reusable ten-column MaterialLineGrid, Phase 1
planning, RFQs, purchase orders or receipt-derived in-transit calculations.

Rollout remains controlled by `NEXUS_V7_BROWSE_MATERIALS`. With the flag off,
the legacy Engineer browser remains unchanged and office roles receive no new
Browse/master-data navigation.

## Domain and migration

`MaterialCategoryMaster` and `MaterialUnitMaster` are stable records with actor
and timestamp metadata. Categories are active or archived. Units are approved,
pending review or archived. No client delete path exists.

The frozen category rail contains:

1. Air Terminals
2. Dampers & Fire Control
3. Fans & Equipment
4. Ductwork & Accessories
5. Piping & Drain
6. Electrical & Controls
7. Supports & Insulation
8. General & Custom

The approved units are Nos, Meter, Cm, Length, Set, Pairs, Roll and Box.

Existing `MaterialItem.category` and `MaterialItem.unit` remain for backward
compatibility. Additive `categoryMasterId` and `unitMasterId` values are now
persisted. A legacy decoder deterministically derives those IDs when they are
absent. Exact approved equivalents are folded; unmatched units such as `ft`,
`kg` or `m³` retain distinct custom IDs and enter Admin review. Re-running the
migration produces the same IDs and does not rewrite the visible legacy value.

## Authority

- Every provisioned role may read categories and units.
- Admin may add/edit/archive/restore categories.
- Admin may add/edit/approve/archive/restore units.
- Procurement may propose a custom unit only as `pendingReview`.
- Procurement cannot approve or archive a unit.
- Engineer cannot mutate either master.
- Only approved units appear in the material form.

Used records are archived rather than deleted, so existing catalogue and
historical transaction references continue resolving.

## Browse experience

Desktop follows the approved Finder pattern: category rail, dense catalogue
list and focused inspector. Search covers description, secondary description,
code, category, size, make, origin, RAL and store. The list exposes available
stock and unit without decorative KPI cards.

Mobile is a separate card-based experience with a category selector and focused
bottom-sheet inspector. It does not squeeze the desktop table.

The inspector shows on-hand, allocated and available quantities. The current
data model has no trustworthy PO-line source for in-transit quantity, so the UI
shows an explicit unavailable state. It does not fabricate zero. A later
Procurement slice will replace this with receipt-aware derived data.

Command/Control+F focuses search and Escape clears it on browser desktop.

## Commercial boundary and CSV

Denied sessions read `materialsProvider`, whose objects contain no cost.
Authorized sessions may use `materialsWithCommercialsProvider`, which enriches
cost only in memory from protected `commercial_records`.

CSV construction is capability-shaped:

- denied export has no cost headers or values;
- authorized export includes unit cost and stock value;
- browser builds download `yorks-material-catalogue.csv`;
- platforms without a browser download surface copy the same CSV to clipboard.

Master rows and shared material payloads never contain commercial values.

## Supabase

The masters reuse the existing local collection → outbox → Supabase → realtime
architecture:

- `materialCategories` ↔ `material_categories_v1`
- `materialUnits` ↔ `material_units_v1`

The migration is self-contained because live verification found the managed
project did not contain the older documented `app_touch_updated_at()` helper.
It creates/pins that helper, tables, GIN indexes, triggers, explicit
authenticated/service grants, RLS and replica identity.

Applied live to project `czykuksmlwswjsgotrpo`:

1. `batch6_material_masters`
2. `batch6_combine_unit_update_policy`
3. `batch6_seed_master_defaults`

The second migration preserves the same Admin/Procurement rule in one UPDATE
policy, removing the advisor's overlapping-policy warning.

The third migration is insert-only and idempotent, so a new connected device
can hydrate the Yorks defaults before opening Browse while later Admin edits
continue to win. Live verification found 8 categories, 18 units (8 approved and
10 pending legacy units), zero commercial payload rows and the expected
deterministic `m³` migration ID.

Tracked pgTAP proof is in
`supabase/tests/database/material_masters_rls.test.sql`.

## Verification

- `flutter pub get` — passed.
- `flutter analyze` — passed with zero issues.
- Batch 6 model/provider/CSV/responsive widget tests — 10 passed.
- Complete Flutter suite — 328 passed.
- Live RLS: Admin create/read — passed.
- Live RLS: Engineer read and category-write denial — passed (`42501`).
- Live RLS: Procurement pending-unit create/replay — passed.
- Live RLS: Procurement self-approval denial — passed (`42501`).
- RLS test rows removed — verified zero remaining.
- Live default seed — 8 categories, 8 approved units and 10 pending legacy
  units; zero commercial keys.
- Supabase security/performance advisors — no new unresolved Batch 6 security
  issue or overlapping-policy warning.
- Desktop Admin Browse at 1280×720 — visually inspected.
- Mobile Admin Browse and focused inspector at 390×844 — visually inspected.
- Admin category and unit registers — visually inspected.
- Release web build — passed.
- `git diff --check` — passed.

The existing iOS CocoaPods/Swift Package Manager notice remains non-blocking
platform maintenance and was not introduced by this slice.

## Rollback

1. Set `NEXUS_V7_BROWSE_MATERIALS=false` to restore legacy presentation and
   remove office navigation immediately.
2. Keep master IDs on material JSON; older decoders ignore additive keys.
3. Keep the two database tables and policies during UI rollback so queued
   writes and historical references remain safe.
4. If infrastructure rollback is explicitly required after confirming no
   queued writes, revoke client grants/drop master policies before dropping
   tables. Database deletion is intentionally not automated by the app.

No Rentals or HR behavior changed.
