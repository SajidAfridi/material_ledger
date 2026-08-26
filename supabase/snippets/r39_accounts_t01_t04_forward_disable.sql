-- Yorks R39 Accounts T01-T04 emergency forward-disable gate.
--
-- REVIEWED ARTIFACT ONLY. Copy this SQL into a newly timestamped forward
-- migration only after YORKS_V1_ACCOUNTS is disabled. It preserves every
-- Accounts row, payment, reversal, document link, receipt fact, audit event and
-- idempotency result. It changes only consumer capability modes and RPC ACLs.

begin;

update public.v1_capability_catalog
set status = 'planned', authorization_mode = 'shadow', is_assignable = false
where capability_key = any(array[
  'view_project_accounts', 'view_project_commercial_values',
  'suggest_billing_progress', 'confirm_billing_progress',
  'configure_project_commercials', 'review_commercial_progress',
  'prepare_client_claim', 'manage_client_invoices',
  'record_client_certification', 'record_client_payment', 'manage_pdc',
  'manage_supplier_bills', 'approve_supplier_bill_payment',
  'view_supplier_costs'
]::text[]);

-- Exact identity signatures avoid revoking an unrelated overload. A missing
-- signature is already fail-closed, so interrupted deployments are re-runnable.
do $forward_disable$
declare
  v_signature text;
  v_function regprocedure;
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
    'public.v1_list_client_receipts_pdc(uuid,uuid,timestamp with time zone,uuid,integer)',
    'public.v1_create_supplier_bill_draft(uuid,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid)',
    'public.v1_update_supplier_bill_draft(uuid,uuid,integer,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid)',
    'public.v1_approve_supplier_bill(uuid,uuid,integer,text,uuid)',
    'public.v1_record_supplier_payment(uuid,uuid,integer,date,text,text,text,text,text,uuid)',
    'public.v1_reverse_supplier_payment(uuid,uuid,integer,uuid,date,text,text,uuid)',
    'public.v1_cancel_supplier_bill(uuid,uuid,integer,text,uuid)',
    'public.v1_get_supplier_bill(uuid,uuid)',
    'public.v1_list_supplier_bills(uuid,text,text,text,timestamp with time zone,uuid,integer)'
  ]::text[] loop
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

do $verify_capabilities$
declare
  v_disabled_count integer;
begin
  select count(*) into v_disabled_count
  from public.v1_capability_catalog
  where capability_key = any(array[
    'view_project_accounts', 'view_project_commercial_values',
    'suggest_billing_progress', 'confirm_billing_progress',
    'configure_project_commercials', 'review_commercial_progress',
    'prepare_client_claim', 'manage_client_invoices',
    'record_client_certification', 'record_client_payment', 'manage_pdc',
    'manage_supplier_bills', 'approve_supplier_bill_payment',
    'view_supplier_costs'
  ]::text[])
    and status = 'planned'
    and authorization_mode = 'shadow'
    and not is_assignable;

  if v_disabled_count <> 14 then
    raise exception 'R39_ACCOUNTS_FORWARD_DISABLE_CAPABILITY_CHECK_FAILED'
      using errcode = '23514';
  end if;
end;
$verify_capabilities$;

-- Verify that no listed, existing RPC retains PUBLIC/anon/authenticated EXECUTE.
do $verify_execution$
declare
  v_signature text;
  v_function regprocedure;
  v_exposed boolean;
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
    'public.v1_list_client_receipts_pdc(uuid,uuid,timestamp with time zone,uuid,integer)',
    'public.v1_create_supplier_bill_draft(uuid,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid)',
    'public.v1_update_supplier_bill_draft(uuid,uuid,integer,uuid,text,text,date,date,text,text,text,uuid,uuid,uuid,text,text,uuid)',
    'public.v1_approve_supplier_bill(uuid,uuid,integer,text,uuid)',
    'public.v1_record_supplier_payment(uuid,uuid,integer,date,text,text,text,text,text,uuid)',
    'public.v1_reverse_supplier_payment(uuid,uuid,integer,uuid,date,text,text,uuid)',
    'public.v1_cancel_supplier_bill(uuid,uuid,integer,text,uuid)',
    'public.v1_get_supplier_bill(uuid,uuid)',
    'public.v1_list_supplier_bills(uuid,text,text,text,timestamp with time zone,uuid,integer)'
  ]::text[] loop
    v_function := to_regprocedure(v_signature);
    if v_function is null then continue; end if;
    select exists (
      select 1
      from aclexplode(coalesce(
        (select p.proacl from pg_proc p where p.oid = v_function),
        acldefault('f', (select p.proowner from pg_proc p where p.oid = v_function))
      )) acl
      left join pg_roles role on role.oid = acl.grantee
      where acl.privilege_type = 'EXECUTE'
        and (acl.grantee = 0 or role.rolname in ('anon', 'authenticated'))
    ) into v_exposed;
    if v_exposed then
      raise exception 'R39_ACCOUNTS_FORWARD_DISABLE_EXECUTE_CHECK_FAILED: %',
        v_signature using errcode = '42501';
    end if;
  end loop;
end;
$verify_execution$;

commit;
