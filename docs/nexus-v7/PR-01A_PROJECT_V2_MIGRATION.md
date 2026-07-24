# PR-01A — Project V2 Migration Note

Status: implemented and verified on 24 July 2026.

## Scope

This slice changes the project domain and provider only. It does not change
screens, routes, feature-flag defaults, Supabase schema, RLS, Rentals or HR.

Project v2 adds:

- Yorks reference;
- optional secondary name;
- job/contract number;
- consultant and main contractor;
- stable subcontractor and other-contractor party records;
- project manager and multiple design engineers;
- multiple `ProjectBuilding` records with optional floors/levels;
- boolean-only FRP-room applicability;
- the V7 `Draft → Planning → Active → Archived` lifecycle;
- creator/updater identity, role and timestamp metadata;
- an explicit `dataVersion = 2`.

Legacy aliases remain readable and writable while existing screens are still
on the flat project shape.

## Legacy mapping

| Legacy value | Project v2 value | Preservation rule |
|---|---|---|
| `nameSecondary` | `secondaryName` | Both JSON keys are emitted during transition. |
| `jobNumber` | `contractOrJobNumber` | Both JSON keys are emitted during transition. |
| `lastUpdated` | `updatedAt` | Both JSON keys are emitted during transition. |
| `assignedEngineerId` | `designEngineerUserIds[]` | The legacy engineer is added once and the legacy field is retained. |
| `buildingName` / `floorNumbers` | One deterministic `ProjectBuilding` | Created only when `buildings` is absent; FRP defaults to `false`. |
| `authorityRef` | `authorityRef` plus migration metadata | Never mapped to Other Contractors. |

Legacy floor text is split only on commas, semicolons or new lines. This avoids
inventing structure from free text. The generated building ID is
`<project-id>-building-legacy`, so repeated decoding produces the same result.

An explicitly present empty `buildings` list is respected. It is not replaced
from stale legacy display fields.

## Provider behavior

- The existing `projects_list_v1` storage key remains unchanged.
- On load, the complete local collection is decoded and rewritten as v2 JSON.
  Soft-deleted rows are included in this normalization.
- Yorks references are compared case-insensitively after trimming. Blank
  references remain allowed for legacy projects until the V7 creation flow
  makes the field mandatory.
- Create and update operations stamp actor ID, actor role and UTC timestamps.
- Engineer visibility accepts either the legacy single assignment or the V7
  design-engineer list.
- Existing activation, completion and deletion commands also update the V7
  lifecycle and audit metadata.

## Supabase boundary and security review

No database migration is applied in PR-01A. The current generic project JSON
payload accepts these additive fields, and `contractValueAED` remains excluded
from shared sync payloads.

The future normalized Supabase project/building/party tables must be introduced
in a controlled schema slice with explicit grants, RLS enabled before exposure,
and authorization derived from `app_metadata`. This batch does not broaden Data
API access and does not add client-side privileged credentials.

## Compatibility and rollback

Current legacy records can roll back to the pre-v2 application because v2
continues to emit the legacy secondary-name, job-number and timestamp aliases,
and this batch adds no UI capable of creating v2-only multi-building data.

After a later batch allows users to create multiple buildings or parties,
rolling back to a pre-v2 writer is unsafe: that writer can discard fields it
does not understand. At that point rollback requires a verified backup/export
and a compatibility migration, not a direct application downgrade.

## Verification cases

- complete v2 aggregate round-trip;
- building and party value-object round-trips;
- deterministic legacy flat-building migration;
- authority reference preservation and non-mapping;
- explicit empty-building behavior;
- idempotent v2 re-decoding;
- local provider migration persistence;
- Yorks-reference uniqueness;
- creator/updater audit stamping;
- multi-engineer visibility;
- all pre-existing project-register tests.
