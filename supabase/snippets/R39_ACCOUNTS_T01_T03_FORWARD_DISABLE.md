# R39 Accounts T01-T03 forward-disable release note

This reviewed emergency artifact returns only the T02 commercial baseline /
Billing Progress and T03 client-receivables consumers to `planned`, `shadow`
and nonassignable. It also removes `EXECUTE` from `PUBLIC`, `anon` and
`authenticated` on their exact command and projection RPCs.

It does **not** drop, delete, truncate, rebase or rewrite Accounts tables,
claims, invoices, certifications, payments, PDCs, revisions, audit events,
idempotency results or permission assignments. `service_role` retains recovery
and inspection access. The safe T01 foundation projection remains available so
operators can confirm that consumers are disabled.

## Emergency application

1. Deploy or confirm an application build with `YORKS_V1_ACCOUNTS=false` before
   changing database execution grants. Verify the existing non-Accounts site.
2. Generate a new migration with
   `npx supabase migration new r39_accounts_t01_t03_forward_disable`.
3. Copy the SQL from
   `supabase/snippets/r39_accounts_t01_t03_forward_disable.sql` into that new
   migration without modifying an already-applied T01, T02 or T03 migration.
4. Run `supabase db reset` and `supabase test db`, then inspect
   `npx supabase db push --linked --dry-run`.
5. Apply the new forward migration with `npx supabase db push --linked` and run
   the post-disable checks below. Never use a remote reset, destructive down
   migration or migration-history repair for this response.

Allow any transaction that began before the deployment to finish before
recording the final row-count and permission evidence; revocation blocks new
calls but does not cancel work already executing inside a transaction.

The SQL is transactional and re-runnable. Missing RPC signatures are already
fail-closed and are skipped; every existing listed RPC must finish without a
`PUBLIC`, `anon` or `authenticated` execute ACL or the transaction fails.

## Post-disable checks

- Exactly 11 T02/T03 capability rows are `planned` / `shadow` /
  `is_assignable=false`.
- Authenticated calls to each listed T02/T03 command/projection fail with an
  execution-permission error.
- `v1_get_accounts_foundation` reports the disabled runtime state.
- Existing Accounts row counts, append-only events, audit rows and idempotency
  results are unchanged.
- Auth, Projects, BOQ, Material Requests, Inventory, Dispatch, Returns, User
  Management and Audit Trail smoke tests remain green.

## Re-enable

Do not delete or edit the applied forward-disable migration. After the incident
is fixed and T02/T03 tests pass again, create a new reviewed forward migration
that restores only the accepted capability modes and exact RPC grants. Verify
that database cutover first, then enable `YORKS_V1_ACCOUNTS` in a separately
verified application deployment. This keeps migration history and every
commercial fact attributable.
