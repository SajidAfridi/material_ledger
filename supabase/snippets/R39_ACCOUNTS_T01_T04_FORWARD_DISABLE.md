# R39 Accounts T01-T04 forward-disable release note

This reviewed emergency artifact returns the 14 operational T02–T04 Accounts
capabilities to `planned`, `shadow` and nonassignable, then removes `EXECUTE`
from `PUBLIC`, `anon` and `authenticated` on their exact command/projection
RPCs. It is deliberately outside `supabase/migrations` and is never applied
automatically.

It does not drop, delete, truncate, rebase or rewrite Accounts relations,
supplier bills, client invoices, certifications, payments, reversals, PDCs,
controlled-document links, operational receipts, audit events, idempotency
results or permission assignments. `service_role` retains inspection and
recovery access.

## Emergency application

1. First deploy or confirm an application build with
   `YORKS_V1_ACCOUNTS=false`; verify the non-Accounts site remains healthy.
2. Create a new migration with
   `npx supabase migration new r39_accounts_t01_t04_forward_disable`.
3. Copy `supabase/snippets/r39_accounts_t01_t04_forward_disable.sql` into that
   new migration. Never edit an already-applied T01–T04 migration.
4. Run `npx supabase db reset` and `npx supabase test db`, then inspect
   `npx supabase db push --linked --dry-run`.
5. Only with explicit production authorization, apply the new forward
   migration and run the post-disable checks below. Never reset a remote
   database or repair migration history for this response.

Allow transactions already running at deployment time to finish before the
final evidence snapshot. Revocation blocks new calls but does not cancel a
transaction already inside a trusted command.

## Post-disable checks

- Exactly 14 T02–T04 capability rows are `planned` / `shadow` /
  `is_assignable=false`.
- Authenticated calls to every listed T02–T04 command/projection fail with an
  execution-permission error.
- `v1_get_accounts_foundation` reports the disabled runtime state.
- All Accounts row counts and append-only evidence counts are unchanged.
- Auth, Projects, BOQ, Material Requests, Inventory, Dispatch, Receipt,
  Returns, User Management and Audit Trail regression checks remain green.

## Re-enable

After correction and complete T01–T04 acceptance, create another reviewed
forward migration that restores only the accepted capability modes and exact
RPC grants. Verify database cutover before enabling `YORKS_V1_ACCOUNTS` in a
separate application deployment. Never delete or edit the applied disable
migration.
