-- Explicit Company-only staff policy approved by the product owner on 2026-09-27.
-- Install is unconfigured: no catalog, grant or business record is seeded here.
-- Publish reviewed scopes separately with tool/company-material-request-launch-policy.sql.
-- Preserve prior grant history: automatic provisioning never reopens a revoked grant.
-- Rollback: disable Company flag / staff policy; retain grants and append-only evidence.
begin;

create table if not exists public.v1_company_material_request_staff_policies (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.v1_company_material_request_categories(id),
  responsible_unit_id uuid not null references public.v1_company_material_request_units(id),
  policy_version text not null check (btrim(policy_version) <> '' and length(policy_version) <= 80),
  is_active boolean not null default true,
  effective_from date not null default current_date,
  effective_to date,
  created_at timestamptz not null default clock_timestamp(),
  check (effective_to is null or effective_to >= effective_from),
  unique(category_id, responsible_unit_id)
);

create table if not exists public.v1_company_material_request_staff_policy_events (
  id uuid primary key default gen_random_uuid(),
  policy_id uuid not null references public.v1_company_material_request_staff_policies(id),
  authorization_id uuid not null unique references public.v1_company_material_request_authorizations(id),
  subject_auth_user_id uuid not null references public.v1_profiles(auth_user_id),
  exact_role_at_grant text not null,
  policy_version_at_grant text not null,
  source_command text not null default 'approved_company_staff_policy',
  created_at timestamptz not null default clock_timestamp()
);
alter table public.v1_company_material_request_staff_policies enable row level security;
alter table public.v1_company_material_request_staff_policy_events enable row level security;
revoke all on public.v1_company_material_request_staff_policies,
  public.v1_company_material_request_staff_policy_events from public, anon, authenticated;
grant select, insert, update on public.v1_company_material_request_staff_policies to service_role;
grant select, insert on public.v1_company_material_request_staff_policy_events to service_role;
drop trigger if exists company_staff_policy_events_append_only
  on public.v1_company_material_request_staff_policy_events;
create trigger company_staff_policy_events_append_only before update or delete
  on public.v1_company_material_request_staff_policy_events
  for each row execute function public.v1_prevent_audit_mutation();

create or replace function public.v1_provision_company_material_request_staff_authorizations(p_auth_user_id uuid)
returns integer language plpgsql security definer set search_path = '' as $$
declare
  v_role text;
  v_count integer;
begin
  -- Live Auth owns the exact role. Global engineers share a canonical PE mirror.
  select u.raw_app_meta_data->>'role' into v_role
  from auth.users u join public.v1_profiles p on p.auth_user_id=u.id and p.is_active
  where u.id=p_auth_user_id and u.deleted_at is null
    and (u.banned_until is null or u.banned_until <= clock_timestamp())
    and u.raw_app_meta_data->>'role' in ('project_engineer','site_engineer','procurement',
      'admin','accountant','senior_mechanical_engineer','project_manager',
      'workshop_in_charge','document_controller')
    and p.canonical_role_snapshot = case u.raw_app_meta_data->>'role'
      when 'senior_mechanical_engineer' then 'project_engineer'
      when 'project_manager' then 'project_engineer'
      when 'workshop_in_charge' then 'project_engineer'
      when 'document_controller' then 'project_engineer'
      else u.raw_app_meta_data->>'role' end;
  if not found then return 0; end if;
  perform pg_advisory_xact_lock(hashtextextended('company_staff_policy:'||p_auth_user_id::text, 0));
  with eligible as (
    select policy.id policy_id, policy.category_id, policy.responsible_unit_id, authority.value authority
    from public.v1_company_material_request_staff_policies policy
    join public.v1_company_material_request_categories c on c.id=policy.category_id and c.is_active
    join public.v1_company_material_request_units u on u.id=policy.responsible_unit_id and u.is_active
    cross join (values ('requester'),('beneficiary'),('receiver'),('approver')) authority(value)
    where policy.is_active and policy.effective_from<=current_date
      and (policy.effective_to is null or policy.effective_to>=current_date)
      and (authority.value <> 'approver' or v_role in ('project_engineer','admin',
        'senior_mechanical_engineer','project_manager','workshop_in_charge','document_controller'))
  ), created as (
    insert into public.v1_company_material_request_authorizations
      (auth_user_id, category_id, responsible_unit_id, authority)
    select p_auth_user_id, e.category_id, e.responsible_unit_id, e.authority
    from eligible e where not exists (
      select 1 from public.v1_company_material_request_authorizations old
      where old.auth_user_id=p_auth_user_id and old.category_id=e.category_id
        and old.responsible_unit_id=e.responsible_unit_id and old.authority=e.authority
    ) on conflict do nothing returning *
  )
  insert into public.v1_company_material_request_staff_policy_events
    (policy_id, authorization_id, subject_auth_user_id, exact_role_at_grant, policy_version_at_grant)
  select e.policy_id, a.id, a.auth_user_id, v_role, policy.policy_version from created a
  join eligible e on e.category_id=a.category_id and e.responsible_unit_id=a.responsible_unit_id
    and e.authority=a.authority
  join public.v1_company_material_request_staff_policies policy on policy.id=e.policy_id
  on conflict (authorization_id) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;
