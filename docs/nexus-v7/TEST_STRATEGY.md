# Yorks Nexus V7 — Test and Verification Strategy

The goal is confidence in a connected, permissioned workflow—not only screens
that render. Every V7 slice must add proof at the lowest useful layer and keep
the existing Rentals, People/HR, Leave, Finance, Inventory, authentication and
sync regression suite passing.

## Test pyramid

### 1. Pure model and migration tests

Cover:

- legacy JSON decoding with missing and old fields;
- Project → ProjectBuilding migration, including legacy
  `buildingName`/`floorNumbers` and preserved `authorityRef`;
- canonical line-field mapping and no information loss;
- stable IDs, schema/data versioning and idempotent migration reruns;
- status transition guards and derived quantity calculations;
- smart similar-row copy/clear rules and CSV escaping.

### 2. Provider/repository tests

Cover:

- draft autosave and recovery;
- project wizard validation and unique Yorks reference handling;
- plan submit, procurement review, revision, diff, requested changes and approval;
- request creation with mixed categories, custom rows, attachments and
  Normal/Urgent priority;
- allocation across warehouse and several suppliers;
- RFQ/quote/PO/receipt source-link preservation;
- partial ordering, partial receipt and outstanding quantity derivation;
- required-on-site destination, over-plan/new-item exceptions and substitution approval;
- Supplier Receipt, Warehouse Issue, Site Delivery Receipt and Site Receipt Confirmation;
- short, damaged and rejected receipt quantities;
- append-only revisions and activity entries;
- provider behaviour when offline, reconnecting, retrying and receiving
  realtime merges.

### 3. Database/RLS tests

For Engineer, Procurement and Admin, prove both allowed and denied cases:

- project and building visibility;
- plan/request ownership and project membership;
- commercial field absence for a denied capability;
- supplier/quote/PO visibility;
- attachment download/upload boundaries;
- approval and receipt commands by permitted/denied roles;
- audit events cannot be updated or deleted by the app roles;
- forged owner IDs, cross-project IDs and anonymous requests are rejected.
- role resolution rejects missing/invalid `app_metadata.role` and never infers a
  privileged role from email or `user_metadata`;
- release startup rejects missing or partial Supabase configuration;

The assertion must inspect returned columns/payloads, not just whether a widget
shows a cost label.

Bootstrap and outbox tests must prove that salary, contract value, material unit
cost and device-derived reservations never enter a shared cloud payload.

### 4. Integration and state-machine tests

Run an end-to-end test for:

`MR → allocation → RFQ → supplier quotations → split PO → partial receipt → MR status`

The test must include at least two suppliers, a warehouse allocation, a partial
receipt, an offline retry and a repeated command with the same idempotency key.
It must prove no duplicate stock movement, order line or receipt line is
created.

### 5. Widget, golden and responsive tests

Cover:

- Engineer mobile request creation;
- Procurement desktop queue, fulfilment and side-by-side quote comparison;
- project workspace related-record navigation;
- exact ten-column grid and restricted-cost rendering;
- keyboard navigation and paste/CSV behaviour;
- empty, loading, error, denied, partial and stale/offline states;
- English plus configured secondary-language strings;
- 44×44 minimum mobile tap targets and no desktop overflow on tablet widths.

Golden tests are for stable visual contracts, not as a substitute for workflow
tests. Screenshots in `design/previews/` are the visual review baseline.

### 6. Performance and release tests

- render/edit 500 material rows without unacceptable input lag;
- measure cold start, hydration and reconnect behaviour;
- run `flutter analyze`, format check, full tests and web release build;
- run a migration dry run against a copy of representative legacy data;
- run database advisors and review RLS/index plans;
- exercise feature-flag rollback and legacy read-only routes.
- validate that all V7 feature flags default off in an ordinary build.

## Minimum proof per implementation slice

| Slice | Required proof |
|---|---|
| Models/migrations | decoder, round-trip, legacy fixtures, idempotency |
| RLS/commercials | positive/negative role matrix and payload-shape tests |
| UI foundation | widget/golden tests for tokens, states and responsive shells |
| Project wizard | validation, draft recovery, role access, screenshot |
| Material grid | exact columns, smart row, keyboard/paste, CSV, 500-row benchmark |
| Plan/MR workflow | state machine, provider integration, offline draft, notifications |
| RFQ/PO/receipt | source links, split quantities, revisions, transactional/idempotent integration |
| Rollout | regression suite, migration dry run, pilot checklist and rollback evidence |

## Required commands before a slice is complete

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --release
```

Run focused tests during development, but report the complete suite before
hand-off. A known unrelated failure must be reported and isolated rather than
silently ignored.
