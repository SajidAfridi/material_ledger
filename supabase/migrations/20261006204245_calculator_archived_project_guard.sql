-- Additive calculator archive guard. Preserve all rows, grants and history.
-- Rollback: revert the client menu change or disable the workspace flag; keep
-- this server restriction. Do not restore the unsafe save function or drop data.
begin;
create or replace function public.v1_calculator_json(p_id uuid,p_detail boolean default true)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',c.id,'title',c.title,'kind',c.kind,'project_id',c.project_id,
 'project_name',p.name,'owner_id',c.owner_id,'owner_name',o.display_name,
 'updated_by_name',u.display_name,'updated_at',c.updated_at,'created_at',c.created_at,
 'record_version',c.record_version,'archived',c.archived,
 'can_edit',public.v1_calculator_access(c.id,true) and not c.archived
 and (c.project_id is null or p.state <> 'archived'),
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
 v_scope_project uuid;
 v_project_state text;
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
 if v_response is not null then return v_response || jsonb_build_object('can_edit',public.v1_calculator_json(v_id)->'can_edit','can_manage',public.v1_calculator_manager()); end if;
 if v_id is null or coalesce(length(btrim(p_payload->>'title')),0) not between 1 and 160
 or v_kind is null or v_kind not in ('duct','esp') or v_data is null or jsonb_typeof(v_data)<>'object'
 or octet_length(v_data::text)>1048576 or (v_data->>'version') is distinct from '1'
 or (v_data->>'app') is distinct from (case when v_kind='duct' then 'duct-calc' else 'esp-calc' end)
 or (v_kind='esp' and (jsonb_typeof(v_data->'rows') is distinct from 'array')) then
 raise exception 'CALCULATOR_INVALID_INPUT' using errcode='22023'; end if;
 -- A cached successful intent is acknowledgement, not another write. New
 -- intents lock the authoritative project row so archive/save cannot race.
 v_scope_project := case when v_existing then v_old.project_id else v_project end;
 if v_scope_project is not null then
   select p.state into v_project_state from public.v1_projects p
    where p.id=v_scope_project for share;
   if not found then raise exception 'CALCULATOR_ACCESS_DENIED' using errcode='42501'; end if;
   if v_project_state='archived' then
     raise exception 'CALCULATOR_PROJECT_ARCHIVED' using errcode='55000';
   end if;
 end if;
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
revoke all on function public.v1_calculator_json(uuid,boolean) from public,anon,authenticated;
revoke all on function public.v1_save_calculator(jsonb,uuid) from public,anon;
grant execute on function public.v1_save_calculator(jsonb,uuid) to authenticated;
commit;
