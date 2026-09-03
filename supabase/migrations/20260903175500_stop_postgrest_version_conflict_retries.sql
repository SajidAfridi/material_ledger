-- Yorks application-level optimistic-lock conflicts are not PostgreSQL
-- serialization failures. PostgREST 14.5 retries SQLSTATE 40001 internally,
-- so one stale private-draft delete can otherwise run forever after the HTTP
-- request has gone away.
--
-- Keep the established direct-Postgres and REST response contract intact:
-- direct callers still receive 40001, while PostgREST receives its custom
-- non-retryable envelope and returns HTTP 409 with body code 40001.
--
-- Data preservation: function-only change; no rows, grants, RLS policies or
-- workflow state are changed. Rollback: restore the preceding delete function
-- definition, accepting the PostgREST retry risk until its runtime is upgraded.

create or replace function public.v1_raise_version_conflict(
  p_message text
) returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if nullif(current_setting('request.method', true), '') is not null then
    raise sqlstate 'PGRST' using
      message = jsonb_build_object(
        'code', '40001',
        'message', p_message,
        'details', null,
        'hint', null
      )::text,
      detail = '{"status":409,"headers":{}}';
  end if;

  raise exception '%', p_message using errcode = '40001';
end;
$$;

revoke all on function public.v1_raise_version_conflict(text)
from public, anon, authenticated;

create or replace function public.v1_delete_my_material_request_private_draft(
  p_payload jsonb,
  p_idempotency_key uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_draft_id uuid;
  v_expected integer;
  v_current public.v1_material_request_private_drafts%rowtype;
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload, array['draft_id', 'expected_sync_version'],
    'delete_private_material_request_draft'
  );
  v_draft_id := nullif(btrim(coalesce(p_payload ->> 'draft_id', '')), '')::uuid;
  v_expected := nullif(p_payload ->> 'expected_sync_version', '')::integer;
  if v_draft_id is null or v_expected is null or v_expected < 1
    or auth.uid() is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PRIVATE_DRAFT_DELETE_INVALID' using errcode = '22023';
  end if;
  select * into v_current
  from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = auth.uid()
  for update;
  if not found then
    return jsonb_build_object('draft_id', v_draft_id, 'deleted', true);
  end if;
  if v_current.sync_version <> v_expected then
    perform public.v1_raise_version_conflict(
      'V1_PRIVATE_DRAFT_VERSION_CONFLICT'
    );
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_delete_my_material_request_private_draft', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  delete from public.v1_material_request_private_drafts draft
  where draft.draft_id = v_draft_id and draft.owner_auth_user_id = auth.uid();
  v_response := jsonb_build_object('draft_id', v_draft_id, 'deleted', true);
  perform public.v1_complete_idempotency(
    'v1_delete_my_material_request_private_draft', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

comment on function public.v1_raise_version_conflict(text) is
  'Raises application optimistic-lock conflicts without triggering PostgREST serialization retries.';
