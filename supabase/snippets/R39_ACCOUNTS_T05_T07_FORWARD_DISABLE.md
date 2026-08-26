# R39 Accounts T05-T07 forward-disable release note

This reviewed emergency artifact disables the normalized Accounts application
surface without deleting commercial evidence. It complements the existing
T01-T04 forward-disable artifact: the application flag is turned off first,
then this SQL returns the export capability to shadow and revokes the T06/T07
client and service entry points.

It does not drop or rewrite baselines, progress, claims, invoices,
certifications, receipts, PDCs, supplier bills, payments, controlled documents,
audit events, notifications, metrics, job history or idempotency results.

## Emergency application

1. Deploy or confirm an application build with `YORKS_V1_ACCOUNTS=false` and
   verify Auth, Projects, BOQ, Material Requests, Inventory, logistics,
   Returns, User Management and Audit Trail.
2. If the defect affects T02-T04 commands, apply the reviewed T01-T04
   forward-disable artifact in the same corrective release.
3. Create a new migration and copy
   `supabase/snippets/r39_accounts_t05_t07_forward_disable.sql` into it. Never
   edit an applied R39 migration.
4. Prove clean reset, full pgTAP and dry-run migration output before any remote
   push. Production execution still needs explicit release authorization.
5. Compare all protected row/evidence counts before and after the corrective
   migration. A discrepancy is a stop condition.

## Re-enable

Ship a new reviewed forward migration that restores only the corrected RPC
grants and the `export_accounts_registers` operational capability. Complete
the five-persona staging UAT on the same application commit before enabling
`YORKS_V1_ACCOUNTS` in a separate deployment.
