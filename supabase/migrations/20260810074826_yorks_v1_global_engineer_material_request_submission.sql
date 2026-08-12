-- Yorks V1: organization-wide Project Engineer roles may create and submit
-- Material Requests without an individual dated project-membership row.  The
-- existing v1_has_active_project_membership helper remains the authority for
-- this exception, so stale/inactive role claims still fail closed.
--
-- Data preservation and rollback:
-- * no existing request, request line, document or audit event is rewritten;
-- * the submit function keeps its existing idempotency, state, scope and
--   quantity guards;
-- * new line descriptions are normalized only on future inserts/updates.

do $global_engineer_submit_guard$
declare
  v_definition text;
  v_old text := $old$
  if v_project_role is null and public.v1_current_role() <> 'admin' then
    raise exception 'V1_MATERIAL_REQUEST_MEMBERSHIP_REQUIRED' using errcode = '42501';
  end if;
$old$;
  v_new text := $new$
  if v_project_role is null
    and public.v1_current_role() <> 'admin'
    and not public.v1_has_active_project_membership(v_project.id, v_actor) then
    raise exception 'V1_MATERIAL_REQUEST_MEMBERSHIP_REQUIRED' using errcode = '42501';
  end if;
$new$;
begin
  v_definition := pg_get_functiondef(
    'public.v1_submit_material_request(jsonb,uuid)'::regprocedure
  );
  if position(v_new in v_definition) > 0 then
    return;
  end if;
  if position(v_old in v_definition) = 0 then
    raise exception 'V1_MATERIAL_REQUEST_GLOBAL_ENGINEER_GUARD_NOT_FOUND';
  end if;
  execute replace(v_definition, v_old, v_new);
end;
$global_engineer_submit_guard$;

-- Keep the controlled document snapshots consistent with the submitted MR by
-- normalizing the first character at the line persistence boundary.  This is
-- intentionally not a retrospective rewrite of immutable historical records.
create or replace function public.v1_normalize_material_request_line_description()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.item_description := nullif(btrim(new.item_description), '');
  if new.item_description is not null then
    new.item_description := upper(left(new.item_description, 1))
      || substr(new.item_description, 2);
  end if;
  return new;
end;
$$;

drop trigger if exists v1_normalize_material_request_line_description
  on public.v1_material_request_lines;
create trigger v1_normalize_material_request_line_description
before insert or update of item_description on public.v1_material_request_lines
for each row execute function public.v1_normalize_material_request_line_description();
