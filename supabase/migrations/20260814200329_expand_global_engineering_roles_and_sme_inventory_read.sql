-- Yorks role accessibility change approved 15 August 2026.
--
-- * Workshop In-Charge and Document Controller are distinct exact Auth roles
--   with the same organization-wide Project Engineer workflow authority as
--   Project Manager. Their exact title remains visible in audit/documents.
-- * Senior Mechanical Engineer gains the full non-commercial inventory read
--   workspace. Inventory/category/stock mutations remain Procurement/Admin.
--
-- The migration is additive and quantity-neutral. It does not rewrite any
-- existing workflow, stock, reservation, movement, document, or audit row.

begin;

create or replace function public.v1_canonical_role_from_exact_role(p_role text)
returns text
language sql
immutable
strict
set search_path = ''
as $$
  select case p_role
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'project_engineer'
    when 'project_manager' then 'project_engineer'
    when 'workshop_in_charge' then 'project_engineer'
    when 'document_controller' then 'project_engineer'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end;
$$;

create or replace function public.v1_is_valid_role(p_role text)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select public.v1_canonical_role_from_exact_role(p_role) <> '';
$$;

create or replace function public.v1_safe_auth_audit_role(
  p_raw_app_meta_data jsonb
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case coalesce(p_raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'senior_mechanical_engineer'
    when 'project_manager' then 'project_manager'
    when 'workshop_in_charge' then 'workshop_in_charge'
    when 'document_controller' then 'document_controller'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    when 'engineer' then 'engineer'
    else 'unrecognized'
  end;
$$;

create or replace function public.v1_chat_exact_role(p_auth_user_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select case coalesce(auth_user.raw_app_meta_data ->> 'role', '')
    when 'project_engineer' then 'project_engineer'
    when 'site_engineer' then 'site_engineer'
    when 'senior_mechanical_engineer' then 'senior_mechanical_engineer'
    when 'project_manager' then 'project_manager'
    when 'workshop_in_charge' then 'workshop_in_charge'
    when 'document_controller' then 'document_controller'
    when 'procurement' then 'procurement'
    when 'admin' then 'admin'
    else ''
  end
  from auth.users auth_user
  join public.v1_profiles profile
    on profile.auth_user_id = auth_user.id and profile.is_active
  where auth_user.id = p_auth_user_id
    and (auth_user.banned_until is null
      or auth_user.banned_until <= clock_timestamp());
$$;

-- Extend every current organization-wide Project Engineer authorization list.
-- Guarded anchors stop the migration if an upstream function changed shape;
-- that is safer than silently leaving one workflow surface inconsistent.
do $global_role_rewrite$
declare
  v_signature regprocedure;
  v_definition text;
  v_updated text;
begin
  foreach v_signature in array array[
    'public.v1_has_active_project_membership(uuid,uuid,text)'::regprocedure,
    'public.v1_can_close_material_request(uuid)'::regprocedure,
    'public.v1_expand_global_notification_recipients()'::regprocedure,
    'public.v1_material_request_participant(uuid,uuid)'::regprocedure,
    'public.v1_submit_material_request(jsonb,uuid)'::regprocedure,
    'public.v1_list_configuration_units()'::regprocedure,
    'public.v1_create_chat_conversation(jsonb,uuid)'::regprocedure,
    'public.v1_sync_chat_context_members(uuid)'::regprocedure
  ]
  loop
    v_definition := pg_get_functiondef(v_signature);
    if position('workshop_in_charge' in v_definition) > 0
      and position('document_controller' in v_definition) > 0 then
      continue;
    end if;
    v_updated := replace(
      v_definition,
      '''senior_mechanical_engineer'', ''project_manager''',
      '''senior_mechanical_engineer'', ''project_manager'', ''workshop_in_charge'', ''document_controller'''
    );
    v_updated := replace(
      v_updated,
      '''admin'', ''project_manager'', ''senior_mechanical_engineer''',
      '''admin'', ''project_manager'', ''senior_mechanical_engineer'', ''workshop_in_charge'', ''document_controller'''
    );
    v_updated := replace(
      v_updated,
      '''admin'', ''senior_mechanical_engineer'', ''project_manager''',
      '''admin'', ''senior_mechanical_engineer'', ''project_manager'', ''workshop_in_charge'', ''document_controller'''
    );
    if v_updated = v_definition then
      raise exception 'V1_GLOBAL_ROLE_REWRITE_ANCHOR_MISSING: %', v_signature;
    end if;
    execute v_updated;
  end loop;
end;
$global_role_rewrite$;

-- The profile mirror stores the normalized workflow role, never the exact job
-- title. Preserve the live function body and extend only its exact-role map.
do $profile_sync_rewrite$
declare
  v_definition text;
  v_updated text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_sync_profile_from_auth(uuid)'::regprocedure
  );
  if position('workshop_in_charge' in v_definition) > 0
    and position('document_controller' in v_definition) > 0 then
    return;
  end if;
  v_updated := replace(
    v_definition,
    'when ''project_manager'' then ''project_engineer''',
    'when ''project_manager'' then ''project_engineer''
    when ''workshop_in_charge'' then ''project_engineer''
    when ''document_controller'' then ''project_engineer'''
  );
  if v_updated = v_definition then
    raise exception 'V1_PROFILE_SYNC_ROLE_ANCHOR_MISSING';
  end if;
  execute v_updated;
end;
$profile_sync_rewrite$;

-- Expand exact-role constraints without invalidating any historical row. Each
-- replacement is a strict superset and is validated before the old constraint
-- is removed, so there is no unchecked state even inside this transaction.
do $constraint_rewrite$
declare
  v_record record;
  v_new_constraint_name text;
  v_old_constraint_name text;
  v_roles text := $$array[
    'project_engineer'::text,
    'site_engineer'::text,
    'senior_mechanical_engineer'::text,
    'project_manager'::text,
    'workshop_in_charge'::text,
    'document_controller'::text,
    'procurement'::text,
    'admin'::text
  ]$$;
begin
  for v_record in
    select * from (values
      ('v1_arrangement_decisions', 'decided_by_exact_role', true),
      ('v1_audit_events', 'actor_exact_role', true),
      ('v1_chat_conversations', 'created_by_exact_role', false),
      ('v1_chat_messages', 'sender_exact_role', true),
      ('v1_delivery_order_revisions', 'generated_by_exact_role', true),
      ('v1_material_dispatches', 'dispatched_by_exact_role', true),
      ('v1_material_request_comment_mentions', 'mentioned_exact_role', false),
      ('v1_material_request_comments', 'author_exact_role', false),
      ('v1_material_request_decisions', 'decided_by_exact_role', false),
      ('v1_material_requests', 'requester_exact_role', true),
      ('v1_receipt_reviews', 'reviewed_by_exact_role', true)
    ) as role_constraint(table_name, column_name, nullable)
  loop
    v_new_constraint_name := left(
      v_record.table_name || '_' || v_record.column_name || '_expanded_check',
      63
    );
    v_old_constraint_name := left(
      v_record.table_name || '_' || v_record.column_name || '_expanded_ch',
      63
    );
    if not exists (
      select 1
      from pg_constraint constraint_record
      where constraint_record.conrelid =
        format('public.%I', v_record.table_name)::regclass
        and constraint_record.conname =
          v_new_constraint_name
    ) then
      if exists (
        select 1
        from pg_constraint constraint_record
        where constraint_record.conrelid =
          format('public.%I', v_record.table_name)::regclass
          and constraint_record.conname =
            v_old_constraint_name
      ) then
        if v_old_constraint_name <> v_new_constraint_name then
          execute format(
            'alter table public.%I rename constraint %I to %I',
            v_record.table_name,
            v_old_constraint_name,
            v_new_constraint_name
          );
        end if;
      else
        execute format(
          'alter table public.%I add constraint %I check (%I = any (%s)%s) not valid',
          v_record.table_name,
          v_new_constraint_name,
          v_record.column_name,
          v_roles,
          case when v_record.nullable then ' or ' || quote_ident(v_record.column_name) || ' is null' else '' end
        );
      end if;
    end if;
    execute format(
      'alter table public.%I validate constraint %I',
      v_record.table_name,
      v_new_constraint_name
    );
  end loop;

  alter table public.v1_arrangement_decisions
    drop constraint if exists v1_arrangement_decisions_exact_role_check;
  alter table public.v1_audit_events
    drop constraint if exists v1_audit_events_actor_exact_role_check;
  alter table public.v1_chat_conversations
    drop constraint if exists v1_chat_conversations_created_by_exact_role_check;
  alter table public.v1_chat_messages
    drop constraint if exists v1_chat_messages_sender_exact_role_check;
  alter table public.v1_delivery_order_revisions
    drop constraint if exists v1_delivery_order_revisions_exact_role_check;
  alter table public.v1_material_dispatches
    drop constraint if exists v1_material_dispatches_exact_role_check;
  alter table public.v1_material_request_comment_mentions
    drop constraint if exists v1_material_request_comment_mentions_mentioned_exact_role_check;
  alter table public.v1_material_request_comments
    drop constraint if exists v1_material_request_comments_author_exact_role_check;
  alter table public.v1_material_request_decisions
    drop constraint if exists v1_material_request_decisions_decided_by_exact_role_check;
  alter table public.v1_material_requests
    drop constraint if exists v1_material_requests_requester_exact_role_check;
  alter table public.v1_receipt_reviews
    drop constraint if exists v1_receipt_reviews_exact_role_check;
end;
$constraint_rewrite$;

-- Read and write are intentionally separate permissions. Only this read
-- predicate adds Senior Mechanical Engineer; every stock/category/import
-- command continues to call v1_can_manage_inventory().
create or replace function public.v1_can_view_inventory()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.v1_current_actor_is_active()
    and (
      public.v1_can_manage_inventory()
      or public.v1_current_exact_role() = 'senior_mechanical_engineer'
    );
$$;

revoke all on function public.v1_can_view_inventory()
  from public, anon, authenticated;

do $inventory_read_rewrite$
declare
  v_signature regprocedure;
  v_definition text;
  v_updated text;
begin
  foreach v_signature in array array[
    'public.v1_inventory_workspace_projection(text)'::regprocedure,
    'public.v1_inventory_item_workspace_projection(uuid)'::regprocedure
  ]
  loop
    v_definition := pg_get_functiondef(v_signature);
    if position('v1_can_view_inventory()' in v_definition) > 0 then
      continue;
    end if;
    v_updated := replace(
      v_definition,
      'if not public.v1_can_manage_inventory() then',
      'if not public.v1_can_view_inventory() then'
    );
    if v_updated = v_definition then
      raise exception 'V1_INVENTORY_READ_REWRITE_ANCHOR_MISSING: %', v_signature;
    end if;
    execute v_updated;
  end loop;
end;
$inventory_read_rewrite$;

comment on function public.v1_can_view_inventory() is
  'Read-only warehouse authorization: Procurement/Admin plus Senior Mechanical Engineer. Does not grant stock mutation.';

commit;
