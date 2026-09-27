-- Explicit product-owner launch policy, 27 September 2026; run as trusted operator.
-- Repeatable data configuration, NOT an app hydration seed or technical-persona seed.
-- Existing catalog, routes, grants, revocations and business records remain intact.
begin;
insert into public.v1_company_material_request_categories(category_code, display_name)
values ('personal','Personal Use'), ('office','Office Supplies'),
  ('warehouse','Warehouse Supplies'), ('workers','Worker Supplies'),
  ('safety','Safety & PPE'), ('other','Other') on conflict(category_code) do nothing;
insert into public.v1_company_material_request_units(unit_code, display_name)
values ('COMPANY','Company Operations') on conflict(unit_code) do nothing;
insert into public.v1_company_material_request_staff_policies(category_id,responsible_unit_id,policy_version)
select c.id,u.id,'2026-09-27_company_use_companywide_policy_v1'
from public.v1_company_material_request_categories c
cross join public.v1_company_material_request_units u
where c.category_code in ('personal','office','warehouse','workers','safety','other')
  and c.is_active and u.unit_code='COMPANY' and u.is_active
on conflict(category_id,responsible_unit_id) do nothing;
select public.v1_provision_company_material_request_staff_authorizations(p.auth_user_id)
from public.v1_profiles p where p.is_active order by p.auth_user_id;

do $$
declare v_primary uuid; v_alternate uuid; v_category record; v_unit uuid;
begin
  select id into v_unit from public.v1_company_material_request_units where unit_code='COMPANY' and is_active;
  if v_unit is null then raise exception 'COMPANY_LAUNCH_ACTIVE_UNIT_REQUIRED'; end if;
  -- A real active Admin is the initial accountable primary. The alternate is
  -- a real senior engineer, then another active approver if none is available.
  select u.id into v_primary from auth.users u join public.v1_profiles p on p.auth_user_id=u.id and p.is_active
  where u.raw_app_meta_data->>'role'='admin' and u.deleted_at is null
    and (u.banned_until is null or u.banned_until<=clock_timestamp())
  order by u.created_at,u.id limit 1;
  if v_primary is null then raise exception 'COMPANY_LAUNCH_ACTIVE_ADMIN_REQUIRED'; end if;
  select u.id into v_alternate from auth.users u join public.v1_profiles p on p.auth_user_id=u.id and p.is_active
  where u.id<>v_primary and u.raw_app_meta_data->>'role' in
    ('admin','project_engineer','senior_mechanical_engineer','project_manager','workshop_in_charge','document_controller')
    and u.deleted_at is null and (u.banned_until is null or u.banned_until<=clock_timestamp())
  order by case u.raw_app_meta_data->>'role' when 'senior_mechanical_engineer' then 0 when 'admin' then 1 else 2 end,
    u.created_at,u.id limit 1;
  if v_alternate is null then raise exception 'COMPANY_LAUNCH_INDEPENDENT_ALTERNATE_REQUIRED'; end if;
  for v_category in select id from public.v1_company_material_request_categories
    where category_code in ('personal','office','warehouse','workers','safety','other') and is_active
  loop
    if not public.v1_company_material_request_active_authorization(v_primary,v_category.id,v_unit,'approver')
      or not public.v1_company_material_request_active_authorization(v_alternate,v_category.id,v_unit,'approver') then
      raise exception 'COMPANY_LAUNCH_APPROVER_GRANT_REQUIRED';
    end if;
    insert into public.v1_company_material_request_approval_routes
      (category_id,responsible_unit_id,primary_approver_auth_user_id,alternate_approver_auth_user_id,policy_version)
    select v_category.id,v_unit,v_primary,v_alternate,'2026-09-27_company_use_companywide_policy_v1'
    where not exists (select 1 from public.v1_company_material_request_approval_routes r
      where r.category_id=v_category.id and r.responsible_unit_id=v_unit);
  end loop;
  if (select count(*) from public.v1_company_material_request_categories
    where category_code in ('personal','office','warehouse','workers','safety','other') and is_active)<>6 then
    raise exception 'COMPANY_LAUNCH_SIX_ACTIVE_CATEGORIES_REQUIRED';
  end if;
end;
$$;
commit;
