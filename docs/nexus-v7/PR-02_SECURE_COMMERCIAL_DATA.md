# PR-02 — Secure Commercial Data Boundary

Status: implemented and verified on 24 July 2026.

## Outcome

Unit Cost and Total Cost are no longer fields in shared operational storage.
They are separate commercial records protected by the same
`viewCommercials` capability in Flutter and Supabase.

The boundary applies to:

- material unit cost,
- goods-receipt unit and total cost,
- project contract/total value,
- project-cost roll-ups,
- cost CSV export.

It does not redesign Rentals or HR.

## Access contract

| Persona/capability | Read commercials | Write commercials |
|---|---:|---:|
| Admin | Yes | Yes |
| Procurement with `viewCommercials` and `goods` | Yes | Yes |
| Procurement after Admin revokes `viewCommercials` | No | No |
| User with `viewCommercials` but without `goods` | Yes | No |
| Engineer without `viewCommercials` | No | No |
| Anonymous | No | No |

Admin remains a locked superuser. Procurement follows the editable Access &
Roles configuration. The old persisted/JWT capability name `cost` is accepted
only as a migration alias; new claims and role-permission JSON emit
`viewCommercials`.

## Application boundary

- `CommercialRecord` is the protected model for material, goods-receipt and
  project values.
- Connected mode reads and writes `commercial_records` and never persists its
  response in the browser/device operational cache.
- Explicit local-development mode uses a separate protected cache and removes
  it as soon as the session loses commercial access.
- `MaterialItem`, `Project` and `GoodsReceipt` retain backward-compatible
  decoders, but their operational/shared serializers strip cost.
- Operational provider state is cost-free. Authorized presentation providers
  enrich records in memory.
- Add Material, receiving, procurement dispatch, project finance, route guards
  and project-cost export all use the same capability.
- Denied forms do not build commercial fields. Provider writes still fail
  closed, so security does not depend on widget visibility.
- Bootstrap and realtime merge paths recursively remove commercial keys,
  including values nested in line arrays or arbitrary maps.

## Supabase boundary

The live project `czykuksmlwswjsgotrpo` has:

- `public.commercial_records` with a composite
  `(subject_type, subject_id)` primary key,
- non-negative numeric constraints and `AED` currency,
- no Anonymous grants,
- authenticated Select/Insert/Update grants only,
- three command-specific policies targeting `authenticated`,
- no client Delete grant or policy,
- `viewCommercials` for reads,
- `viewCommercials` plus Admin/`goods` for writes,
- five recursive payload triggers on `materials`, `projects`,
  `goodsReceipts`, `materialRequests` and `materialPlans`.

The trigger helper is `SECURITY DEFINER` with an empty `search_path`; direct
execution remains revoked from Anonymous and authenticated users.

Exact deployed migrations:

1. `20260724015401_secure_commercial_boundary.sql`
2. `20260724015517_fix_cost_free_trigger_execution.sql`
3. `20260724015856_drop_unused_commercial_updated_at_index.sql`

The `admin-users` Edge Function is deployed as active version 2 with JWT
verification enabled and canonical `viewCommercials` default claims.

## Data migration evidence

- 56 material unit costs moved to `commercial_records`.
- No current project or goods-receipt rows contained a commercial value to
  migrate.
- All five operational tables report zero rows containing any recognized
  commercial key after recursive inspection.
- Five server triggers prevent future direct REST/client writes from
  reintroducing top-level or nested cost fields.

## Verification

The automated Flutter suite covers:

- denied Engineer state and local cache,
- authorized in-memory enrichment with cost-free shared state,
- denied and read-only writes,
- Procurement role revocation,
- legacy capability migration,
- project and goods-receipt storage/outbox payloads,
- nested bootstrap sanitization,
- denied and correctly escaped CSV export,
- absence of Unit Price in the Engineer material editor.

The tracked pgTAP test covers positive and negative RLS cases. The same matrix
was executed against the live database inside rolled-back transactions,
including recursive trigger behavior.

Post-migration advisors report no commercial-table security or performance
finding. Pre-existing notices remain for deny-all `users`/`auditLogs`, leaked
password protection, older multiple-permissive policies and two older unused
indexes; none was introduced by PR-02.

The final Auth claim snapshot contains one Admin and two Engineer identities,
with no identity currently assigned the Procurement role. The simulated and
local Procurement matrices pass, but an approved Procurement user must be
provisioned or reassigned by Admin before real-persona acceptance testing. No
identity was guessed or reassigned as part of this batch.

## Rollback and recovery

Do not restore commercial values to shared JSON as a normal rollback. An older
app can continue operating while the server table and stripping triggers stay
in place; it will see zero for fields it previously read from shared payloads.

If a release must be rolled back:

1. keep all three database migrations applied,
2. keep `admin-users` version 2 or newer,
3. roll back only the Flutter application,
4. forward-fix the application before changing the protected table.

The 56 migrated values remain recoverable in `commercial_records`. Removing
the table or payload triggers requires an approved data-export and security
review and is not an application rollback step.
