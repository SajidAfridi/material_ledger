-- Preserve the approved Accounts progress workflow while retaining source-import
-- attribution for workbook-backed confirmations.
--
-- The initial YRA-322 import briefly installed an evidence check that was stricter
-- than the authoritative confirmation command. In particular, an authorised
-- decrease may intentionally be recorded without adding another evidence document.
-- Keep source imports linked through their foreign keys and revisions, but do not
-- change the established progress-confirmation semantics.

alter table public.v1_accounts_billing_progress
  drop constraint if exists v1_accounts_progress_confirmation_evidence_check;

create index if not exists v1_accounts_progress_source_import_idx
  on public.v1_accounts_billing_progress (confirmed_source_import_id)
  where confirmed_source_import_id is not null;

create index if not exists v1_accounts_progress_revisions_source_import_idx
  on public.v1_accounts_billing_progress_revisions (source_import_id)
  where source_import_id is not null;

comment on column public.v1_accounts_billing_progress.confirmed_source_import_id is
  'Optional immutable source-import attribution for a confirmed value; ordinary command evidence rules remain authoritative.';
