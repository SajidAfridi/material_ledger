-- Yorks Workforce T08: canonical collaboration, evidence and notification
-- projections. This additive slice reuses Team Chat, Yorks Documents and the
-- trusted notification/push outbox. It creates no workflow transition,
-- scheduler, report/export, new capability, legacy migration or release.

begin;

create table public.v1_workforce_timesheet_discussions (
  period_id uuid primary key
    references public.v1_workforce_monthly_periods(id) on delete restrict,
  conversation_id uuid not null unique
    references public.v1_chat_conversations(id) on delete restrict,
  created_by_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

create table public.v1_workforce_document_upload_metadata (
  upload_intent_id uuid primary key
    references public.v1_document_upload_intents(id) on delete restrict,
  evidence_type text not null check (evidence_type in (
    'medical_certificate','leave_document','overtime_authorization',
    'worker_transfer_note','site_attendance_sheet',
    'daily_supporting_photo','monthly_timesheet_attachment',
    'other_workforce_document'
  )),
  worker_id uuid references public.v1_workforce_workers(id) on delete restrict,
  attendance_day_id uuid references public.v1_workforce_attendance_days(id)
    on delete restrict,
  period_id uuid references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  retained_project_id uuid references public.v1_projects(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  check (worker_id is not null or attendance_day_id is not null
    or period_id is not null)
);

create table public.v1_workforce_document_version_metadata (
  document_version_id uuid primary key
    references public.v1_document_versions(id) on delete restrict,
  document_id uuid not null references public.v1_documents(id) on delete restrict,
  evidence_type text not null check (evidence_type in (
    'medical_certificate','leave_document','overtime_authorization',
    'worker_transfer_note','site_attendance_sheet',
    'daily_supporting_photo','monthly_timesheet_attachment',
    'other_workforce_document'
  )),
  worker_id uuid references public.v1_workforce_workers(id) on delete restrict,
  attendance_day_id uuid references public.v1_workforce_attendance_days(id)
    on delete restrict,
  period_id uuid references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  retained_project_id uuid references public.v1_projects(id) on delete restrict,
  created_at timestamptz not null default clock_timestamp(),
  check (worker_id is not null or attendance_day_id is not null
    or period_id is not null)
);

create index v1_workforce_document_versions_period_idx
  on public.v1_workforce_document_version_metadata(period_id,created_at desc);
create index v1_workforce_document_versions_day_idx
  on public.v1_workforce_document_version_metadata(attendance_day_id,created_at desc);
create index v1_workforce_document_versions_worker_idx
  on public.v1_workforce_document_version_metadata(worker_id,created_at desc);

create table public.v1_workforce_notification_deliveries (
  source_audit_event_id uuid not null
    references public.v1_audit_events(id) on delete restrict,
  recipient_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  event_code text not null,
  notification_id uuid not null unique
    references public.v1_notifications(id) on delete restrict
      deferrable initially deferred,
  created_at timestamptz not null default clock_timestamp(),
  primary key(source_audit_event_id,recipient_auth_user_id,event_code)
);

create table public.v1_workforce_notification_digests (
  id uuid primary key default gen_random_uuid(),
  digest_kind text not null check (digest_kind in (
    'daily_attendance_missing','monthly_period_incomplete'
  )),
  team_id uuid not null references public.v1_workforce_teams(id) on delete restrict,
  work_date date,
  period_id uuid references public.v1_workforce_monthly_periods(id)
    on delete restrict,
  recipient_auth_user_id uuid not null
    references public.v1_profiles(auth_user_id) on delete restrict,
  item_count integer not null check (item_count > 0),
  notification_id uuid not null unique
    references public.v1_notifications(id) on delete restrict
      deferrable initially deferred,
  idempotency_key uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  check ((digest_kind='daily_attendance_missing' and work_date is not null
      and period_id is null)
    or (digest_kind='monthly_period_incomplete' and work_date is null
      and period_id is not null)),
  unique nulls not distinct (
    digest_kind,team_id,work_date,period_id,recipient_auth_user_id
  )
);

alter table public.v1_workforce_timesheet_discussions enable row level security;
alter table public.v1_workforce_document_upload_metadata enable row level security;
alter table public.v1_workforce_document_version_metadata enable row level security;
alter table public.v1_workforce_notification_deliveries enable row level security;
alter table public.v1_workforce_notification_digests enable row level security;

revoke all on table public.v1_workforce_timesheet_discussions,
  public.v1_workforce_document_upload_metadata,
  public.v1_workforce_document_version_metadata,
  public.v1_workforce_notification_deliveries,
  public.v1_workforce_notification_digests
from public,anon,authenticated;
grant all on table public.v1_workforce_timesheet_discussions,
  public.v1_workforce_document_upload_metadata,
  public.v1_workforce_document_version_metadata,
  public.v1_workforce_notification_deliveries,
  public.v1_workforce_notification_digests to service_role;

create trigger v1_workforce_timesheet_discussions_no_delete
before delete on public.v1_workforce_timesheet_discussions
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_document_upload_metadata_no_delete
before delete on public.v1_workforce_document_upload_metadata
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_document_version_metadata_no_delete
before delete on public.v1_workforce_document_version_metadata
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_notification_deliveries_no_delete
before delete on public.v1_workforce_notification_deliveries
for each row execute function public.v1_workforce_block_delete();
create trigger v1_workforce_notification_digests_no_delete
before delete on public.v1_workforce_notification_digests
for each row execute function public.v1_workforce_block_delete();

-- Canonical Chat and Documents already retain exact roles. T08 widens only
-- their storage checks to the complete nine-role Yorks catalog; authorization
-- still comes from the trusted entity/capability predicates below.
alter table public.v1_chat_conversations
  drop constraint if exists v1_chat_conversations_created_by_exact_role_check;
alter table public.v1_chat_conversations add constraint
  v1_chat_conversations_created_by_exact_role_check check (
    created_by_exact_role in ('project_engineer','site_engineer',
      'senior_mechanical_engineer','project_manager','workshop_in_charge',
      'document_controller','procurement','accountant','admin'));
alter table public.v1_chat_messages
  drop constraint if exists v1_chat_messages_sender_exact_role_check;
alter table public.v1_chat_messages add constraint
  v1_chat_messages_sender_exact_role_check check (sender_exact_role is null or
    sender_exact_role in ('project_engineer','site_engineer',
      'senior_mechanical_engineer','project_manager','workshop_in_charge',
      'document_controller','procurement','accountant','admin'));
alter table public.v1_chat_messages
  drop constraint if exists v1_chat_messages_linked_entity_type_check;
alter table public.v1_chat_messages add constraint
  v1_chat_messages_linked_entity_type_check check (
    linked_entity_type is null or linked_entity_type in (
      'project','material_request','workforce_worker',
      'workforce_attendance_day','workforce_monthly_period'));

alter table public.v1_documents
  drop constraint if exists v1_documents_created_by_role_check;
alter table public.v1_documents add constraint v1_documents_created_by_role_check
  check (created_by_role in ('project_engineer','site_engineer',
    'senior_mechanical_engineer','project_manager','workshop_in_charge',
    'document_controller','procurement','accountant','admin'));
alter table public.v1_document_versions
  drop constraint if exists v1_document_versions_uploaded_by_role_check;
alter table public.v1_document_versions add constraint
  v1_document_versions_uploaded_by_role_check check (uploaded_by_role in (
    'project_engineer','site_engineer','senior_mechanical_engineer',
    'project_manager','workshop_in_charge','document_controller','procurement',
    'accountant','admin'));
alter table public.v1_document_links
  drop constraint if exists v1_document_links_linked_by_role_check;
alter table public.v1_document_links add constraint
  v1_document_links_linked_by_role_check check (linked_by_role in (
    'project_engineer','site_engineer','senior_mechanical_engineer',
    'project_manager','workshop_in_charge','document_controller','procurement',
    'accountant','admin'));
alter table public.v1_document_links
  drop constraint if exists v1_document_links_removed_by_role_check;
alter table public.v1_document_links add constraint
  v1_document_links_removed_by_role_check check (removed_by_role is null or
    removed_by_role in ('project_engineer','site_engineer',
      'senior_mechanical_engineer','project_manager','workshop_in_charge',
      'document_controller','procurement','accountant','admin'));
alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_actor_role_check;
alter table public.v1_document_upload_intents add constraint
  v1_document_upload_intents_actor_role_check check (actor_role in (
    'project_engineer','site_engineer','senior_mechanical_engineer',
    'project_manager','workshop_in_charge','document_controller','procurement',
    'accountant','admin'));
alter table public.v1_document_links
  drop constraint if exists v1_document_links_entity_type_check;
alter table public.v1_document_links add constraint
  v1_document_links_entity_type_check check (entity_type in (
    'project','boq_group','material_request','dispatch','receipt_review',
    'material_return','delivery_order','rental_property','supplier',
    'supplier_receipt_batch','accounts_baseline_revision',
    'accounts_billing_progress_revision','accounts_client_claim',
    'accounts_client_invoice','accounts_client_certification',
    'accounts_client_payment','accounts_client_pdc',
    'accounts_supplier_bill','accounts_supplier_match','workforce_worker',
    'workforce_attendance_day','workforce_monthly_period'));
alter table public.v1_document_upload_intents
  drop constraint if exists v1_document_upload_intents_target_entity_type_check;
alter table public.v1_document_upload_intents add constraint
  v1_document_upload_intents_target_entity_type_check check (
    target_entity_type in ('project','boq_group','material_request','dispatch',
      'receipt_review','material_return','delivery_order','rental_property',
      'supplier','supplier_receipt_batch','accounts_baseline_revision',
      'accounts_billing_progress_revision','accounts_client_claim',
      'accounts_client_invoice','accounts_client_certification',
      'accounts_client_payment','accounts_client_pdc',
      'accounts_supplier_bill','accounts_supplier_match','workforce_worker',
      'workforce_attendance_day','workforce_monthly_period'));

create or replace function public.v1_chat_exact_role(p_auth_user_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select public.v1_permission_exact_role(p_auth_user_id);
$$;

create or replace function public.v1_workforce_t08_actor_has_capability(
  p_actor uuid,p_capability_key text,p_project_id uuid default null
) returns boolean language sql stable security definer set search_path='' as $$
  select p_actor is not null
    and public.v1_permission_exact_role(p_actor)<>''
    and coalesce((public.v1_permission_authoritative_resolution(
      p_actor,p_capability_key,p_project_id)->>'effective')::boolean,false);
$$;

create or replace function public.v1_workforce_t08_period_actor_authorized(
  p_actor uuid,p_capability_key text,p_period_id uuid,
  p_require_targets boolean default true
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_period public.v1_workforce_monthly_periods%rowtype;
  v_date public.v1_workforce_monthly_period_dates%rowtype; v_target jsonb;
begin
  if p_actor is null or p_capability_key not in (
    'workforce.view','workforce.attendance.maintain',
    'workforce.timesheets.maintain','workforce.timesheets.review',
    'workforce.timesheets.correct_during_review','workforce.timesheets.verify',
    'workforce.timesheets.final_approve','workforce.periods.reopen')
    or public.v1_permission_exact_role(p_actor)='' then return false; end if;
  select * into v_period from public.v1_workforce_monthly_periods
    where id=p_period_id;
  if not found then return false; end if;
  if public.v1_permission_exact_role(p_actor)='admin' then
    return public.v1_workforce_t08_actor_has_capability(
      p_actor,p_capability_key,null);
  end if;
  if not exists(select 1 from public.v1_workforce_monthly_period_dates d
    where d.validation_run_id=v_period.current_validation_run_id) then
    return false;
  end if;
  for v_date in select * from public.v1_workforce_monthly_period_dates d
    where d.validation_run_id=v_period.current_validation_run_id loop
    if not public.v1_workforce_t08_actor_has_capability(p_actor,p_capability_key,
        nullif(v_date.assignment_snapshot->>'project_id','')::uuid)
      or public.v1_workforce_matching_responsibility(p_actor,v_date.worker_id,
        v_date.work_date,
        nullif(v_date.assignment_snapshot->>'team_id','')::uuid,
        nullif(v_date.assignment_snapshot->>'project_id','')::uuid,
        nullif(v_date.assignment_snapshot->>'project_scope_id','')::uuid,
        nullif(v_date.assignment_snapshot->>'internal_location_id','')::uuid)
        ='{}'::jsonb then return false; end if;
    if p_require_targets
      and v_date.allocation_snapshot->>'allocation_state'='active' then
      for v_target in select value from jsonb_array_elements(
        coalesce(v_date.allocation_snapshot->'targets','[]'::jsonb)) loop
        if not public.v1_workforce_t08_actor_has_capability(p_actor,
            p_capability_key,case when v_target->>'target_kind'='project_work'
              then nullif(v_target->>'project_id','')::uuid else null end)
          or not exists(select 1
            from public.v1_workforce_responsibility_assignments r
            where r.auth_user_id=p_actor and r.valid_from<=v_date.work_date
              and (r.valid_to is null or r.valid_to>=v_date.work_date) and (
                r.scope_kind='organization' or
                (v_target->>'target_kind'='project_work' and (
                  (r.scope_kind='project' and r.project_id=
                    nullif(v_target->>'project_id','')::uuid) or
                  (r.scope_kind='project_scope' and r.project_id=
                    nullif(v_target->>'project_id','')::uuid and
                    r.project_scope_id=
                      nullif(v_target->>'project_scope_id','')::uuid))) or
                (v_target->>'target_kind'='internal_work'
                  and r.scope_kind='internal_location'
                  and r.internal_location_id=
                    nullif(v_target->>'internal_location_id','')::uuid)))
        then return false; end if;
      end loop;
    end if;
  end loop;
  return true;
end;
$$;

create or replace function public.v1_workforce_t08_day_actor_authorized(
  p_actor uuid,p_capability_key text,p_day_id uuid,
  p_require_targets boolean default true
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_day public.v1_workforce_attendance_days%rowtype;
  v_set public.v1_workforce_timesheet_allocation_sets%rowtype; v_target record;
begin
  select * into v_day from public.v1_workforce_attendance_days where id=p_day_id;
  if not found or public.v1_permission_exact_role(p_actor)='' or
    not public.v1_workforce_t08_actor_has_capability(p_actor,p_capability_key,
      v_day.assignment_project_id_snapshot) then return false; end if;
  if public.v1_permission_exact_role(p_actor)<>'admin' and
    public.v1_workforce_matching_responsibility(p_actor,v_day.worker_id,
      v_day.work_date,v_day.assignment_team_id_snapshot,
      v_day.assignment_project_id_snapshot,v_day.assignment_project_scope_id_snapshot,
      v_day.assignment_internal_location_id_snapshot)='{}'::jsonb
    then return false; end if;
  if not p_require_targets then return true; end if;
  select * into v_set from public.v1_workforce_timesheet_allocation_sets s
    where s.attendance_day_id=p_day_id and s.current_state='active';
  if not found then return true; end if;
  for v_target in select a.* from public.v1_workforce_timesheet_allocations a
    where a.allocation_revision_id=v_set.current_revision_id loop
    if not public.v1_workforce_t08_actor_has_capability(p_actor,p_capability_key,
        v_target.project_id)
      or (public.v1_permission_exact_role(p_actor)<>'admin' and not exists(
        select 1 from public.v1_workforce_responsibility_assignments r
        where r.auth_user_id=p_actor and r.valid_from<=v_day.work_date
          and (r.valid_to is null or r.valid_to>=v_day.work_date) and (
            r.scope_kind='organization' or
            (v_target.target_kind='project_work' and (
              (r.scope_kind='project' and r.project_id=v_target.project_id) or
              (r.scope_kind='project_scope' and r.project_id=v_target.project_id
                and r.project_scope_id=v_target.project_scope_id))) or
            (v_target.target_kind='internal_work'
              and r.scope_kind='internal_location'
              and r.internal_location_id=v_target.internal_location_id))))
      then return false; end if;
  end loop;
  return true;
end;
$$;

create or replace function public.v1_workforce_t08_worker_actor_authorized(
  p_actor uuid,p_capability_key text,p_worker_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select public.v1_permission_exact_role(p_actor)='admin'
      and public.v1_workforce_t08_actor_has_capability(
        p_actor,p_capability_key,null)
    or (public.v1_workforce_t08_actor_has_capability(
          p_actor,p_capability_key,null) and exists(
      select 1 from public.v1_workforce_responsibility_assignments r
      where r.auth_user_id=p_actor
        and r.valid_from<=(clock_timestamp() at time zone 'UTC')::date
        and (r.valid_to is null or r.valid_to>=
          (clock_timestamp() at time zone 'UTC')::date)
        and (r.scope_kind='organization'
          or (r.scope_kind='worker' and r.worker_id=p_worker_id))));
$$;

create or replace function public.v1_workforce_t08_target_readable(
  p_actor uuid,p_entity_type text,p_entity_id uuid
) returns boolean language sql stable security definer set search_path='' as $$
  select case p_entity_type
    when 'workforce_monthly_period' then
      public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.view',p_entity_id,false)
    when 'workforce_attendance_day' then
      public.v1_workforce_t08_day_actor_authorized(
        p_actor,'workforce.view',p_entity_id,false)
    when 'workforce_worker' then
      public.v1_workforce_t08_worker_actor_authorized(
        p_actor,'workforce.view',p_entity_id)
    else false end;
$$;

create or replace function public.v1_workforce_t08_target_writable(
  p_actor uuid,p_entity_type text,p_entity_id uuid
) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
  if public.v1_permission_exact_role(p_actor)='admin'
    and public.v1_workforce_t08_actor_has_capability(
      p_actor,'workforce.view',null) then return true; end if;
  if p_entity_type='workforce_monthly_period' then
    return public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.timesheets.maintain',p_entity_id,true)
      or public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.timesheets.review',p_entity_id,true)
      or public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.timesheets.correct_during_review',p_entity_id,true)
      or public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.timesheets.verify',p_entity_id,true)
      or public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.timesheets.final_approve',p_entity_id,true)
      or public.v1_workforce_t08_period_actor_authorized(
        p_actor,'workforce.periods.reopen',p_entity_id,true);
  elsif p_entity_type='workforce_attendance_day' then
    return public.v1_workforce_t08_day_actor_authorized(
        p_actor,'workforce.attendance.maintain',p_entity_id,true)
      or public.v1_workforce_t08_day_actor_authorized(
        p_actor,'workforce.timesheets.maintain',p_entity_id,true)
      or public.v1_workforce_t08_day_actor_authorized(
        p_actor,'workforce.timesheets.correct_during_review',p_entity_id,true);
  elsif p_entity_type='workforce_worker' then
    return public.v1_workforce_t08_worker_actor_authorized(
      p_actor,'workforce.attendance.maintain',p_entity_id);
  end if;
  return false;
end;
$$;

create or replace function public.v1_workforce_t08_sync_discussion_members(
  p_conversation_id uuid
) returns void language plpgsql security definer set search_path='' as $$
declare v_period_id uuid; v_creator uuid;
begin
  select d.period_id,c.created_by_auth_user_id into v_period_id,v_creator
  from public.v1_workforce_timesheet_discussions d
  join public.v1_chat_conversations c on c.id=d.conversation_id
  where d.conversation_id=p_conversation_id;
  if v_period_id is null then return; end if;
  insert into public.v1_chat_members(conversation_id,auth_user_id,member_role)
  select p_conversation_id,p.auth_user_id,
    case when p.auth_user_id=v_creator then 'owner' else 'member' end
  from public.v1_profiles p where p.is_active
    and public.v1_workforce_t08_period_actor_authorized(
      p.auth_user_id,'workforce.view',v_period_id,false)
  on conflict(conversation_id,auth_user_id) do update set
    left_at=null,joined_at=case when v1_chat_members.left_at is null
      then v1_chat_members.joined_at else clock_timestamp() end;
  update public.v1_chat_members m set left_at=clock_timestamp()
  where m.conversation_id=p_conversation_id and m.left_at is null
    and not public.v1_workforce_t08_period_actor_authorized(
      m.auth_user_id,'workforce.view',v_period_id,false);
end;
$$;

create or replace function public.v1_chat_is_active_member(
  p_conversation_id uuid,p_auth_user_id uuid default auth.uid()
) returns boolean language sql stable security definer set search_path='' as $$
  select p_auth_user_id is not null and p_auth_user_id=auth.uid()
    and public.v1_current_actor_is_active() and case when exists(
      select 1 from public.v1_workforce_timesheet_discussions d
      where d.conversation_id=p_conversation_id) then exists(
        select 1 from public.v1_workforce_timesheet_discussions d
        where d.conversation_id=p_conversation_id
          and public.v1_workforce_t08_period_actor_authorized(
            p_auth_user_id,'workforce.view',d.period_id,false))
      else exists(select 1 from public.v1_chat_members m
        join public.v1_profiles p on p.auth_user_id=m.auth_user_id
        join public.v1_chat_conversations c on c.id=m.conversation_id
        where m.conversation_id=p_conversation_id
          and m.auth_user_id=p_auth_user_id and m.left_at is null and p.is_active
          and case c.kind
            when 'project' then public.v1_project_readable(c.project_id)
            when 'material_request' then
              public.v1_material_request_readable(c.material_request_id)
            else true end) end;
$$;

create or replace function public.v1_list_chat_conversations()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid();
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_CHAT_LIST_DENIED' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(public.v1_chat_conversation_json(
      c.id,v_actor) order by m.is_pinned desc,
      ((public.v1_chat_conversation_json(c.id,v_actor)->>'unread_count')::int>0) desc,
      coalesce(c.last_message_at,c.created_at) desc,c.id desc)
    from public.v1_chat_conversations c join public.v1_chat_members m
      on m.conversation_id=c.id and m.auth_user_id=v_actor and m.left_at is null
    where public.v1_chat_is_active_member(c.id,v_actor)),'[]'::jsonb);
end;
$$;

create or replace function public.v1_workforce_t08_message_sync_trigger()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if exists(select 1 from public.v1_workforce_timesheet_discussions d
    where d.conversation_id=new.conversation_id) then
    perform public.v1_workforce_t08_sync_discussion_members(new.conversation_id);
  end if;
  return new;
end;
$$;
create trigger v1_workforce_t08_message_sync
after insert on public.v1_chat_messages for each row
execute function public.v1_workforce_t08_message_sync_trigger();

create or replace function public.v1_workforce_t08_ensure_discussion(
  p_period_id uuid,p_creator uuid
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_conversation uuid; v_team text; v_month date; v_role text;
begin
  perform pg_advisory_xact_lock(hashtextextended(
    'v1_workforce_t08_discussion|'||p_period_id::text,0));
  select d.conversation_id into v_conversation
  from public.v1_workforce_timesheet_discussions d where d.period_id=p_period_id;
  if v_conversation is not null then return v_conversation; end if;
  select t.team_name,p.period_month into v_team,v_month
  from public.v1_workforce_monthly_periods p
  join public.v1_workforce_teams t on t.id=p.team_id where p.id=p_period_id;
  if v_team is null then
    raise exception 'V1_WORKFORCE_PERIOD_NOT_FOUND' using errcode='P0002'; end if;
  v_role:=public.v1_permission_exact_role(p_creator);
  if v_role='' then raise exception 'V1_WORKFORCE_T08_CREATOR_INVALID'
    using errcode='42501'; end if;
  insert into public.v1_chat_conversations(kind,title,description,
    created_by_auth_user_id,created_by_exact_role)
  values('group',left(v_team||' · '||to_char(v_month,'Mon YYYY'),120),
    'Timesheet Discussion',p_creator,v_role) returning id into v_conversation;
  insert into public.v1_workforce_timesheet_discussions(
    period_id,conversation_id,created_by_auth_user_id)
  values(p_period_id,v_conversation,p_creator);
  perform public.v1_workforce_t08_sync_discussion_members(v_conversation);
  return v_conversation;
end;
$$;

create or replace function public.v1_open_workforce_timesheet_discussion(
  p_period_id uuid,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_conversation uuid; v_existing jsonb;
  v_response jsonb; v_payload jsonb;
begin
  if v_actor is null or p_period_id is null or p_idempotency_key is null
    or not public.v1_workforce_t08_period_actor_authorized(
      v_actor,'workforce.view',p_period_id,false) then
    raise exception 'V1_WORKFORCE_T08_DISCUSSION_OPEN_DENIED'
      using errcode='42501'; end if;
  v_payload:=jsonb_build_object('period_id',p_period_id);
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_open_workforce_timesheet_discussion',p_idempotency_key,v_payload);
  if v_existing is not null then return v_existing; end if;
  v_conversation:=public.v1_workforce_t08_ensure_discussion(p_period_id,v_actor);
  v_response:=jsonb_build_object('schema_version','yorks.workforce.discussion.v1',
    'period_id',p_period_id,'conversation',public.v1_get_chat_conversation(
      v_conversation,null,100));
  perform public.v1_complete_idempotency(
    'v1_open_workforce_timesheet_discussion',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_send_workforce_timesheet_message(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_period uuid; v_conversation uuid;
  v_link_type text; v_link_id uuid; v_clean jsonb; v_existing jsonb;
  v_child uuid; v_response jsonb; v_message uuid;
begin
  if v_actor is null or p_idempotency_key is null
    or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T08_MESSAGE_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['period_id','body',
    'reply_to_message_id','linked_entity_type','linked_entity_id',
    'attachment_ids','mentioned_auth_user_ids'],'workforce_timesheet_message');
  begin v_period:=(p_payload->>'period_id')::uuid;
    v_link_type:=nullif(p_payload->>'linked_entity_type','');
    v_link_id:=nullif(p_payload->>'linked_entity_id','')::uuid;
  exception when others then
    raise exception 'V1_WORKFORCE_T08_MESSAGE_INVALID' using errcode='22023'; end;
  if not public.v1_workforce_t08_period_actor_authorized(
      v_actor,'workforce.view',v_period,false) then
    raise exception 'V1_WORKFORCE_T08_MESSAGE_DENIED' using errcode='42501'; end if;
  select conversation_id into v_conversation
    from public.v1_workforce_timesheet_discussions where period_id=v_period;
  if v_conversation is null then
    raise exception 'V1_WORKFORCE_T08_DISCUSSION_NOT_OPEN' using errcode='23514'; end if;
  if (v_link_type is null)<>(v_link_id is null) or
    (v_link_type is not null and v_link_type not in (
      'workforce_worker','workforce_attendance_day','workforce_monthly_period'))
    then raise exception 'V1_WORKFORCE_T08_LINK_INVALID' using errcode='22023'; end if;
  if v_link_type='workforce_monthly_period' and v_link_id<>v_period then
    raise exception 'V1_WORKFORCE_T08_LINK_INVALID' using errcode='22023';
  elsif v_link_type='workforce_worker' and not exists(
    select 1 from public.v1_workforce_monthly_periods p
    join public.v1_workforce_monthly_period_dates d
      on d.validation_run_id=p.current_validation_run_id
    where p.id=v_period and d.worker_id=v_link_id) then
    raise exception 'V1_WORKFORCE_T08_LINK_INVALID' using errcode='22023';
  elsif v_link_type='workforce_attendance_day' and not exists(
    select 1 from public.v1_workforce_monthly_periods p
    join public.v1_workforce_attendance_days d
      on d.assignment_team_id_snapshot=p.team_id
      and date_trunc('month',d.work_date)::date=p.period_month
    where p.id=v_period and d.id=v_link_id) then
    raise exception 'V1_WORKFORCE_T08_LINK_INVALID' using errcode='22023'; end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_send_workforce_timesheet_message',p_idempotency_key,p_payload);
  if v_existing is not null then return v_existing; end if;
  perform public.v1_workforce_t08_sync_discussion_members(v_conversation);
  v_clean:=(p_payload-array['period_id','linked_entity_type','linked_entity_id'])
    ||jsonb_build_object('conversation_id',v_conversation);
  v_child:=md5('v1_workforce_t08_message|'||p_idempotency_key::text)::uuid;
  v_response:=public.v1_send_chat_message(v_clean,v_child);
  v_message:=(v_response->'message'->>'id')::uuid;
  if v_link_type is not null then
    update public.v1_chat_messages set linked_entity_type=v_link_type,
      linked_entity_id=v_link_id where id=v_message;
    v_response:=jsonb_build_object('message',
      public.v1_chat_message_json(v_message,v_actor),'conversation',
      public.v1_chat_conversation_json(v_conversation,v_actor));
  end if;
  v_response:=jsonb_build_object('schema_version',
    'yorks.workforce.discussion.message.v1','period_id',v_period)||v_response;
  perform public.v1_complete_idempotency(
    'v1_send_workforce_timesheet_message',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_append_chat_system_event(
  p_conversation_id uuid,p_event_code text,p_source_audit_event_id uuid,
  p_occurred_at timestamptz
) returns uuid language plpgsql security definer set search_path='' as $$
declare v_message_id uuid;
begin
  if p_event_code not in ('project_channel_created','material_request_submitted',
    'material_request_updated_for_approval','material_request_approved',
    'material_request_returned','arrangement_started','arrangement_saved',
    'arrangement_approved','arrangement_returned','materials_dispatched',
    'receipt_confirmed','material_request_closed','material_request_cancelled',
    'workforce_period_submitted','workforce_period_returned',
    'workforce_correction_completed','workforce_period_verified',
    'workforce_period_approved_locked','workforce_reopen_requested',
    'workforce_reopen_approved') then
    raise exception 'V1_CHAT_SYSTEM_EVENT_INVALID' using errcode='22023'; end if;
  insert into public.v1_chat_messages(conversation_id,kind,system_event_code,
    source_audit_event_id,created_at) values(p_conversation_id,'system',
    p_event_code,p_source_audit_event_id,coalesce(p_occurred_at,clock_timestamp()))
  on conflict(source_audit_event_id) do update
    set source_audit_event_id=excluded.source_audit_event_id returning id into v_message_id;
  update public.v1_chat_conversations set
    last_message_at=greatest(coalesce(last_message_at,'-infinity'::timestamptz),
      coalesce(p_occurred_at,clock_timestamp())),
    updated_at=greatest(updated_at,coalesce(p_occurred_at,clock_timestamp()))
    where id=p_conversation_id;
  return v_message_id;
end;
$$;

create or replace function public.v1_document_target_project_id(
  p_entity_type text,p_entity_id uuid
) returns uuid language plpgsql stable security definer set search_path='' as $$
declare v_project uuid;
begin
  if p_entity_type like 'accounts_%' then
    v_project:=public.v1_accounts_document_target_project_id(
      p_entity_type,p_entity_id);
  elsif p_entity_type like 'workforce_%' then
    case p_entity_type
      when 'workforce_worker' then return null;
      when 'workforce_attendance_day' then
        select assignment_project_id_snapshot into v_project
        from public.v1_workforce_attendance_days where id=p_entity_id;
      when 'workforce_monthly_period' then
        select case
          when count(distinct nullif(d.assignment_snapshot->>'project_id',''))=1
            then min(nullif(d.assignment_snapshot->>'project_id',''))::uuid
          end into v_project
        from public.v1_workforce_monthly_periods p
        join public.v1_workforce_monthly_period_dates d
          on d.validation_run_id=p.current_validation_run_id
        where p.id=p_entity_id;
      else raise exception 'V1_DOCUMENT_TARGET_TYPE_INVALID' using errcode='22023';
    end case;
  else
    case p_entity_type
      when 'project' then
        select id into v_project from public.v1_projects where id=p_entity_id;
      when 'boq_group' then
        select project_id into v_project from public.v1_boq_groups where id=p_entity_id;
      when 'material_request' then
        select project_id into v_project from public.v1_material_requests where id=p_entity_id;
      when 'dispatch' then
        select r.project_id into v_project
        from public.v1_material_dispatches d
        join public.v1_material_requests r on r.id=d.request_id
        where d.id=p_entity_id;
      when 'receipt_review' then
        select r.project_id into v_project
        from public.v1_receipt_reviews review
        join public.v1_material_requests r on r.id=review.request_id
        where review.id=p_entity_id and review.state='confirmed';
      when 'material_return' then
        select project_id into v_project from public.v1_material_returns
        where id=p_entity_id;
      when 'delivery_order' then
        select r.project_id into v_project
        from public.v1_delivery_orders o
        join public.v1_material_dispatches d on d.id=o.dispatch_id
        join public.v1_material_requests r on r.id=d.request_id
        where o.id=p_entity_id;
      else raise exception 'V1_DOCUMENT_TARGET_TYPE_INVALID' using errcode='22023';
    end case;
  end if;
  if p_entity_type not like 'workforce_%' and v_project is null then
    raise exception 'V1_DOCUMENT_TARGET_NOT_FOUND' using errcode='22023';
  end if;
  return v_project;
end;
$$;

create or replace function public.v1_document_target_readable(
  p_entity_type text,p_entity_id uuid
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_request uuid; v_project uuid;
begin
  if p_entity_type like 'workforce_%' then
    return public.v1_workforce_t08_target_readable(auth.uid(),p_entity_type,p_entity_id);
  end if;
  if p_entity_type like 'accounts_%' then
    return public.v1_accounts_document_target_readable(
      p_entity_type,p_entity_id);
  end if;
  case p_entity_type
    when 'project' then return public.v1_project_readable(p_entity_id);
    when 'boq_group' then select project_id into v_project from public.v1_boq_groups where id=p_entity_id; return v_project is not null and public.v1_project_readable(v_project);
    when 'material_request' then return public.v1_material_request_readable(p_entity_id);
    when 'dispatch' then select request_id into v_request from public.v1_material_dispatches where id=p_entity_id; return v_request is not null and public.v1_material_request_readable(v_request);
    when 'receipt_review' then select request_id into v_request from public.v1_receipt_reviews where id=p_entity_id and state='confirmed'; return v_request is not null and public.v1_material_request_readable(v_request);
    when 'material_return' then return public.v1_material_return_readable(p_entity_id);
    when 'delivery_order' then select d.request_id into v_request from public.v1_delivery_orders o join public.v1_material_dispatches d on d.id=o.dispatch_id where o.id=p_entity_id; return v_request is not null and public.v1_material_request_readable(v_request);
    when 'rental_property' then return auth.uid() is not null
      and public.v1_current_actor_is_active() and public.v1_current_role()='admin'
      and exists(select 1 from public.v1_rental_properties where id=p_entity_id);
    when 'supplier' then return public.v1_can_manage_inventory()
      and exists(select 1 from public.v1_suppliers where id=p_entity_id);
    when 'supplier_receipt_batch' then return public.v1_can_manage_inventory()
      and exists(select 1 from public.v1_supplier_receipt_batches where id=p_entity_id);
    else return false;
  end case;
end;
$$;

create or replace function public.v1_document_target_writable(
  p_entity_type text,p_entity_id uuid,p_classification text
) returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_project uuid; v_state text; v_role text:=public.v1_current_role();
begin
  if p_entity_type like 'workforce_%' then
    return p_classification='operational' and public.v1_current_actor_is_active()
      and public.v1_workforce_t08_target_writable(auth.uid(),p_entity_type,p_entity_id);
  end if;
  if p_entity_type like 'accounts_%' then
    return p_classification in ('operational','commercial')
      and public.v1_accounts_document_target_readable(p_entity_type,p_entity_id)
      and public.v1_accounts_document_target_writable(p_entity_type,p_entity_id);
  end if;
  if not public.v1_document_target_readable(p_entity_type,p_entity_id)
    or not public.v1_document_classification_writable(p_classification) then return false; end if;
  if p_entity_type='rental_property' then return p_classification='commercial'
    and exists(select 1 from public.v1_rental_properties where id=p_entity_id and not is_archived); end if;
  if p_entity_type='receipt_review' then return p_classification='operational'
    and v_role in ('project_engineer','site_engineer','admin')
    and exists(select 1 from public.v1_receipt_reviews
      where id=p_entity_id and state='confirmed'); end if;
  if p_entity_type='supplier' then return (
      p_classification='operational'
      or (p_classification='commercial'
        and public.v1_has_capability('manage_commercials'))
      or (p_classification='admin_restricted' and v_role='admin'))
    and public.v1_can_manage_inventory()
    and exists(select 1 from public.v1_suppliers where id=p_entity_id); end if;
  if p_entity_type='supplier_receipt_batch' then return (
      p_classification='operational'
      or (p_classification='commercial'
        and public.v1_has_capability('manage_commercials'))
      or (p_classification='admin_restricted' and v_role='admin'))
    and public.v1_can_manage_inventory()
    and exists(select 1 from public.v1_supplier_receipt_batches
      where id=p_entity_id and state='committed'); end if;
  v_project:=public.v1_document_target_project_id(p_entity_type,p_entity_id);
  select state into v_state from public.v1_projects where id=v_project;
  return v_state in ('draft','active','on_hold','completed');
end;
$$;

-- Workforce evidence is authorized by its canonical upload target. Secondary
-- retained links improve discovery but can neither grant access on their own
-- nor accidentally deny a caller who is authorized for the canonical period.
create or replace function public.v1_document_readable(p_document_id uuid)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_classification text; v_links_readable boolean; v_is_accounts boolean;
  v_is_workforce boolean; v_target_type text; v_target_id uuid;
begin
  if auth.uid() is null or not public.v1_current_actor_is_active() then
    return false;
  end if;
  select classification into v_classification from public.v1_documents
    where id=p_document_id;
  if v_classification is null then return false; end if;
  select exists(select 1 from public.v1_accounts_document_metadata
      where document_id=p_document_id),
    exists(select 1 from public.v1_workforce_document_version_metadata
      where document_id=p_document_id)
    into v_is_accounts,v_is_workforce;
  if v_is_workforce then
    select i.target_entity_type,i.target_entity_id
      into v_target_type,v_target_id
      from public.v1_document_upload_intents i
      where i.finalized_document_id=p_document_id
        and i.target_entity_type like 'workforce_%'
      order by i.finalized_at desc nulls last,i.id desc limit 1;
    return v_classification='operational' and v_target_id is not null
      and public.v1_workforce_t08_target_readable(
        auth.uid(),v_target_type,v_target_id);
  end if;
  select count(*)>0 and bool_and(
    public.v1_document_target_readable(link.entity_type,link.entity_id))
    into v_links_readable from public.v1_document_links link
    where link.document_id=p_document_id and link.removed_at is null;
  if not coalesce(v_links_readable,false) then return false; end if;
  if v_is_accounts then
    return v_classification in ('operational','commercial');
  end if;
  return case v_classification
    when 'operational' then true
    when 'commercial' then public.v1_has_capability('view_commercials')
    when 'admin_restricted' then public.v1_current_role()='admin'
    else false end;
end;
$$;

create or replace function public.v1_prepare_workforce_document_upload(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text; v_entity_type text; v_entity_id uuid;
  v_document uuid; v_classification text; v_file text; v_mime text; v_size bigint;
  v_sha text; v_evidence text; v_worker uuid; v_day uuid; v_period uuid;
  v_supplied_worker uuid; v_supplied_day uuid; v_supplied_period uuid;
  v_day_worker uuid; v_day_work_date date; v_day_project uuid;
  v_project uuid; v_intent uuid:=gen_random_uuid(); v_revision integer;
  v_existing jsonb; v_response jsonb; v_previous record;
  v_previous_entity_type text; v_previous_entity_id uuid;
begin
  if v_actor is null or p_idempotency_key is null or jsonb_typeof(p_payload)<>'object'
    then raise exception 'V1_WORKFORCE_DOCUMENT_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,array['entity_type','entity_id',
    'document_id','classification','file_name','mime_type','byte_size','sha256',
    'evidence_type','worker_id','attendance_day_id','period_id'],
    'workforce_document_upload');
  begin v_entity_type:=nullif(p_payload->>'entity_type','');
    v_entity_id:=(p_payload->>'entity_id')::uuid;
    v_document:=nullif(p_payload->>'document_id','')::uuid;
    v_supplied_worker:=nullif(p_payload->>'worker_id','')::uuid;
    v_supplied_day:=nullif(p_payload->>'attendance_day_id','')::uuid;
    v_supplied_period:=nullif(p_payload->>'period_id','')::uuid;
    v_size:=(p_payload->>'byte_size')::bigint;
  exception when others then raise exception 'V1_WORKFORCE_DOCUMENT_INVALID'
    using errcode='22023'; end;
  v_role:=public.v1_permission_exact_role(v_actor);
  v_classification:=p_payload->>'classification'; v_file:=btrim(p_payload->>'file_name');
  v_mime:=p_payload->>'mime_type'; v_sha:=lower(p_payload->>'sha256');
  v_evidence:=p_payload->>'evidence_type';
  if v_role='' or v_entity_type not in ('workforce_worker',
      'workforce_attendance_day','workforce_monthly_period')
    or v_classification<>'operational' or v_file='' or char_length(v_file)>180
    or position('/' in v_file)>0 or position(chr(92) in v_file)>0
    or v_mime not in ('application/pdf',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'image/jpeg','image/png') or v_size<1 or v_size>6291456
    or v_sha!~'^[a-f0-9]{64}$' or v_evidence not in (
      'medical_certificate','leave_document','overtime_authorization',
      'worker_transfer_note','site_attendance_sheet','daily_supporting_photo',
      'monthly_timesheet_attachment','other_workforce_document')
    then raise exception 'V1_WORKFORCE_DOCUMENT_INVALID' using errcode='22023'; end if;
  -- Resolve the canonical target first. Optional links are never allowed to
  -- replace its identity or retained project context.
  if v_entity_type='workforce_worker' then
    v_worker:=v_entity_id;
    if v_supplied_worker is not null and v_supplied_worker<>v_worker then
      raise exception 'V1_WORKFORCE_DOCUMENT_TARGET_INVALID' using errcode='22023';
    end if;
    v_day:=v_supplied_day; v_period:=v_supplied_period; v_project:=null;
  elsif v_entity_type='workforce_attendance_day' then
    v_day:=v_entity_id; v_period:=v_supplied_period;
    if v_supplied_day is not null and v_supplied_day<>v_day then
      raise exception 'V1_WORKFORCE_DOCUMENT_TARGET_INVALID' using errcode='22023';
    end if;
  else
    v_period:=v_entity_id; v_day:=v_supplied_day;
    if v_supplied_period is not null and v_supplied_period<>v_period then
      raise exception 'V1_WORKFORCE_DOCUMENT_TARGET_INVALID' using errcode='22023';
    end if;
  end if;

  if v_day is not null then
    select worker_id,work_date,assignment_project_id_snapshot
      into v_day_worker,v_day_work_date,v_day_project
      from public.v1_workforce_attendance_days where id=v_day;
    if not found then
      raise exception 'V1_WORKFORCE_DOCUMENT_TARGET_INVALID' using errcode='22023';
    end if;
    if v_worker is not null and v_worker<>v_day_worker then
      raise exception 'V1_WORKFORCE_DOCUMENT_CONTEXT_MISMATCH' using errcode='22023';
    end if;
    v_worker:=v_day_worker;
    if v_supplied_worker is not null and v_supplied_worker<>v_worker then
      raise exception 'V1_WORKFORCE_DOCUMENT_CONTEXT_MISMATCH' using errcode='22023';
    end if;
    if v_entity_type='workforce_attendance_day' then v_project:=v_day_project; end if;
  elsif v_supplied_worker is not null then
    if v_worker is not null and v_worker<>v_supplied_worker then
      raise exception 'V1_WORKFORCE_DOCUMENT_CONTEXT_MISMATCH' using errcode='22023';
    end if;
    v_worker:=v_supplied_worker;
  end if;

  if v_period is not null then
    if not exists(select 1 from public.v1_workforce_monthly_periods
        where id=v_period) then
      raise exception 'V1_WORKFORCE_DOCUMENT_TARGET_INVALID' using errcode='22023';
    end if;
    if v_entity_type='workforce_monthly_period' then
      v_project:=public.v1_document_target_project_id(
        'workforce_monthly_period',v_period);
    end if;
    if v_worker is not null and not exists(
      select 1 from public.v1_workforce_monthly_periods p
      join public.v1_workforce_monthly_period_dates pd
        on pd.validation_run_id=p.current_validation_run_id
       and pd.worker_id=v_worker
      where p.id=v_period
        and (v_day is null or (
          pd.work_date=v_day_work_date
          and pd.attendance_snapshot->>'attendance_day_id'=v_day::text
        ))) then
      raise exception 'V1_WORKFORCE_DOCUMENT_CONTEXT_MISMATCH' using errcode='22023';
    end if;
  end if;

  -- The canonical target remains the write-authority boundary. Exact retained
  -- source membership makes any secondary link descriptive, not a second path
  -- by which a caller can forge or broaden context.
  if (v_evidence in ('medical_certificate','leave_document',
      'overtime_authorization','site_attendance_sheet','daily_supporting_photo')
      and v_day is null)
    or (v_evidence='worker_transfer_note' and v_worker is null)
    or (v_evidence='monthly_timesheet_attachment' and v_period is null)
    or not public.v1_workforce_t08_target_writable(
      v_actor,v_entity_type,v_entity_id) then
    raise exception 'V1_WORKFORCE_DOCUMENT_WRITE_DENIED' using errcode='42501'; end if;
  if v_document is not null then
    select m.* into v_previous from public.v1_workforce_document_version_metadata m
    join public.v1_documents d on d.current_version_id=m.document_version_id
    where d.id=v_document;
    select i.target_entity_type,i.target_entity_id
      into v_previous_entity_type,v_previous_entity_id
      from public.v1_document_upload_intents i
      where i.finalized_document_id=v_document
        and i.target_entity_type like 'workforce_%'
      order by i.finalized_at desc nulls last,i.id desc limit 1;
    if not found or v_previous.document_version_id is null
      or not public.v1_document_writable(v_document)
      or v_previous.evidence_type<>v_evidence
      or v_previous.worker_id is distinct from v_worker
      or v_previous.attendance_day_id is distinct from v_day
      or v_previous.period_id is distinct from v_period
      or v_previous_entity_type is distinct from v_entity_type
      or v_previous_entity_id is distinct from v_entity_id then
      raise exception 'V1_WORKFORCE_DOCUMENT_VERSION_DENIED' using errcode='42501'; end if;
    select coalesce(max(revision_number),0)+1 into v_revision
      from public.v1_document_versions where document_id=v_document;
  else v_revision:=1; end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_prepare_workforce_document_upload',p_idempotency_key,p_payload);
  if v_existing is not null then return v_existing; end if;
  insert into public.v1_document_upload_intents(id,project_id,target_entity_type,
    target_entity_id,document_id,planned_revision_number,classification,
    original_file_name,mime_type,byte_size,expected_sha256,origin,object_path,
    actor_auth_user_id,actor_role,idempotency_key,expires_at)
  values(v_intent,v_project,v_entity_type,v_entity_id,v_document,v_revision,
    'operational',v_file,v_mime,v_size,v_sha,'uploaded',
    'documents/workforce/'||v_intent::text||'/content',v_actor,v_role,
    p_idempotency_key,clock_timestamp()+interval '15 minutes');
  insert into public.v1_workforce_document_upload_metadata(upload_intent_id,
    evidence_type,worker_id,attendance_day_id,period_id,retained_project_id)
  values(v_intent,v_evidence,v_worker,v_day,v_period,v_project);
  v_response:=jsonb_build_object('schema_version',
    'yorks.workforce.document-upload.v1','upload_intent_id',v_intent,
    'bucket_id','yorks-documents','object_path',
    'documents/workforce/'||v_intent::text||'/content','mime_type',v_mime,
    'byte_size',v_size,'expires_at',clock_timestamp()+interval '15 minutes',
    'planned_revision_number',v_revision);
  perform public.v1_complete_idempotency(
    'v1_prepare_workforce_document_upload',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_workforce_t08_finalize_document_metadata()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_meta public.v1_workforce_document_upload_metadata%rowtype;
  v_role text;
begin
  if old.finalized_at is not null or new.finalized_at is null then return new; end if;
  select * into v_meta from public.v1_workforce_document_upload_metadata
    where upload_intent_id=new.id;
  if not found then return new; end if;
  insert into public.v1_workforce_document_version_metadata(
    document_version_id,document_id,evidence_type,worker_id,attendance_day_id,
    period_id,retained_project_id) values(new.finalized_version_id,
    new.finalized_document_id,v_meta.evidence_type,v_meta.worker_id,
    v_meta.attendance_day_id,v_meta.period_id,v_meta.retained_project_id);
  v_role:=new.actor_role;
  if v_meta.worker_id is not null and new.target_entity_type<>'workforce_worker' then
    insert into public.v1_document_links(id,document_id,project_id,entity_type,
      entity_id,linked_by_auth_user_id,linked_by_role)
    values(gen_random_uuid(),new.finalized_document_id,null,'workforce_worker',
      v_meta.worker_id,new.actor_auth_user_id,v_role) on conflict do nothing;
  end if;
  if v_meta.attendance_day_id is not null
    and new.target_entity_type<>'workforce_attendance_day' then
    insert into public.v1_document_links(id,document_id,project_id,entity_type,
      entity_id,linked_by_auth_user_id,linked_by_role)
    values(gen_random_uuid(),new.finalized_document_id,v_meta.retained_project_id,
      'workforce_attendance_day',v_meta.attendance_day_id,
      new.actor_auth_user_id,v_role) on conflict do nothing;
  end if;
  if v_meta.period_id is not null
    and new.target_entity_type<>'workforce_monthly_period' then
    insert into public.v1_document_links(id,document_id,project_id,entity_type,
      entity_id,linked_by_auth_user_id,linked_by_role)
    values(gen_random_uuid(),new.finalized_document_id,v_meta.retained_project_id,
      'workforce_monthly_period',v_meta.period_id,
      new.actor_auth_user_id,v_role) on conflict do nothing;
  end if;
  return new;
end;
$$;
create trigger v1_workforce_t08_finalize_document_metadata
after update of finalized_at on public.v1_document_upload_intents
for each row execute function public.v1_workforce_t08_finalize_document_metadata();

create or replace function public.v1_list_workforce_documents(
  p_period_id uuid default null,p_attendance_day_id uuid default null,
  p_worker_id uuid default null
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if auth.uid() is null or (p_period_id is null and p_attendance_day_id is null
      and p_worker_id is null) then
    raise exception 'V1_WORKFORCE_DOCUMENT_READ_INVALID' using errcode='22023'; end if;
  return jsonb_build_object('schema_version','yorks.workforce.documents.v1',
    'documents',coalesce((select jsonb_agg(jsonb_build_object(
      'document_id',d.id,'classification',d.classification,
      'current_version_id',d.current_version_id,'evidence_type',m.evidence_type,
      'worker_id',m.worker_id,'attendance_day_id',m.attendance_day_id,
      'period_id',m.period_id,'retained_project_id',m.retained_project_id,
      'versions',(select jsonb_agg(jsonb_build_object('version_id',v.id,
        'revision_number',v.revision_number,'file_name',v.original_file_name,
        'mime_type',v.mime_type,'byte_size',v.byte_size,'sha256',v.sha256,
        'uploaded_at',v.uploaded_at) order by v.revision_number desc)
        from public.v1_document_versions v where v.document_id=d.id))
      order by d.created_at desc,d.id) from public.v1_documents d
      join public.v1_workforce_document_version_metadata m
        on m.document_version_id=d.current_version_id
      where (p_period_id is null or m.period_id=p_period_id)
        and (p_attendance_day_id is null or m.attendance_day_id=p_attendance_day_id)
        and (p_worker_id is null or m.worker_id=p_worker_id)
        and public.v1_document_readable(d.id)),'[]'::jsonb));
end;
$$;

create or replace function public.v1_workforce_t08_audit_bridge()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_period uuid; v_conversation uuid; v_system text; v_event text;
  v_capability text; v_recipient uuid; v_notification uuid; v_pair record;
begin
  if new.entity_type<>'workforce_monthly_period' or new.event_type not in (
    'workforce_monthly_period_submitted','workforce_monthly_period_returned',
    'workforce_monthly_reviewer_correction','workforce_monthly_period_verified',
    'workforce_monthly_period_approved_and_locked',
    'workforce_monthly_reopen_requested','workforce_monthly_reopen_authorized')
    then return new; end if;
  v_period:=new.entity_id;
  v_system:=case new.event_type
    when 'workforce_monthly_period_submitted' then 'workforce_period_submitted'
    when 'workforce_monthly_period_returned' then 'workforce_period_returned'
    when 'workforce_monthly_reviewer_correction' then 'workforce_correction_completed'
    when 'workforce_monthly_period_verified' then 'workforce_period_verified'
    when 'workforce_monthly_period_approved_and_locked' then 'workforce_period_approved_locked'
    when 'workforce_monthly_reopen_requested' then 'workforce_reopen_requested'
    else 'workforce_reopen_approved' end;
  v_conversation:=public.v1_workforce_t08_ensure_discussion(v_period,
    new.actor_auth_user_id);
  perform public.v1_append_chat_system_event(v_conversation,v_system,new.id,new.occurred_at);
  for v_pair in select * from (values
    (case new.event_type
      when 'workforce_monthly_period_submitted' then 'workforce_period_submitted'
      when 'workforce_monthly_period_returned' then 'workforce_period_returned'
      when 'workforce_monthly_reviewer_correction' then 'workforce_correction_completed'
      when 'workforce_monthly_period_verified' then 'workforce_period_verified'
      when 'workforce_monthly_period_approved_and_locked' then 'workforce_period_approved_locked'
      when 'workforce_monthly_reopen_requested' then 'workforce_reopen_requested'
      else 'workforce_reopen_approved' end,
    case new.event_type
      when 'workforce_monthly_period_submitted' then 'workforce.timesheets.review'
      when 'workforce_monthly_period_returned' then 'workforce.timesheets.maintain'
      when 'workforce_monthly_reviewer_correction' then 'workforce.timesheets.maintain'
      when 'workforce_monthly_period_verified' then 'workforce.timesheets.maintain'
      when 'workforce_monthly_period_approved_and_locked' then 'workforce.timesheets.maintain'
      when 'workforce_monthly_reopen_requested' then 'workforce.periods.reopen'
      else 'workforce.timesheets.maintain' end),
    (case when new.event_type='workforce_monthly_period_verified'
      then 'workforce_final_approval_required' end,
     case when new.event_type='workforce_monthly_period_verified'
      then 'workforce.timesheets.final_approve' end)) as x(event_code,capability)
    where event_code is not null loop
    for v_recipient in select p.auth_user_id from public.v1_profiles p
      where p.is_active and p.auth_user_id<>new.actor_auth_user_id
        and public.v1_workforce_t08_period_actor_authorized(
          p.auth_user_id,v_pair.capability,v_period,true) loop
      v_notification:=gen_random_uuid();
      insert into public.v1_workforce_notification_deliveries(
        source_audit_event_id,recipient_auth_user_id,event_code,notification_id)
      values(new.id,v_recipient,v_pair.event_code,v_notification)
      on conflict do nothing;
      if found then insert into public.v1_notifications(id,
        recipient_auth_user_id,event_code,entity_type,entity_id,project_id,created_at)
        values(v_notification,v_recipient,v_pair.event_code,
          'workforce_monthly_period',v_period,
          public.v1_document_target_project_id('workforce_monthly_period',v_period),
          new.occurred_at); end if;
    end loop;
  end loop;
  return new;
exception when others then
  -- Collaboration is a projection of the committed workflow. It must never
  -- become transition authority or make the originating T07 command fail.
  raise warning 'V1_WORKFORCE_T08_AUDIT_BRIDGE_FAILED: %',sqlerrm;
  return new;
end;
$$;
create trigger v1_workforce_t08_audit_bridge
after insert on public.v1_audit_events for each row
execute function public.v1_workforce_t08_audit_bridge();

create or replace function public.v1_dispatch_workforce_notification_digest(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_actor uuid; v_kind text; v_team uuid; v_date date; v_period uuid;
  v_period_row public.v1_workforce_monthly_periods%rowtype; v_roster jsonb;
  v_count integer; v_page_count integer; v_offset integer:=0;
  v_recipient uuid; v_notification uuid; v_existing jsonb;
  v_response jsonb; v_delivered integer:=0;
begin
  v_actor:=public.v1_workforce_assert_admin();
  if p_idempotency_key is null or jsonb_typeof(p_payload)<>'object' then
    raise exception 'V1_WORKFORCE_T08_DIGEST_INVALID' using errcode='22023'; end if;
  perform public.v1_assert_object_keys(p_payload,
    array['digest_kind','team_id','work_date','period_id'],'workforce_digest');
  begin v_kind:=p_payload->>'digest_kind';
    v_team:=(p_payload->>'team_id')::uuid;
    v_date:=nullif(p_payload->>'work_date','')::date;
    v_period:=nullif(p_payload->>'period_id','')::uuid;
  exception when others then raise exception 'V1_WORKFORCE_T08_DIGEST_INVALID'
    using errcode='22023'; end;
  if (v_kind='daily_attendance_missing' and (v_date is null or v_period is not null))
    or (v_kind='monthly_period_incomplete' and (v_period is null or v_date is not null))
    or v_kind not in ('daily_attendance_missing','monthly_period_incomplete') then
    raise exception 'V1_WORKFORCE_T08_DIGEST_INVALID' using errcode='22023'; end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_dispatch_workforce_notification_digest',p_idempotency_key,p_payload);
  if v_existing is not null then return v_existing; end if;
  if v_kind='daily_attendance_missing' then
    v_count:=0;
    loop
      v_roster:=public.v1_get_workforce_daily_roster(
        v_date,v_team,null,null,null,null,500,v_offset);
      v_page_count:=jsonb_array_length(coalesce(v_roster->'rows','[]'::jsonb));
      select v_count+count(*) into v_count from jsonb_array_elements(
        coalesce(v_roster->'rows','[]'::jsonb)) r
        where r->'attendance' is null or r->'attendance'='null'::jsonb
          or r#>>'{attendance,status}'='not_entered';
      exit when v_page_count<500;
      v_offset:=v_offset+v_page_count;
    end loop;
  else
    select * into v_period_row from public.v1_workforce_monthly_periods
      where id=v_period and team_id=v_team;
    if not found then raise exception 'V1_WORKFORCE_T08_DIGEST_INVALID'
      using errcode='22023'; end if;
    select coalesce(run.blocking_issue_count,0)+coalesce(run.warning_issue_count,0)
      into v_count from public.v1_workforce_monthly_validation_runs run
      where run.id=v_period_row.current_validation_run_id;
  end if;
  if coalesce(v_count,0)>0 then
    for v_recipient in select p.auth_user_id from public.v1_profiles p
      where p.is_active and p.auth_user_id<>v_actor and (
        (v_kind='monthly_period_incomplete' and
          public.v1_workforce_t08_period_actor_authorized(p.auth_user_id,
            'workforce.timesheets.maintain',v_period,true)) or
        (v_kind='daily_attendance_missing' and exists(
          select 1 from public.v1_workforce_workers w
          cross join lateral public.v1_workforce_effective_assignment(w.id,v_date) a
          where a->>'team_id'=v_team::text
            and public.v1_workforce_t08_actor_has_capability(p.auth_user_id,
              'workforce.attendance.maintain',nullif(a->>'project_id','')::uuid)
            and public.v1_workforce_matching_responsibility(p.auth_user_id,w.id,
              v_date,nullif(a->>'team_id','')::uuid,
              nullif(a->>'project_id','')::uuid,
              nullif(a->>'project_scope_id','')::uuid,
              nullif(a->>'internal_location_id','')::uuid)<>'{}'::jsonb))) loop
      v_notification:=gen_random_uuid();
      insert into public.v1_workforce_notification_digests(id,digest_kind,team_id,
        work_date,period_id,recipient_auth_user_id,item_count,notification_id,
        idempotency_key) values(gen_random_uuid(),v_kind,v_team,v_date,v_period,
        v_recipient,v_count,v_notification,p_idempotency_key) on conflict do nothing;
      if found then
        insert into public.v1_notifications(id,recipient_auth_user_id,event_code,
          entity_type,entity_id,project_id) values(v_notification,v_recipient,
          case when v_kind='daily_attendance_missing'
            then 'workforce_daily_attendance_missing'
            else 'workforce_monthly_period_incomplete' end,
          case when v_kind='daily_attendance_missing'
            then 'workforce_daily_roster' else 'workforce_monthly_period' end,
          case when v_kind='daily_attendance_missing' then v_team else v_period end,
          case when v_period is not null then
            public.v1_document_target_project_id('workforce_monthly_period',v_period)
            else null end);
        v_delivered:=v_delivered+1;
      end if;
    end loop;
  end if;
  v_response:=jsonb_build_object('schema_version','yorks.workforce.digest.v1',
    'digest_kind',v_kind,'item_count',coalesce(v_count,0),
    'delivered_count',v_delivered);
  perform public.v1_complete_idempotency(
    'v1_dispatch_workforce_notification_digest',p_idempotency_key,v_response);
  return v_response;
end;
$$;

create or replace function public.v1_get_workforce_collaboration(
  p_period_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_conversation uuid;
begin
  if v_actor is null or not public.v1_workforce_t08_period_actor_authorized(
      v_actor,'workforce.view',p_period_id,false) then
    raise exception 'V1_WORKFORCE_T08_COLLABORATION_DENIED' using errcode='42501'; end if;
  select conversation_id into v_conversation
    from public.v1_workforce_timesheet_discussions where period_id=p_period_id;
  return jsonb_build_object('schema_version','yorks.workforce.collaboration.v1',
    'period_id',p_period_id,
    'discussion',case when v_conversation is null then null
      else public.v1_get_chat_conversation(v_conversation,null,100) end,
    'documents',public.v1_list_workforce_documents(p_period_id,null,null)->'documents',
    'notifications',coalesce((select jsonb_agg(jsonb_build_object(
      'notification_id',n.id,'event_code',n.event_code,'created_at',n.created_at,
      'seen_at',n.seen_at,'item_count',d.item_count) order by n.created_at desc)
      from public.v1_notifications n left join public.v1_workforce_notification_digests d
        on d.notification_id=n.id where n.recipient_auth_user_id=v_actor
          and n.entity_type in ('workforce_monthly_period','workforce_daily_roster')
          and (n.entity_id=p_period_id or d.period_id=p_period_id)),'[]'::jsonb));
end;
$$;

revoke all on function public.v1_workforce_t08_actor_has_capability(uuid,text,uuid),
  public.v1_workforce_t08_period_actor_authorized(uuid,text,uuid,boolean),
  public.v1_workforce_t08_day_actor_authorized(uuid,text,uuid,boolean),
  public.v1_workforce_t08_worker_actor_authorized(uuid,text,uuid),
  public.v1_workforce_t08_target_readable(uuid,text,uuid),
  public.v1_workforce_t08_target_writable(uuid,text,uuid),
  public.v1_workforce_t08_sync_discussion_members(uuid),
  public.v1_workforce_t08_message_sync_trigger(),
  public.v1_workforce_t08_ensure_discussion(uuid,uuid),
  public.v1_workforce_t08_finalize_document_metadata(),
  public.v1_workforce_t08_audit_bridge()
from public,anon,authenticated;

revoke all on function public.v1_open_workforce_timesheet_discussion(uuid,uuid),
  public.v1_send_workforce_timesheet_message(jsonb,uuid),
  public.v1_prepare_workforce_document_upload(jsonb,uuid),
  public.v1_list_workforce_documents(uuid,uuid,uuid),
  public.v1_dispatch_workforce_notification_digest(jsonb,uuid),
  public.v1_get_workforce_collaboration(uuid)
from public,anon;
grant execute on function public.v1_open_workforce_timesheet_discussion(uuid,uuid),
  public.v1_send_workforce_timesheet_message(jsonb,uuid),
  public.v1_prepare_workforce_document_upload(jsonb,uuid),
  public.v1_list_workforce_documents(uuid,uuid,uuid),
  public.v1_dispatch_workforce_notification_digest(jsonb,uuid),
  public.v1_get_workforce_collaboration(uuid)
to authenticated,service_role;

commit;
