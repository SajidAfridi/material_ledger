-- Yorks R39 Accounts T01-T03 emergency forward-disable gate.
--
-- REVIEWED ARTIFACT ONLY: this file is deliberately outside migrations and is
-- never auto-applied. Production use requires copying this exact SQL into a
-- newly generated, timestamped forward migration after the application flag
-- has been disabled and the normal release checks have passed.
--
-- Data preservation contract:
-- * no table, row, RLS policy, trigger, audit event or idempotency fact is
--   dropped, deleted, truncated or rewritten;
-- * only the 11 consumers activated by T02/T03 return to planned/shadow and
--   nonassignable;
-- * authenticated, anon and PUBLIC lose T02/T03 command/projection execution;
-- * service_role retains inspection/recovery access;
-- * the T01 foundation projection remains available and reports these
--   consumers as disabled.

begin;

update public.v1_capability_catalog
set status = 'planned',
    authorization_mode = 'shadow',
    is_assignable = false
where capability_key = any(array[
  'view_project_accounts',
  'view_project_commercial_values',
  'suggest_billing_progress',
  'confirm_billing_progress',
  'configure_project_commercials',
  'review_commercial_progress',
  'prepare_client_claim',
  'manage_client_invoices',
  'record_client_certification',
  'record_client_payment',
  'manage_pdc'
]::text[]);

-- Use identity signatures so overloaded functions are revoked precisely. A
-- missing function is already fail-closed and is skipped, making this safe to
-- re-run after either a complete or interrupted T02/T03 deployment.
do $forward_disable$
declare
  v_signature text;
  v_function regprocedure;
begin
  foreach v_signature in array array[
    -- T02 baseline and Billing Progress commands/projections.
    'public.v1_initialize_project_commercial_baseline(uuid,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid)',
    'public.v1_revise_project_commercial_baseline(uuid,integer,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid)',
    'public.v1_suggest_billing_progress(uuid,uuid,integer,text,text,uuid[],text,uuid)',
    'public.v1_confirm_billing_progress(uuid,uuid,integer,text,text,uuid[],text,uuid)',
    'public.v1_review_commercial_progress(uuid,uuid,integer,text,text,uuid)',
    'public.v1_get_project_commercial_baseline(uuid)',
    'public.v1_list_project_commercial_baseline_revisions(uuid,integer)',
    'public.v1_list_project_commercial_baseline_revisions(uuid,integer,integer)',
    'public.v1_list_billing_progress(uuid,uuid,text,text,boolean)',
    'public.v1_list_billing_progress_revisions(uuid,uuid,integer,integer)',

    -- T03 claim and client-receivables commands.
    'public.v1_create_client_claim_draft(uuid,text,date,date,jsonb,text,uuid,text)',
    'public.v1_update_client_claim_draft(uuid,uuid,integer,text,date,date,jsonb,text,uuid,text)',
    'public.v1_delete_client_claim_draft(uuid,uuid,integer,text,uuid)',
    'public.v1_submit_client_claim_to_accounts(uuid,uuid,integer,text,uuid)',
    'public.v1_cancel_client_claim(uuid,uuid,integer,text,uuid)',
    'public.v1_create_client_invoice_draft(uuid,uuid,text,text,uuid)',
    'public.v1_update_client_invoice_draft(uuid,uuid,integer,text,text,uuid)',
    'public.v1_submit_client_invoice(uuid,uuid,integer,date,text,uuid)',
    'public.v1_mark_client_invoice_under_certification(uuid,uuid,integer,text,uuid)',
    'public.v1_return_client_invoice(uuid,uuid,integer,text,uuid)',
    'public.v1_cancel_client_invoice(uuid,uuid,integer,text,uuid)',
    'public.v1_record_client_certification(uuid,uuid,integer,text,date,text,text,uuid)',
    'public.v1_record_client_payment(uuid,uuid,integer,date,text,text,text,text,uuid)',
    'public.v1_reverse_client_payment(uuid,uuid,integer,uuid,date,text,text,uuid)',
    'public.v1_create_client_pdc(uuid,uuid,integer,text,date,text,text,uuid)',
    'public.v1_transition_client_pdc(uuid,uuid,integer,text,date,text,text,uuid)',
    'public.v1_replace_client_pdc(uuid,uuid,integer,text,date,text,text,text,uuid)',

    -- T03 role-safe projections.
    'public.v1_get_client_claim(uuid,uuid)',
    'public.v1_list_client_claims(uuid,text,timestamp with time zone,uuid,integer)',
    'public.v1_get_client_invoice(uuid,uuid)',
    'public.v1_list_client_invoices(uuid,text,text,timestamp with time zone,uuid,integer)',
    'public.v1_list_client_receipts_pdc(uuid,uuid,timestamp with time zone,uuid,integer)'
  ]::text[]
  loop
    v_function := to_regprocedure(v_signature);
    if v_function is not null then
      execute format(
        'revoke all on function %s from public, anon, authenticated',
        v_function
      );
    end if;
  end loop;
end;
$forward_disable$;

