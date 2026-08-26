-- Yorks R39 Accounts T06: protected documents, Accounts activity,
-- authoritative notifications and role-safe export/report projections.
--
-- This migration is additive. It reuses the existing private, immutable
-- document store, append-only audit table and durable notification outbox.
-- No operational Project, BOQ, Material Request, stock, dispatch, receipt or
-- return record is updated by this slice.

update public.v1_capability_catalog
set status = 'operational',
    authorization_mode = 'enforced',
    is_assignable = true
where capability_key = 'export_accounts_registers';

alter table public.v1_document_links
  drop constraint if exists v1_document_links_entity_type_check;
alter table public.v1_document_links
  add constraint v1_document_links_entity_type_check check (entity_type in (
    'project', 'boq_group', 'material_request', 'dispatch', 'receipt_review',
    'material_return', 'delivery_order', 'rental_property', 'supplier',
    'supplier_receipt_batch', 'accounts_baseline_revision',
    'accounts_billing_progress_revision', 'accounts_client_claim',
    'accounts_client_invoice', 'accounts_client_certification',
    'accounts_client_payment', 'accounts_client_pdc',
    'accounts_supplier_bill', 'accounts_supplier_match'
  ));

alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_target_entity_type_check;
alter table public.v1_document_upload_intents
  add constraint v1_document_upload_intents_target_entity_type_check check (
    target_entity_type in (
      'project', 'boq_group', 'material_request', 'dispatch', 'receipt_review',
      'material_return', 'delivery_order', 'rental_property', 'supplier',
      'supplier_receipt_batch', 'accounts_baseline_revision',
      'accounts_billing_progress_revision', 'accounts_client_claim',
      'accounts_client_invoice', 'accounts_client_certification',
      'accounts_client_payment', 'accounts_client_pdc',
      'accounts_supplier_bill', 'accounts_supplier_match'
    )
  );

