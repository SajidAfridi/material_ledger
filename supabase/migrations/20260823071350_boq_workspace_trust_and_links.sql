-- BOQ workspace trust metadata.
--
-- Data preservation: projection-only change. No BOQ, document, request or
-- audit row is mutated. Rollback is the prior v1_boq_group_projection body
-- from 20260808100023_yorks_v1_r38_scoped_boqs.sql; clients tolerate absent
-- optional count/editor keys.

create or replace function public.v1_boq_group_projection(p_group_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', group_record.id,
    'project_id', group_record.project_id,
    'scope_id', group_record.scope_id,
    'scope_kind', scope_record.scope_kind,
    'scope_code', scope_record.scope_code,
    'scope_name', scope_record.name,
    'is_legacy_unassigned', group_record.scope_id is null,
    'name', group_record.name,
    'worksheet_title', group_record.worksheet_title,
    'display_order', group_record.display_order,
    'is_custom', group_record.is_custom,
    'is_archived', group_record.is_archived,
    'record_version', group_record.record_version,
    'row_count', (
      select count(*) from public.v1_boq_rows row_record
      where row_record.group_id = group_record.id and not row_record.is_archived
    ),
    'column_count', (
      select count(*) from public.v1_boq_columns column_record
      where column_record.group_id = group_record.id
        and not column_record.is_archived
    ),
    'document_count', (
      select count(*)
      from public.v1_document_links link_record
      where link_record.entity_type = 'boq_group'
        and link_record.entity_id = group_record.id
        and link_record.removed_at is null
        and public.v1_document_readable(link_record.document_id)
    ),
    'linked_request_count', (
      select count(distinct line_record.request_id)
      from public.v1_material_request_lines line_record
      where line_record.source_boq_group_id = group_record.id
        and public.v1_material_request_readable(line_record.request_id)
    ),
    'last_edited_by', last_edit.actor_display_name,
    'last_edited_role', last_edit.actor_role,
    'last_edited_at', last_edit.occurred_at,
    'updated_at', group_record.updated_at
  )
  from public.v1_boq_groups group_record
  left join public.v1_project_scopes scope_record
    on scope_record.id = group_record.scope_id
  left join lateral (
    select
      coalesce(
        audit.actor_display_name_snapshot,
        public.v1_safe_profile_display_name(
          null::text,
          audit.actor_auth_user_id
        )
      ) as actor_display_name,
      audit.actor_role,
      audit.occurred_at
    from public.v1_audit_events audit
    where audit.entity_type = 'boq_group'
      and audit.entity_id = group_record.id
    order by audit.occurred_at desc, audit.id desc
    limit 1
  ) last_edit on true
  where group_record.id = p_group_id;
$$;

revoke all on function public.v1_boq_group_projection(uuid)
  from public, anon, authenticated;