revoke all on function public.v1_provision_company_material_request_staff_authorizations(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_provision_company_material_request_staff_authorizations(uuid) to service_role;

create or replace function public.v1_company_staff_policy_auth_trigger()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.v1_provision_company_material_request_staff_authorizations(new.id);
  return new;
end;
$$;
revoke all on function public.v1_company_staff_policy_auth_trigger() from public, anon, authenticated;
-- PostgreSQL fires same-kind triggers alphabetically: run after v1_sync_profile_from_auth.
-- An exact-role change can leave its canonical mirror unchanged (PE -> SME), so
-- trigger on Auth itself rather than relying on a profile UPDATE being emitted.
drop trigger if exists v1_z_company_staff_policy on auth.users;
create trigger v1_z_company_staff_policy after insert or update of raw_app_meta_data, banned_until, deleted_at
  on auth.users for each row execute function public.v1_company_staff_policy_auth_trigger();

create or replace function public.v1_company_material_request_active_authorization(
  p_auth_user_id uuid, p_category_id uuid, p_responsible_unit_id uuid, p_authority text
)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_auth_user_id is not null and exists (
    select 1 from public.v1_company_material_request_authorizations a
    join public.v1_profiles p on p.auth_user_id=a.auth_user_id and p.is_active
    join auth.users u on u.id=p.auth_user_id and u.deleted_at is null
      and (u.banned_until is null or u.banned_until<=statement_timestamp())
    join public.v1_company_material_request_categories c on c.id=a.category_id and c.is_active
    join public.v1_company_material_request_units unit on unit.id=a.responsible_unit_id and unit.is_active
    left join public.v1_company_material_request_staff_policy_events event on event.authorization_id=a.id
    left join public.v1_company_material_request_staff_policies policy on policy.id=event.policy_id
    where a.auth_user_id=p_auth_user_id and a.category_id=p_category_id
      and a.responsible_unit_id=p_responsible_unit_id and a.authority=p_authority
      and a.effective_from<=current_date and (a.effective_to is null or a.effective_to>=current_date)
      and u.raw_app_meta_data->>'role' in ('project_engineer','site_engineer','procurement',
        'admin','accountant','senior_mechanical_engineer','project_manager','workshop_in_charge','document_controller')
      and p.canonical_role_snapshot = case u.raw_app_meta_data->>'role'
        when 'senior_mechanical_engineer' then 'project_engineer'
        when 'project_manager' then 'project_engineer'
        when 'workshop_in_charge' then 'project_engineer'
        when 'document_controller' then 'project_engineer'
        else u.raw_app_meta_data->>'role' end
      and (p_authority <> 'approver' or u.raw_app_meta_data->>'role' in ('project_engineer','admin',
        'senior_mechanical_engineer','project_manager','workshop_in_charge','document_controller'))
      and (event.id is null or (policy.is_active and policy.effective_from<=current_date
        and (policy.effective_to is null or policy.effective_to>=current_date)))
  );
$$;
create or replace function public.v1_list_company_material_request_draft_options()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_OPTIONS_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'category_id', category.id,
      'category_code', category.category_code,
      'category_name', category.display_name,
      'responsible_unit_id', unit_record.id,
      'responsible_unit_code', unit_record.unit_code,
      'responsible_unit_name', unit_record.display_name,
      'beneficiaries', coalesce((
        select jsonb_agg(jsonb_build_object(
          'auth_user_id', profile.auth_user_id,
          'display_name', profile.display_name
        ) order by lower(profile.display_name), profile.auth_user_id)
        from public.v1_company_material_request_authorizations authorization_record
        join public.v1_profiles profile
          on profile.auth_user_id = authorization_record.auth_user_id and profile.is_active
        where authorization_record.category_id = category.id
          and authorization_record.responsible_unit_id = unit_record.id
          and authorization_record.authority = 'beneficiary'
          and public.v1_company_material_request_active_authorization(
            authorization_record.auth_user_id, category.id, unit_record.id, 'beneficiary')
          and authorization_record.effective_from <= current_date
          and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
      ), '[]'::jsonb),
      'receivers', coalesce((
        select jsonb_agg(jsonb_build_object(
          'auth_user_id', profile.auth_user_id,
          'display_name', profile.display_name
        ) order by lower(profile.display_name), profile.auth_user_id)
        from public.v1_company_material_request_authorizations authorization_record
        join public.v1_profiles profile
          on profile.auth_user_id = authorization_record.auth_user_id and profile.is_active
        where authorization_record.category_id = category.id
          and authorization_record.responsible_unit_id = unit_record.id
          and authorization_record.authority = 'receiver'
          and public.v1_company_material_request_active_authorization(
            authorization_record.auth_user_id, category.id, unit_record.id, 'receiver')
          and authorization_record.effective_from <= current_date
          and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
      ), '[]'::jsonb)
    ) order by lower(category.display_name), lower(unit_record.display_name))
    from public.v1_company_material_request_authorizations authorization_record
    join public.v1_company_material_request_categories category
      on category.id = authorization_record.category_id and category.is_active
    join public.v1_company_material_request_units unit_record
      on unit_record.id = authorization_record.responsible_unit_id and unit_record.is_active
    where authorization_record.auth_user_id = v_actor
      and authorization_record.authority = 'requester'
          and public.v1_company_material_request_active_authorization(
            authorization_record.auth_user_id, category.id, unit_record.id, 'requester')
      and authorization_record.effective_from <= current_date
      and (authorization_record.effective_to is null or authorization_record.effective_to >= current_date)
  ), '[]'::jsonb);
end;
$$;

commit;
