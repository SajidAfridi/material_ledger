# AGENTS.md — Yorks Nexus V7

## Mission

Implement the approved Yorks Nexus V7 Materials & Projects design in the existing Flutter repository incrementally, without breaking Rentals, People/HR, Leave, Finance, Inventory history, authentication, sync or existing production hardening.

## Required architecture

- Flutter + Dart
- Riverpod for state
- GoRouter for navigation and role guards
- Supabase/Postgres as the production backend
- existing local CollectionStore/outbox/realtime patterns where suitable
- critical stock, approval and commercial transitions validated server-side

## Product scope for V7 work

Focus on:

1. Projects and project creation
2. Phase 1 material planning
3. Procurement availability review and source confirmation
4. Engineer approval
5. Browse Materials
6. Phase 2 Material Requests
7. Procurement package, RFQ, quotations, PO and delivery receipt
8. Documents, activity and traceability connected to those records

Do not redesign unrelated modules unless the task explicitly says so.

## Design principles

- Calm before clever.
- Information before decoration.
- Speed through familiarity.
- Confidence through transparency.
- Precision over personality.
- One source of truth.
- Engineers familiar with Excel should understand material tables immediately.

## UI rules

- Use existing `AppColors`, `AppSpacing`, `AppTypography` and shared widgets.
- No hard-coded user-facing strings.
- Preserve English plus the configured secondary language.
- All mobile tap targets must be at least 44x44.
- Desktop material tables must support keyboard navigation.
- Mobile material editing must use a focused row editor.
- Animations must be short, subtle and non-blocking.
- Always show actor, role, timestamp and current action owner on important workflow records.
- Browser project creation uses three stages: Essentials & Responsibility,
  Buildings, and Review & Create. Attachments are optional and inline.
- Do not add arbitrary weighted project-completeness percentages to this scope.

## Exact material columns

The standard material table may show only:

1. S:No
2. Item Description
3. Size (If any)
4. Model/Serial No.
5. Make/Origin
6. QTY
7. Unit
8. Remarks
9. Unit Cost
10. Total Cost

Cost columns are capability-controlled. Never add technical fields as standard visible columns without an explicit requirement.
The visible `Model/Serial No.` label remains the approved client wording, but
the data model must keep planning-time model/tag data separate from a serial
number captured at receipt.

## Frozen transaction rules

- Read `docs/nexus-v7/PRODUCT_DECISIONS.md` before every V7 task.
- Every plan line is building-scoped, including an explicit Project-wide/Common
  scope.
- Phase 1 availability review never reserves stock.
- Phase 2 allocation is explicit, transactional and server-confirmed.
- Within-plan requests route directly to Procurement; new, over-plan or
  substituted materials require an exception reason and approval.
- Required-on-site date and destination are mandatory at MR submission.
- Supplier Receipt, Warehouse Issue, Site Delivery Receipt and Site Receipt
  Confirmation are distinct business events.
- Do not use workflow statuses named Arranged, Done or Processed.
- Do not hard-delete records with downstream activity. Archive, cancel, void or
  correct them with an auditable reason.

## Security rules

- Engineers must never receive restricted commercial data when cost visibility is disabled.
- UI hiding is not security.
- Keep commercial values in protected storage/views/tables.
- Every RLS change requires positive and negative tests for Engineer, Procurement and Admin.
- Audit events must be append-only and server-generated for critical state transitions.
- Stock allocation, dispatch, return and receipt must be transactional and idempotent.
- Supabase Auth/Postgres are the production identity and data authority.
  Firebase may be used only for FCM transport.
- Release builds must fail closed when Supabase configuration is incomplete.
- Authorization claims come only from server-controlled `app_metadata`; never
  infer a privileged role from an email address or editable user metadata.

## Data migration

- Existing JSON must continue to decode.
- Migrations must be idempotent.
- Never silently discard legacy fields.
- Never reinterpret `authorityRef` as an Other Contractor.
- Preserve IDs, timestamps and attribution.

## Code organisation

Follow the current repository conventions. Prefer small additions over a broad architecture rewrite.

- models: `lib/shared/models/`
- providers/controllers: `lib/shared/providers/`
- repositories/data access: `lib/shared/repositories/` and `lib/shared/sync/`
- feature UI: `lib/features/<feature>/presentation/`
- reusable UI: existing core/shared widget locations
- routes and guards: `lib/app/router.dart`

Widgets must not call Supabase directly. They call providers/controllers/repositories.

## Commands required before completion

```bash
flutter pub get
dart format --output=none --set-exit-if-changed <changed Dart files>
flutter analyze
flutter test
flutter build web --release \
  --dart-define=SUPABASE_URL=https://ci.invalid \
  --dart-define=SUPABASE_ANON_KEY=ci-publishable-key
```

Run narrower tests during development, then the complete suite before finishing.

## Pull request discipline

- One issue and one coherent vertical slice per PR.
- Do not change unrelated modules.
- Include migration notes.
- Include screenshots for UI changes.
- Include tests proving permissions and workflow transitions.
- Leave the worktree clean.
- Summarise files changed, commands run, tests passed and known limitations.

## Stop conditions

Stop and report instead of guessing when:

- the design and current SRS conflict
- a migration could lose existing data
- cost/RLS behaviour is uncertain
- a task requires destructive production changes
- tests expose an existing unrelated failure
- credentials or production access would be required
