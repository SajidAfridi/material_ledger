-- Yorks scoped capability cutover: core project and material workflows.
--
-- The foundation migration deliberately introduced every capability in
-- shadow mode. This follow-up turns on only the capabilities whose complete
-- normalized V1 server surface is guarded below. Existing project membership,
-- exact-role, workflow-state, separation-of-duty, quantity, commercial,
-- version, locking and idempotency predicates remain mandatory and are
-- combined with (never replaced by) the person-specific capability decision.
--
-- Data preservation: no workflow row is rewritten. Existing role templates
-- preserve the effective access that each exact Yorks role had immediately
-- before this cutover. Person assignments become authoritative only for the
-- explicitly listed capability keys.
--
-- Rollback: in a corrective forward migration, set the listed catalog rows
-- back to `shadow` and restore the prior helper definitions. Never remove the
-- assignment or immutable permission/audit history created during operation.

begin;

-- A reusable private invalidation primitive makes the cutover's Realtime
-- consequence directly testable. Production already has active profiles when
-- this migration runs; clean local resets seed their personas afterwards.
create or replace function public.v1_invalidate_active_permission_snapshots()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  update public.v1_permission_revisions revision
  set revision = revision.revision + 1,
      updated_by_auth_user_id = null,
      updated_at = clock_timestamp()
  from public.v1_profiles profile
  where profile.auth_user_id = revision.auth_user_id
    and profile.is_active;
  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

-- Preserve the pre-capability Engineering project boundary as a separate hard
-- predicate. Create, edit and submit intentionally call this predicate with
-- different capability keys; denying one named action must not accidentally
-- deny another. Organization-wide Engineering roles are explicit here rather
-- than relying on canonical-role normalization plus a membership side effect.
create or replace function public.v1_material_request_engineering_project_access(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_exact_role();
  v_project_state text;
begin
  if v_actor is null
    or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;

  select project.state into v_project_state
  from public.v1_projects project
  where project.id = p_project_id;
  if v_project_state not in ('draft', 'active') then
    return false;
  end if;

  if v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    ) then
    return true;
  end if;

  return v_exact_role in ('project_engineer', 'site_engineer')
    and public.v1_has_active_project_membership(
      p_project_id, v_actor, null
    );
end;
$$;

-- Project reads are centralized through this predicate, including project
-- RLS and every normalized project-context projection. The capability resolver
-- separately re-checks membership/global-role access, so a grant cannot create
-- project access by itself.
create or replace function public.v1_project_readable(p_project_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_exact_role();
  v_state text;
  v_legacy_allowed boolean := false;
begin
  if v_actor is null
    or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;

  if v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    ) then
    v_legacy_allowed := exists (
      select 1 from public.v1_projects project
      where project.id = p_project_id
    );
  elsif v_exact_role in ('project_engineer', 'site_engineer') then
    v_legacy_allowed := public.v1_has_active_project_membership(
      p_project_id, v_actor, null
    );
  elsif v_exact_role = 'procurement' then
    select project.state into v_state
    from public.v1_projects project
    where project.id = p_project_id;
    v_legacy_allowed := v_state in ('active', 'on_hold');
  end if;

  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'projects.view', p_project_id
    );
end;
$$;

