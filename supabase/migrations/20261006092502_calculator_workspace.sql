-- Additive calculator workspace. Existing device drafts and engineering functions
-- remain untouched. Rollback disables the workspace flag; retain records/grants/audit.
begin;
create table if not exists public.v1_calculators (
 id uuid primary key,
 title text not null check (length(btrim(title)) between 1 and 160),
 kind text not null check (kind in ('duct','esp')),
 project_id uuid references public.v1_projects(id) on delete restrict,
 owner_id uuid not null references public.v1_profiles(auth_user_id) on delete restrict,
 payload jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 1048576),
 record_version integer not null default 1,
 archived boolean not null default false,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 updated_by uuid not null references public.v1_profiles(auth_user_id) on delete restrict
);
create table if not exists public.v1_calculator_grants (
 calculator_id uuid not null references public.v1_calculators(id) on delete restrict,
 user_id uuid not null references public.v1_profiles(auth_user_id) on delete restrict,
 access text not null check (access in ('view','edit')),
 primary key(calculator_id,user_id)
);
create index if not exists v1_calculators_recent on public.v1_calculators(updated_at desc,id);
create index if not exists v1_calculator_grants_user on public.v1_calculator_grants(user_id,calculator_id);
alter table public.v1_calculators enable row level security;
alter table public.v1_calculator_grants enable row level security;
revoke all on public.v1_calculators,public.v1_calculator_grants from public,anon,authenticated;
grant all on public.v1_calculators,public.v1_calculator_grants to service_role;

create or replace function public.v1_calculator_active_actor() returns boolean
language sql stable security definer set search_path='' as $$
 select public.v1_current_actor_is_active() and exists (
  select 1 from auth.users u where u.id=auth.uid() and u.deleted_at is null
 );
$$;
revoke all on function public.v1_calculator_active_actor() from public,anon,authenticated;

create or replace function public.v1_calculator_manager() returns boolean
language sql stable security definer set search_path='' as $$
 select public.v1_calculator_active_actor() and public.v1_current_exact_role() in
 ('admin','senior_mechanical_engineer','project_manager');
$$;
create or replace function public.v1_calculator_access(p_id uuid,p_edit boolean default false)
returns boolean language sql stable security definer set search_path='' as $$
 select public.v1_calculator_active_actor() and exists(select 1 from auth.users where id=auth.uid() and deleted_at is null) and exists (
 select 1 from public.v1_calculators c where c.id=p_id
 and (c.project_id is null or public.v1_project_readable(c.project_id))
 and (public.v1_calculator_manager() or
 (c.owner_id=auth.uid() and public.v1_current_role() in ('project_engineer','site_engineer','admin')) or exists
 (select 1 from public.v1_calculator_grants g where g.calculator_id=c.id and g.user_id=auth.uid()
 and (not p_edit or g.access='edit'))));
$$;
create or replace function public.v1_calculator_json(p_id uuid,p_detail boolean default true)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c.id,'title',c.title,'kind',c.kind,'project_id',c.project_id,
 'project_name',p.name,'owner_id',c.owner_id,'owner_name',o.display_name,
 'updated_by_name',u.display_name,'updated_at',c.updated_at,'created_at',c.created_at,
 'record_version',c.record_version,'archived',c.archived,
 'can_edit',public.v1_calculator_access(c.id,true) and not c.archived,
 'can_manage',public.v1_calculator_manager(),
 'payload',case when p_detail then c.payload else null end,
 'grants',case when p_detail and public.v1_calculator_manager() then coalesce((select jsonb_agg(
 jsonb_build_object('user_id',g.user_id,'access',g.access,'name',gp.display_name))
 from public.v1_calculator_grants g join public.v1_profiles gp on gp.auth_user_id=g.user_id
 where g.calculator_id=c.id),'[]'::jsonb) else '[]'::jsonb end)
 from public.v1_calculators c join public.v1_profiles o on o.auth_user_id=c.owner_id
 join public.v1_profiles u on u.auth_user_id=c.updated_by
 left join public.v1_projects p on p.id=c.project_id
 where c.id=p_id and public.v1_calculator_access(c.id,false);
