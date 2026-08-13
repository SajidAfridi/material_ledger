-- Yorks V1 notification delivery and recipient completeness.
--
-- This migration is additive. It does not rewrite existing notifications,
-- workflow rows, quantities, memberships, device tokens or outbox attempts.
-- Trusted workflow/member state changes append safe code-only notification
-- rows; the existing recipient-only projection and durable push outbox remain
-- the only client and transport surfaces.

create or replace function public.v1_expand_global_notification_recipients()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 1 then
    return new;
  end if;

  -- Approval edits and receipt work are actionable for organization-wide
  -- Project Engineer roles even without a membership row.
  if new.event_code in (
    'material_request_approval_required',
    'material_request_updated_for_approval',
    'arrangement_review_required',
    'receipt_review_required'
  ) then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id,
      created_at
    )
    select profile.auth_user_id, new.event_code, new.entity_type, new.entity_id,
      new.project_id, new.created_at
    from public.v1_profiles profile
    join auth.users auth_user on auth_user.id = profile.auth_user_id
    where profile.is_active
      and coalesce(auth_user.raw_app_meta_data ->> 'role', '') in (
        'senior_mechanical_engineer', 'project_manager'
      )
      and not exists (
        select 1 from public.v1_notifications existing
        where existing.recipient_auth_user_id = profile.auth_user_id
          and existing.event_code = new.event_code
          and existing.entity_type = new.entity_type
          and existing.entity_id = new.entity_id
      );
  end if;

  -- A finalized pre-approved arrangement is immediately dispatch-ready. The
  -- Procurement rows remain actionable; the active project team and global
  -- Engineer roles receive the same safe status update for awareness.
  if new.project_id is not null and new.event_code in (
    'arrangement_ready_for_dispatch',
    'arrangement_completed_unavailable'
  ) then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id,
      created_at
    )
    select candidate.auth_user_id, new.event_code, new.entity_type,
      new.entity_id, new.project_id, new.created_at
    from (
      select member.member_auth_user_id as auth_user_id
      from public.v1_project_members member
      where member.project_id = new.project_id
        and member.project_role in ('project_engineer', 'site_engineer')
        and member.effective_from <= clock_timestamp()
        and (member.effective_to is null
          or member.effective_to > clock_timestamp())
      union
      select profile.auth_user_id
      from public.v1_profiles profile
      join auth.users auth_user on auth_user.id = profile.auth_user_id
      where profile.is_active
        and coalesce(auth_user.raw_app_meta_data ->> 'role', '') in (
          'senior_mechanical_engineer', 'project_manager'
        )
    ) candidate
    join public.v1_profiles profile
      on profile.auth_user_id = candidate.auth_user_id
    where profile.is_active
      and not exists (
        select 1 from public.v1_notifications existing
        where existing.recipient_auth_user_id = candidate.auth_user_id
          and existing.event_code = new.event_code
          and existing.entity_type = new.entity_type
          and existing.entity_id = new.entity_id
      );
  end if;
  return new;
end;
$$;

-- Material Return decisions belong to the Engineering submitter. This trigger
-- fires only for the trusted submitted -> confirmed/rejected transition; RLS
-- still denies direct authenticated table updates.
create or replace function public.v1_notify_material_return_decision()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.state = 'submitted' and new.state in ('confirmed', 'rejected')
     and new.state is distinct from old.state
     and new.submitted_by_auth_user_id is not null
     and (auth.uid() is null or new.submitted_by_auth_user_id <> auth.uid()) then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      new.submitted_by_auth_user_id,
      case new.state when 'confirmed' then 'material_return_confirmed'
        else 'material_return_rejected' end,
      'material_return', new.id, new.project_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists v1_material_returns_notify_decision
  on public.v1_material_returns;
create trigger v1_material_returns_notify_decision
after update of state on public.v1_material_returns
for each row execute function public.v1_notify_material_return_decision();

-- Cancellation affects both the requester and Procurement ownership. Exclude
-- the actor and de-duplicate the candidate set before appending notifications.
create or replace function public.v1_notify_material_request_cancelled()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.state = 'cancelled' and new.state is distinct from old.state then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    )
    select candidate.auth_user_id, 'material_request_cancelled',
      'material_request', new.id, new.project_id
    from (
      select new.created_by_auth_user_id as auth_user_id
      union
      select profile.auth_user_id
      from public.v1_profiles profile
      join auth.users auth_user on auth_user.id = profile.auth_user_id
      where profile.is_active
        and coalesce(auth_user.raw_app_meta_data ->> 'role', '') = 'procurement'
    ) candidate
    where auth.uid() is null or candidate.auth_user_id <> auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists v1_material_requests_notify_cancelled
  on public.v1_material_requests;
create trigger v1_material_requests_notify_cancelled
after update of state on public.v1_material_requests
for each row execute function public.v1_notify_material_request_cancelled();

-- New and revoked project assignments are important access events. They point
-- to the project only and contain no project name, commercial value or reason.
create or replace function public.v1_notify_project_membership_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recipient uuid;
  v_event_code text;
  v_project_id uuid;
  v_entity_id uuid;
begin
  if tg_op = 'INSERT' then
    v_recipient := new.member_auth_user_id;
    v_event_code := 'project_member_assigned';
    v_project_id := new.project_id;
    v_entity_id := new.id;
  elsif old.effective_to is null and new.effective_to is not null then
    v_recipient := new.member_auth_user_id;
    v_event_code := 'project_member_revoked';
    v_project_id := new.project_id;
    v_entity_id := new.id;
  else
    return new;
  end if;
  if auth.uid() is null or v_recipient <> auth.uid() then
    insert into public.v1_notifications (
      recipient_auth_user_id, event_code, entity_type, entity_id, project_id
    ) values (
      v_recipient, v_event_code, 'project_member', v_entity_id, v_project_id
    );
  end if;
  return new;
end;
$$;

drop trigger if exists v1_project_members_notify_insert
  on public.v1_project_members;
create trigger v1_project_members_notify_insert
after insert on public.v1_project_members
for each row execute function public.v1_notify_project_membership_change();

drop trigger if exists v1_project_members_notify_revoke
  on public.v1_project_members;
create trigger v1_project_members_notify_revoke
after update of effective_to on public.v1_project_members
for each row execute function public.v1_notify_project_membership_change();

revoke all on function public.v1_expand_global_notification_recipients()
  from public, anon, authenticated;
revoke all on function public.v1_notify_material_return_decision()
  from public, anon, authenticated;
revoke all on function public.v1_notify_material_request_cancelled()
  from public, anon, authenticated;
revoke all on function public.v1_notify_project_membership_change()
  from public, anon, authenticated;
grant execute on function public.v1_expand_global_notification_recipients()
  to service_role;
grant execute on function public.v1_notify_material_return_decision()
  to service_role;
grant execute on function public.v1_notify_material_request_cancelled()
  to service_role;
grant execute on function public.v1_notify_project_membership_change()
  to service_role;

-- Rollback is forward-only: drop the three new transition triggers and restore
-- the earlier global-recipient function definition. Preserve every appended
-- notification, outbox attempt and workflow/audit record; never delete alert
-- history or device tokens to roll back presentation behavior.
