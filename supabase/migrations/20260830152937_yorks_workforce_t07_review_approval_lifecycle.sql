-- Yorks Workforce T07: protected monthly review and approval lifecycle.
--
-- Additive and data-preserving. T01-T06 facts and validation runs remain the
-- authority. This slice adds immutable lifecycle/revision/snapshot evidence,
-- fail-closed command boundaries and a transaction-scoped reviewer-correction
-- bridge into the accepted T03-T05 writers.

begin;

alter table public.v1_workforce_monthly_periods
  drop constraint if exists v1_workforce_monthly_periods_current_status_check;
alter table public.v1_workforce_monthly_periods
  add constraint v1_workforce_monthly_periods_current_status_check check (
    current_status in (
      'draft', 'ready_for_review', 'submitted', 'under_review',
      'returned_for_correction', 'awaiting_final_approval', 'locked',
      'reopened'
    )
  ),
  add column current_approval_revision_number bigint not null default 0
    check (current_approval_revision_number >= 0),
  add column current_edit_scope_id uuid;

create table public.v1_workforce_monthly_approval_revisions (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  revision_number bigint not null check (revision_number > 0),
  opened_from_snapshot_id uuid,
  opened_reason text not null check (
    btrim(opened_reason) <> '' and char_length(opened_reason) <= 2000
  ),
  opened_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  opened_by_exact_role text not null,
  opened_at timestamptz not null default clock_timestamp(),
  unique(period_id, revision_number),
  unique(period_id, id)
);

create table public.v1_workforce_monthly_transitions (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  approval_revision_number bigint not null check (approval_revision_number > 0),
  action_kind text not null check (action_kind in (
    'submit', 'return_for_correction', 'reviewer_correction',
    'verify_forward', 'approve_lock', 'reopen_authorized'
  )),
  from_status text not null,
  to_status text not null,
  from_record_version bigint not null check (from_record_version > 0),
  to_record_version bigint not null check (to_record_version > 0),
  validation_run_id uuid not null
    references public.v1_workforce_monthly_validation_runs(id) on delete restrict,
  source_fingerprint text not null check (source_fingerprint ~ '^[0-9a-f]{64}$'),
  actor_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  actor_exact_role text not null,
  capability_key text not null check (capability_key in (
    'workforce.timesheets.maintain', 'workforce.timesheets.review',
    'workforce.timesheets.correct_during_review',
    'workforce.timesheets.verify', 'workforce.timesheets.final_approve',
    'workforce.periods.reopen'
  )),
  reason text not null check (char_length(reason) <= 2000),
  warning_acknowledgements jsonb not null default '[]'::jsonb
    check (jsonb_typeof(warning_acknowledgements) = 'array'),
  attachment_reference text check (
    attachment_reference is null or char_length(attachment_reference) <= 500
  ),
  idempotency_key uuid not null,
  occurred_at timestamptz not null default clock_timestamp(),
  unique(actor_auth_user_id, idempotency_key),
  unique(period_id, to_record_version)
);

create table public.v1_workforce_monthly_edit_scopes (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  approval_revision_number bigint not null check (approval_revision_number > 0),
  scope_kind text not null check (scope_kind in ('return', 'reopen')),
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),
  attachment_reference text check (
    attachment_reference is null or char_length(attachment_reference) <= 500
  ),
  created_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  unique(period_id, id)
);

alter table public.v1_workforce_monthly_periods
  add constraint v1_workforce_monthly_periods_edit_scope_fk
  foreign key (id, current_edit_scope_id)
  references public.v1_workforce_monthly_edit_scopes(period_id, id)
  on delete restrict deferrable initially deferred;

create table public.v1_workforce_monthly_edit_scope_entries (
  edit_scope_id uuid not null
    references public.v1_workforce_monthly_edit_scopes(id) on delete restrict,
  worker_id uuid not null references public.v1_workforce_workers(id)
    on delete restrict,
  work_date date not null,
  primary key(edit_scope_id, worker_id, work_date)
);

create table public.v1_workforce_monthly_reviewer_corrections (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  approval_revision_number bigint not null check (approval_revision_number > 0),
  worker_id uuid not null references public.v1_workforce_workers(id)
    on delete restrict,
  work_date date not null,
  before_value jsonb not null check (jsonb_typeof(before_value) = 'object'),
  after_value jsonb not null check (jsonb_typeof(after_value) = 'object'),
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),
  corrected_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  corrected_by_exact_role text not null,
  corrected_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique(corrected_by_auth_user_id, idempotency_key)
);

create table public.v1_workforce_monthly_reopen_requests (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  locked_revision_number bigint not null check (locked_revision_number > 0),
  reason text not null check (
    btrim(reason) <> '' and char_length(reason) <= 2000
  ),
  attachment_reference text check (
    attachment_reference is null or char_length(attachment_reference) <= 500
  ),
  affected_entries jsonb not null check (
    jsonb_typeof(affected_entries) = 'array' and
    jsonb_array_length(affected_entries) > 0
  ),
  requested_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  requested_by_exact_role text not null,
  requested_at timestamptz not null default clock_timestamp(),
  authorized_by_auth_user_id uuid
    references public.v1_profiles(auth_user_id) on delete restrict,
  authorized_by_exact_role text,
  authorized_at timestamptz,
  authorization_reason text,
  new_revision_number bigint,
  idempotency_key uuid not null,
  authorization_idempotency_key uuid,
  unique(requested_by_auth_user_id, idempotency_key),
  unique(authorized_by_auth_user_id, authorization_idempotency_key),
  check ((authorized_at is null and authorized_by_auth_user_id is null
      and authorized_by_exact_role is null and new_revision_number is null)
    or (authorized_at is not null and authorized_by_auth_user_id is not null
      and authorized_by_exact_role is not null and new_revision_number is not null))
);

create table public.v1_workforce_monthly_approved_snapshots (
  id uuid primary key default gen_random_uuid(),
  period_id uuid not null references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  approval_revision_number bigint not null check (approval_revision_number > 0),
  validation_run_id uuid not null
    references public.v1_workforce_monthly_validation_runs(id) on delete restrict,
  snapshot_payload jsonb not null check (jsonb_typeof(snapshot_payload) = 'object'),
  snapshot_hash text not null check (snapshot_hash ~ '^[0-9a-f]{64}$'),
  approved_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  approved_by_exact_role text not null,
  approved_at timestamptz not null default clock_timestamp(),
  locked_at timestamptz not null default clock_timestamp(),
  unique(period_id, approval_revision_number),
  unique(period_id, id)
);

alter table public.v1_workforce_monthly_approval_revisions
  add constraint v1_workforce_monthly_revision_snapshot_fk
  foreign key(opened_from_snapshot_id)
  references public.v1_workforce_monthly_approved_snapshots(id)
  on delete restrict deferrable initially deferred;

-- A caller cannot manufacture this context: authenticated users have no table
-- privileges and only the reviewer-correction RPC inserts a row in its own
-- transaction immediately before calling the accepted T05 writer.
create table public.v1_workforce_monthly_correction_contexts (
  actor_auth_user_id uuid not null,
  backend_pid integer not null,
  transaction_id bigint not null,
  period_id uuid not null,
  worker_id uuid not null,
  work_date date not null,
  primary key(actor_auth_user_id, backend_pid, transaction_id)
);

create index v1_workforce_monthly_transitions_period_idx
  on public.v1_workforce_monthly_transitions(period_id, occurred_at, id);
create index v1_workforce_monthly_corrections_period_idx
  on public.v1_workforce_monthly_reviewer_corrections(
    period_id, approval_revision_number, worker_id, work_date
  );
create index v1_workforce_monthly_reopen_period_idx
  on public.v1_workforce_monthly_reopen_requests(period_id, requested_at desc);

alter table public.v1_workforce_monthly_approval_revisions enable row level security;
alter table public.v1_workforce_monthly_transitions enable row level security;
alter table public.v1_workforce_monthly_edit_scopes enable row level security;
alter table public.v1_workforce_monthly_edit_scope_entries enable row level security;
alter table public.v1_workforce_monthly_reviewer_corrections enable row level security;
alter table public.v1_workforce_monthly_reopen_requests enable row level security;
alter table public.v1_workforce_monthly_approved_snapshots enable row level security;
alter table public.v1_workforce_monthly_correction_contexts enable row level security;

revoke all on table public.v1_workforce_monthly_approval_revisions,
  public.v1_workforce_monthly_transitions,
  public.v1_workforce_monthly_edit_scopes,
  public.v1_workforce_monthly_edit_scope_entries,
  public.v1_workforce_monthly_reviewer_corrections,
  public.v1_workforce_monthly_reopen_requests,
  public.v1_workforce_monthly_approved_snapshots,
  public.v1_workforce_monthly_correction_contexts