create or replace function public.v1_can_edit_project(p_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when auth.uid() is null
      or public.v1_current_exact_role() = ''
      or not public.v1_current_actor_is_active()
      then false
    when public.v1_current_exact_role() = 'admin'
      or public.v1_current_exact_role() in (
        'senior_mechanical_engineer', 'project_manager',
        'workshop_in_charge', 'document_controller'
      ) then
      public.v1_current_user_has_capability('projects.edit', p_project_id)
    when public.v1_current_exact_role() in (
      'project_engineer', 'site_engineer'
    ) then
      public.v1_has_active_project_membership(
        p_project_id, auth.uid(), null
      ) and public.v1_current_user_has_capability(
        'projects.edit', p_project_id
      )
    else false
  end;
$$;

-- All normalized BOQ mutation commands converge on this helper. Commercial
-- response/write boundaries remain separate and continue to be enforced by
-- the existing commercial capability relation.
create or replace function public.v1_can_edit_boq_project(p_project_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_exact_role text := public.v1_current_exact_role();
  v_legacy_allowed boolean := false;
begin
  if v_actor is null
    or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    ) then
    v_legacy_allowed := true;
  elsif v_exact_role in ('project_engineer', 'site_engineer') then
    v_legacy_allowed := public.v1_has_active_project_membership(
      p_project_id, v_actor, null
    );
  end if;
  return v_legacy_allowed
    and public.v1_current_user_has_capability('boq.edit', p_project_id);
end;
$$;

-- Request participation is used both for the current caller and for trusted
-- mention/notification recipient expansion. Resolve the target user's live
-- server identity directly rather than borrowing the caller's JWT.
create or replace function public.v1_material_request_participant(
  p_request_id uuid,
  p_auth_user_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_exact_role text;
  v_has_view boolean := false;
begin
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;

  if not found or p_auth_user_id is null or not exists (
    select 1 from public.v1_profiles profile
    where profile.auth_user_id = p_auth_user_id and profile.is_active
  ) then
    return false;
  end if;

  v_has_view := coalesce((
    public.v1_permission_authoritative_resolution(
      p_auth_user_id, 'material_requests.view', v_request.project_id
    ) ->> 'effective'
  )::boolean, false);
  if not v_has_view then
    return false;
  end if;

  select coalesce(user_record.raw_app_meta_data ->> 'role', '')
    into v_exact_role
  from auth.users user_record
  where user_record.id = p_auth_user_id;

  if v_exact_role = 'admin' then
    return true;
  end if;
  if v_request.state = 'draft' then
    return v_request.created_by_auth_user_id = p_auth_user_id;
  end if;
  if v_exact_role in (
    'senior_mechanical_engineer', 'project_manager',
    'workshop_in_charge', 'document_controller'
  ) then
    return true;
  end if;
  if v_exact_role in ('project_engineer', 'site_engineer') then
    return exists (
      select 1 from public.v1_project_members member
      where member.project_id = v_request.project_id
        and member.member_auth_user_id = p_auth_user_id
        and member.effective_from <= clock_timestamp()
        and (
          member.effective_to is null
          or member.effective_to > clock_timestamp()
        )
    );
  end if;
  if v_exact_role = 'procurement' then
    return v_request.state in (
      'submitted', 'approved_for_arrangement', 'arranging',
      'awaiting_approval', 'approved', 'partially_dispatched',
      'dispatched', 'partially_received', 'received', 'closed', 'cancelled'
    );
  end if;
  return false;
end;
$$;

create or replace function public.v1_can_create_material_request(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
begin
  return public.v1_material_request_engineering_project_access(p_project_id)
    and public.v1_current_user_has_capability(
      'material_requests.create', p_project_id
    );
end;
$$;

create or replace function public.v1_can_edit_material_request_before_approval(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_exact_role text := public.v1_current_exact_role();
  v_legacy_allowed boolean := false;
begin
  if auth.uid() is null
    or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;

  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found
    or v_request.state not in (
      'awaiting_request_approval', 'changes_requested'
    )
    or exists (
      select 1 from public.v1_procurement_arrangements arrangement
      where arrangement.request_id = p_request_id
    ) then
    return false;
  end if;

  if v_request.created_by_auth_user_id = auth.uid() then
    v_legacy_allowed := true;
  elsif v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    ) then
    v_legacy_allowed := true;
  elsif v_exact_role = 'project_engineer' then
    v_legacy_allowed := public.v1_has_active_project_membership(
      v_request.project_id, auth.uid(), 'project_engineer'
    );
  end if;

  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'material_requests.edit', v_request.project_id
    );
end;
$$;

-- The existing UI exposes one decision affordance, while the transaction
-- accepts two distinct actions. This predicate reports whether at least one
-- action is available; the command below still guards the selected action.
create or replace function public.v1_can_decide_material_request(
  p_request_id uuid
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_request public.v1_material_requests%rowtype;
  v_exact_role text := public.v1_current_exact_role();
  v_allow_self boolean := public.v1_material_request_published_policy_boolean(
    'requests.allow_authorized_creator_self_approval', true
  );
  v_legacy_allowed boolean;
begin
  if auth.uid() is null
    or v_exact_role not in (
      'project_engineer', 'site_engineer',
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller', 'admin'
    )
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if not found then
    return false;
  end if;
  if not v_allow_self and v_request.created_by_auth_user_id = auth.uid() then
    return false;
  end if;
  v_legacy_allowed := v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or (
      v_exact_role = 'project_engineer'
      and public.v1_has_active_project_membership(
        v_request.project_id, auth.uid(), 'project_engineer'
      )
    )
    or (
      -- A Site Engineer account does not inherit approval from its base role.
      -- It becomes structurally eligible only while it holds the project's
      -- explicit, dated Project Engineer membership; the person capability
      -- decision below remains independently mandatory.
      v_exact_role = 'site_engineer'
      and public.v1_has_active_project_membership(
        v_request.project_id, auth.uid(), 'project_engineer'
      )
    );
  return v_legacy_allowed and (
    public.v1_current_user_has_capability(
      'material_requests.approve', v_request.project_id
    )
    or public.v1_current_user_has_capability(
      'material_requests.return_for_changes', v_request.project_id
    )
  );
end;
$$;

create or replace function public.v1_can_close_material_request(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_exact_role text := public.v1_current_exact_role();
  v_legacy_allowed boolean := false;
begin
  if auth.uid() is null
    or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select request_record.project_id into v_project_id
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if v_project_id is null then
    return false;
  end if;
  if v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    ) then
    v_legacy_allowed := true;
  elsif v_exact_role = 'project_engineer' then
    v_legacy_allowed := public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'project_engineer'
    );
  elsif v_exact_role = 'site_engineer' then
    v_legacy_allowed := public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'site_engineer'
    );
  end if;
  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'material_requests.close', v_project_id
    );
