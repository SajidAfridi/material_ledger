-- Keep arrangement audit events lightweight when the canonical Material
-- Request discussion already exists. Arrangement transitions do not change
-- chat eligibility, so re-entering v1_create_chat_conversation for every
-- audit event only creates an idempotency claim and rewrites the same member
-- rows. The guarded fast path below reuses the existing conversation and only
-- reconciles members when a currently active Procurement user is missing.
--
-- Data preservation: no conversation, member, message, audit or workflow row
-- is removed or rewritten. The missing-conversation branch deliberately keeps
-- the previous trusted creation command as a legacy-recovery fallback.
--
-- Rollback: restore the preceding v1_chat_audit_event_bridge definition from
-- 20260814114626_yorks_r38_5_team_chat.sql. Retain all rows created while this
-- migration is active; they use the same canonical tables and source-audit
-- uniqueness contract.

begin;

do $guard$
declare
  v_definition text := pg_get_functiondef(
    'public.v1_chat_audit_event_bridge()'::regprocedure
  );
begin
  if position(
    'v_response := public.v1_create_chat_conversation(' in v_definition
  ) = 0 or position(
    'when ''arrangement_begun'' then ''arrangement_started''' in v_definition
  ) = 0 then
    raise exception
      'V1_CHAT_AUDIT_BRIDGE_OPTIMIZATION_ANCHOR_MISSING';
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
      -- Approval/submission normally added all active Procurement users. A
      -- role activated later is the only arrangement-specific recovery case
      -- worth reconciling synchronously; the common path performs no member
      -- writes and preserves every per-user preference timestamp.
      if exists (
        select 1
        from public.v1_profiles profile
        join auth.users auth_user on auth_user.id = profile.auth_user_id
        where profile.is_active
          and (auth_user.banned_until is null
            or auth_user.banned_until <= clock_timestamp())
          and auth_user.raw_app_meta_data ->> 'role' = 'procurement'
          and not exists (
            select 1
            from public.v1_chat_members member
            where member.conversation_id = v_conversation_id
              and member.auth_user_id = profile.auth_user_id
              and member.left_at is null
          )
      ) then
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
  'Best-effort audit-to-chat projection. Arrangement events reuse the canonical MR discussion and reconcile members only when an active Procurement user is missing.';

commit;