from public, anon, authenticated;
grant all on table public.v1_workforce_monthly_approval_revisions,
  public.v1_workforce_monthly_transitions,
  public.v1_workforce_monthly_edit_scopes,
  public.v1_workforce_monthly_edit_scope_entries,
  public.v1_workforce_monthly_reviewer_corrections,
  public.v1_workforce_monthly_reopen_requests,
  public.v1_workforce_monthly_approved_snapshots,
  public.v1_workforce_monthly_correction_contexts
to service_role;

create or replace function public.v1_workforce_t07_block_history_change()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'V1_WORKFORCE_T07_HISTORY_IMMUTABLE' using errcode='23514';
end;
$$;

create trigger v1_workforce_monthly_revisions_immutable
before update or delete on public.v1_workforce_monthly_approval_revisions
for each row execute function public.v1_workforce_t07_block_history_change();
create trigger v1_workforce_monthly_transitions_immutable
before update or delete on public.v1_workforce_monthly_transitions
for each row execute function public.v1_workforce_t07_block_history_change();
create trigger v1_workforce_monthly_edit_scopes_immutable
before update or delete on public.v1_workforce_monthly_edit_scopes
for each row execute function public.v1_workforce_t07_block_history_change();
create trigger v1_workforce_monthly_edit_entries_immutable
before update or delete on public.v1_workforce_monthly_edit_scope_entries
for each row execute function public.v1_workforce_t07_block_history_change();
create trigger v1_workforce_monthly_corrections_immutable
before update or delete on public.v1_workforce_monthly_reviewer_corrections
for each row execute function public.v1_workforce_t07_block_history_change();
create trigger v1_workforce_monthly_snapshots_immutable
before update or delete on public.v1_workforce_monthly_approved_snapshots
for each row execute function public.v1_workforce_t07_block_history_change();

create or replace function public.v1_workforce_t07_guard_reopen_request()
returns trigger language plpgsql set search_path='' as $$
begin
  if tg_op='DELETE' then
    raise exception 'V1_WORKFORCE_T07_HISTORY_IMMUTABLE' using errcode='23514';
  end if;
  if old.authorized_at is not null
    or (to_jsonb(new)-array['authorized_by_auth_user_id','authorized_by_exact_role',
        'authorized_at','authorization_reason','new_revision_number',
        'authorization_idempotency_key']::text[])
       is distinct from
       (to_jsonb(old)-array['authorized_by_auth_user_id','authorized_by_exact_role',
        'authorized_at','authorization_reason','new_revision_number',
        'authorization_idempotency_key']::text[])
    or new.authorized_by_auth_user_id is distinct from auth.uid()
    or new.authorized_at is null or btrim(coalesce(new.authorization_reason,''))=''
    or new.new_revision_number<>old.locked_revision_number+1
    or new.authorization_idempotency_key is null
    or not exists(select 1 from public.v1_workforce_monthly_transitions transition
      where transition.period_id=old.period_id
        and transition.approval_revision_number=new.new_revision_number
        and transition.action_kind='reopen_authorized'
        and transition.actor_auth_user_id=new.authorized_by_auth_user_id
        and transition.idempotency_key=new.authorization_idempotency_key)
  then raise exception 'V1_WORKFORCE_T07_REOPEN_UPDATE_INVALID' using errcode='23514';
  end if;
  return new;
end;
$$;

create trigger v1_workforce_monthly_reopen_guard
before update or delete on public.v1_workforce_monthly_reopen_requests
for each row execute function public.v1_workforce_t07_guard_reopen_request();

create or replace function public.v1_workforce_t07_context_active(
  p_actor uuid, p_worker_id uuid, p_work_date date
) returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1 from public.v1_workforce_monthly_correction_contexts context
    where context.actor_auth_user_id=p_actor
      and context.backend_pid=pg_backend_pid()
      and context.transaction_id=txid_current()
      and context.worker_id=p_worker_id and context.work_date=p_work_date
  );
$$;