-- Fail the transaction unless every activated T02/T03 consumer is disabled.
do $verify_capabilities$
declare
  v_disabled_count integer;
begin
  select count(*)
  into v_disabled_count
  from public.v1_capability_catalog
  where capability_key = any(array[
    'view_project_accounts',
    'view_project_commercial_values',
    'suggest_billing_progress',
    'confirm_billing_progress',
    'configure_project_commercials',
    'review_commercial_progress',
    'prepare_client_claim',
    'manage_client_invoices',
    'record_client_certification',
    'record_client_payment',
    'manage_pdc'
  ]::text[])
    and status = 'planned'
    and authorization_mode = 'shadow'
    and not is_assignable;

  if v_disabled_count <> 11 then
    raise exception 'R39_ACCOUNTS_FORWARD_DISABLE_CAPABILITY_CHECK_FAILED'
      using errcode = '23514';
  end if;
end;
$verify_capabilities$;

-- Verify there is no direct or PUBLIC execute ACL on any existing listed RPC.
do $verify_execution$
declare
  v_signature text;
  v_function regprocedure;
  v_public_execute boolean;
begin
  foreach v_signature in array array[
    'public.v1_initialize_project_commercial_baseline(uuid,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid)',
    'public.v1_revise_project_commercial_baseline(uuid,integer,text,text,text,integer,integer,jsonb,jsonb,jsonb,text,uuid)',
    'public.v1_suggest_billing_progress(uuid,uuid,integer,text,text,uuid[],text,uuid)',
    'public.v1_confirm_billing_progress(uuid,uuid,integer,text,text,uuid[],text,uuid)',
    'public.v1_review_commercial_progress(uuid,uuid,integer,text,text,uuid)',
    'public.v1_get_project_commercial_baseline(uuid)',
    'public.v1_list_project_commercial_baseline_revisions(uuid,integer)',
    'public.v1_list_project_commercial_baseline_revisions(uuid,integer,integer)',
    'public.v1_list_billing_progress(uuid,uuid,text,text,boolean)',
    'public.v1_list_billing_progress_revisions(uuid,uuid,integer,integer)',
    'public.v1_create_client_claim_draft(uuid,text,date,date,jsonb,text,uuid,text)',
    'public.v1_update_client_claim_draft(uuid,uuid,integer,text,date,date,jsonb,text,uuid,text)',
    'public.v1_delete_client_claim_draft(uuid,uuid,integer,text,uuid)',
    'public.v1_submit_client_claim_to_accounts(uuid,uuid,integer,text,uuid)',
    'public.v1_cancel_client_claim(uuid,uuid,integer,text,uuid)',
    'public.v1_create_client_invoice_draft(uuid,uuid,text,text,uuid)',
    'public.v1_update_client_invoice_draft(uuid,uuid,integer,text,text,uuid)',
    'public.v1_submit_client_invoice(uuid,uuid,integer,date,text,uuid)',
    'public.v1_mark_client_invoice_under_certification(uuid,uuid,integer,text,uuid)',
    'public.v1_return_client_invoice(uuid,uuid,integer,text,uuid)',
    'public.v1_cancel_client_invoice(uuid,uuid,integer,text,uuid)',
    'public.v1_record_client_certification(uuid,uuid,integer,text,date,text,text,uuid)',
    'public.v1_record_client_payment(uuid,uuid,integer,date,text,text,text,text,uuid)',
    'public.v1_reverse_client_payment(uuid,uuid,integer,uuid,date,text,text,uuid)',
    'public.v1_create_client_pdc(uuid,uuid,integer,text,date,text,text,uuid)',
    'public.v1_transition_client_pdc(uuid,uuid,integer,text,date,text,text,uuid)',
    'public.v1_replace_client_pdc(uuid,uuid,integer,text,date,text,text,text,uuid)',
    'public.v1_get_client_claim(uuid,uuid)',
    'public.v1_list_client_claims(uuid,text,timestamp with time zone,uuid,integer)',
    'public.v1_get_client_invoice(uuid,uuid)',
    'public.v1_list_client_invoices(uuid,text,text,timestamp with time zone,uuid,integer)',
    'public.v1_list_client_receipts_pdc(uuid,uuid,timestamp with time zone,uuid,integer)'
  ]::text[]
  loop
    v_function := to_regprocedure(v_signature);
    if v_function is null then
      continue;
    end if;

    select exists (
      select 1
      from aclexplode(coalesce(
        (select proc.proacl from pg_proc proc where proc.oid = v_function),
        acldefault('f', (
          select proc.proowner from pg_proc proc where proc.oid = v_function
        ))
      )) acl
      left join pg_roles role on role.oid = acl.grantee
      where acl.privilege_type = 'EXECUTE'
        and (
          acl.grantee = 0
          or role.rolname in ('anon', 'authenticated')
        )
    ) into v_public_execute;

    if v_public_execute then
      raise exception 'R39_ACCOUNTS_FORWARD_DISABLE_EXECUTE_CHECK_FAILED: %',
        v_signature
        using errcode = '42501';
    end if;
  end loop;
end;
$verify_execution$;

commit;
