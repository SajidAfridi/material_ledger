-- Preserve the complete Material Request discussion membership contract while
-- keeping arrangement audit events on the no-write fast path. The preceding
-- optimization covered the common missing-Procurement case. This follow-up
-- detects every member delta that the established synchronizer can repair:
-- newly eligible request creators/project members/global engineering roles,
-- active Procurement users, reactivated members and members who are no longer
-- authorized for the request.
--
-- Data preservation: no conversation, message, audit or workflow row is
-- deleted. Existing member preferences and join timestamps remain untouched
-- when the eligible set is already current. On actual drift, the existing
-- trusted synchronizer retains its historical archive/reactivation behavior.
--
-- Rollback: restore v1_chat_audit_event_bridge() from migration
-- 20260928181001. Retain all member and message rows created while this
-- migration is active; they follow the same append-only audit contract.

begin;

do $guard$
declare
  v_definition text := pg_get_functiondef(
    'public.v1_chat_audit_event_bridge()'::regprocedure
  );
begin
  if position(
    'reconcile members only when an active Procurement user is missing' in
      obj_description(
        'public.v1_chat_audit_event_bridge()'::regprocedure,
        'pg_proc'
      )
  ) = 0 or position(
    'v_is_arrangement_event := new.event_type in' in v_definition
  ) = 0 then
    raise exception
      'V1_CHAT_AUDIT_BRIDGE_STALENESS_ANCHOR_MISSING';
  end if;
end;
$guard$;

create or replace function public.v1_chat_audit_event_bridge()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request_id uuid;
  v_conversation_id uuid;
  v_event_code text;
  v_response jsonb;
  v_is_arrangement_event boolean;
  v_members_stale boolean := false;
begin
  if new.event_type in (
    'chat_conversation_created', 'chat_message_sent'
  ) then return new; end if;
  v_event_code := case new.event_type
    when 'material_request_submitted' then 'material_request_submitted'
    when 'material_request_updated_for_approval'
      then 'material_request_updated_for_approval'
    when 'material_request_approved' then 'material_request_approved'
    when 'material_request_returned' then 'material_request_returned'
    when 'arrangement_begun' then 'arrangement_started'
    when 'arrangement_saved' then 'arrangement_saved'
    when 'arrangement_approved' then 'arrangement_approved'
    when 'arrangement_returned' then 'arrangement_returned'
    when 'materials_dispatched' then 'materials_dispatched'
    when 'receipt_review_confirmed' then 'receipt_confirmed'
    when 'material_request_closed' then 'material_request_closed'
    when 'material_request_cancelled' then 'material_request_cancelled'
    else null
  end;
  if v_event_code is null then return new; end if;
  v_request_id := public.v1_resolve_notification_request_id(
    new.entity_type, new.entity_id
  );
  if v_request_id is null and new.entity_type = 'material_request' then
    v_request_id := new.entity_id;
  end if;
  if v_request_id is null then return new; end if;

  v_is_arrangement_event := new.event_type in (
    'arrangement_begun', 'arrangement_saved',
    'arrangement_approved', 'arrangement_returned'
  );

  if v_is_arrangement_event then
    -- Serialize with explicit discussion/team-chat creation so the partial
    -- unique index remains a final invariant rather than an error path.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'chat-request:' || v_request_id::text, 0
      )
    );
    select conversation.id into v_conversation_id
    from public.v1_chat_conversations conversation
    where conversation.kind = 'material_request'
      and conversation.material_request_id = v_request_id;

    if v_conversation_id is not null then
      with request_context as materialized (
        select
          request_record.created_by_auth_user_id,
          request_record.project_id,
          request_record.state
        from public.v1_material_requests request_record
        where request_record.id = v_request_id
      ), candidate as materialized (
        select context.created_by_auth_user_id as auth_user_id
        from request_context context
        union
        select project_member.member_auth_user_id
        from request_context context
        join public.v1_project_members project_member
          on project_member.project_id = context.project_id
        where project_member.effective_from <= clock_timestamp()
          and (
            project_member.effective_to is null
            or project_member.effective_to > clock_timestamp()
          )
        union
        select profile.auth_user_id
        from public.v1_profiles profile
        join auth.users auth_user on auth_user.id = profile.auth_user_id
        where profile.is_active
          and (
            auth_user.banned_until is null
            or auth_user.banned_until <= clock_timestamp()
          )
          and auth_user.raw_app_meta_data ->> 'role' in (
            'admin', 'senior_mechanical_engineer', 'project_manager'
          )
        union
        select profile.auth_user_id
        from request_context context
        join public.v1_profiles profile on profile.is_active
        join auth.users auth_user on auth_user.id = profile.auth_user_id
        where (
            auth_user.banned_until is null
            or auth_user.banned_until <= clock_timestamp()
          )
          and auth_user.raw_app_meta_data ->> 'role' = 'procurement'
          and context.state in (
            'submitted', 'approved_for_arrangement', 'arranging',
            'awaiting_approval', 'approved', 'partially_dispatched',
            'dispatched', 'partially_received', 'received', 'closed',
            'cancelled'
          )
      ), eligible as materialized (
        select candidate.auth_user_id
        from candidate
        join public.v1_profiles profile
          on profile.auth_user_id = candidate.auth_user_id
         and profile.is_active
        join auth.users auth_user on auth_user.id = candidate.auth_user_id
        where (
            auth_user.banned_until is null
            or auth_user.banned_until <= clock_timestamp()
          )
          and auth_user.raw_app_meta_data ->> 'role' in (
            'project_engineer', 'site_engineer',
            'senior_mechanical_engineer', 'project_manager',
            'procurement', 'admin'
          )
      )
      select
        exists (
          select 1
          from eligible
          where not exists (
            select 1
            from public.v1_chat_members member
            where member.conversation_id = v_conversation_id
              and member.auth_user_id = eligible.auth_user_id
              and member.left_at is null
          )
        ) or exists (
          select 1
          from public.v1_chat_members member
          where member.conversation_id = v_conversation_id
            and member.left_at is null
            and not public.v1_material_request_participant(
              v_request_id, member.auth_user_id
            )
        )
      into v_members_stale;

      if v_members_stale then
        perform public.v1_sync_chat_context_members(v_conversation_id);
      end if;
    end if;
  end if;

  if v_conversation_id is null then
    -- Non-arrangement events retain the established membership semantics.
    -- Arrangement events use the same command only for legacy records whose
    -- canonical backing conversation is genuinely absent.
    v_response := public.v1_create_chat_conversation(
      jsonb_build_object(
        'kind', 'material_request',
        'material_request_id', v_request_id,
        'participant_auth_user_ids', '[]'::jsonb
      ),
      gen_random_uuid()
    );
    v_conversation_id := (v_response -> 'conversation' ->> 'id')::uuid;
  end if;

  perform public.v1_append_chat_system_event(
    v_conversation_id, v_event_code, new.id, new.occurred_at
  );
  return new;
exception
  when others then
    -- Chat is a best-effort projection of trusted workflow history. It must
    -- never roll back the workflow/audit command that produced this row.
    return new;
end;
$$;

revoke all on function public.v1_chat_audit_event_bridge()
from public, anon, authenticated;
grant execute on function public.v1_chat_audit_event_bridge()
to postgres, service_role;

comment on function public.v1_chat_audit_event_bridge() is
  'Best-effort audit-to-chat projection. Arrangement events reuse the canonical MR discussion and run the trusted member synchronizer only when a set-wise drift check finds a real membership delta.';

commit;
