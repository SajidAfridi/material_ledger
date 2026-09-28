-- Replace the scalar permission check introduced by 20260929110000 with one
-- set-wise resolution of the two capabilities that govern Material Request
-- participation. This preserves the exact enforced/shadow assignment
-- precedence for projects.view and material_requests.view, including scoped
-- overrides, without recursively resolving permissions once per chat member.
--
-- Data preservation: this only replaces a trigger function. No conversation,
-- membership, preference, message, audit or workflow row is rewritten.
--
-- Rollback: restore v1_chat_audit_event_bridge() from migration
-- 20260929110000. Retain all rows produced while this definition is active.

begin;

do $guard$
declare
  v_definition text := pg_get_functiondef(
    'public.v1_chat_audit_event_bridge()'::regprocedure
  );
begin
  if position(
    'public.v1_material_request_participant(' in v_definition
  ) = 0 or not exists (
    select 1
    from public.v1_capability_catalog catalog
    where catalog.capability_key = 'material_requests.view'
      and catalog.dependencies = array['projects.view']::text[]
  ) then
    raise exception
      'V1_CHAT_AUDIT_BRIDGE_SETWISE_ANCHOR_MISSING';
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
          request_record.state,
          request_record.post_approval_amendment_pending,
          request_record.post_approval_edit_enabled,
          request_record.procurement_role_edit_enabled,
          request_record.procurement_editor_auth_user_id,
          project.state as project_state
        from public.v1_material_requests request_record
        join public.v1_projects project
          on project.id = request_record.project_id
        where request_record.id = v_request_id
      ), insertion_candidate as materialized (
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
      ), candidate as materialized (
        select insertion_candidate.auth_user_id, true as insertable
        from insertion_candidate
        union all
        select member.auth_user_id, false
        from public.v1_chat_members member
        where member.conversation_id = v_conversation_id
          and member.left_at is null
      ), actor as materialized (
        select
          candidate.auth_user_id,
          bool_or(
            candidate.insertable and (
              auth_user.banned_until is null
              or auth_user.banned_until <= clock_timestamp()
            )
          ) as insertable,
          auth_user.raw_app_meta_data ->> 'role' as exact_role,
          context.*,
          case
            when auth_user.raw_app_meta_data ->> 'role' in (
              'admin', 'senior_mechanical_engineer', 'project_manager',
              'workshop_in_charge', 'document_controller'
            ) then true
            when auth_user.raw_app_meta_data ->> 'role' = 'procurement'
              then context.project_state in ('active', 'on_hold')
            else exists (
              select 1
              from public.v1_project_members project_member
              where project_member.project_id = context.project_id
                and project_member.member_auth_user_id =
                  candidate.auth_user_id
                and project_member.effective_from <= clock_timestamp()
                and (
                  project_member.effective_to is null
                  or project_member.effective_to > clock_timestamp()
                )
            )
          end as has_project_access
        from candidate
        cross join request_context context
        join public.v1_profiles profile
          on profile.auth_user_id = candidate.auth_user_id
         and profile.is_active
        join auth.users auth_user on auth_user.id = candidate.auth_user_id
        group by
          candidate.auth_user_id,
          auth_user.raw_app_meta_data,
          auth_user.banned_until,
          context.created_by_auth_user_id,
          context.project_id,
          context.state,
          context.post_approval_amendment_pending,
          context.post_approval_edit_enabled,
          context.procurement_role_edit_enabled,
          context.procurement_editor_auth_user_id,
          context.project_state
      ), capability_effect as materialized (
        select
          actor.auth_user_id,
          actor.insertable,
          actor.exact_role,
          actor.created_by_auth_user_id,
          actor.project_id,
          actor.state,
          actor.post_approval_amendment_pending,
          actor.post_approval_edit_enabled,
          actor.procurement_role_edit_enabled,
          actor.procurement_editor_auth_user_id,
          actor.has_project_access,
          catalog.capability_key,
          case
            when catalog.status <> 'operational' then false
            when catalog.requires_project_access
              and not actor.has_project_access then false
            when catalog.authorization_mode = 'enforced'
              and managed.effect is not null
              then managed.effect = 'grant'
            when legacy.effect is not null then legacy.effect = 'grant'
            else coalesce(role_default.is_granted, false)
          end as is_granted
        from actor
        join public.v1_capability_catalog catalog
          on catalog.capability_key in (
            'projects.view', 'material_requests.view'
          )
        left join public.v1_permission_role_defaults role_default
          on role_default.role_name = actor.exact_role
         and role_default.capability_key = catalog.capability_key
        left join lateral (
          select assignment.effect
          from public.v1_permission_assignments assignment
          where assignment.auth_user_id = actor.auth_user_id
            and assignment.capability_key = catalog.capability_key
            and assignment.origin = 'permission_management'
            and assignment.effective_from <= clock_timestamp()
            and (
              assignment.effective_until is null
              or assignment.effective_until > clock_timestamp()
            )
            and (
              assignment.scope_kind = 'organization'
              or (
                assignment.scope_kind = 'project'
                and exists (
                  select 1
                  from public.v1_permission_assignment_projects scoped
                  where scoped.assignment_id = assignment.id
                    and scoped.project_id = actor.project_id
                )
              )
            )
          order by
            case assignment.scope_kind when 'project' then 0 else 1 end,
            case assignment.effect when 'deny' then 0 else 1 end
          limit 1
        ) managed on true
        left join lateral (
          select assignment.effect
          from public.v1_permission_assignments assignment
          where assignment.auth_user_id = actor.auth_user_id
            and assignment.capability_key = catalog.capability_key
            and assignment.origin <> 'permission_management'
            and assignment.effective_from <= clock_timestamp()
            and (
              assignment.effective_until is null
              or assignment.effective_until > clock_timestamp()
            )
            and (
              assignment.scope_kind = 'organization'
              or (
                assignment.scope_kind = 'project'
                and exists (
                  select 1
                  from public.v1_permission_assignment_projects scoped
                  where scoped.assignment_id = assignment.id
                    and scoped.project_id = actor.project_id
                )
              )
            )
          order by
            case assignment.scope_kind when 'project' then 0 else 1 end,
            case assignment.effect when 'deny' then 0 else 1 end
          limit 1
        ) legacy on true
      ), authorized_actor as materialized (
        select
          effect.auth_user_id,
          bool_or(effect.insertable) and effect.exact_role in (
            'project_engineer', 'site_engineer',
            'senior_mechanical_engineer', 'project_manager',
            'procurement', 'admin'
          ) as insertable,
          bool_and(effect.is_granted) and case
            when effect.exact_role = 'admin' then true
            when effect.state = 'draft' then
              effect.created_by_auth_user_id = effect.auth_user_id
            when effect.exact_role in (
              'senior_mechanical_engineer', 'project_manager',
              'workshop_in_charge', 'document_controller'
            ) then true
            when effect.exact_role in (
              'project_engineer', 'site_engineer'
            ) then effect.has_project_access
            when effect.exact_role = 'procurement' then
              effect.state in (
                'submitted', 'approved_for_arrangement', 'arranging',
                'awaiting_approval', 'approved', 'partially_dispatched',
                'dispatched', 'partially_received', 'received', 'closed',
                'cancelled'
              ) or (
                effect.post_approval_amendment_pending
                and effect.post_approval_edit_enabled
                and (
                  effect.procurement_role_edit_enabled
                  or effect.procurement_editor_auth_user_id =
                    effect.auth_user_id
                )
                and effect.state in (
                  'awaiting_request_approval', 'changes_requested'
                )
                and not exists (
                  select 1
                  from public.v1_procurement_arrangements arrangement
                  where arrangement.request_id = v_request_id
                )
              )
            else false
          end as is_authorized
        from capability_effect effect
        group by
          effect.auth_user_id,
          effect.exact_role,
          effect.state,
          effect.created_by_auth_user_id,
          effect.has_project_access,
          effect.post_approval_amendment_pending,
          effect.post_approval_edit_enabled,
          effect.procurement_role_edit_enabled,
          effect.procurement_editor_auth_user_id
      )
      select
        exists (
          select 1
          from authorized_actor authorized
          where authorized.insertable
            and authorized.is_authorized
            and not exists (
              select 1
              from public.v1_chat_members member
              where member.conversation_id = v_conversation_id
                and member.auth_user_id = authorized.auth_user_id
                and member.left_at is null
            )
        ) or exists (
          select 1
          from public.v1_chat_members member
          where member.conversation_id = v_conversation_id
            and member.left_at is null
            and not exists (
              select 1
              from authorized_actor authorized
              where authorized.auth_user_id = member.auth_user_id
                and authorized.is_authorized
            )
        )
      into v_members_stale;

      if v_members_stale then
        perform public.v1_sync_chat_context_members(v_conversation_id);
      end if;
    end if;
  end if;

  if v_conversation_id is null then
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
    return new;
end;
$$;

revoke all on function public.v1_chat_audit_event_bridge()
from public, anon, authenticated;
grant execute on function public.v1_chat_audit_event_bridge()
to postgres, service_role;

comment on function public.v1_chat_audit_event_bridge() is
  'Best-effort audit-to-chat projection. Arrangement events reuse the canonical MR discussion and resolve membership drift set-wise before invoking the trusted synchronizer.';

commit;
