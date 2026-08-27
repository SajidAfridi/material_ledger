begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

select ok(
  has_function_privilege(
    'authenticated',
    'public.v1_get_accounts_office_register(text,text,text,integer,integer)',
    'execute'
  )
  and not has_function_privilege(
    'anon',
    'public.v1_get_accounts_office_register(text,text,text,integer,integer)',
    'execute'
  ),
  'T08 exposes the office projection only to authenticated callers'
);

insert into public.v1_projects(
  id, project_ref, name, project_site, state, current_action_owner_role,
  created_by_auth_user_id, created_by_role
) values(
  '39810000-0000-4000-8000-000000000001', 'R39-T08-001',
  'Account Office projection', 'Abu Dhabi', 'active', 'project_engineer',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

insert into public.v1_audit_events(
  id, event_type, entity_type, entity_id, project_id,
  actor_auth_user_id, actor_role, actor_exact_role, occurred_at,
  idempotency_key, reason
) values(
  '39820000-0000-4000-8000-000000000001',
  'accounts.client_payment.recorded', 'accounts_client_payment',
  '39830000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000013',
  'accountant', 'accountant', '2026-08-27 09:45:00+00',
  '39890000-0000-4000-8000-000000000001',
  'T08 office activity fixture'
);

insert into public.v1_accounts_baseline_revisions(
  id, project_id, revision_number, status, contract_value, currency_code,
  vat_rate_percent, payment_terms_days, reminder_lead_days,
  management_review_policy, reason, approved_by_auth_user_id,
  approved_by_role, approved_by_exact_role, idempotency_key
) values(
  '39840000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001', 1, 'current',
  100000.00, 'AED', 0.0000, 45, 10, '{}'::jsonb,
  'T08 lossless projection fixture',
  '10000000-0000-4000-8000-000000000004', 'admin', 'admin',
  '39890000-0000-4000-8000-000000000002'
);
insert into public.v1_accounts_project_commercial_profiles(
  project_id, current_baseline_revision_id, created_by_auth_user_id,
  created_by_role, created_by_exact_role
) values(
  '39810000-0000-4000-8000-000000000001',
  '39840000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000004', 'admin', 'admin'
);
insert into public.v1_accounts_client_claims(
  id, project_id, baseline_revision_id, claim_reference,
  claim_period_start, claim_period_end, status,
  created_by_auth_user_id, created_by_role, created_by_exact_role,
  idempotency_key
) values(
  '39850000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001',
  '39840000-0000-4000-8000-000000000001', 'CLM-T08-001',
  date '2026-08-01', date '2026-08-27', 'draft',
  '10000000-0000-4000-8000-000000000013', 'accountant', 'accountant',
  '39890000-0000-4000-8000-000000000003'
);
insert into public.v1_accounts_supplier_bills(
  id, project_id, supplier_name_snapshot, supplier_invoice_reference,
  invoice_date, due_date, ex_vat_amount, vat_rate_percent, vat_amount,
  total_incl_vat, notes, created_by_auth_user_id, created_by_role,
  created_by_exact_role, idempotency_key
) values(
  '39860000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001',
  'T08 Supplier LLC', 'SUP-T08-001', current_date, current_date + 5,
  100.00, 5.0000, 5.00, 105.00, 'T08 supplier visibility fixture',
  '10000000-0000-4000-8000-000000000013', 'accountant', 'accountant',
  '39890000-0000-4000-8000-000000000004'
);
insert into public.v1_documents(
  id, classification, created_by_auth_user_id, created_by_role
) values(
  '39870000-0000-4000-8000-000000000001', 'commercial',
  '10000000-0000-4000-8000-000000000004', 'admin'
);
insert into public.v1_document_versions(
  id, document_id, revision_number, object_path, original_file_name,
  mime_type, byte_size, sha256, origin, uploaded_by_auth_user_id,
  uploaded_by_role
) values(
  '39871000-0000-4000-8000-000000000001',
  '39870000-0000-4000-8000-000000000001', 1,
  'documents/r39-t08/accounts-office.pdf', 'Accounts Office.pdf',
  'application/pdf', 2048, repeat('b', 64), 'uploaded',
  '10000000-0000-4000-8000-000000000004', 'admin'
);
update public.v1_documents
set current_version_id = '39871000-0000-4000-8000-000000000001'
where id = '39870000-0000-4000-8000-000000000001';
insert into public.v1_accounts_document_metadata(document_id, document_type)
values('39870000-0000-4000-8000-000000000001', 'contract');
insert into public.v1_document_links(
  id, document_id, project_id, entity_type, entity_id, linked_at,
  linked_by_auth_user_id, linked_by_role
) values(
  '39872000-0000-4000-8000-000000000001',
  '39870000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001', 'accounts_baseline_revision',
  '39840000-0000-4000-8000-000000000001', '2026-08-27 09:00:00+00',
  '10000000-0000-4000-8000-000000000004', 'admin'
),(
  '39872000-0000-4000-8000-000000000002',
  '39870000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001', 'accounts_client_claim',
  '39850000-0000-4000-8000-000000000001', '2026-08-27 09:01:00+00',
  '10000000-0000-4000-8000-000000000004', 'admin'
);

create temporary table v1_r39_t08_results(
  result_key text primary key,
  payload jsonb not null
);
grant select, insert on v1_r39_t08_results to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant","app_user_id":"usr-local-accountant"}}',
  true
);