$$;
create or replace function public.v1_list_calculators(p_search text default '',p_offset integer default 0,p_archived boolean default false,p_kind text default 'all',p_scope text default 'all')
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_result jsonb;
begin
 if not public.v1_calculator_active_actor() then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 select coalesce(jsonb_agg(item order by updated_at desc,id),'[]'::jsonb) into v_result from (
 select c.id,c.updated_at,public.v1_calculator_json(c.id,false) item from public.v1_calculators c
 where public.v1_calculator_access(c.id,false) and c.archived=p_archived
 and (p_kind='all' or c.kind=p_kind)
 and (p_scope='all' or (p_scope='general' and c.project_id is null) or (p_scope='project' and c.project_id is not null))
 and (coalesce(p_search,'')='' or position(lower(left(p_search,160)) in lower(c.title))>0)
 order by c.updated_at desc,c.id limit 50 offset greatest(0,least(coalesce(p_offset,0),100000)) ) q;
 return jsonb_build_object('items',v_result,'can_create',public.v1_current_role() in ('admin','project_engineer','site_engineer'),
 'can_manage',public.v1_calculator_manager());
end; $$;
create or replace function public.v1_get_calculator(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.v1_calculator_access(p_id,false) then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 return public.v1_calculator_json(p_id);
end; $$;
create or replace function public.v1_calculator_options() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.v1_calculator_active_actor() then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 return jsonb_build_object('projects',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) order by p.name)
 from public.v1_projects p where public.v1_project_readable(p.id) and p.state <> 'archived'),'[]'::jsonb),
 'people',case when public.v1_calculator_manager() then coalesce((select jsonb_agg(jsonb_build_object('id',p.auth_user_id,'name',p.display_name) order by p.display_name)
 from public.v1_profiles p join auth.users u on u.id=p.auth_user_id where p.is_active and u.deleted_at is null
 and (u.banned_until is null or u.banned_until <= now())
 and public.v1_is_valid_role(u.raw_app_meta_data->>'role')),'[]'::jsonb) else '[]'::jsonb end);
end; $$;

create or replace function public.v1_validate_calculator_data(p_data jsonb,p_kind text)
returns void language plpgsql immutable set search_path='' as $$
declare v_key text; v_value text; v_row jsonb;
begin
 if p_data is null or jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>1048576
 or p_data->'version' is distinct from '1'::jsonb
 or (p_data->>'app') is distinct from (case when p_kind='duct' then 'duct-calc' else 'esp-calc' end) then
 raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
 if p_kind='duct' then
  foreach v_key in array array['flow','width','height','diameter','targetVelocity','targetFriction','equivalentDiameter','aspectRatio'] loop
   if p_data ? v_key and p_data->v_key <> 'null'::jsonb then
    v_value:=p_data->>v_key;
    if jsonb_typeof(p_data->v_key)<>'string' or length(v_value)>100
      or (btrim(v_value)<>'' and (replace(v_value,',','.') !~ '^\s*[+]?[0-9]*[.]?[0-9]+([eE][+-]?[0-9]+)?\s*$')) then
     raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
    if btrim(v_value)<>'' then perform replace(v_value,',','.')::double precision; end if;
   end if;
  end loop;
  if (p_data ? 'shape' and p_data->>'shape' not in ('rectangular','circular'))
  or (p_data ? 'unitSystem' and p_data->>'unitSystem' not in ('SI','Imperial'))
  or (p_data ? 'mode' and p_data->>'mode' not in ('checkSize','velocity','friction','equivalentDiameter'))
  or (p_data ? 'condition' and p_data->>'condition' not in ('Air at 15°C','20°C Air STP','Air at 25°C','Air at 30°C'))
  or (p_data ? 'material' and p_data->>'material' not in ('Galvanized steel','Aluminium','Black steel','Flexible duct','Concrete')) then
   raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
 else
  if jsonb_typeof(p_data->'rows') is distinct from 'array' then raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
  if jsonb_array_length(p_data->'rows')>1000 or (p_data ? 'header' and jsonb_typeof(p_data->'header')<>'object') then
   raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
  if p_data ? 'safetyFactor' and (jsonb_typeof(p_data->'safetyFactor')<>'string' or p_data->>'safetyFactor' !~ '^[+]?[0-9]*[.]?[0-9]+([eE][+-]?[0-9]+)?$') then
   raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
  if p_data ? 'safetyFactor' then perform (p_data->>'safetyFactor')::double precision; end if;
  for v_row in select value from jsonb_array_elements(p_data->'rows') loop
   if jsonb_typeof(v_row)<>'object' then raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
   foreach v_key in array array['id','fitting','flow','width','height','length','diameter','manualEsp'] loop
    if v_row ? v_key and v_row->v_key <> 'null'::jsonb and jsonb_typeof(v_row->v_key)<>'string' then
     raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
   end loop;
   foreach v_key in array array['flow','width','height','length','diameter','manualEsp'] loop
    v_value:=v_row->>v_key;
    if v_value is not null and btrim(v_value)<>'' and (length(v_value)>100 or replace(v_value,',','.') !~ '^\s*[+]?[0-9]*[.]?[0-9]+([eE][+-]?[0-9]+)?\s*$') then
     raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
    if v_value is not null and btrim(v_value)<>'' then perform replace(v_value,',','.')::double precision; end if;
   end loop;
  end loop;
  if exists(select 1 from jsonb_array_elements(p_data->'rows') r where r->>'id' is not null group by r->>'id' having count(*)>1) then
   raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
 end if;