end;
$$;

create or replace function public.v1_can_arrange_material_request(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text := public.v1_current_exact_role();
  v_project_id uuid;
  v_project_state text;
begin
  if auth.uid() is null
    or v_exact_role not in ('procurement', 'admin')
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select request_record.project_id, project.state
    into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  return v_project_state in ('active', 'on_hold')
    and public.v1_current_user_has_capability(
      'procurement.arrange', v_project_id
    );
end;
$$;

create or replace function public.v1_can_dispatch_material_request(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
begin
  if not public.v1_can_manage_inventory() then
    return false;
  end if;
  select request_record.project_id, project.state
    into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  return v_project_state = 'active'
    and public.v1_current_user_has_capability(
      'dispatch.create', v_project_id
    );
end;
$$;

create or replace function public.v1_can_confirm_material_receipt(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_exact_role text := public.v1_current_exact_role();
  v_project_id uuid;
  v_project_state text;
  v_legacy_allowed boolean := false;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select request_record.project_id, project.state
    into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  if v_project_id is null
    or v_project_state not in ('active', 'on_hold', 'completed') then
    return false;
  end if;
  v_legacy_allowed := v_exact_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or (
      v_exact_role in ('project_engineer', 'site_engineer')
      and public.v1_has_active_project_membership(
        v_project_id, auth.uid(), null
      )
    );
  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'receipts.confirm', v_project_id
    );
end;
$$;

create or replace function public.v1_can_generate_delivery_order(
  p_request_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_project_id uuid;
  v_project_state text;
  v_exact_role text := public.v1_current_exact_role();
  v_legacy_allowed boolean := false;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select request_record.project_id, project.state
    into v_project_id, v_project_state
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  where request_record.id = p_request_id;
  if v_project_id is null
    or v_project_state not in ('active', 'on_hold', 'completed')
    or not exists (
      select 1
      from public.v1_material_dispatches dispatch
      where dispatch.request_id = p_request_id
        and dispatch.state in (
          'dispatched', 'receipt_pending', 'partially_received', 'received'
        )
    ) then
    return false;
  end if;
  v_legacy_allowed := v_exact_role in ('procurement', 'admin')
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or (
      v_exact_role in ('project_engineer', 'site_engineer')
      and public.v1_has_active_project_membership(
        v_project_id, auth.uid(), null
      )
    );
  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'delivery_orders.generate', v_project_id
    );
end;
$$;

-- Controlled Material Returns retain their existing project/state/role
-- predicates. Dispatch gets its own compatibility helper so the create and
-- dispatch capabilities can be changed independently without weakening either.
create or replace function public.v1_can_create_project_material_return(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
  v_state text;
  v_legacy_allowed boolean;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'site_engineer', 'admin') then
    return false;
  end if;
  select project.state into v_state
  from public.v1_projects project where project.id = p_project_id;
  v_legacy_allowed := v_state in ('active', 'on_hold', 'completed') and (
    v_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or public.v1_has_active_project_membership(
      p_project_id, auth.uid(), null
    )
  );
  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'returns.create', p_project_id
    );
end;
$$;

create or replace function public.v1_can_approve_project_material_return(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
  v_legacy_allowed boolean;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'admin') then
    return false;
  end if;
  v_legacy_allowed := v_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or public.v1_has_active_project_membership(
      p_project_id, auth.uid(), null
    );
  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'returns.approve', p_project_id
    );
end;
$$;

