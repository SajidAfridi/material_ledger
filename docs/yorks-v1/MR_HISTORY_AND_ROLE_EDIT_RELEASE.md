# MR history stability and Procurement role editing

Scope: the approved MR header/sidebar polish plus the 25 September 2026
request for a direct switch granting all Procurement users edit access.

- Routine detail refresh preserves the authorized history timeline and its
  geometry. Permission/history invalidation clears it. Modal information panels
  fill the viewport. Header actions adapt to available width and text scale.
- The Procurement switch sends one version-checked command without a dialog or
  recipient query, prevents duplicate clicks while saving, and shows confirmed
  state. Existing named grants remain valid until explicitly changed.
- The explicit role grant defaults false, requires an active exact Procurement
  role and arrangement capability, and preserves the arrangement cutoff.
- The server records grant scope/version/actor in the existing immutable audit
  event. Request History labels that event, and the audit catalogue classifies it.
  PostHog receives only confirmed outcomes or normalized failures, with no record
  or recipient IDs. Analytics is separate from the authoritative audit ledger.

## Verification

34 focused Flutter tests passed: responsive layouts, refresh geometry,
permission invalidation, server-confirmed switches, rejected saves, telemetry
ordering and privacy allowlist. Flutter analyze passed. Visual evidence covers
1920/1440 desktop, 1366 with navigation expanded, tablet and 360px mobile.
Staging transactional pgTAP: 33 existing named-grant and 26 role-grant assertions
passed. Covers two Procurement actors, Site Engineer denial, Project Engineer
and Admin grants, inactive actor denial, stale competing updates, idempotency,
the prior reapproval rule, arrangement cutoff, and one audit event per
successful command. This paragraph records the earlier release; the 25
September Save refinement in `PRODUCT_DECISIONS.md` supersedes reapproval.
All fixtures were rolled back; staging retained its 17 original requests and
zero enabled role grants. True simultaneous writer load testing was not run.

The complete Flutter suite remains red with inherited failures; it is not a
production release approval. Local Supabase reset/test was unavailable because
Docker was not running and the CLI was not installed; tests ran transactionally
against the confirmed staging project instead. PostHog ingestion was not
verified: the connected tool rejects its required learn command. The staging
security advisor includes existing RPC-only/no-policy notices and disabled
leaked-password protection; this slice does not change those platform settings.
See https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.

## Deployment and rollback

Staging project: iqltcyimlqtcwyzlemwx. Apply migrations
20260924210656, 20260924210914 and 20260924211111 before the client.
Production has not been changed and requires explicit approval.
To roll back, disable any role grants through the audited command before
reverting client/functions. Retain the additive column, original named grants,
request revisions and audit history. Do not drop or rewrite records.
Final deployment/hash evidence is stored with the automation evidence package.
