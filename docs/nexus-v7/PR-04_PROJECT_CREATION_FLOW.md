# PR-04 — Yorks Nexus V7 project creation flow

Date: 24 July 2026  
Status: complete

## Scope

This slice replaces the legacy one-page project form only when the V7 Projects
flag is enabled. The existing `/projects/new` route and legacy form remain the
fail-closed fallback.

The enabled flow is shared by Engineer, Procurement and Admin and contains
exactly three stages:

1. Essentials & Responsibility
2. Buildings
3. Review & Create

Parties remain optional in stage 1. Document references remain optional inside
stage 2 and are not promoted into a fourth stage.

## Product behavior

- Yorks reference, project name, client, site, start date and at least one
  design/site engineer are required.
- Yorks references are checked case-insensitively against the project register.
- End date is optional and cannot precede the start date.
- Project manager, secondary name, contract/job number, consultant, main
  contractor, subcontractors, other contractors and notes are optional.
- Multiple physical buildings are supported. Code and name are required for
  each building; code is unique within the project.
- Floors/levels remain optional and FRP remains a strict Yes/No value.
- Every created project receives one explicit, non-physical `COMMON` scope for
  project-wide material and document relationships.
- Legacy `authorityRef` is never populated from Other Contractors.
- Optional document metadata records file name, type, reference, project or
  building scope, actor, role and UTC time. Binary upload remains in the later
  Documents workspace.
- Engineer-created projects enter Procurement's existing acceptance queue.
  Procurement/Admin-created projects are acknowledged at creation to avoid a
  redundant office step.
- The final record retains creator/updater identity, role and UTC timestamp and
  continues through the existing project outbox.

## Draft and responsive behavior

- Drafts autosave after input changes and can also be saved explicitly.
- The storage key is isolated by stable application user id.
- Reopening the flow restores the user's step and values.
- Discard clears only that user's unfinished project.
- Desktop uses the approved left stage rail and two-column fields.
- Tablet/mobile use a horizontal stage strip and stacked fields/actions.
- Stage changes reset the flow scroll position; no desktop layout is squeezed
  into mobile.
- All actions retain the shared 44 px minimum target.

## Data compatibility

`Project.currentDataVersion` is now `3`. Version 3 adds:

- `ProjectBuilding.scope` (`physical` or `common`);
- `Project.attachments`;
- project/building-linked attachment audit metadata.

Version 1 flat buildings still migrate deterministically. Explicit version 2
records remain valid and are not assigned false legacy migration metadata.
Unknown additive version 3 fields are absent by default when an older record is
decoded.

The legacy flat `buildingName`, `floorNumbers` and `assignedEngineerId` fields
are still populated on new projects so screens outside PR-04 continue to work.

## Supabase review

No database migration or policy expansion is required in this slice. Projects
continue through the existing operational JSONB collection and outbox, with a
stable project id in every upsert. Existing authenticated project RLS remains
the server boundary. Commercial values are not introduced into the project
payload.

The attachment rows in this slice are metadata only. Supabase Storage object
policies and normalized document tables must be introduced by the Documents
workspace slice before binary upload is enabled.

## Verification

- Version 1, 2 and 3 project serialization/migration tests.
- Building scope and attachment round-trip tests.
- Per-user draft save, restore, isolation and discard tests.
- Engineer and office conversion/acceptance tests.
- Feature-flag rollback test.
- Exact three-stage contract test.
- End-to-end review/create test, including common scope, Other Contractors,
  actor/role metadata and Procurement acceptance behavior.
- Mobile and tablet overflow tests.
- Human-readable 1280×900 desktop golden.
- Human-readable 390×844 mobile golden.
- Both golden images visually inspected against the approved V7 design.
- `flutter analyze`: passed with zero issues.
- `flutter test`: passed, 302 tests.
- `flutter build web --release` with non-secret CI Supabase placeholders:
  passed.
- `git diff --check`: passed.

## Rollout

The owning flag remains off by default:

```text
NEXUS_V7_PROJECTS=false
```

Enable it only in a controlled environment after the target Supabase project
and three real personas have passed the project-creation acceptance script.

## Rollback

The safe operational rollback is to set `NEXUS_V7_PROJECTS=false`; this restores
the legacy form without changing the route.

After version 3 projects exist, do not roll back the version 3 codecs. Older
code can ignore the additive values while reading, but it may remove building
scope or attachment metadata if it rewrites a project. Keep the additive model
support deployed even if the V7 screen is disabled.