create or replace function public.v1_workforce_t07_entry_mutation_allowed(
  p_actor uuid, p_worker_id uuid, p_work_date date, p_team_id uuid
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare
  v_period public.v1_workforce_monthly_periods%rowtype;
begin
  select period.* into v_period
  from public.v1_workforce_monthly_periods period
  where period.team_id=p_team_id
    and period.period_month=date_trunc('month',p_work_date)::date;
  if not found or v_period.current_status in ('draft','ready_for_review') then
    return true;
  end if;
  if public.v1_workforce_t07_context_active(p_actor,p_worker_id,p_work_date)
    and v_period.current_status in ('submitted','under_review') then
    return true;
  end if;
  if v_period.current_status in ('returned_for_correction','reopened')
    and v_period.current_edit_scope_id is not null
    and exists (
      select 1 from public.v1_workforce_monthly_edit_scope_entries entry
      where entry.edit_scope_id=v_period.current_edit_scope_id
        and entry.worker_id=p_worker_id and entry.work_date=p_work_date
    ) then
    return true;
  end if;
  return false;
end;
$$;

create or replace function public.v1_workforce_t07_period_authorized(
  p_capability_key text, p_period_id uuid, p_require_targets boolean default true
) returns boolean language plpgsql security definer set search_path='' as $$
declare
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_actor uuid:=auth.uid();
  v_role text;
  v_date public.v1_workforce_monthly_period_dates%rowtype;
  v_target jsonb;
begin
  if v_actor is null or p_capability_key not in (
    'workforce.view','workforce.timesheets.maintain',
    'workforce.timesheets.review','workforce.timesheets.correct_during_review',
    'workforce.timesheets.verify','workforce.timesheets.final_approve',
    'workforce.periods.reopen'
  ) or not public.v1_current_actor_is_active()
  then
    return false;
  end if;
  select * into v_period from public.v1_workforce_monthly_periods
  where id=p_period_id;
  if not found then return false; end if;
  v_role:=public.v1_permission_exact_role(v_actor);
  if v_role='' then return false; end if;
  if v_role='admin' then
    return public.v1_current_user_has_capability(p_capability_key,null);
  end if;

  if not exists(select 1 from public.v1_workforce_monthly_period_dates d
    where d.validation_run_id=v_period.current_validation_run_id) then
    return public.v1_workforce_monthly_empty_scope_authorized(
      p_capability_key,v_period.team_id,v_period.period_month);
  end if;

  for v_date in select * from public.v1_workforce_monthly_period_dates d
    where d.validation_run_id=v_period.current_validation_run_id loop
    if not public.v1_current_user_has_capability(p_capability_key,
        nullif(v_date.assignment_snapshot->>'project_id','')::uuid)
      or public.v1_workforce_matching_responsibility(v_actor,v_date.worker_id,
        v_date.work_date,
        nullif(v_date.assignment_snapshot->>'team_id','')::uuid,
        nullif(v_date.assignment_snapshot->>'project_id','')::uuid,
        nullif(v_date.assignment_snapshot->>'project_scope_id','')::uuid,
        nullif(v_date.assignment_snapshot->>'internal_location_id','')::uuid
      )='{}'::jsonb then return false; end if;
    if p_require_targets and v_date.allocation_snapshot->>'allocation_state'='active' then
      for v_target in select value from jsonb_array_elements(
        coalesce(v_date.allocation_snapshot->'targets','[]'::jsonb)) loop
        if not public.v1_current_user_has_capability(p_capability_key,
            case when v_target->>'target_kind'='project_work'
              then nullif(v_target->>'project_id','')::uuid else null end)
          or not exists(select 1 from public.v1_workforce_responsibility_assignments r
            where r.auth_user_id=v_actor and r.valid_from<=v_date.work_date
              and (r.valid_to is null or r.valid_to>=v_date.work_date) and (
                r.scope_kind='organization' or
                (v_target->>'target_kind'='project_work' and (
                  (r.scope_kind='project' and r.project_id=
                    nullif(v_target->>'project_id','')::uuid) or
                  (r.scope_kind='project_scope' and r.project_id=
                    nullif(v_target->>'project_id','')::uuid and
                    r.project_scope_id=nullif(v_target->>'project_scope_id','')::uuid))) or
                (v_target->>'target_kind'='internal_work'
                  and r.scope_kind='internal_location'
                  and r.internal_location_id=
                    nullif(v_target->>'internal_location_id','')::uuid)
              )) then return false; end if;
      end loop;
    end if;
  end loop;
  return true;
end;
$$;

create or replace function public.v1_workforce_t07_validate_entries(
  p_period_id uuid, p_entries jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_period public.v1_workforce_monthly_periods%rowtype; v_item jsonb;
  v_result jsonb:='[]'::jsonb; v_worker uuid; v_date date;
begin
  if jsonb_typeof(p_entries)<>'array' or jsonb_array_length(p_entries)=0
    or jsonb_array_length(p_entries)>500 then
    raise exception 'V1_WORKFORCE_T07_AFFECTED_ENTRIES_INVALID' using errcode='22023';
  end if;
  select * into strict v_period from public.v1_workforce_monthly_periods
  where id=p_period_id;
  for v_item in select value from jsonb_array_elements(p_entries) loop
    if jsonb_typeof(v_item)<>'object'
      or exists(select 1 from jsonb_object_keys(v_item) key
        where key not in ('worker_id','work_date'))
      or not (v_item ?& array['worker_id','work_date']) then
      raise exception 'V1_WORKFORCE_T07_AFFECTED_ENTRIES_INVALID' using errcode='22023';
    end if;
    begin v_worker:=(v_item->>'worker_id')::uuid; v_date:=(v_item->>'work_date')::date;
    exception when others then
      raise exception 'V1_WORKFORCE_T07_AFFECTED_ENTRIES_INVALID' using errcode='22023';
    end;
    if not exists(select 1 from public.v1_workforce_monthly_period_dates d
      where d.validation_run_id=v_period.current_validation_run_id
        and d.worker_id=v_worker and d.work_date=v_date) then
      raise exception 'V1_WORKFORCE_T07_AFFECTED_ENTRY_NOT_IN_PERIOD' using errcode='23514';
    end if;
    v_result:=v_result||jsonb_build_array(jsonb_build_object(
      'worker_id',v_worker,'work_date',v_date));
  end loop;
  if (select count(*) from jsonb_array_elements(v_result)) <>
     (select count(distinct value) from jsonb_array_elements(v_result)) then
    raise exception 'V1_WORKFORCE_T07_AFFECTED_ENTRIES_DUPLICATE' using errcode='23514';
  end if;
  return v_result;
end;
$$;

create or replace function public.v1_workforce_monthly_guard_period_update()
returns trigger language plpgsql set search_path='' as $$
declare v_validation_allowed boolean;
begin
  if (to_jsonb(new)-array['current_validation_run_id','current_validation_number',
      'current_status','record_version','updated_by_auth_user_id','updated_at',
      'current_approval_revision_number','current_edit_scope_id']::text[])
    is distinct from
    (to_jsonb(old)-array['current_validation_run_id','current_validation_number',
      'current_status','record_version','updated_by_auth_user_id','updated_at',
      'current_approval_revision_number','current_edit_scope_id']::text[]) then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_UPDATE_INVALID' using errcode='23514';
  end if;
  if new.current_validation_number=old.current_validation_number+1 then
    v_validation_allowed:=old.current_status in ('draft','ready_for_review',
      'returned_for_correction','reopened');
    if old.current_status in ('submitted','under_review') then
      select exists(select 1
        from public.v1_workforce_monthly_correction_contexts context
        where context.period_id=old.id
          and context.actor_auth_user_id=auth.uid()
          and context.backend_pid=pg_backend_pid()
          and context.transaction_id=txid_current())
      into v_validation_allowed;
    end if;
    if not v_validation_allowed
      or new.current_status not in ('draft','ready_for_review')
      or new.current_approval_revision_number<>old.current_approval_revision_number
      or new.current_edit_scope_id is distinct from old.current_edit_scope_id
      or new.record_version<>(case when old.current_validation_number=0
        then old.record_version else old.record_version+1 end)
      or not exists(select 1 from public.v1_workforce_monthly_validation_runs run
        where run.id=new.current_validation_run_id and run.period_id=new.id
          and run.validation_number=new.current_validation_number
          and run.validation_status=new.current_status) then
      raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_UPDATE_INVALID' using errcode='23514';
    end if;
    return new;
  end if;
  if new.current_validation_number<>old.current_validation_number
    or new.current_validation_run_id is distinct from old.current_validation_run_id
    or new.record_version<>old.record_version+1
    or not exists(select 1 from public.v1_workforce_monthly_transitions transition
      where transition.period_id=new.id
        and transition.from_status=old.current_status
        and transition.to_status=new.current_status
        and transition.from_record_version=old.record_version
        and transition.to_record_version=new.record_version
        and transition.approval_revision_number=new.current_approval_revision_number)
  then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_UPDATE_INVALID' using errcode='23514';
  end if;
  return new;
end;
$$;

-- Existing T03-T05 helpers remain the writer authority. These replacements
-- add only lifecycle locking and the server-created correction context.
create or replace function public.v1_workforce_roster_authority_context(
  p_capability_key text,p_worker_id uuid,p_work_date date,p_team_id uuid,
  p_project_id uuid,p_project_scope_id uuid,p_internal_location_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_responsibility jsonb;
  v_correction boolean:=false;
begin
  if p_capability_key not in ('workforce.view','workforce.attendance.maintain',
      'workforce.timesheets.maintain') or v_actor is null or p_worker_id is null
      or p_work_date is null then return '{}'::jsonb; end if;
  if p_capability_key<>'workforce.view'
    and not public.v1_workforce_t07_entry_mutation_allowed(
      v_actor,p_worker_id,p_work_date,p_team_id) then return '{}'::jsonb; end if;
  v_correction:=p_capability_key<>'workforce.view'
    and public.v1_workforce_t07_context_active(v_actor,p_worker_id,p_work_date);
  v_role:=public.v1_permission_exact_role(v_actor);
  if v_role='' or not public.v1_current_actor_is_active() or not (
    public.v1_current_user_has_capability(p_capability_key,p_project_id)
    or (v_correction and public.v1_current_user_has_capability(
      'workforce.timesheets.correct_during_review',p_project_id))
  ) then return '{}'::jsonb; end if;
  if v_role='admin' then return jsonb_build_object('authority_kind',
    case when v_correction then 'reviewer_correction' else 'admin_organization' end,
    'responsibility_assignment_id',null,'scope_kind','organization',
    'scope_reference','admin:organization','record_version',null); end if;
  v_responsibility:=public.v1_workforce_matching_responsibility(v_actor,p_worker_id,
    p_work_date,p_team_id,p_project_id,p_project_scope_id,p_internal_location_id);
  if v_responsibility='{}'::jsonb then return '{}'::jsonb; end if;
  return v_responsibility||jsonb_build_object('authority_kind',
    case when v_correction then 'reviewer_correction' else 'responsibility' end);
end;
$$;

create or replace function public.v1_workforce_attendance_authority_context(
  p_capability_key text,p_worker_id uuid,p_work_date date,p_team_id uuid,
  p_project_id uuid,p_project_scope_id uuid,p_internal_location_id uuid
) returns jsonb language sql security definer set search_path='' as $$
  select public.v1_workforce_roster_authority_context(p_capability_key,p_worker_id,
    p_work_date,p_team_id,p_project_id,p_project_scope_id,p_internal_location_id);
$$;

create or replace function public.v1_workforce_timesheet_worker_authority(
  p_capability_key text,p_day public.v1_workforce_attendance_days
) returns jsonb language sql security definer set search_path='' as $$
  select case when p_day.id is null then '{}'::jsonb else
    public.v1_workforce_roster_authority_context(p_capability_key,p_day.worker_id,
      p_day.work_date,p_day.assignment_team_id_snapshot,
      p_day.assignment_project_id_snapshot,p_day.assignment_project_scope_id_snapshot,
      p_day.assignment_internal_location_id_snapshot) end;
$$;

create or replace function public.v1_workforce_timesheet_target_authority(
  p_capability_key text,p_work_date date,p_target_kind text,p_project_id uuid,
  p_project_scope_id uuid,p_internal_location_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_result jsonb; v_correction boolean;
begin
  if p_capability_key not in ('workforce.view','workforce.timesheets.maintain')
    or v_actor is null or p_work_date is null
    or p_target_kind not in ('project_work','internal_work') then return '{}'::jsonb; end if;
  v_correction:=p_capability_key='workforce.timesheets.maintain' and exists(
    select 1 from public.v1_workforce_monthly_correction_contexts context
    where context.actor_auth_user_id=v_actor and context.backend_pid=pg_backend_pid()
      and context.transaction_id=txid_current() and context.work_date=p_work_date);
  v_role:=public.v1_permission_exact_role(v_actor);
  if v_role='' or not public.v1_current_actor_is_active() or not (
    public.v1_current_user_has_capability(p_capability_key,
      case when p_target_kind='project_work' then p_project_id else null end)
    or (v_correction and public.v1_current_user_has_capability(
      'workforce.timesheets.correct_during_review',
      case when p_target_kind='project_work' then p_project_id else null end))
  ) then return '{}'::jsonb; end if;
  if v_role='admin' then return jsonb_build_object('authority_kind',
    case when v_correction then 'reviewer_correction' else 'admin_organization' end,
    'scope_kind','organization','scope_reference','admin:organization'); end if;
  select jsonb_build_object('authority_kind',case when v_correction
      then 'reviewer_correction' else 'responsibility' end,
    'responsibility_assignment_id',r.id,'scope_kind',r.scope_kind,
    'scope_reference',r.scope_reference,'record_version',r.record_version)
  into v_result from public.v1_workforce_responsibility_assignments r
  where r.auth_user_id=v_actor and r.valid_from<=p_work_date
    and (r.valid_to is null or r.valid_to>=p_work_date) and (
      r.scope_kind='organization' or (p_target_kind='project_work' and (
        (r.scope_kind='project' and r.project_id=p_project_id) or
        (r.scope_kind='project_scope' and r.project_id=p_project_id
          and r.project_scope_id=p_project_scope_id))) or
      (p_target_kind='internal_work' and r.scope_kind='internal_location'
        and r.internal_location_id=p_internal_location_id))
  order by case r.scope_kind when 'project_scope' then 0
    when 'internal_location' then 1 when 'project' then 2 else 3 end,
    r.valid_from desc,r.id limit 1;
  return coalesce(v_result,'{}'::jsonb);
end;
$$;

-- Lifecycle JSON keeps command flags server-derived and self-action safe.
create or replace function public.v1_workforce_monthly_lifecycle_json(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_period public.v1_workforce_monthly_periods%rowtype;
  v_run public.v1_workforce_monthly_validation_runs%rowtype;
  v_actor uuid:=auth.uid(); v_fingerprint text; v_stale boolean;
begin
  select * into strict v_period from public.v1_workforce_monthly_periods where id=p_period_id;
  select * into strict v_run from public.v1_workforce_monthly_validation_runs
    where id=v_period.current_validation_run_id;
  v_fingerprint:=public.v1_workforce_monthly_source_fingerprint(v_period.team_id,v_period.period_month);
  v_stale:=v_run.source_fingerprint<>v_fingerprint;
  return jsonb_build_object('schema_version',1,'authorization_mode','enforced_t07',
    'period_id',v_period.id,'team_id',v_period.team_id,'period_month',v_period.period_month,
    'status',v_period.current_status,'record_version',v_period.record_version,
    'approval_revision_number',v_period.current_approval_revision_number,
    'validation_run_id',v_run.id,'validation_number',v_run.validation_number,
    'source_fingerprint',v_run.source_fingerprint,'current_source_fingerprint',v_fingerprint,
    'is_stale',v_stale,'blocking_issue_count',v_run.blocking_issue_count,
    'warning_issue_count',v_run.warning_issue_count,
    'submitter_auth_user_id',public.v1_workforce_t07_submitter(
      p_period_id,v_period.current_approval_revision_number),
    'can_submit',not v_stale and v_run.blocking_issue_count=0
      and v_period.current_status='ready_for_review'
      and public.v1_workforce_t07_period_authorized('workforce.timesheets.maintain',p_period_id,true),
    'can_return',v_period.current_status in ('submitted','under_review')
      and public.v1_workforce_t07_submitter(p_period_id,
        v_period.current_approval_revision_number) is distinct from v_actor
      and public.v1_workforce_t07_period_authorized('workforce.timesheets.review',p_period_id,true),
    'can_correct',v_period.current_status in ('submitted','under_review')
      and public.v1_workforce_t07_submitter(p_period_id,
        v_period.current_approval_revision_number) is distinct from v_actor
      and public.v1_workforce_t07_period_authorized(
        'workforce.timesheets.correct_during_review',p_period_id,true),
    'can_verify',not v_stale and v_period.current_status in ('submitted','under_review')
      and public.v1_workforce_t07_submitter(p_period_id,
        v_period.current_approval_revision_number) is distinct from v_actor
      and public.v1_workforce_t07_period_authorized('workforce.timesheets.verify',p_period_id,true),
    'can_final_approve',not v_stale and v_period.current_status='awaiting_final_approval'
      and public.v1_workforce_t07_submitter(p_period_id,
        v_period.current_approval_revision_number) is distinct from v_actor
      and not exists(select 1 from public.v1_workforce_monthly_transitions t
        where t.period_id=p_period_id and t.approval_revision_number=v_period.current_approval_revision_number
          and t.action_kind in (
            'return_for_correction','reviewer_correction','verify_forward'
          )
          and t.actor_auth_user_id=v_actor)
      and public.v1_workforce_t07_period_authorized('workforce.timesheets.final_approve',p_period_id,true),
    'can_request_reopen',v_period.current_status='locked'
      and not exists(select 1 from public.v1_workforce_monthly_reopen_requests r
        where r.period_id=p_period_id and r.authorized_at is null)
      and public.v1_workforce_t07_period_authorized('workforce.timesheets.maintain',p_period_id,true),
    'can_authorize_reopen',v_period.current_status='locked'
      and exists(select 1 from public.v1_workforce_monthly_reopen_requests r
        where r.period_id=p_period_id and r.authorized_at is null
          and r.requested_by_auth_user_id is distinct from v_actor)
      and public.v1_workforce_t07_period_authorized('workforce.periods.reopen',p_period_id,true),
    'transitions',coalesce((select jsonb_agg(jsonb_build_object('transition_id',t.id,
      'action_kind',t.action_kind,'from_status',t.from_status,'to_status',t.to_status,
      'actor_auth_user_id',t.actor_auth_user_id,'actor_exact_role',t.actor_exact_role,
      'reason',t.reason,'occurred_at',t.occurred_at) order by t.occurred_at,t.id)
      from public.v1_workforce_monthly_transitions t where t.period_id=p_period_id),'[]'::jsonb),
    'corrections',coalesce((select jsonb_agg(jsonb_build_object('correction_id',c.id,
      'worker_id',c.worker_id,'work_date',c.work_date,'before_value',c.before_value,
      'after_value',c.after_value,'reason',c.reason,
      'corrected_by_auth_user_id',c.corrected_by_auth_user_id,'corrected_at',c.corrected_at)
      order by c.corrected_at,c.id) from public.v1_workforce_monthly_reviewer_corrections c
      where c.period_id=p_period_id),'[]'::jsonb),
    'approved_snapshots',coalesce((select jsonb_agg(jsonb_build_object('snapshot_id',s.id,
      'revision_number',s.approval_revision_number,'snapshot_hash',s.snapshot_hash,
      'approved_by_auth_user_id',s.approved_by_auth_user_id,'approved_at',s.approved_at,
      'locked_at',s.locked_at) order by s.approval_revision_number)
      from public.v1_workforce_monthly_approved_snapshots s where s.period_id=p_period_id),'[]'::jsonb),
    'reopen_requests',coalesce((select jsonb_agg(jsonb_build_object('request_id',r.id,
      'reason',r.reason,'affected_entries',r.affected_entries,
      'requested_by_auth_user_id',r.requested_by_auth_user_id,'requested_at',r.requested_at,
      'authorized_by_auth_user_id',r.authorized_by_auth_user_id,'authorized_at',r.authorized_at,
      'new_revision_number',r.new_revision_number) order by r.requested_at,r.id)
      from public.v1_workforce_monthly_reopen_requests r where r.period_id=p_period_id),'[]'::jsonb));
end;
$$;

create or replace function public.v1_workforce_t07_child_key(
  p_root_key uuid, p_action text
) returns uuid language sql immutable strict set search_path='' as $$
  select md5('v1_workforce_t07|'||p_root_key::text||'|'||p_action)::uuid;
$$;

create or replace function public.v1_workforce_t07_submitter(
  p_period_id uuid,p_revision_number bigint
) returns uuid language sql security definer set search_path='' as $$
  select transition.actor_auth_user_id
  from public.v1_workforce_monthly_transitions transition
  where transition.period_id=p_period_id
    and transition.approval_revision_number=p_revision_number
    and transition.action_kind='submit'
  order by transition.occurred_at desc,transition.id desc limit 1;
$$;

create or replace function public.v1_workforce_t07_current_source_valid(
  p_period_id uuid
) returns boolean language sql security definer set search_path='' as $$
  select run.blocking_issue_count=0 and run.source_fingerprint=
    public.v1_workforce_monthly_source_fingerprint(period.team_id,period.period_month)
  from public.v1_workforce_monthly_periods period
  join public.v1_workforce_monthly_validation_runs run
    on run.id=period.current_validation_run_id
  where period.id=p_period_id;
$$;

create or replace function public.v1_workforce_t07_validate_warning_acknowledgements(
  p_period_id uuid,p_acknowledgements jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_period public.v1_workforce_monthly_periods%rowtype;
  v_required jsonb; v_supplied jsonb;
begin
  if jsonb_typeof(p_acknowledgements)<>'array' then
    raise exception 'V1_WORKFORCE_T07_WARNING_ACK_INVALID' using errcode='22023';
  end if;
  select * into strict v_period from public.v1_workforce_monthly_periods where id=p_period_id;
  begin
    select coalesce(jsonb_agg(to_jsonb(id) order by id),'[]'::jsonb) into v_supplied
    from (select distinct value #>> '{}' as raw,(value #>> '{}')::uuid as id
      from jsonb_array_elements(p_acknowledgements)
      where jsonb_typeof(value)='string') supplied;
  exception when others then
    raise exception 'V1_WORKFORCE_T07_WARNING_ACK_INVALID' using errcode='22023';
  end;
  if jsonb_array_length(v_supplied)<>jsonb_array_length(p_acknowledgements) then
    raise exception 'V1_WORKFORCE_T07_WARNING_ACK_INVALID' using errcode='22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(issue.id) order by issue.id),'[]'::jsonb)
  into v_required from public.v1_workforce_monthly_validation_issues issue
  where issue.validation_run_id=v_period.current_validation_run_id
    and issue.severity='warning';
  if v_supplied<>v_required then
    raise exception 'V1_WORKFORCE_T07_WARNING_ACK_REQUIRED' using errcode='23514';
  end if;
  return v_supplied;
end;
$$;

create or replace function public.v1_submit_workforce_monthly_period(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid;
  v_period public.v1_workforce_monthly_periods%rowtype; v_revision bigint;
  v_ack jsonb; v_existing jsonb; v_response jsonb; v_reason text;
begin
  if v_actor is null or p_expected_period_version is null
    or p_expected_period_version<1 or p_idempotency_key is null
    or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_SUBMIT_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['period_id','warning_issue_ids','reason'],
    'submit_workforce_monthly_period');
  if not (p_payload?&array['period_id','warning_issue_ids','reason'])
    or jsonb_typeof(p_payload->'reason')<>'string' then
    raise exception 'V1_WORKFORCE_T07_SUBMIT_INVALID' using errcode='22023'; end if;
  begin v_period_id:=(p_payload->>'period_id')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_SUBMIT_INVALID' using errcode='22023'; end;
  v_reason:=btrim(p_payload->>'reason');
  if v_reason='' or char_length(v_reason)>2000 then
    raise exception 'V1_WORKFORCE_T07_SUBMIT_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  if not public.v1_workforce_t07_period_authorized('workforce.timesheets.maintain',v_period_id,true)
    then raise exception 'V1_WORKFORCE_T07_SUBMIT_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_submit_workforce_monthly_period',
    p_idempotency_key,jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status<>'ready_for_review'
    or not public.v1_workforce_t07_current_source_valid(v_period_id) then
    raise exception 'V1_WORKFORCE_T07_PERIOD_NOT_READY' using errcode='23514'; end if;
  v_ack:=public.v1_workforce_t07_validate_warning_acknowledgements(
    v_period_id,p_payload->'warning_issue_ids');
  v_revision:=case when v_period.current_approval_revision_number=0 then 1
    else v_period.current_approval_revision_number end;
  if v_period.current_approval_revision_number=0 then
    insert into public.v1_workforce_monthly_approval_revisions(
      period_id,revision_number,opened_reason,opened_by_auth_user_id,opened_by_exact_role)
    values(v_period_id,v_revision,v_reason,v_actor,v_role);
  elsif not exists(select 1 from public.v1_workforce_monthly_approval_revisions r
      where r.period_id=v_period_id and r.revision_number=v_revision) then
    raise exception 'V1_WORKFORCE_T07_REVISION_INVALID' using errcode='23514';
  end if;
  insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
    action_kind,from_status,to_status,from_record_version,to_record_version,
    validation_run_id,source_fingerprint,actor_auth_user_id,actor_exact_role,
    capability_key,reason,warning_acknowledgements,idempotency_key)
  select v_period_id,v_revision,'submit',v_period.current_status,'submitted',
    v_period.record_version,v_period.record_version+1,v_period.current_validation_run_id,
    run.source_fingerprint,v_actor,v_role,'workforce.timesheets.maintain',v_reason,v_ack,p_idempotency_key
  from public.v1_workforce_monthly_validation_runs run
  where run.id=v_period.current_validation_run_id;
  update public.v1_workforce_monthly_periods set current_status='submitted',
    current_approval_revision_number=v_revision,current_edit_scope_id=null,
    record_version=record_version+1,updated_by_auth_user_id=v_actor,
    updated_at=clock_timestamp() where id=v_period_id;
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_period_submitted',
    'workforce_monthly_period',v_period_id,null,to_jsonb(v_period),v_response,v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency('v1_submit_workforce_monthly_period',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_return_workforce_monthly_period(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid; v_reason text;
  v_attachment text; v_entries jsonb; v_period public.v1_workforce_monthly_periods%rowtype;
  v_scope_id uuid:=gen_random_uuid(); v_item jsonb; v_existing jsonb; v_response jsonb;
begin
  if v_actor is null or p_expected_period_version is null or p_expected_period_version<1
    or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_RETURN_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,
    array['period_id','reason','affected_entries','attachment_reference'],
    'return_workforce_monthly_period');
  if not (p_payload?&array['period_id','reason','affected_entries']) then
    raise exception 'V1_WORKFORCE_T07_RETURN_INVALID' using errcode='22023'; end if;
  begin v_period_id:=(p_payload->>'period_id')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_RETURN_INVALID' using errcode='22023'; end;
  v_reason:=btrim(coalesce(p_payload->>'reason',''));
  v_attachment:=nullif(btrim(coalesce(p_payload->>'attachment_reference','')),'');
  if v_reason='' or char_length(v_reason)>2000 or char_length(coalesce(v_attachment,''))>500 then
    raise exception 'V1_WORKFORCE_T07_RETURN_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  if not public.v1_workforce_t07_period_authorized('workforce.timesheets.review',v_period_id,true)
    then raise exception 'V1_WORKFORCE_T07_RETURN_DENIED' using errcode='42501'; end if;
  if public.v1_workforce_t07_submitter(v_period_id,
      v_period.current_approval_revision_number)=v_actor then
    raise exception 'V1_WORKFORCE_T07_SELF_ACTION_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_return_workforce_monthly_period',
    p_idempotency_key,jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status not in ('submitted','under_review') then
    raise exception 'V1_WORKFORCE_T07_RETURN_STATE_INVALID' using errcode='23514'; end if;
  v_entries:=public.v1_workforce_t07_validate_entries(v_period_id,p_payload->'affected_entries');
  insert into public.v1_workforce_monthly_edit_scopes(id,period_id,approval_revision_number,
    scope_kind,reason,attachment_reference,created_by_auth_user_id)
  values(v_scope_id,v_period_id,v_period.current_approval_revision_number,'return',
    v_reason,v_attachment,v_actor);
  for v_item in select value from jsonb_array_elements(v_entries) loop
    insert into public.v1_workforce_monthly_edit_scope_entries(edit_scope_id,worker_id,work_date)
    values(v_scope_id,(v_item->>'worker_id')::uuid,(v_item->>'work_date')::date);
  end loop;
  insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
    action_kind,from_status,to_status,from_record_version,to_record_version,
    validation_run_id,source_fingerprint,actor_auth_user_id,actor_exact_role,
    capability_key,reason,attachment_reference,idempotency_key)
  select v_period_id,v_period.current_approval_revision_number,'return_for_correction',
    v_period.current_status,'returned_for_correction',v_period.record_version,
    v_period.record_version+1,v_period.current_validation_run_id,run.source_fingerprint,
    v_actor,v_role,'workforce.timesheets.review',v_reason,v_attachment,p_idempotency_key
  from public.v1_workforce_monthly_validation_runs run where run.id=v_period.current_validation_run_id;
  update public.v1_workforce_monthly_periods set current_status='returned_for_correction',
    current_edit_scope_id=v_scope_id,record_version=record_version+1,
    updated_by_auth_user_id=v_actor,updated_at=clock_timestamp() where id=v_period_id;
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_period_returned',
    'workforce_monthly_period',v_period_id,null,to_jsonb(v_period),v_response,v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency('v1_return_workforce_monthly_period',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_correct_workforce_monthly_entry_during_review(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid; v_worker_id uuid;
  v_work_date date; v_reason text; v_period public.v1_workforce_monthly_periods%rowtype;
  v_existing jsonb; v_before jsonb; v_after jsonb;
  v_response jsonb; v_transition_key uuid;
begin
  if v_actor is null or p_expected_period_version is null or p_expected_period_version<1
    or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['period_id','row','reason'],
    'correct_workforce_monthly_entry_during_review');
  if not (p_payload?&array['period_id','row','reason'])
    or jsonb_typeof(p_payload->'row')<>'object' then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_INVALID' using errcode='22023'; end if;
  begin
    v_period_id:=(p_payload->>'period_id')::uuid;
    v_worker_id:=(p_payload#>>'{row,worker_id}')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_CORRECTION_INVALID' using errcode='22023'; end;
  v_reason:=btrim(coalesce(p_payload->>'reason',''));
  if v_reason='' or char_length(v_reason)>2000 then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  select d.work_date into v_work_date from public.v1_workforce_monthly_period_dates d
    where d.validation_run_id=v_period.current_validation_run_id and d.worker_id=v_worker_id
      and d.work_date=(p_payload#>>'{row,work_date}')::date;
  if not found then raise exception 'V1_WORKFORCE_T07_CORRECTION_ENTRY_INVALID' using errcode='23514'; end if;
  if not public.v1_workforce_t07_period_authorized(
      'workforce.timesheets.correct_during_review',v_period_id,true) then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_DENIED' using errcode='42501'; end if;
  if public.v1_workforce_t07_submitter(v_period_id,
      v_period.current_approval_revision_number)=v_actor then
    raise exception 'V1_WORKFORCE_T07_SELF_ACTION_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_correct_workforce_monthly_entry_during_review',p_idempotency_key,
    jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status not in ('submitted','under_review') then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_STATE_INVALID' using errcode='23514'; end if;
  v_before:=public.v1_workforce_daily_roster_row_json(v_worker_id,v_work_date);
  if v_before='{}'::jsonb then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_ENTRY_INVALID' using errcode='23514'; end if;
  insert into public.v1_workforce_monthly_correction_contexts(
    actor_auth_user_id,backend_pid,transaction_id,period_id,worker_id,work_date)
  values(v_actor,pg_backend_pid(),txid_current(),v_period_id,v_worker_id,v_work_date);
  perform public.v1_save_workforce_daily_roster(v_work_date,
    jsonb_build_array((p_payload->'row')-'work_date'),v_reason,
    public.v1_workforce_t07_child_key(p_idempotency_key,'roster'));
  v_after:=public.v1_workforce_daily_roster_row_json(v_worker_id,v_work_date);
  perform public.v1_validate_workforce_monthly_period(
    jsonb_build_object('team_id',v_period.team_id,'period_month',v_period.period_month),
    v_period.record_version,public.v1_workforce_t07_child_key(p_idempotency_key,'validation'));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if v_period.current_status<>'ready_for_review' then
    raise exception 'V1_WORKFORCE_T07_CORRECTION_VALIDATION_FAILED' using errcode='23514'; end if;
  insert into public.v1_workforce_monthly_reviewer_corrections(period_id,
    approval_revision_number,worker_id,work_date,before_value,after_value,reason,
    corrected_by_auth_user_id,corrected_by_exact_role,idempotency_key)
  values(v_period_id,v_period.current_approval_revision_number,v_worker_id,v_work_date,
    v_before,v_after,v_reason,v_actor,v_role,p_idempotency_key);
  v_transition_key:=public.v1_workforce_t07_child_key(p_idempotency_key,'transition');
  insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
    action_kind,from_status,to_status,from_record_version,to_record_version,
    validation_run_id,source_fingerprint,actor_auth_user_id,actor_exact_role,
    capability_key,reason,idempotency_key)
  select v_period_id,v_period.current_approval_revision_number,'reviewer_correction',
    v_period.current_status,'ready_for_review',v_period.record_version,v_period.record_version+1,
    v_period.current_validation_run_id,run.source_fingerprint,v_actor,v_role,
    'workforce.timesheets.correct_during_review',v_reason,v_transition_key
  from public.v1_workforce_monthly_validation_runs run where run.id=v_period.current_validation_run_id;
  update public.v1_workforce_monthly_periods set current_status='ready_for_review',
    record_version=record_version+1,updated_by_auth_user_id=v_actor,
    updated_at=clock_timestamp() where id=v_period_id;
  delete from public.v1_workforce_monthly_correction_contexts
    where actor_auth_user_id=v_actor and backend_pid=pg_backend_pid()
      and transaction_id=txid_current();
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_reviewer_correction',
    'workforce_monthly_period',v_period_id,null,v_before,v_after,v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency(
    'v1_correct_workforce_monthly_entry_during_review',p_idempotency_key,v_response);
  return v_response;
exception when invalid_text_representation or invalid_datetime_format then
  raise exception 'V1_WORKFORCE_T07_CORRECTION_INVALID' using errcode='22023';
end;
$$;

create or replace function public.v1_verify_workforce_monthly_period(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid; v_reason text;
  v_period public.v1_workforce_monthly_periods%rowtype;
  v_existing jsonb; v_response jsonb;
begin
  if v_actor is null or p_expected_period_version is null or p_expected_period_version<1
    or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_VERIFY_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['period_id','reason'],
    'verify_workforce_monthly_period');
  if not (p_payload?&array['period_id','reason']) then
    raise exception 'V1_WORKFORCE_T07_VERIFY_INVALID' using errcode='22023'; end if;
  begin v_period_id:=(p_payload->>'period_id')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_VERIFY_INVALID' using errcode='22023'; end;
  v_reason:=btrim(coalesce(p_payload->>'reason',''));
  if v_reason='' or char_length(v_reason)>2000 then
    raise exception 'V1_WORKFORCE_T07_VERIFY_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  if not public.v1_workforce_t07_period_authorized('workforce.timesheets.review',v_period_id,true)
    or not public.v1_workforce_t07_period_authorized('workforce.timesheets.verify',v_period_id,true)
    then raise exception 'V1_WORKFORCE_T07_VERIFY_DENIED' using errcode='42501'; end if;
  if public.v1_workforce_t07_submitter(v_period_id,
      v_period.current_approval_revision_number)=v_actor then
    raise exception 'V1_WORKFORCE_T07_SELF_ACTION_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_verify_workforce_monthly_period',
    p_idempotency_key,jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status not in ('submitted','under_review')
    or not public.v1_workforce_t07_current_source_valid(v_period_id) then
    raise exception 'V1_WORKFORCE_T07_VERIFY_STATE_INVALID' using errcode='23514'; end if;
  insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
    action_kind,from_status,to_status,from_record_version,to_record_version,
    validation_run_id,source_fingerprint,actor_auth_user_id,actor_exact_role,
    capability_key,reason,idempotency_key)
  select v_period_id,v_period.current_approval_revision_number,'verify_forward',
    v_period.current_status,'awaiting_final_approval',v_period.record_version,
    v_period.record_version+1,v_period.current_validation_run_id,run.source_fingerprint,
    v_actor,v_role,'workforce.timesheets.verify',v_reason,p_idempotency_key
  from public.v1_workforce_monthly_validation_runs run where run.id=v_period.current_validation_run_id;
  update public.v1_workforce_monthly_periods set current_status='awaiting_final_approval',
    record_version=record_version+1,updated_by_auth_user_id=v_actor,
    updated_at=clock_timestamp() where id=v_period_id;
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_period_verified',
    'workforce_monthly_period',v_period_id,null,to_jsonb(v_period),v_response,v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency('v1_verify_workforce_monthly_period',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_workforce_t07_snapshot_payload(
  p_period_id uuid,p_approved_by uuid,p_approved_role text,p_approved_at timestamptz
) returns jsonb language sql security definer set search_path='' as $$
  select jsonb_build_object(
    'schema_version',1,'snapshot_kind','workforce_monthly_approved_period',
    'period',jsonb_build_object('period_id',period.id,'team_id',period.team_id,
      'period_month',period.period_month,'approval_revision_number',
      period.current_approval_revision_number,'validation_run_id',run.id,
      'validation_number',run.validation_number,'source_fingerprint',run.source_fingerprint),
    'approval',jsonb_build_object('approved_by_auth_user_id',p_approved_by,
      'approved_by_exact_role',p_approved_role,'approved_at',p_approved_at,
      'locked_at',p_approved_at),
    'summary',to_jsonb(run)-array['authority_snapshot','idempotency_key']::text[],
    'workers',coalesce((select jsonb_agg(to_jsonb(worker) order by worker.worker_number_snapshot,worker.id)
      from public.v1_workforce_monthly_period_workers worker
      where worker.validation_run_id=run.id),'[]'::jsonb),
    'dates',coalesce((select jsonb_agg(to_jsonb(day) order by day.worker_id,day.work_date,day.id)
      from public.v1_workforce_monthly_period_dates day
      where day.validation_run_id=run.id),'[]'::jsonb),
    'issues',coalesce((select jsonb_agg(to_jsonb(issue) order by issue.sort_order,issue.worker_id,
        issue.work_date,issue.issue_code,issue.id)
      from public.v1_workforce_monthly_validation_issues issue
      where issue.validation_run_id=run.id),'[]'::jsonb),
    'review_chain',coalesce((select jsonb_agg(to_jsonb(transition)
        order by transition.occurred_at,transition.id)
      from public.v1_workforce_monthly_transitions transition
      where transition.period_id=period.id
        and transition.approval_revision_number=period.current_approval_revision_number),
      '[]'::jsonb),
    'reviewer_corrections',coalesce((select jsonb_agg(to_jsonb(correction)
        order by correction.corrected_at,correction.id)
      from public.v1_workforce_monthly_reviewer_corrections correction
      where correction.period_id=period.id
        and correction.approval_revision_number=period.current_approval_revision_number),
      '[]'::jsonb)
  ) from public.v1_workforce_monthly_periods period
  join public.v1_workforce_monthly_validation_runs run
    on run.id=period.current_validation_run_id
  where period.id=p_period_id;
$$;

create or replace function public.v1_approve_lock_workforce_monthly_period(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid; v_reason text;
  v_period public.v1_workforce_monthly_periods%rowtype; v_existing jsonb;
  v_snapshot_id uuid:=gen_random_uuid(); v_snapshot jsonb; v_snapshot_hash text;
  v_approved_at timestamptz:=clock_timestamp(); v_response jsonb;
begin
  if v_actor is null or p_expected_period_version is null or p_expected_period_version<1
    or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_APPROVE_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['period_id','reason'],
    'approve_lock_workforce_monthly_period');
  if not (p_payload?&array['period_id','reason']) then
    raise exception 'V1_WORKFORCE_T07_APPROVE_INVALID' using errcode='22023'; end if;
  begin v_period_id:=(p_payload->>'period_id')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_APPROVE_INVALID' using errcode='22023'; end;
  v_reason:=btrim(coalesce(p_payload->>'reason',''));
  if v_reason='' or char_length(v_reason)>2000 then
    raise exception 'V1_WORKFORCE_T07_APPROVE_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  if not public.v1_workforce_t07_period_authorized(
      'workforce.timesheets.final_approve',v_period_id,true) then
    raise exception 'V1_WORKFORCE_T07_APPROVE_DENIED' using errcode='42501'; end if;
  if public.v1_workforce_t07_submitter(v_period_id,
      v_period.current_approval_revision_number)=v_actor
    or exists(select 1 from public.v1_workforce_monthly_transitions transition
      where transition.period_id=v_period_id
        and transition.approval_revision_number=v_period.current_approval_revision_number
        and transition.action_kind in (
          'return_for_correction','reviewer_correction','verify_forward'
        )
        and transition.actor_auth_user_id=v_actor) then
    raise exception 'V1_WORKFORCE_T07_SELF_ACTION_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_approve_lock_workforce_monthly_period',
    p_idempotency_key,jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status<>'awaiting_final_approval'
    or not public.v1_workforce_t07_current_source_valid(v_period_id) then
    raise exception 'V1_WORKFORCE_T07_APPROVE_STATE_INVALID' using errcode='23514'; end if;
  v_snapshot:=public.v1_workforce_t07_snapshot_payload(v_period_id,v_actor,v_role,v_approved_at);
  if v_snapshot is null then raise exception 'V1_WORKFORCE_T07_SNAPSHOT_INVALID' using errcode='23514'; end if;
  v_snapshot_hash:=public.v1_hash_json(v_snapshot);
  insert into public.v1_workforce_monthly_approved_snapshots(id,period_id,
    approval_revision_number,validation_run_id,snapshot_payload,snapshot_hash,
    approved_by_auth_user_id,approved_by_exact_role,approved_at,locked_at)
  values(v_snapshot_id,v_period_id,v_period.current_approval_revision_number,
    v_period.current_validation_run_id,v_snapshot,v_snapshot_hash,v_actor,v_role,
    v_approved_at,v_approved_at);
  insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
    action_kind,from_status,to_status,from_record_version,to_record_version,
    validation_run_id,source_fingerprint,actor_auth_user_id,actor_exact_role,
    capability_key,reason,idempotency_key)
  select v_period_id,v_period.current_approval_revision_number,'approve_lock',
    v_period.current_status,'locked',v_period.record_version,v_period.record_version+1,
    v_period.current_validation_run_id,run.source_fingerprint,v_actor,v_role,
    'workforce.timesheets.final_approve',v_reason,p_idempotency_key
  from public.v1_workforce_monthly_validation_runs run where run.id=v_period.current_validation_run_id;
  update public.v1_workforce_monthly_periods set current_status='locked',
    current_edit_scope_id=null,record_version=record_version+1,
    updated_by_auth_user_id=v_actor,updated_at=v_approved_at where id=v_period_id;
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_period_approved_and_locked',
    'workforce_monthly_period',v_period_id,null,to_jsonb(v_period),v_response,v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency(
    'v1_approve_lock_workforce_monthly_period',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_request_workforce_monthly_reopen(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid; v_reason text;
  v_attachment text; v_entries jsonb; v_period public.v1_workforce_monthly_periods%rowtype;
  v_request_id uuid:=gen_random_uuid(); v_existing jsonb; v_response jsonb;
begin
  if v_actor is null or p_expected_period_version is null or p_expected_period_version<1
    or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,
    array['period_id','reason','affected_entries','attachment_reference'],
    'request_workforce_monthly_reopen');
  if not (p_payload?&array['period_id','reason','affected_entries']) then
    raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_INVALID' using errcode='22023'; end if;
  begin v_period_id:=(p_payload->>'period_id')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_INVALID' using errcode='22023'; end;
  v_reason:=btrim(coalesce(p_payload->>'reason',''));
  v_attachment:=nullif(btrim(coalesce(p_payload->>'attachment_reference','')),'');
  if v_reason='' or char_length(v_reason)>2000 or char_length(coalesce(v_attachment,''))>500 then
    raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  if not public.v1_workforce_t07_period_authorized('workforce.timesheets.maintain',v_period_id,true)
    then raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_request_workforce_monthly_reopen',
    p_idempotency_key,jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status<>'locked' or not exists(
      select 1 from public.v1_workforce_monthly_approved_snapshots snapshot
      where snapshot.period_id=v_period_id
        and snapshot.approval_revision_number=v_period.current_approval_revision_number)
    or exists(select 1 from public.v1_workforce_monthly_reopen_requests request
      where request.period_id=v_period_id and request.authorized_at is null) then
    raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_STATE_INVALID' using errcode='23514'; end if;
  v_entries:=public.v1_workforce_t07_validate_entries(v_period_id,p_payload->'affected_entries');
  insert into public.v1_workforce_monthly_reopen_requests(id,period_id,
    locked_revision_number,reason,attachment_reference,affected_entries,
    requested_by_auth_user_id,requested_by_exact_role,idempotency_key)
  values(v_request_id,v_period_id,v_period.current_approval_revision_number,v_reason,
    v_attachment,v_entries,v_actor,v_role,p_idempotency_key);
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_reopen_requested',
    'workforce_monthly_period',v_period_id,null,null,jsonb_build_object(
      'request_id',v_request_id,'affected_entries',v_entries),v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency('v1_request_workforce_monthly_reopen',
    p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_authorize_workforce_monthly_reopen(
  p_payload jsonb,p_expected_period_version bigint,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_period_id uuid; v_request_id uuid;
  v_reason text; v_period public.v1_workforce_monthly_periods%rowtype;
  v_request public.v1_workforce_monthly_reopen_requests%rowtype;
  v_snapshot public.v1_workforce_monthly_approved_snapshots%rowtype;
  v_new_revision bigint; v_scope_id uuid:=gen_random_uuid(); v_item jsonb;
  v_existing jsonb; v_response jsonb;
begin
  if v_actor is null or p_expected_period_version is null or p_expected_period_version<1
    or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['period_id','request_id','reason'],
    'authorize_workforce_monthly_reopen');
  if not (p_payload?&array['period_id','request_id','reason']) then
    raise exception 'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_INVALID' using errcode='22023'; end if;
  begin v_period_id:=(p_payload->>'period_id')::uuid;
    v_request_id:=(p_payload->>'request_id')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_INVALID' using errcode='22023'; end;
  v_reason:=btrim(coalesce(p_payload->>'reason',''));
  if v_reason='' or char_length(v_reason)>2000 then
    raise exception 'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor); v_role:=public.v1_permission_exact_role(v_actor);
  perform pg_advisory_xact_lock(hashtextextended('v1_workforce_t07_period|'||v_period_id,0));
  select * into v_period from public.v1_workforce_monthly_periods where id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  select * into v_request from public.v1_workforce_monthly_reopen_requests request
    where request.id=v_request_id and request.period_id=v_period_id for update;
  if not found then raise exception 'V1_WORKFORCE_T07_REOPEN_REQUEST_NOT_FOUND' using errcode='P0002'; end if;
  if not public.v1_workforce_t07_period_authorized('workforce.periods.reopen',v_period_id,true)
    then raise exception 'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_DENIED' using errcode='42501'; end if;
  if v_request.requested_by_auth_user_id=v_actor then
    raise exception 'V1_WORKFORCE_T07_SELF_ACTION_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_authorize_workforce_monthly_reopen',
    p_idempotency_key,jsonb_build_object('payload',p_payload,'expected_period_version',p_expected_period_version));
  if v_existing is not null then return v_existing; end if;
  if v_period.record_version<>p_expected_period_version then
    raise exception 'V1_WORKFORCE_MONTHLY_PERIOD_VERSION_CONFLICT' using errcode='40001'; end if;
  if v_period.current_status<>'locked' or v_request.authorized_at is not null
    or v_request.locked_revision_number<>v_period.current_approval_revision_number then
    raise exception 'V1_WORKFORCE_T07_REOPEN_AUTHORIZE_STATE_INVALID' using errcode='23514'; end if;
  select * into strict v_snapshot from public.v1_workforce_monthly_approved_snapshots snapshot
    where snapshot.period_id=v_period_id
      and snapshot.approval_revision_number=v_period.current_approval_revision_number;
  v_new_revision:=v_period.current_approval_revision_number+1;
  insert into public.v1_workforce_monthly_approval_revisions(period_id,revision_number,
    opened_from_snapshot_id,opened_reason,opened_by_auth_user_id,opened_by_exact_role)
  values(v_period_id,v_new_revision,v_snapshot.id,v_reason,v_actor,v_role);
  insert into public.v1_workforce_monthly_edit_scopes(id,period_id,approval_revision_number,
    scope_kind,reason,attachment_reference,created_by_auth_user_id)
  values(v_scope_id,v_period_id,v_new_revision,'reopen',v_request.reason,
    v_request.attachment_reference,v_actor);
  for v_item in select value from jsonb_array_elements(v_request.affected_entries) loop
    insert into public.v1_workforce_monthly_edit_scope_entries(edit_scope_id,worker_id,work_date)
    values(v_scope_id,(v_item->>'worker_id')::uuid,(v_item->>'work_date')::date);
  end loop;
  insert into public.v1_workforce_monthly_transitions(period_id,approval_revision_number,
    action_kind,from_status,to_status,from_record_version,to_record_version,
    validation_run_id,source_fingerprint,actor_auth_user_id,actor_exact_role,
    capability_key,reason,idempotency_key)
  select v_period_id,v_new_revision,'reopen_authorized',v_period.current_status,'reopened',
    v_period.record_version,v_period.record_version+1,v_period.current_validation_run_id,
    run.source_fingerprint,v_actor,v_role,'workforce.periods.reopen',v_reason,p_idempotency_key
  from public.v1_workforce_monthly_validation_runs run where run.id=v_period.current_validation_run_id;
  update public.v1_workforce_monthly_reopen_requests set
    authorized_by_auth_user_id=v_actor,authorized_by_exact_role=v_role,
    authorized_at=clock_timestamp(),authorization_reason=v_reason,
    new_revision_number=v_new_revision,authorization_idempotency_key=p_idempotency_key
  where id=v_request_id;
  update public.v1_workforce_monthly_periods set current_status='reopened',
    current_approval_revision_number=v_new_revision,current_edit_scope_id=v_scope_id,
    record_version=record_version+1,updated_by_auth_user_id=v_actor,
    updated_at=clock_timestamp() where id=v_period_id;
  v_response:=public.v1_workforce_monthly_lifecycle_json(v_period_id);
  perform public.v1_write_audit_event('workforce_monthly_reopen_authorized',
    'workforce_monthly_period',v_period_id,null,to_jsonb(v_period),v_response,v_reason,p_idempotency_key);
  perform public.v1_complete_idempotency('v1_authorize_workforce_monthly_reopen',
    p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_get_workforce_monthly_lifecycle(
  p_period_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null or p_period_id is null then
    raise exception 'V1_WORKFORCE_T07_READ_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  if not public.v1_workforce_t07_period_authorized('workforce.view',p_period_id,false) then
    raise exception 'V1_WORKFORCE_T07_READ_DENIED' using errcode='42501'; end if;
  return public.v1_workforce_monthly_lifecycle_json(p_period_id);
end;
$$;

create or replace function public.v1_list_workforce_monthly_approval_queue(
  p_status text default null,p_limit integer default 50,p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_status text:=nullif(btrim(coalesce(p_status,'')),'');
  v_items jsonb; v_count bigint;
begin
  if v_actor is null or p_limit is null or p_limit<1 or p_limit>100
    or p_offset is null or p_offset<0
    or (v_status is not null and v_status not in ('draft','ready_for_review',
      'submitted','under_review','returned_for_correction',
      'awaiting_final_approval','locked','reopened')) then
    raise exception 'V1_WORKFORCE_T07_QUEUE_INVALID' using errcode='22023'; end if;
  perform public.v1_sync_profile_from_auth(v_actor);
  with authorized as materialized (
    select period.id,period.period_month,team.team_name,period.current_status,
      period.updated_at
    from public.v1_workforce_monthly_periods period
    join public.v1_workforce_teams team on team.id=period.team_id
    where (v_status is null or period.current_status=v_status)
      and public.v1_workforce_t07_period_authorized('workforce.view',period.id,false)
  ), page as (
    select * from authorized order by period_month desc,lower(team_name),id
    limit p_limit offset p_offset
  )
  select (select count(*) from authorized),coalesce((select jsonb_agg(
    jsonb_build_object('period_id',page.id,'team_name',page.team_name,
      'period_month',page.period_month,'status',page.current_status,
      'updated_at',page.updated_at,'lifecycle',
      public.v1_workforce_monthly_lifecycle_json(page.id))
    order by page.period_month desc,lower(page.team_name),page.id) from page),'[]'::jsonb)
  into v_count,v_items;
  return jsonb_build_object('schema_version',1,'authorization_mode','enforced_t07',
    'status_filter',v_status,'limit',p_limit,'offset',p_offset,
    'total_count',v_count,'items',v_items);
end;
$$;

update public.v1_capability_catalog
set status='operational',authorization_mode='enforced',is_assignable=true
where capability_key in ('workforce.timesheets.review',
  'workforce.timesheets.correct_during_review','workforce.timesheets.verify',
  'workforce.timesheets.final_approve','workforce.periods.reopen');

do $workforce_t07_capability_contract$
begin
  if (select count(*) from public.v1_capability_catalog catalog
      where public.v1_workforce_is_capability_key(catalog.capability_key)
        and catalog.status='operational' and catalog.authorization_mode='enforced'
        and catalog.is_assignable)<>8
    or exists(select 1 from public.v1_capability_catalog catalog
      where public.v1_workforce_is_capability_key(catalog.capability_key)
        and catalog.capability_key not in ('workforce.view',
          'workforce.attendance.maintain','workforce.timesheets.maintain',
          'workforce.timesheets.review','workforce.timesheets.correct_during_review',
          'workforce.timesheets.verify','workforce.timesheets.final_approve',
          'workforce.periods.reopen') and (catalog.status<>'planned'
            or catalog.authorization_mode<>'shadow' or catalog.is_assignable)) then
    raise exception 'V1_WORKFORCE_T07_CAPABILITY_CUTOVER_CONFLICT' using errcode='23514';
  end if;
end;
$workforce_t07_capability_contract$;

revoke all on function public.v1_workforce_t07_block_history_change()
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_guard_reopen_request()
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_context_active(uuid,uuid,date)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_entry_mutation_allowed(uuid,uuid,date,uuid)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_period_authorized(text,uuid,boolean)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_validate_entries(uuid,jsonb)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_monthly_lifecycle_json(uuid)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_child_key(uuid,text)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_submitter(uuid,bigint)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_current_source_valid(uuid)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_validate_warning_acknowledgements(uuid,jsonb)
  from public,anon,authenticated;
revoke all on function public.v1_workforce_t07_snapshot_payload(uuid,uuid,text,timestamptz)
  from public,anon,authenticated;

revoke all on function public.v1_get_workforce_monthly_lifecycle(uuid)
  from public,anon;
revoke all on function public.v1_list_workforce_monthly_approval_queue(text,integer,integer)
  from public,anon;
revoke all on function public.v1_submit_workforce_monthly_period(jsonb,bigint,uuid)
  from public,anon;
revoke all on function public.v1_return_workforce_monthly_period(jsonb,bigint,uuid)
  from public,anon;
revoke all on function public.v1_correct_workforce_monthly_entry_during_review(jsonb,bigint,uuid)
  from public,anon;
revoke all on function public.v1_verify_workforce_monthly_period(jsonb,bigint,uuid)
  from public,anon;
revoke all on function public.v1_approve_lock_workforce_monthly_period(jsonb,bigint,uuid)
  from public,anon;
revoke all on function public.v1_request_workforce_monthly_reopen(jsonb,bigint,uuid)
  from public,anon;
revoke all on function public.v1_authorize_workforce_monthly_reopen(jsonb,bigint,uuid)
  from public,anon;

grant execute on function public.v1_get_workforce_monthly_lifecycle(uuid)
  to authenticated;
grant execute on function public.v1_list_workforce_monthly_approval_queue(text,integer,integer)
  to authenticated;
grant execute on function public.v1_submit_workforce_monthly_period(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_return_workforce_monthly_period(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_correct_workforce_monthly_entry_during_review(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_verify_workforce_monthly_period(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_approve_lock_workforce_monthly_period(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_request_workforce_monthly_reopen(jsonb,bigint,uuid)
  to authenticated;
grant execute on function public.v1_authorize_workforce_monthly_reopen(jsonb,bigint,uuid)
  to authenticated;

comment on table public.v1_workforce_monthly_approved_snapshots is
  'T07 immutable approved-and-locked monthly snapshots; no payroll or cost data.';
comment on function public.v1_submit_workforce_monthly_period(jsonb,bigint,uuid) is
  'T07 explicit submit with exact warning acknowledgement and optimistic versioning.';
comment on function public.v1_approve_lock_workforce_monthly_period(jsonb,bigint,uuid) is
  'T07 atomic final approval and immutable lock; separation enforced server-side.';

commit;