create table if not exists public.v1_accounts_document_upload_metadata (
  upload_intent_id uuid primary key
    references public.v1_document_upload_intents (id) on delete restrict,
  document_type text not null check (document_type in (
    'contract', 'contract_variation', 'progress_evidence', 'client_claim',
    'client_invoice', 'client_certification', 'payment_certificate',
    'pdc_copy', 'payment_receipt', 'supplier_invoice', 'po_lpo',
    'delivery_receipt', 'payment_advice', 'commercial_correspondence', 'other'
  )),
  created_by_auth_user_id uuid not null
    references public.v1_profiles (auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

create table if not exists public.v1_accounts_document_metadata (
  document_id uuid primary key
    references public.v1_documents (id) on delete restrict,
  document_type text not null check (document_type in (
    'contract', 'contract_variation', 'progress_evidence', 'client_claim',
    'client_invoice', 'client_certification', 'payment_certificate',
    'pdc_copy', 'payment_receipt', 'supplier_invoice', 'po_lpo',
    'delivery_receipt', 'payment_advice', 'commercial_correspondence', 'other'
  )),
  archived_at timestamptz,
  archived_by_auth_user_id uuid
    references public.v1_profiles (auth_user_id) on delete restrict,
  archive_reason text,
  created_at timestamptz not null default clock_timestamp(),
  check (
    (archived_at is null and archived_by_auth_user_id is null
      and archive_reason is null)
    or (archived_at is not null and archived_by_auth_user_id is not null
      and nullif(btrim(archive_reason), '') is not null)
  )
);

alter table public.v1_accounts_document_upload_metadata enable row level security;
alter table public.v1_accounts_document_metadata enable row level security;
revoke all on table public.v1_accounts_document_upload_metadata
  from public, anon, authenticated;
revoke all on table public.v1_accounts_document_metadata
  from public, anon, authenticated;
grant all on table public.v1_accounts_document_upload_metadata to service_role;
grant all on table public.v1_accounts_document_metadata to service_role;

create or replace function public.v1_accounts_document_target_project_id(
  p_entity_type text,
  p_entity_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
begin
  case p_entity_type
    when 'accounts_baseline_revision' then
      select project_id into v_project_id
      from public.v1_accounts_baseline_revisions where id = p_entity_id;
    when 'accounts_billing_progress_revision' then
      select project_id into v_project_id
      from public.v1_accounts_billing_progress_revisions where id = p_entity_id;
    when 'accounts_client_claim' then
      select project_id into v_project_id
      from public.v1_accounts_client_claims where id = p_entity_id;
    when 'accounts_client_invoice' then
      select project_id into v_project_id
      from public.v1_accounts_client_invoices where id = p_entity_id;
    when 'accounts_client_certification' then
      select project_id into v_project_id
      from public.v1_accounts_client_certifications where id = p_entity_id;
    when 'accounts_client_payment' then
      select project_id into v_project_id
      from public.v1_accounts_client_payments where id = p_entity_id;
    when 'accounts_client_pdc' then
      select project_id into v_project_id
      from public.v1_accounts_client_pdcs where id = p_entity_id;
    when 'accounts_supplier_bill' then
      select project_id into v_project_id
      from public.v1_accounts_supplier_bills where id = p_entity_id;
    when 'accounts_supplier_match' then
      select project_id into v_project_id
      from public.v1_accounts_supplier_bills where id = p_entity_id;
    else
      return null;
  end case;
  return v_project_id;
end;
$$;

create or replace function public.v1_accounts_document_target_readable(
  p_entity_type text,
  p_entity_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid := public.v1_accounts_document_target_project_id(
    p_entity_type, p_entity_id
  );
  v_capability text;
begin
  if v_project_id is null then return false; end if;
  v_capability := case
    when p_entity_type in ('accounts_supplier_bill','accounts_supplier_match')
      then 'view_supplier_costs'
    when p_entity_type = 'accounts_billing_progress_revision'
      then 'view_project_accounts'
    else 'view_project_commercial_values'
  end;
  return public.v1_current_user_has_capability(v_capability, v_project_id);
end;
$$;

create or replace function public.v1_accounts_document_target_writable(
  p_entity_type text,
  p_entity_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid := public.v1_accounts_document_target_project_id(
    p_entity_type, p_entity_id
  );
begin
  if v_project_id is null then return false; end if;
  return case p_entity_type
    when 'accounts_baseline_revision' then
      public.v1_current_user_has_capability(
        'configure_project_commercials', v_project_id
      )
    when 'accounts_billing_progress_revision' then
      public.v1_current_user_has_capability(
        'suggest_billing_progress', v_project_id
      ) or public.v1_current_user_has_capability(
        'confirm_billing_progress', v_project_id
      )
    when 'accounts_client_claim' then
      public.v1_current_user_has_capability(
        'prepare_client_claim', v_project_id
      ) or public.v1_current_user_has_capability(
        'manage_client_invoices', v_project_id
      )
    when 'accounts_client_invoice' then
      public.v1_current_user_has_capability(
        'manage_client_invoices', v_project_id
      )
    when 'accounts_client_certification' then
      public.v1_current_user_has_capability(
        'record_client_certification', v_project_id
      )
    when 'accounts_client_payment' then
      public.v1_current_user_has_capability(
        'record_client_payment', v_project_id
      )
    when 'accounts_client_pdc' then
      public.v1_current_user_has_capability('manage_pdc', v_project_id)
    when 'accounts_supplier_bill' then
      public.v1_current_user_has_capability(
        'manage_supplier_bills', v_project_id
      )
    when 'accounts_supplier_match' then
      public.v1_current_user_has_capability(
        'manage_supplier_bills', v_project_id
      )
    else false
  end;
end;
$$;

create or replace function public.v1_document_target_project_id(
  p_entity_type text,
  p_entity_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
begin
  if p_entity_type like 'accounts_%' then
    v_project_id := public.v1_accounts_document_target_project_id(
      p_entity_type, p_entity_id
    );
  else
    case p_entity_type
      when 'project' then
        select id into v_project_id from public.v1_projects where id=p_entity_id;
      when 'boq_group' then
        select project_id into v_project_id from public.v1_boq_groups where id=p_entity_id;
      when 'material_request' then
        select project_id into v_project_id from public.v1_material_requests where id=p_entity_id;
      when 'dispatch' then
        select request_record.project_id into v_project_id
        from public.v1_material_dispatches dispatch_record
        join public.v1_material_requests request_record
          on request_record.id=dispatch_record.request_id
        where dispatch_record.id=p_entity_id;
      when 'receipt_review' then
        select request_record.project_id into v_project_id
        from public.v1_receipt_reviews review
        join public.v1_material_requests request_record
          on request_record.id=review.request_id
        where review.id=p_entity_id and review.state='confirmed';
      when 'material_return' then
        select project_id into v_project_id from public.v1_material_returns where id=p_entity_id;
      when 'delivery_order' then
        select request_record.project_id into v_project_id
        from public.v1_delivery_orders delivery_order
        join public.v1_material_dispatches dispatch_record
          on dispatch_record.id=delivery_order.dispatch_id
        join public.v1_material_requests request_record
          on request_record.id=dispatch_record.request_id
        where delivery_order.id=p_entity_id;
      else
        raise exception 'V1_DOCUMENT_TARGET_TYPE_INVALID' using errcode='22023';
    end case;
  end if;
  if v_project_id is null then
    raise exception 'V1_DOCUMENT_TARGET_NOT_FOUND' using errcode='22023';
  end if;
  return v_project_id;
end;
$$;

create or replace function public.v1_document_target_readable(
  p_entity_type text,
  p_entity_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_project_id uuid;
begin
  if p_entity_type like 'accounts_%' then
    return public.v1_accounts_document_target_readable(
      p_entity_type, p_entity_id
    );
  end if;
  case p_entity_type
    when 'project' then return public.v1_project_readable(p_entity_id);
    when 'boq_group' then
      select project_id into v_project_id from public.v1_boq_groups where id=p_entity_id;
      return v_project_id is not null and public.v1_project_readable(v_project_id);
    when 'material_request' then return public.v1_material_request_readable(p_entity_id);
    when 'dispatch' then
      select request_id into v_request_id from public.v1_material_dispatches where id=p_entity_id;
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'receipt_review' then
      select request_id into v_request_id from public.v1_receipt_reviews
      where id=p_entity_id and state='confirmed';
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'material_return' then return public.v1_material_return_readable(p_entity_id);
    when 'delivery_order' then
      select dispatch_record.request_id into v_request_id
      from public.v1_delivery_orders delivery_order
      join public.v1_material_dispatches dispatch_record
        on dispatch_record.id=delivery_order.dispatch_id
      where delivery_order.id=p_entity_id;
      return v_request_id is not null and public.v1_material_request_readable(v_request_id);
    when 'rental_property' then
      return auth.uid() is not null and public.v1_current_actor_is_active()
        and public.v1_current_role()='admin' and exists(
          select 1 from public.v1_rental_properties where id=p_entity_id
        );
    when 'supplier' then
      return public.v1_can_manage_inventory() and exists(
        select 1 from public.v1_suppliers where id=p_entity_id
      );
    when 'supplier_receipt_batch' then
      return public.v1_can_manage_inventory() and exists(
        select 1 from public.v1_supplier_receipt_batches where id=p_entity_id
      );
    else return false;
  end case;
end;
$$;

create or replace function public.v1_document_target_writable(
  p_entity_type text,
  p_entity_id uuid,
  p_classification text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
  v_role text := public.v1_current_role();
begin
  if p_entity_type like 'accounts_%' then
    return p_classification in ('operational','commercial')
      and public.v1_accounts_document_target_readable(p_entity_type,p_entity_id)
      and public.v1_accounts_document_target_writable(p_entity_type,p_entity_id);
  end if;
  if not public.v1_document_target_readable(p_entity_type,p_entity_id)
    or not public.v1_document_classification_writable(p_classification) then
    return false;
  end if;
  if p_entity_type='rental_property' then
    return p_classification='commercial' and exists(
      select 1 from public.v1_rental_properties where id=p_entity_id and not is_archived
    );
  end if;
  if p_entity_type='receipt_review' then
    return p_classification='operational'
      and v_role in ('project_engineer','site_engineer','admin') and exists(
        select 1 from public.v1_receipt_reviews
        where id=p_entity_id and state='confirmed'
      );
  end if;
  if p_entity_type='supplier' then
    return (p_classification='operational'
      or (p_classification='commercial' and public.v1_has_capability('manage_commercials'))
      or (p_classification='admin_restricted' and v_role='admin'))
      and public.v1_can_manage_inventory()
      and exists(select 1 from public.v1_suppliers where id=p_entity_id);
  end if;
  if p_entity_type='supplier_receipt_batch' then
    return (p_classification='operational'
      or (p_classification='commercial' and public.v1_has_capability('manage_commercials'))
      or (p_classification='admin_restricted' and v_role='admin'))
      and public.v1_can_manage_inventory() and exists(
        select 1 from public.v1_supplier_receipt_batches
        where id=p_entity_id and state='committed'
      );
  end if;
  v_project_id:=public.v1_document_target_project_id(p_entity_type,p_entity_id);
  select state into v_project_state from public.v1_projects where id=v_project_id;
  return v_project_state in ('draft','active','on_hold','completed');
end;
$$;

create or replace function public.v1_document_readable(p_document_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_classification text;
  v_links_readable boolean;
  v_is_accounts boolean;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then return false; end if;
  select classification into v_classification from public.v1_documents where id=p_document_id;
  if v_classification is null then return false; end if;
  select exists(select 1 from public.v1_accounts_document_metadata where document_id=p_document_id)
    into v_is_accounts;
  select count(*)>0 and bool_and(
    public.v1_document_target_readable(link.entity_type,link.entity_id)
  ) into v_links_readable
  from public.v1_document_links link
  where link.document_id=p_document_id and link.removed_at is null;
  if not coalesce(v_links_readable,false) then return false; end if;
  if v_is_accounts then return v_classification in ('operational','commercial'); end if;
  return case v_classification
    when 'operational' then true
    when 'commercial' then public.v1_has_capability('view_commercials')
    when 'admin_restricted' then public.v1_current_role()='admin'
    else false end;
end;
$$;

create or replace function public.v1_document_writable(p_document_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_classification text;
  v_project_count integer;
  v_is_accounts boolean;
  v_all_targets_writable boolean;
begin
  select classification into v_classification from public.v1_documents where id=p_document_id;
  if v_classification is null or not public.v1_document_readable(p_document_id) then return false; end if;
  select exists(select 1 from public.v1_accounts_document_metadata where document_id=p_document_id)
    into v_is_accounts;
  if v_is_accounts then
    select count(*)>0 and bool_and(public.v1_accounts_document_target_writable(
      link.entity_type,link.entity_id
    )) into v_all_targets_writable
    from public.v1_document_links link
    where link.document_id=p_document_id and link.removed_at is null;
    if not coalesce(v_all_targets_writable,false) then return false; end if;
  elsif not public.v1_document_classification_writable(v_classification) then
    return false;
  end if;
  select count(distinct project_id) into v_project_count
  from public.v1_document_links where document_id=p_document_id and removed_at is null;
  return v_project_count<=1 or public.v1_current_role()='admin';
end;
$$;

create or replace function public.v1_accounts_capture_document_metadata()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_meta public.v1_accounts_document_upload_metadata%rowtype;
  v_existing_type text;
  v_request_hash text;
begin
  if old.finalized_document_id is not null or new.finalized_document_id is null then
    return new;
  end if;
  select * into v_meta from public.v1_accounts_document_upload_metadata
  where upload_intent_id=new.id;
  if not found then return new; end if;
  select document_type into v_existing_type
  from public.v1_accounts_document_metadata where document_id=new.finalized_document_id;
  if v_existing_type is not null and v_existing_type<>v_meta.document_type then
    raise exception 'R39_ACCOUNTS_DOCUMENT_TYPE_IMMUTABLE' using errcode='23514';
  end if;
  insert into public.v1_accounts_document_metadata(document_id,document_type)
  values(new.finalized_document_id,v_meta.document_type)
  on conflict(document_id) do nothing;
  select request_hash into v_request_hash from public.v1_idempotency_keys
  where actor_auth_user_id=new.actor_auth_user_id
    and command_name='v1_prepare_document_upload'
    and idempotency_key=new.idempotency_key;
  insert into public.v1_audit_events(
    event_type,entity_type,entity_id,project_id,actor_auth_user_id,actor_role,
    occurred_at,idempotency_key,after_data,request_hash
  ) values(
    'accounts.document.finalized','accounts_document',new.finalized_document_id,
    new.project_id,new.actor_auth_user_id,new.actor_role,clock_timestamp(),
    new.idempotency_key,jsonb_build_object(
      'document_id',new.finalized_document_id,
      'document_version_id',new.finalized_version_id,
      'document_type',v_meta.document_type,
      'revision_number',new.planned_revision_number,
      'sha256',new.expected_sha256
    ),v_request_hash
  );
  return new;
end;
$$;

drop trigger if exists v1_accounts_capture_document_metadata
  on public.v1_document_upload_intents;
create trigger v1_accounts_capture_document_metadata
after update of finalized_document_id on public.v1_document_upload_intents
for each row execute function public.v1_accounts_capture_document_metadata();

create or replace function public.v1_prepare_accounts_document_upload(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_document_type text := nullif(btrim(p_payload->>'accounts_document_type'),'');
  v_entity_type text := nullif(btrim(p_payload->>'entity_type'),'');
  v_classification text := nullif(btrim(p_payload->>'classification'),'');
  v_document_id uuid := nullif(p_payload->>'document_id','')::uuid;
  v_result jsonb;
  v_intent_id uuid;
  v_existing_type text;
begin
  if v_document_type not in (
    'contract','contract_variation','progress_evidence','client_claim',
    'client_invoice','client_certification','payment_certificate','pdc_copy',
    'payment_receipt','supplier_invoice','po_lpo','delivery_receipt',
    'payment_advice','commercial_correspondence','other'
  ) or v_entity_type not like 'accounts_%' then
    raise exception 'R39_ACCOUNTS_DOCUMENT_PAYLOAD_INVALID' using errcode='22023';
  end if;
  if (v_document_type='progress_evidence' and v_classification not in ('operational','commercial'))
    or (v_document_type<>'progress_evidence' and v_classification<>'commercial') then
    raise exception 'R39_ACCOUNTS_DOCUMENT_CLASSIFICATION_INVALID' using errcode='22023';
  end if;
  if v_document_id is not null then
    select document_type into v_existing_type
    from public.v1_accounts_document_metadata where document_id=v_document_id;
    if v_existing_type is null or v_existing_type<>v_document_type then
      raise exception 'R39_ACCOUNTS_DOCUMENT_TYPE_IMMUTABLE' using errcode='23514';
    end if;
  end if;
  v_result:=public.v1_prepare_document_upload(
    p_payload-'accounts_document_type',p_idempotency_key
  );
  v_intent_id:=(v_result->>'upload_intent_id')::uuid;
  insert into public.v1_accounts_document_upload_metadata(
    upload_intent_id,document_type,created_by_auth_user_id
  ) values(v_intent_id,v_document_type,auth.uid())
  on conflict(upload_intent_id) do nothing;
  select document_type into v_existing_type
  from public.v1_accounts_document_upload_metadata where upload_intent_id=v_intent_id;
  if v_existing_type<>v_document_type then
    raise exception 'R39_ACCOUNTS_IDEMPOTENCY_CONFLICT' using errcode='23505';
  end if;
  if nullif(v_result->>'finalized_document_id','') is not null then
    insert into public.v1_accounts_document_metadata(document_id,document_type)
    values((v_result->>'finalized_document_id')::uuid,v_document_type)
    on conflict(document_id) do nothing;
  end if;
  return v_result;
end;
$$;

create or replace function public.v1_get_accounts_documents(
  p_project_id uuid,
  p_search text default null,
  p_document_type text default null,
  p_include_archived boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_documents jsonb;
  v_targets jsonb;
begin
  perform public.v1_accounts_require_capability(p_project_id,'view_project_accounts');
  if p_document_type is not null and p_document_type not in (
    'contract','contract_variation','progress_evidence','client_claim',
    'client_invoice','client_certification','payment_certificate','pdc_copy',
    'payment_receipt','supplier_invoice','po_lpo','delivery_receipt',
    'payment_advice','commercial_correspondence','other'
  ) then raise exception 'R39_ACCOUNTS_DOCUMENT_TYPE_INVALID' using errcode='22023'; end if;
  select coalesce(jsonb_agg(item order by uploaded_at desc,document_id),'[]'::jsonb)
    into v_documents from (
    select document_record.id as document_id,version_record.uploaded_at,
      jsonb_build_object(
        'id',document_record.id,'classification',document_record.classification,
        'accounts_document_type',metadata.document_type,
        'created_at',document_record.created_at,
        'archived',metadata.archived_at is not null,
        'current_version',jsonb_build_object(
          'id',version_record.id,'revision_number',version_record.revision_number,
          'bucket_id',version_record.bucket_id,'object_path',version_record.object_path,
          'original_file_name',version_record.original_file_name,
          'mime_type',version_record.mime_type,'byte_size',version_record.byte_size,
          'sha256',version_record.sha256,'origin',version_record.origin,
          'source_entity_type',version_record.source_entity_type,
          'source_entity_id',version_record.source_entity_id,
          'source_revision',version_record.source_revision,
          'uploaded_at',version_record.uploaded_at,
          'uploaded_by_auth_user_id',version_record.uploaded_by_auth_user_id,
          'uploaded_by_role',version_record.uploaded_by_role,
          'uploaded_by_display_name',public.v1_safe_profile_display_name(
            uploader.display_name,uploader.auth_user_id
          )
        ),
        'versions',(select coalesce(jsonb_agg(jsonb_build_object(
          'id',history.id,'revision_number',history.revision_number,
          'bucket_id',history.bucket_id,'object_path',history.object_path,
          'original_file_name',history.original_file_name,'mime_type',history.mime_type,
          'byte_size',history.byte_size,'sha256',history.sha256,'origin',history.origin,
          'source_entity_type',history.source_entity_type,
          'source_entity_id',history.source_entity_id,
          'source_revision',history.source_revision,'uploaded_at',history.uploaded_at,
          'uploaded_by_auth_user_id',history.uploaded_by_auth_user_id,
          'uploaded_by_role',history.uploaded_by_role,
          'uploaded_by_display_name',public.v1_safe_profile_display_name(
            history_profile.display_name,history_profile.auth_user_id
          )) order by history.revision_number desc),'[]'::jsonb)
          from public.v1_document_versions history
          join public.v1_profiles history_profile
            on history_profile.auth_user_id=history.uploaded_by_auth_user_id
          where history.document_id=document_record.id),
        'links',(select coalesce(jsonb_agg(jsonb_build_object(
          'id',link.id,'project_id',link.project_id,'entity_type',link.entity_type,
          'entity_id',link.entity_id,'linked_at',link.linked_at,
          'cross_project_reason',link.cross_project_reason
        ) order by link.linked_at),'[]'::jsonb)
          from public.v1_document_links link where link.document_id=document_record.id
            and link.removed_at is null)
      ) as item
    from public.v1_accounts_document_metadata metadata
    join public.v1_documents document_record on document_record.id=metadata.document_id
    join public.v1_document_versions version_record
      on version_record.id=document_record.current_version_id
    join public.v1_profiles uploader
      on uploader.auth_user_id=version_record.uploaded_by_auth_user_id
    where (p_include_archived or metadata.archived_at is null)
      and (p_document_type is null or metadata.document_type=p_document_type)
      and (p_search is null or btrim(p_search)='' or
        version_record.original_file_name ilike '%'||btrim(p_search)||'%' or
        metadata.document_type ilike '%'||btrim(p_search)||'%')
      and exists(select 1 from public.v1_document_links link
        where link.document_id=document_record.id and link.project_id=p_project_id
          and link.removed_at is null)
      and public.v1_document_readable(document_record.id)
  ) visible;

  select coalesce(jsonb_agg(target order by target->>'label'),'[]'::jsonb)
    into v_targets from (
    select jsonb_build_object('entity_type','accounts_baseline_revision',
      'entity_id',baseline.id,'label','Baseline revision '||baseline.revision_number) target
    from public.v1_accounts_project_commercial_profiles profile
    join public.v1_accounts_baseline_revisions baseline
      on baseline.id=profile.current_baseline_revision_id
    where profile.project_id=p_project_id
    union all
    select jsonb_build_object('entity_type','accounts_client_claim','entity_id',id,
      'label','Claim · '||claim_reference)
    from public.v1_accounts_client_claims where project_id=p_project_id and status<>'cancelled'
    union all
    select jsonb_build_object('entity_type','accounts_client_invoice','entity_id',id,
      'label','Invoice · '||invoice_reference)
    from public.v1_accounts_client_invoices where project_id=p_project_id and status<>'cancelled'
    union all
    select jsonb_build_object('entity_type','accounts_client_pdc','entity_id',id,
      'label','PDC · '||cheque_number)
    from public.v1_accounts_client_pdcs where project_id=p_project_id and status<>'cancelled'
    union all
    select jsonb_build_object('entity_type','accounts_supplier_bill','entity_id',id,
      'label','Supplier invoice · '||supplier_invoice_reference)
    from public.v1_accounts_supplier_bills where project_id=p_project_id and status<>'cancelled'
  ) target_rows;
  return jsonb_build_object(
    'schema_version',6,'project_id',p_project_id,'documents',v_documents,
    'upload_targets',v_targets,
    'can_upload',exists(select 1 from jsonb_array_elements(v_targets) target
      where public.v1_accounts_document_target_writable(
        target->>'entity_type',(target->>'entity_id')::uuid
      ))
  );
end;
$$;

create or replace function public.v1_get_accounts_activity(
  p_project_id uuid,
  p_entity_type text default null,
  p_action text default null,
  p_actor_auth_user_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_can_values boolean;
  v_can_supplier boolean;
  v_total integer;
  v_entries jsonb;
begin
  perform public.v1_accounts_require_capability(p_project_id,'view_project_accounts');
  if p_limit not between 1 and 100 or p_offset<0 or (p_from is not null and p_to is not null and p_from>p_to) then
    raise exception 'R39_ACCOUNTS_ACTIVITY_FILTER_INVALID' using errcode='22023';
  end if;
  v_can_values:=public.v1_current_user_has_capability(
    'view_project_commercial_values',p_project_id
  );
  v_can_supplier:=public.v1_current_user_has_capability('view_supplier_costs',p_project_id);
  with filtered as materialized (
    select audit.*,profile.display_name
    from public.v1_audit_events audit
    join public.v1_profiles profile on profile.auth_user_id=audit.actor_auth_user_id
    where audit.project_id=p_project_id
      and (audit.event_type like 'accounts.%' or audit.entity_type like 'accounts_%')
      and (v_can_supplier or audit.entity_type not in ('accounts_supplier_bill','accounts_supplier_payment'))
      and (p_entity_type is null or audit.entity_type=p_entity_type)
      and (p_action is null or audit.event_type=p_action)
      and (p_actor_auth_user_id is null or audit.actor_auth_user_id=p_actor_auth_user_id)
      and (p_from is null or audit.occurred_at>=p_from)
      and (p_to is null or audit.occurred_at<=p_to)
  ), page as (
    select * from filtered order by occurred_at desc,id desc limit p_limit offset p_offset
  )
  select (select count(*) from filtered),coalesce(jsonb_agg(jsonb_build_object(
    'id',page.id,'event_type',page.event_type,'entity_type',page.entity_type,
    'entity_id',page.entity_id,'project_id',page.project_id,
    'actor_auth_user_id',page.actor_auth_user_id,
    'actor_display_name',public.v1_safe_profile_display_name(page.display_name,page.actor_auth_user_id),
    'actor_exact_role',coalesce(page.actor_exact_role,page.actor_role),
    'occurred_at',page.occurred_at,'reason',page.reason,
    'idempotency_key',page.idempotency_key,
    'before_data',case when v_can_values then page.before_data else null end,
    'after_data',case when v_can_values then page.after_data else null end
  ) order by page.occurred_at desc,page.id desc),'[]'::jsonb)
  into v_total,v_entries from page;
  return jsonb_build_object(
    'schema_version',6,'project_id',p_project_id,'total',v_total,
    'limit',p_limit,'offset',p_offset,'entries',v_entries
  );
end;
$$;

create unique index if not exists v1_accounts_notification_once_idx
  on public.v1_notifications(
    recipient_auth_user_id,event_code,entity_type,entity_id
  ) where event_code like 'accounts_%';

create or replace function public.v1_accounts_notification_recipient_allowed(
  p_auth_user_id uuid,
  p_capability_key text,
  p_project_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((public.v1_permission_candidate_raw(
    p_auth_user_id,p_capability_key,p_project_id
  )->>'effective')::boolean,false);
$$;

create or replace function public.v1_accounts_notify_from_audit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient uuid;
  v_event_code text;
begin
  if new.project_id is null or new.event_type not like 'accounts.%' then return new; end if;
  if new.event_type='accounts.client_claim.ready_for_accounts' then
    v_event_code:='accounts_claim_ready';
    for v_recipient in select profile.auth_user_id from public.v1_profiles profile
      where profile.is_active and public.v1_permission_exact_role(profile.auth_user_id)='accountant'
        and public.v1_accounts_notification_recipient_allowed(
          profile.auth_user_id,'manage_client_invoices',new.project_id
        )
    loop
      insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
      values(v_recipient,v_event_code,new.entity_type,new.entity_id,new.project_id)
      on conflict(recipient_auth_user_id,event_code,entity_type,entity_id)
        where event_code like 'accounts_%' do nothing;
    end loop;
  elsif new.event_type='accounts.client_invoice.returned'
    or (new.event_type='accounts.client_certification.recorded' and new.reason is not null) then
    v_event_code:=case when new.event_type like '%returned' then 'accounts_claim_returned'
      else 'accounts_certification_difference' end;
    for v_recipient in
      select distinct recipient from (
        select member.member_auth_user_id recipient
        from public.v1_project_members member
        where member.project_id=new.project_id and member.project_role='project_engineer'
          and member.effective_from<=clock_timestamp()
          and (member.effective_to is null or member.effective_to>clock_timestamp())
        union all
        select profile.auth_user_id from public.v1_profiles profile
        where profile.is_active and public.v1_permission_exact_role(profile.auth_user_id)
          in ('senior_mechanical_engineer','project_manager')
      ) recipients
    loop
      insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
      values(v_recipient,v_event_code,new.entity_type,new.entity_id,new.project_id)
      on conflict(recipient_auth_user_id,event_code,entity_type,entity_id)
        where event_code like 'accounts_%' do nothing;
    end loop;
  elsif new.event_type in ('accounts.supplier_bill.created','accounts.supplier_bill.updated') then
    if coalesce(new.after_data->>'match_status','blocked')<>'matched' then
      v_event_code:='accounts_supplier_evidence_incomplete';
      for v_recipient in select profile.auth_user_id from public.v1_profiles profile
        where profile.is_active and public.v1_permission_exact_role(profile.auth_user_id)='procurement'
          and public.v1_accounts_notification_recipient_allowed(
            profile.auth_user_id,'manage_supplier_bills',new.project_id
          )
      loop
        insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
        values(v_recipient,v_event_code,new.entity_type,new.entity_id,new.project_id)
        on conflict(recipient_auth_user_id,event_code,entity_type,entity_id)
          where event_code like 'accounts_%' do nothing;
      end loop;
    else
      v_event_code:='accounts_supplier_bill_ready';
      for v_recipient in select profile.auth_user_id from public.v1_profiles profile
        where profile.is_active and public.v1_permission_exact_role(profile.auth_user_id) in ('accountant','admin')
          and public.v1_accounts_notification_recipient_allowed(
            profile.auth_user_id,'approve_supplier_bill_payment',new.project_id
          )
      loop
        insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
        values(v_recipient,v_event_code,new.entity_type,new.entity_id,new.project_id)
        on conflict(recipient_auth_user_id,event_code,entity_type,entity_id)
          where event_code like 'accounts_%' do nothing;
      end loop;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_accounts_notify_from_audit on public.v1_audit_events;
create trigger v1_accounts_notify_from_audit
after insert on public.v1_audit_events
for each row execute function public.v1_accounts_notify_from_audit();

create or replace function public.v1_refresh_accounts_due_notifications()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_inserted integer:=0;
  v_count integer;
begin
  if coalesce(auth.jwt()->>'role','')<>'service_role' then
    raise exception 'R39_ACCOUNTS_REMINDER_SERVICE_ONLY' using errcode='42501';
  end if;
  insert into public.v1_notifications(
    recipient_auth_user_id,event_code,entity_type,entity_id,project_id
  )
  select profile.auth_user_id,
    case when invoice.due_date<current_date then 'accounts_invoice_overdue'
      else 'accounts_invoice_due_soon' end,
    'accounts_client_invoice',invoice.id,invoice.project_id
  from public.v1_accounts_client_invoices invoice
  join public.v1_profiles profile on profile.is_active
    and public.v1_permission_exact_role(profile.auth_user_id)='accountant'
    and public.v1_accounts_notification_recipient_allowed(
      profile.auth_user_id,'manage_client_invoices',invoice.project_id
    )
  where invoice.status not in ('draft','returned','cancelled','paid')
    and invoice.due_date is not null
    and invoice.due_date<=current_date+invoice.reminder_lead_days_snapshot
  on conflict(recipient_auth_user_id,event_code,entity_type,entity_id)
    where event_code like 'accounts_%' do nothing;
  get diagnostics v_count=row_count; v_inserted:=v_inserted+v_count;

  insert into public.v1_notifications(
    recipient_auth_user_id,event_code,entity_type,entity_id,project_id
  )
  select profile.auth_user_id,
    case when pdc.cheque_date<current_date then 'accounts_pdc_overdue'
      else 'accounts_pdc_due_soon' end,
    'accounts_client_pdc',pdc.id,pdc.project_id
  from public.v1_accounts_client_pdcs pdc
  join public.v1_accounts_client_invoices invoice on invoice.id=pdc.invoice_id
  join public.v1_profiles profile on profile.is_active
    and public.v1_permission_exact_role(profile.auth_user_id)='accountant'
    and public.v1_accounts_notification_recipient_allowed(
      profile.auth_user_id,'manage_pdc',pdc.project_id
    )
  where pdc.status in ('expected','received','deposited')
    and pdc.cheque_date<=current_date+invoice.reminder_lead_days_snapshot
  on conflict(recipient_auth_user_id,event_code,entity_type,entity_id)
    where event_code like 'accounts_%' do nothing;
  get diagnostics v_count=row_count; v_inserted:=v_inserted+v_count;
  return v_inserted;
end;
$$;

create or replace function public.v1_get_accounts_export(
  p_export_kind text,
  p_project_id uuid default null,
  p_idempotency_key uuid default gen_random_uuid()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_role text:=public.v1_permission_exact_role(auth.uid());
  v_project public.v1_projects%rowtype;
  v_columns jsonb;
  v_rows jsonb;
  v_result jsonb;
  v_existing jsonb;
  v_payload jsonb;
begin
  if p_export_kind not in ('portfolio','project_summary','billing_progress',
    'client_invoices','supplier_bills','pdc_register') then
    raise exception 'R39_ACCOUNTS_EXPORT_KIND_INVALID' using errcode='22023';
  end if;
  if p_export_kind='portfolio' then
    if v_role not in ('accountant','admin','senior_mechanical_engineer','project_manager') then
      raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
    end if;
  elsif p_project_id is null or not public.v1_current_user_has_capability(
    'export_accounts_registers',p_project_id
  ) then raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
  if p_export_kind in ('project_summary','client_invoices','pdc_register')
    and not public.v1_current_user_has_capability(
      'view_project_commercial_values',p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  if p_export_kind='supplier_bills'
    and not public.v1_current_user_has_capability(
      'view_supplier_costs',p_project_id
    ) then
    raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501';
  end if;
  v_payload:=jsonb_build_object('export_kind',p_export_kind,'project_id',p_project_id);
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_get_accounts_export',p_idempotency_key,v_payload
  );
  if v_existing is not null then return v_existing; end if;
  if p_project_id is not null then
    select * into v_project from public.v1_projects where id=p_project_id;
    if not found then raise exception 'R39_ACCOUNTS_PROJECT_NOT_FOUND' using errcode='P0002'; end if;
  end if;
  case p_export_kind
    when 'portfolio' then
      v_columns:='["Project","Client","Contract","Confirmed work","Claimed","Certified","Paid","Still due","Progress %"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(project.project_ref,
        coalesce(client.party_name,''),baseline.contract_value::text,
        coalesce(progress.confirmed,0)::text,coalesce(invoice.claimed,0)::text,
        coalesce(invoice.certified,0)::text,coalesce(invoice.paid,0)::text,
        greatest(coalesce(invoice.certified,0)-coalesce(invoice.paid,0),0)::text,
        coalesce(progress.percent,0)::text) order by project.project_ref),'[]'::jsonb)
      into v_rows from public.v1_projects project
      join public.v1_accounts_project_commercial_profiles profile on profile.project_id=project.id
      join public.v1_accounts_baseline_revisions baseline on baseline.id=profile.current_baseline_revision_id
      left join lateral(select party_name from public.v1_project_parties
        where project_id=project.id and party_kind='client' order by created_at,id limit 1) client on true
      left join lateral(select coalesce(sum(round(baseline.contract_value*b.allocation_percent/100*s.allocation_percent/100*p.confirmed_percent/100,2)),0) confirmed,
        case when coalesce(sum(b.allocation_percent*s.allocation_percent),0)=0 then 0
          else round(sum(b.allocation_percent*s.allocation_percent*p.confirmed_percent)
            /sum(b.allocation_percent*s.allocation_percent),2) end percent
        from public.v1_accounts_billing_progress p
        join public.v1_accounts_baseline_building_allocations b on b.id=p.building_allocation_id
        join public.v1_accounts_baseline_stage_allocations s on s.id=p.stage_allocation_id
        where p.project_id=project.id and p.review_status<>'returned') progress on true
      left join lateral(select coalesce(sum(i.claimed_ex_vat),0) claimed,
        coalesce(sum(public.v1_accounts_invoice_certified_incl_vat(i.id)),0) certified,
        coalesce(sum(public.v1_accounts_invoice_paid_amount(i.id)),0) paid
        from public.v1_accounts_client_invoices i where i.project_id=project.id and i.status<>'cancelled') invoice on true
      where public.v1_current_user_has_capability('export_accounts_registers',project.id)
        and public.v1_current_user_has_capability('view_project_commercial_values',project.id);
    when 'project_summary' then
      v_columns:='["Project","Contract","Confirmed work","Claimed","Certified","Paid","Still due"]'::jsonb;
      select jsonb_agg(jsonb_build_array(v_project.project_ref,baseline.contract_value::text,
        coalesce(progress.confirmed,0)::text,coalesce(invoice.claimed,0)::text,
        coalesce(invoice.certified,0)::text,coalesce(invoice.paid,0)::text,
        greatest(coalesce(invoice.certified,0)-coalesce(invoice.paid,0),0)::text))
      into v_rows from public.v1_accounts_project_commercial_profiles profile
      join public.v1_accounts_baseline_revisions baseline on baseline.id=profile.current_baseline_revision_id
      left join lateral(select coalesce(sum(round(baseline.contract_value*b.allocation_percent/100*s.allocation_percent/100*p.confirmed_percent/100,2)),0) confirmed
        from public.v1_accounts_billing_progress p
        join public.v1_accounts_baseline_building_allocations b on b.id=p.building_allocation_id
        join public.v1_accounts_baseline_stage_allocations s on s.id=p.stage_allocation_id
        where p.project_id=p_project_id and p.review_status<>'returned') progress on true
      left join lateral(select coalesce(sum(i.claimed_ex_vat),0) claimed,
        coalesce(sum(public.v1_accounts_invoice_certified_incl_vat(i.id)),0) certified,
        coalesce(sum(public.v1_accounts_invoice_paid_amount(i.id)),0) paid
        from public.v1_accounts_client_invoices i where i.project_id=p_project_id and i.status<>'cancelled') invoice on true
      where profile.project_id=p_project_id;
    when 'billing_progress' then
      v_columns:='["Building","Stage","Suggested %","Confirmed %","Evidence","Updated"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(scope.name,stage.stage_name,
        entry.suggested_percent::text,entry.confirmed_percent::text,
        coalesce(entry.confirmed_evidence_summary,entry.suggested_evidence_summary,''),
        entry.updated_at::text) order by scope.scope_kind,scope.scope_code,stage.display_order),'[]'::jsonb)
      into v_rows from public.v1_accounts_billing_progress entry
      join public.v1_project_scopes scope on scope.id=entry.project_scope_id
      join public.v1_accounts_baseline_stage_allocations stage
        on stage.id=entry.stage_allocation_id
      where entry.project_id=p_project_id;
    when 'client_invoices' then
      v_columns:='["Invoice","Status","Claimed ex VAT","Certified incl VAT","Paid","Still due","Submitted","Due"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(invoice.invoice_reference,invoice.status,
        invoice.claimed_ex_vat::text,public.v1_accounts_invoice_certified_incl_vat(invoice.id)::text,
        public.v1_accounts_invoice_paid_amount(invoice.id)::text,
        greatest(public.v1_accounts_invoice_certified_incl_vat(invoice.id)-public.v1_accounts_invoice_paid_amount(invoice.id),0)::text,
        coalesce(invoice.submission_date::text,''),coalesce(invoice.due_date::text,''))
        order by invoice.updated_at desc,invoice.id desc),'[]'::jsonb)
      into v_rows from public.v1_accounts_client_invoices invoice where invoice.project_id=p_project_id;
    when 'supplier_bills' then
      if not public.v1_current_user_has_capability('view_supplier_costs',p_project_id) then
        raise exception 'R39_ACCOUNTS_ACCESS_DENIED' using errcode='42501'; end if;
      v_columns:='["Supplier invoice","Supplier","Match","Payment","Total incl VAT","Due"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(bill.supplier_invoice_reference,
        bill.supplier_name_snapshot,public.v1_accounts_supplier_match_status(bill.id),
        public.v1_accounts_supplier_payment_status(bill.id),bill.total_incl_vat::text,
        bill.due_date::text) order by bill.updated_at desc,bill.id desc),'[]'::jsonb)
      into v_rows from public.v1_accounts_supplier_bills bill where bill.project_id=p_project_id;
    when 'pdc_register' then
      v_columns:='["Cheque","Invoice","Bank","Cheque date","Amount","Status","Action required"]'::jsonb;
      select coalesce(jsonb_agg(jsonb_build_array(pdc.cheque_number,invoice.invoice_reference,
        coalesce(pdc.bank_name,''),pdc.cheque_date::text,pdc.amount::text,pdc.status,
        pdc.action_required::text) order by pdc.cheque_date,pdc.id),'[]'::jsonb)
      into v_rows from public.v1_accounts_client_pdcs pdc
      join public.v1_accounts_client_invoices invoice on invoice.id=pdc.invoice_id
      where pdc.project_id=p_project_id;
  end case;
  v_result:=jsonb_build_object(
    'schema_version',6,'report_kind',p_export_kind,'project_id',p_project_id,
    'project_reference',v_project.project_ref,'project_name',v_project.name,
    'currency','AED','access_context',v_role,'generated_at',clock_timestamp(),
    'generated_by_auth_user_id',v_actor,
    'generated_by_display_name',(select public.v1_safe_profile_display_name(
      profile.display_name,profile.auth_user_id
    ) from public.v1_profiles profile where profile.auth_user_id=v_actor),
    'columns',v_columns,'rows',coalesce(v_rows,'[]'::jsonb)
  );
  perform public.v1_write_audit_event(
    'accounts.export.generated','accounts_export',p_idempotency_key,p_project_id,
    null,jsonb_build_object('report_kind',p_export_kind,'row_count',jsonb_array_length(coalesce(v_rows,'[]'::jsonb))),
    null,p_idempotency_key
  );
  perform public.v1_complete_idempotency('v1_get_accounts_export',p_idempotency_key,v_result);
  return v_result;
end;
$$;

revoke all on function public.v1_accounts_document_target_project_id(text,uuid)
  from public,anon,authenticated;
revoke all on function public.v1_accounts_document_target_readable(text,uuid)
  from public,anon,authenticated;
revoke all on function public.v1_accounts_document_target_writable(text,uuid)
  from public,anon,authenticated;
revoke all on function public.v1_accounts_capture_document_metadata()
  from public,anon,authenticated;
revoke all on function public.v1_prepare_accounts_document_upload(jsonb,uuid)
  from public,anon,authenticated;
revoke all on function public.v1_get_accounts_documents(uuid,text,text,boolean)
  from public,anon,authenticated;
revoke all on function public.v1_get_accounts_activity(uuid,text,text,uuid,timestamptz,timestamptz,integer,integer)
  from public,anon,authenticated;
revoke all on function public.v1_accounts_notification_recipient_allowed(uuid,text,uuid)
  from public,anon,authenticated;
revoke all on function public.v1_accounts_notify_from_audit()
  from public,anon,authenticated;
revoke all on function public.v1_refresh_accounts_due_notifications()
  from public,anon,authenticated;
revoke all on function public.v1_get_accounts_export(text,uuid,uuid)
  from public,anon,authenticated;

grant execute on function public.v1_prepare_accounts_document_upload(jsonb,uuid)
  to authenticated;
grant execute on function public.v1_get_accounts_documents(uuid,text,text,boolean)
  to authenticated;
grant execute on function public.v1_get_accounts_activity(uuid,text,text,uuid,timestamptz,timestamptz,integer,integer)
  to authenticated;
grant execute on function public.v1_get_accounts_export(text,uuid,uuid)
  to authenticated;
grant execute on function public.v1_refresh_accounts_due_notifications()
  to service_role;

comment on table public.v1_accounts_document_metadata is
  'R39 Accounts classification/state extension for the shared immutable document store.';
comment on function public.v1_get_accounts_export(text,uuid,uuid) is
  'Returns a role-safe structured report model and appends an export audit event.';
