-- Keep project-scoped allocation (so an archived project cannot block a
-- replacement project with the same reference) while restoring Yorks' familiar
-- MR001, MR002 sequence. The application never predicts or writes this value;
-- it is allocated only by the locked submit command below.
begin;

-- Reconcile the temporary 100-series floor to the highest number actually
-- issued for each project. This preserves any number that may have been
-- allocated between releases and makes an untouched project start at MR001.
update public.v1_material_request_reference_counters counter_record
set next_request_sequence = coalesce(
  (
    select max(
      (regexp_match(request_record.request_number, '-MR([0-9]+)$'))[1]::integer
    ) + 1
    from public.v1_material_requests request_record
    where request_record.project_id = counter_record.project_id
      and request_record.request_number ~ '-MR[0-9]+$'
  ),
  1
),
updated_at = clock_timestamp();

do $migration$
declare
  v_definition text := pg_get_functiondef(
    'public.v1_submit_material_request(jsonb,uuid)'::regprocedure
  );
begin
  if position('values (v_project.id, 101, clock_timestamp())' in v_definition) = 0
      or position($old_number$
  v_request_number := regexp_replace(
    upper(v_project.project_ref), '[^A-Z0-9]+', '', 'g'
  ) || '-MR' || v_sequence::text;
$old_number$ in v_definition) = 0 then
    raise exception 'V1_MATERIAL_REQUEST_NUMBERING_SOURCE_UNEXPECTED';
  end if;

  v_definition := replace(
    v_definition,
    'values (v_project.id, 101, clock_timestamp())',
    'values (v_project.id, 2, clock_timestamp())'
  );
  v_definition := replace(
    v_definition,
    $old_number$
  v_request_number := regexp_replace(
    upper(v_project.project_ref), '[^A-Z0-9]+', '', 'g'
  ) || '-MR' || v_sequence::text;
$old_number$,
    $new_number$
  v_request_number := regexp_replace(
    upper(v_project.project_ref), '[^A-Z0-9]+', '', 'g'
  ) || '-MR' || lpad(v_sequence::text, 3, '0');
$new_number$
  );
  execute v_definition;
end;
$migration$;

revoke all on function public.v1_submit_material_request(jsonb, uuid)
  from public, anon;
grant execute on function public.v1_submit_material_request(jsonb, uuid)
  to authenticated;

commit;
