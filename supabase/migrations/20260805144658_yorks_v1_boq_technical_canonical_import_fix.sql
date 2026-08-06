-- R35 repair: the client correctly maps equipment schedules' Size, Model and
-- equipment tag columns, but the header-hierarchy replacement of the trusted
-- worksheet commands retained the older, narrower canonical-field allow-list.
-- Rebuild only those two function definitions from their installed bodies so
-- all version, permission, idempotency and audit behaviour remains unchanged.
--
-- This is intentionally repeatable. A fresh database may already carry the
-- expanded allow-list; a database carrying the historical definition is
-- upgraded in place. Existing BOQ rows, groups and source-workbook provenance
-- are not modified.
do $$
declare
  v_definition text;
  v_old_allow_list text :=
    '''description'', ''brand_origin'', ''quantity'', ''unit'', ''planning_model_tag''';
  v_new_allow_list text :=
    '''description'', ''size'', ''model'', ''equipment_tag'', ''brand_origin'', ''quantity'', ''unit'', ''planning_model_tag''';
begin
  foreach v_definition in array array[
    pg_get_functiondef('public.v1_save_boq_worksheet(jsonb,uuid)'::regprocedure),
    pg_get_functiondef('public.v1_import_boq_worksheet(jsonb,uuid)'::regprocedure)
  ] loop
    if position(v_new_allow_list in v_definition) > 0 then
      continue;
    end if;
    if position(v_old_allow_list in v_definition) = 0 then
      raise exception 'V1_BOQ_CANONICAL_ALLOWLIST_UNKNOWN';
    end if;
    execute replace(v_definition, v_old_allow_list, v_new_allow_list);
  end loop;
end;
$$;