insert into v1_r39_t08_results(result_key, payload)
select 'activity', public.v1_get_accounts_office_register(
  'activity', null, null, 25, 0
);

select ok(
  (
    select payload->>'section' = 'activity'
      and payload->>'total' = '1'
      and payload->'items'->0->>'project_reference' = 'R39-T08-001'
      and payload->'items'->0->>'reference' = 'accounts.client_payment.recorded'
      and payload->'summary'->>'amount' = '0'
      and jsonb_typeof(payload->'items') = 'array'
    from v1_r39_t08_results where result_key = 'activity'
  ),
  'Accountant receives one server-shaped portfolio activity page with decimal strings'
);

insert into v1_r39_t08_results(result_key, payload)
select 'claims', public.v1_get_accounts_office_register(
  'claims', null, null, 25, 0
);
select ok(
  (
    select payload->>'total' = '1'
      and payload->'items'->0->>'reference' = 'CLM-T08-001'
      and jsonb_typeof(payload->'summary'->'amount') = 'string'
      and jsonb_typeof(payload->'items'->0->'amount') = 'string'
      and payload->'items'->0->>'amount' = '0'
      and not (payload ? 'capabilities')
    from v1_r39_t08_results where result_key = 'claims'
  ),
  'Money is lossless text and the read projection exposes no cross-project mutation hints'
);

insert into v1_r39_t08_results(result_key, payload)
select 'supplier', public.v1_get_accounts_office_register(
  'supplier_bills', null, null, 25, 0
);
select ok(
  (
    select payload->>'total' = '1'
      and payload->'items'->0->>'reference' = 'SUP-T08-001'
      and payload->'items'->0->'metadata'->>'match_status' = 'blocked'
      and jsonb_typeof(payload->'items'->0->'metadata'->'vat_amount') = 'string'
    from v1_r39_t08_results where result_key = 'supplier'
  ),
  'Supplier projection uses the authoritative match status and lossless VAT text'
);

insert into v1_r39_t08_results(result_key, payload)
select 'documents', public.v1_get_accounts_office_register(
  'documents', null, null, 25, 0
);
select ok(
  (
    select payload->>'total' = '1'
      and payload->'items'->0->>'reference' = 'Accounts Office.pdf'
      and payload->'items'->0->'metadata'->>'entity_type'
        = 'accounts_baseline_revision'
    from v1_r39_t08_results where result_key = 'documents'
  ),
  'Multiple active Accounts links produce one deterministic document/project row'
);

insert into v1_r39_t08_results(result_key, payload)
select 'filtered', public.v1_get_accounts_office_register(
  'activity', 'does-not-exist', null, 25, 0
);
select is(
  (select payload->>'total' from v1_r39_t08_results where result_key = 'filtered'),
  '0',
  'Office search is applied before pagination and summary calculation'
);

select throws_ok(
  $sql$select public.v1_get_accounts_office_register(
    'bank_reconciliation', null, null, 25, 0
  )$sql$,
  '22023', 'R39_ACCOUNTS_OFFICE_SECTION_INVALID',
  'Deferred bank reconciliation cannot be requested through the office RPC'
);
select throws_ok(
  $sql$select public.v1_get_accounts_office_register(
    'claims', null, null, 101, 0
  )$sql$,
  '22023', 'R39_ACCOUNTS_OFFICE_PAGE_INVALID',
  'Invalid Account Office pagination fails closed'
);

reset role;
insert into public.v1_permission_assignments(
  id, auth_user_id, capability_key, effect, scope_kind, reason,
  changed_by_auth_user_id
) values(
  '39880000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000013',
  'view_project_accounts', 'deny', 'project',
  'T08 verifies supplier-cost-only scope cannot enter Account Office rows',
  '10000000-0000-4000-8000-000000000004'
);
insert into public.v1_permission_assignment_projects(assignment_id, project_id)
values(
  '39880000-0000-4000-8000-000000000001',
  '39810000-0000-4000-8000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000013","role":"authenticated","app_metadata":{"role":"accountant","app_user_id":"usr-local-accountant"}}',
  true
);
select ok(
  public.v1_current_user_has_capability(
    'view_supplier_costs', '39810000-0000-4000-8000-000000000001'
  )
  and not public.v1_current_user_has_capability(
    'view_project_accounts', '39810000-0000-4000-8000-000000000001'
  ),
  'Fixture has supplier-cost capability but no Accounts scope for the project'
);
select ok(
  public.v1_get_accounts_office_register(
    'supplier_bills', null, null, 25, 0
  )->>'total' = '0'
  and public.v1_get_accounts_office_register(
    'due_schedule', null, null, 25, 0
  )->>'total' = '0',
  'Supplier and supplier-due rows require both capabilities on the same project'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',
  true
);
select throws_ok(
  $sql$select public.v1_get_accounts_office_register(
    'activity', null, null, 25, 0
  )$sql$,
  '42501', 'R39_ACCOUNTS_ACCESS_DENIED',
  'Site Engineer cannot open the organization Account Office'
);

reset role;
select * from finish();
rollback;