create or replace function public.v1_can_dispatch_project_material_return(
  p_project_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_role text := public.v1_current_role();
  v_exact_role text := public.v1_current_exact_role();
  v_state text;
  v_legacy_allowed boolean;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active()
    or v_role not in ('project_engineer', 'site_engineer', 'admin') then
    return false;
  end if;
  select project.state into v_state
  from public.v1_projects project where project.id = p_project_id;
  v_legacy_allowed := v_state in ('active', 'on_hold', 'completed') and (
    v_role = 'admin'
    or v_exact_role in (
      'senior_mechanical_engineer', 'project_manager',
      'workshop_in_charge', 'document_controller'
    )
    or public.v1_has_active_project_membership(
      p_project_id, auth.uid(), null
    )
  );
  return v_legacy_allowed
    and public.v1_current_user_has_capability(
      'returns.dispatch', p_project_id
    );
end;
$$;

create or replace function public.v1_material_return_readable(
  p_return_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.v1_material_returns material_return
    where material_return.id = p_return_id
      and public.v1_project_readable(material_return.project_id)
      and public.v1_current_user_has_capability(
        'returns.view', material_return.project_id
      )
  );
$$;

-- Inject granular guards into the few commands whose legacy authorization was
-- intentionally action-specific rather than centralized in a reusable helper.
do $project_create_guard$
declare
  v_definition text;
  v_updated text;
  v_anchor text := E'  v_existing_response := public.v1_idempotency_get_or_claim(';
  v_replacement text := E'  if not public.v1_current_user_has_capability(\n    ''projects.create'', null\n  ) then\n    raise exception ''V1_PROJECT_CREATE_DENIED'' using errcode = ''42501'';\n  end if;\n\n  v_existing_response := public.v1_idempotency_get_or_claim(';
begin
  v_definition := pg_get_functiondef(
    'public.v1_create_project(jsonb,uuid)'::regprocedure
  );
  if position('projects.create' in v_definition) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_CREATE_PROJECT_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$project_create_guard$;

-- Project-state and team-management authorization still has one legacy
-- exception that the role-template model cannot yet express: an exact Site
-- Engineer may hold a dated project_engineer membership. Keep those consumers
-- entirely legacy-authoritative and their named capabilities in shadow until
-- that membership-role predicate is represented by the resolver.
--
-- No rewrite is applied to v1_assign_project_member,
-- v1_revoke_project_member or v1_set_project_state in this cutover.

do $project_archive_guard$
declare
  v_definition text;
  v_updated text;
  v_anchor text := 'select * into v_project from public.v1_projects project';
  v_replacement text := E'if not public.v1_current_user_has_capability(\n    ''projects.archive'', v_project_id\n  ) then\n    raise exception ''V1_PROJECT_ARCHIVE_DENIED'' using errcode = ''42501'';\n  end if;\n  select * into v_project from public.v1_projects project';
begin
  v_definition := pg_get_functiondef(
    'public.v1_archive_project(jsonb,uuid)'::regprocedure
  );
  if position('projects.archive' in v_definition) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_ARCHIVE_PROJECT_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$project_archive_guard$;

do $boq_read_guards$
declare
  v_rule record;
  v_definition text;
  v_updated text;
begin
  for v_rule in select * from (values
    (
      'public.v1_list_boq_groups(uuid)',
      'if not public.v1_project_readable(p_project_id) then',
      'if not public.v1_project_readable(p_project_id) or not ' ||
        'public.v1_current_user_has_capability(''boq.view'', p_project_id) then'
    ),
    (
      'public.v1_list_boq_groups_for_scope(uuid,uuid)',
      'if not public.v1_project_readable(p_project_id) then',
      'if not public.v1_project_readable(p_project_id) or not ' ||
        'public.v1_current_user_has_capability(''boq.view'', p_project_id) then'
    ),
    (
      'public.v1_get_boq_worksheet(uuid)',
      'if not found or not public.v1_project_readable(v_group.project_id) then',
      'if not found or not public.v1_project_readable(v_group.project_id) ' ||
        'or not public.v1_current_user_has_capability(' ||
        '''boq.view'', v_group.project_id) then'
    )
  ) as rule(signature, anchor, replacement)
  loop
    v_definition := pg_get_functiondef(v_rule.signature::regprocedure);
    if position('boq.view' in v_definition) = 0 then
      v_updated := replace(v_definition, v_rule.anchor, v_rule.replacement);
      if v_updated = v_definition then
        raise exception 'V1_CAPABILITY_CUTOVER_BOQ_READ_ANCHOR_MISSING: %',
          v_rule.signature;
      end if;
      execute v_updated;
    end if;
  end loop;
end;
$boq_read_guards$;

-- The only directly readable BOQ tables are the folder shell and catalog.
-- All worksheet row/column tables remain RPC-only with no authenticated grant.
drop policy if exists v1_boq_group_templates_select_authenticated
  on public.v1_boq_group_templates;
create policy v1_boq_group_templates_select_authenticated
on public.v1_boq_group_templates
for select
to authenticated
using (
  (select public.v1_rls_current_actor_is_active())
  and (select public.v1_current_user_has_capability('boq.view', null))
);

drop policy if exists v1_boq_groups_select_authorized
  on public.v1_boq_groups;
create policy v1_boq_groups_select_authorized
on public.v1_boq_groups
for select
to authenticated
using (
  (select public.v1_project_readable(project_id))
  and (select public.v1_current_user_has_capability('boq.view', project_id))
);

-- The legacy draft command used the create predicate before it knew whether
-- the client ID referred to an existing draft. Move authorization after the
-- locked lookup so new draft creation and owner-only draft editing are truly
-- independent actions.
do $material_request_draft_guard$
declare
  v_definition text;
  v_updated text;
  v_early_guard text := E'  if not public.v1_can_create_material_request(v_project_id) then\n    raise exception ''V1_MATERIAL_REQUEST_DRAFT_DENIED'' using errcode = ''42501'';\n  end if;\n';
  v_found_anchor text := '  v_request_exists := found;';
  v_found_replacement text := E'  v_request_exists := found;\n  if v_request_exists then\n    if not public.v1_material_request_engineering_project_access(v_project_id)\n      or not public.v1_current_user_has_capability(\n        ''material_requests.edit'', v_project_id\n      ) then\n      raise exception ''V1_MATERIAL_REQUEST_DRAFT_EDIT_DENIED''\n        using errcode = ''42501'';\n    end if;\n  elsif not public.v1_can_create_material_request(v_project_id) then\n    raise exception ''V1_MATERIAL_REQUEST_DRAFT_DENIED''\n      using errcode = ''42501'';\n  end if;';
begin
  v_definition := pg_get_functiondef(
    'public.v1_save_material_request_draft(jsonb)'::regprocedure
  );
  if position('material_requests.edit' in v_definition) = 0 then
    v_updated := replace(v_definition, v_early_guard, '');
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_MR_DRAFT_EARLY_GUARD_MISSING';
    end if;
    v_definition := v_updated;
    v_updated := replace(v_definition, v_found_anchor, v_found_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_MR_DRAFT_FOUND_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$material_request_draft_guard$;

do $material_request_submit_guard$
declare
  v_definition text;
  v_updated text;
  v_anchor text := 'or not public.v1_can_create_material_request(v_project.id) then';
  v_replacement text := E'or not public.v1_material_request_engineering_project_access(v_project.id)\n    or not public.v1_current_user_has_capability(\n      ''material_requests.submit'', v_project.id\n    ) then';
begin
  v_definition := pg_get_functiondef(
    'public.v1_submit_material_request(jsonb,uuid)'::regprocedure
  );
  if position('material_requests.submit' in v_definition) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_MR_SUBMIT_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$material_request_submit_guard$;

do $material_request_decision_guard$
declare
  v_definition text;
  v_updated text;
  v_anchor text := 'if not found or not public.v1_can_decide_material_request(v_request_id) then';
  v_replacement text := E'if not found\n    or not public.v1_can_decide_material_request(v_request_id)\n    or not public.v1_current_user_has_capability(\n      case when v_decision = ''approved''\n        then ''material_requests.approve''\n        else ''material_requests.return_for_changes'' end,\n      v_request.project_id\n    ) then';
begin
  v_definition := pg_get_functiondef(
    'public.v1_decide_material_request(jsonb,uuid)'::regprocedure
  );
  if position('material_requests.return_for_changes' in v_definition) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_MR_DECISION_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$material_request_decision_guard$;

-- The immutable decision stores both the actor's exact organization role and
-- the project capacity used for the decision. A Site Engineer who is allowed
-- through the dated Project Engineer membership path must therefore be
-- attributed as Project Engineer in `decided_by_role`, while retaining
-- `site_engineer` in `decided_by_exact_role`.
do $material_request_site_project_engineer_attribution$
declare
  v_definition text;
  v_updated text;
  v_anchor text :=
    'public.v1_current_role(), v_exact_role, v_display_name';
  v_replacement text := E'case when v_exact_role = ''site_engineer''\n'
    || E'      then ''project_engineer'' else public.v1_current_role() end,\n'
    || E'    v_exact_role, v_display_name';
begin
  v_definition := pg_get_functiondef(
    'public.v1_decide_material_request(jsonb,uuid)'::regprocedure
  );
  if position(
    'case when v_exact_role = ''site_engineer''' in v_definition
  ) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception
        'V1_CAPABILITY_CUTOVER_MR_SITE_PE_ATTRIBUTION_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$material_request_site_project_engineer_attribution$;

do $material_request_cancel_guard$
declare
  v_definition text;
  v_updated text;
  v_anchor text := 'if public.v1_current_role() <> ''admin'' and not (';
  v_replacement text := E'if not public.v1_current_user_has_capability(\n    ''material_requests.cancel'', v_request.project_id\n  ) then\n    raise exception ''V1_MATERIAL_REQUEST_CANCEL_DENIED'' using errcode = ''42501'';\n  end if;\n  if public.v1_current_role() <> ''admin'' and not (';
begin
  v_definition := pg_get_functiondef(
    'public.v1_cancel_material_request(jsonb,uuid)'::regprocedure
  );
  if position('material_requests.cancel' in v_definition) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_MR_CANCEL_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$material_request_cancel_guard$;

do $material_return_dispatch_guard$
declare
  v_definition text;
  v_updated text;
  v_anchor text := 'not public.v1_can_create_project_material_return(v_return.project_id)';
  v_replacement text := 'not public.v1_can_dispatch_project_material_return(v_return.project_id)';
begin
  v_definition := pg_get_functiondef(
    'public.v1_dispatch_project_material_return(jsonb,uuid)'::regprocedure
  );
  if position('v1_can_dispatch_project_material_return' in v_definition) = 0 then
    v_updated := replace(v_definition, v_anchor, v_replacement);
    if v_updated = v_definition then
      raise exception 'V1_CAPABILITY_CUTOVER_RETURN_DISPATCH_ANCHOR_MISSING';
    end if;
    execute v_updated;
  end if;
end;
$material_return_dispatch_guard$;

-- Keep the new compatibility helper private. Replaced functions retain their
-- existing explicit ACLs; CREATE OR REPLACE does not broaden them.
revoke all on function public.v1_material_request_engineering_project_access(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_material_request_engineering_project_access(uuid)
  to service_role;

revoke all on function public.v1_can_dispatch_project_material_return(uuid)
  from public, anon, authenticated;
grant execute on function public.v1_can_dispatch_project_material_return(uuid)
  to service_role;

-- Guard coverage above is complete for exactly these keys. Fine-grained
-- capabilities whose current runtime combines multiple actions remain shadow
-- until their RPC/projection response shapes are split in a later cutover.
do $enable_core_capabilities$
declare
  v_keys constant text[] := array[
    'projects.view', 'projects.create', 'projects.edit',
    'projects.archive',
    'boq.view', 'boq.edit',
    'material_requests.view', 'material_requests.create',
    'material_requests.edit', 'material_requests.submit',
    'material_requests.approve',
    'material_requests.return_for_changes', 'material_requests.cancel',
    'material_requests.close', 'procurement.arrange', 'dispatch.create',
    'delivery_orders.generate', 'receipts.confirm', 'returns.view',
    'returns.create', 'returns.approve', 'returns.dispatch'
  ]::text[];
  v_updated integer;
begin
  perform public.v1_assert_permission_cutover_parity(v_keys);
  update public.v1_capability_catalog catalog
  set authorization_mode = 'enforced'
  where catalog.capability_key = any(v_keys)
    and catalog.status = 'operational';
  get diagnostics v_updated = row_count;
  if v_updated <> cardinality(v_keys) then
    raise exception 'V1_CAPABILITY_CUTOVER_CATALOG_MISMATCH: expected %, updated %',
      cardinality(v_keys), v_updated;
  end if;
end;
$enable_core_capabilities$;

-- Authorization-mode changes must invalidate every open active-user snapshot.
-- One set-based bump preserves monotonicity while ensuring this migration
-- advances each active user exactly once, regardless of role or assignment.
select public.v1_invalidate_active_permission_snapshots();

revoke all on function public.v1_invalidate_active_permission_snapshots()
  from public, anon, authenticated;
grant execute on function public.v1_invalidate_active_permission_snapshots()
  to service_role;

commit;