exception when numeric_value_out_of_range or invalid_text_representation then
 raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023';
end; $$;
revoke all on function public.v1_validate_calculator_data(jsonb,text) from public,anon,authenticated;

create or replace function public.v1_save_calculator(p_payload jsonb,p_idempotency_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare
 v_id uuid := (p_payload->>'id')::uuid;
 v_project uuid := nullif(p_payload->>'project_id','')::uuid;
 v_old public.v1_calculators%rowtype;
 v_existing boolean;
 v_response jsonb;
 v_data jsonb := p_payload->'payload';
 v_kind text := p_payload->>'kind';
begin
 if not public.v1_calculator_active_actor() then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('calculator:'||v_id::text,0));
 select * into v_old from public.v1_calculators where id=v_id for update;
 v_existing:=found;
 if v_existing then
   if not public.v1_calculator_access(v_id,true) then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 else
   if public.v1_current_role() not in ('admin','project_engineer','site_engineer') or
    (v_project is not null and not public.v1_project_readable(v_project)) then
    raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 end if;
 v_response:=public.v1_idempotency_get_or_claim('save_calculator',p_idempotency_key,p_payload);
 if v_response is not null then return v_response || jsonb_build_object('can_edit',public.v1_calculator_access(v_id,true) and not v_old.archived,'can_manage',public.v1_calculator_manager()); end if;
 if v_id is null or coalesce(length(btrim(p_payload->>'title')),0) not between 1 and 160
 or v_kind is null or v_kind not in ('duct','esp') or v_data is null or jsonb_typeof(v_data)<>'object'
 or octet_length(v_data::text)>1048576 or (v_data->>'version') is distinct from '1'
 or (v_data->>'app') is distinct from (case when v_kind='duct' then 'duct-calc' else 'esp-calc' end)
 or (v_kind='esp' and (jsonb_typeof(v_data->'rows') is distinct from 'array')) then
 raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
 perform public.v1_validate_calculator_data(v_data,v_kind);
 if v_existing then
   if v_old.archived then raise exception 'CALCULATOR_ARCHIVED' using errcode='55000'; end if;
   if v_old.record_version is distinct from (p_payload->>'expected_version')::integer then
     raise exception 'CALCULATOR_VERSION_CONFLICT' using errcode='40001'; end if;
   if v_old.kind<>v_kind or v_old.project_id is distinct from v_project then
     raise exception 'CALCULATOR_SCOPE_IMMUTABLE' using errcode='22023'; end if;
   update public.v1_calculators set title=btrim(p_payload->>'title'),payload=v_data,
    record_version=record_version+1,updated_at=clock_timestamp(),updated_by=auth.uid() where id=v_id;
 else
   if coalesce((p_payload->>'expected_version')::integer,0)<>0 then
     raise exception 'CALCULATOR_VERSION_CONFLICT' using errcode='40001'; end if;
   insert into public.v1_calculators(id,title,kind,project_id,owner_id,payload,updated_by)
   values(v_id,btrim(p_payload->>'title'),v_kind,v_project,auth.uid(),v_data,auth.uid());
 end if;
 perform public.v1_write_audit_event('calculator_saved','calculator',v_id,v_project,
  case when v_existing then to_jsonb(v_old) else null end,
  (select to_jsonb(c) from public.v1_calculators c where id=v_id),null,p_idempotency_key);
 v_response:=public.v1_calculator_json(v_id);
 perform public.v1_complete_idempotency('save_calculator',p_idempotency_key,v_response);
 return v_response;
end; $$;
create or replace function public.v1_manage_calculator(p_payload jsonb,p_idempotency_key uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_id uuid:=(p_payload->>'id')::uuid; v_old public.v1_calculators%rowtype; v_response jsonb; v_user uuid; v_before jsonb;
begin
 if not public.v1_calculator_active_actor() then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('calculator:'||v_id::text,0));
 select * into v_old from public.v1_calculators where id=v_id for update;
 if not public.v1_calculator_manager() or not public.v1_calculator_access(v_id,false) then
 raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
 v_response:=public.v1_idempotency_get_or_claim('manage_calculator',p_idempotency_key,p_payload);
 if v_response is not null then return v_response || jsonb_build_object('can_edit',public.v1_calculator_access(v_id,true) and not v_old.archived,'can_manage',public.v1_calculator_manager()); end if;
 if v_old.record_version is distinct from (p_payload->>'expected_version')::integer then
 raise exception 'CALCULATOR_VERSION_CONFLICT' using errcode='40001'; end if;
 v_before:=public.v1_calculator_json(v_id);
 if p_payload->>'action'='access' then
  v_user:=(p_payload->>'user_id')::uuid;
  if not exists(select 1 from public.v1_profiles p join auth.users u on u.id=p.auth_user_id
  where p.auth_user_id=v_user and p.is_active and u.deleted_at is null
  and (u.banned_until is null or u.banned_until<=now()) and public.v1_is_valid_role(u.raw_app_meta_data->>'role')) then
  raise exception 'CALCULATOR_INVALID_MEMBER' using errcode='22023'; end if;
  if p_payload->>'access'='none' then
    delete from public.v1_calculator_grants where calculator_id=v_id and user_id=v_user;
  elsif p_payload->>'access' in ('view','edit') then
    insert into public.v1_calculator_grants(calculator_id,user_id,access) values(v_id,v_user,p_payload->>'access')
    on conflict(calculator_id,user_id) do update set access=excluded.access;
  else raise exception 'CALCULATOR_INVALID_ACCESS' using errcode='22023'; end if;
 elsif p_payload->>'action'='archive' then
  if jsonb_typeof(p_payload->'archived') is distinct from 'boolean' then
   raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
 else raise exception 'CALCULATOR_INVALID_ACTION' using errcode='22023'; end if;
 update public.v1_calculators set record_version=record_version+1,updated_at=clock_timestamp(),updated_by=auth.uid(),
 archived=case when p_payload->>'action'='archive' then (p_payload->>'archived')::boolean else archived end where id=v_id;
 perform public.v1_write_audit_event('calculator_access_or_archive_changed','calculator',v_id,v_old.project_id,
 v_before - 'payload',public.v1_calculator_json(v_id) - 'payload',null,p_idempotency_key);
 v_response:=public.v1_calculator_json(v_id);
 perform public.v1_complete_idempotency('manage_calculator',p_idempotency_key,v_response);
 return v_response;
end; $$;
revoke all on function public.v1_calculator_manager(),public.v1_calculator_access(uuid,boolean),public.v1_calculator_json(uuid,boolean) from public,anon,authenticated;
revoke all on function public.v1_list_calculators(text,integer,boolean,text,text),public.v1_get_calculator(uuid),public.v1_calculator_options(),public.v1_save_calculator(jsonb,uuid),public.v1_manage_calculator(jsonb,uuid) from public,anon;
grant execute on function public.v1_list_calculators(text,integer,boolean,text,text),public.v1_get_calculator(uuid),public.v1_calculator_options(),public.v1_save_calculator(jsonb,uuid),public.v1_manage_calculator(jsonb,uuid) to authenticated;
commit;
