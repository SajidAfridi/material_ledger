-- Batch 8 / PR-08: normalized Phase 1 planning projection and workflow guard.
--
-- The Flutter outbox still writes one idempotent materialPlans snapshot. This
-- migration validates every state transition at the database boundary and
-- projects each accepted snapshot into relational plan/version/line/comment/
-- activity tables. Submitted specifications and reviewed versions therefore
-- remain queryable and cannot be overwritten by a later client snapshot.

create or replace function public.phase1_status_code(p_label text)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_label
    when 'Draft' then 'draft'
    when 'Submitted' then 'submitted'
    when 'In review' then 'procurement_review'
    when 'Under Procurement Review' then 'procurement_review'
    when 'Changes requested' then 'changes_requested'
    when 'Ready for approval' then 'ready_for_approval'
    when 'Approved' then 'approved'
    when 'Superseded' then 'superseded'
    else 'invalid'
  end;
$$;

revoke execute on function public.phase1_status_code(text) from public, anon;
grant execute on function public.phase1_status_code(text)
  to authenticated, service_role;

create table if not exists public.phase1_plans (
  id uuid primary key default gen_random_uuid(),
  legacy_id text not null unique,
  project_id text not null unique references public.projects(id),
  status text not null check (
    status in (
      'draft',
      'submitted',
      'procurement_review',
      'changes_requested',
      'ready_for_approval',
      'approved',
      'superseded'
    )
  ),
  current_version integer not null default 0 check (current_version >= 0),
  current_owner_role text,
  current_owner_user_id text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  approved_at timestamptz,
  lock_version integer not null default 0 check (lock_version >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  updated_by_user_id text
);

create table if not exists public.phase1_plan_versions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.phase1_plans(id) on delete restrict,
  version_no integer not null check (version_no > 0),
  status text not null check (
    status in (
      'submitted',
      'procurement_review',
      'changes_requested',
      'ready_for_approval',
      'approved',
      'superseded'
    )
  ),
  created_at timestamptz not null,
  created_by_user_id text,
  created_by_name text not null,
  created_by_role text not null,
  reviewed_at timestamptz,
  approved_at timestamptz,
  unique (plan_id, version_no)
);

create table if not exists public.phase1_plan_lines (
  id uuid primary key default gen_random_uuid(),
  version_id uuid not null
    references public.phase1_plan_versions(id) on delete restrict,
  legacy_line_id text not null,
  line_no integer not null check (line_no > 0),
  catalogue_material_id text,
  category_id text,
  building_id text not null,
  item_description text not null check (btrim(item_description) <> ''),
  size_text text not null default '',
  model_serial_text text not null default '',
  make_origin_text text not null default '',
  requested_qty numeric not null check (requested_qty > 0),
  unit_symbol text not null check (btrim(unit_symbol) <> ''),
  remarks text not null default '',
  is_custom boolean not null default false,
  proposed_source text not null default 'not_reviewed' check (
    proposed_source in (
      'not_reviewed',
      'warehouse',
      'external_supplier',
      'mixed'
    )
  ),
  on_hand_qty_snapshot numeric check (
    on_hand_qty_snapshot is null or on_hand_qty_snapshot >= 0
  ),
  available_qty_snapshot numeric check (
    available_qty_snapshot is null or available_qty_snapshot >= 0
  ),
  procurement_note text not null default '',
  source_reviewed_at timestamptz,
  source_reviewed_by_user_id text,
  unique (version_id, legacy_line_id),
  unique (version_id, line_no)
);

create table if not exists public.phase1_plan_comments (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.phase1_plans(id) on delete restrict,
  version_no integer not null check (version_no >= 0),
  source_comment_id text not null,
  legacy_line_id text,
  author_user_id text,
  author_name text not null,
  author_role text not null,
  body text not null check (btrim(body) <> ''),
  created_at timestamptz not null,
  unique (plan_id, source_comment_id)
);

create table if not exists public.phase1_plan_activity (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.phase1_plans(id) on delete restrict,
  version_no integer not null check (version_no >= 0),
  source_event_id text not null,
  action text not null check (btrim(action) <> ''),
  detail text not null default '',
  actor_user_id text,
  actor_name text not null,
  actor_role text not null,
  occurred_at timestamptz not null,
  unique (plan_id, source_event_id)
);

create index if not exists phase1_plan_versions_plan_status
  on public.phase1_plan_versions (plan_id, status, version_no desc);
create index if not exists phase1_plan_lines_version_line
  on public.phase1_plan_lines (version_id, line_no);
create index if not exists phase1_plan_comments_plan_time
  on public.phase1_plan_comments (plan_id, created_at);
create index if not exists phase1_plan_activity_plan_time
  on public.phase1_plan_activity (plan_id, occurred_at desc);

create or replace function public.phase1_validate_snapshot_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  caller_role text := public.app_role();
  old_status text;
  new_status text := public.phase1_status_code(new.data ->> 'status');
  old_version integer := 0;
  new_version integer := coalesce((new.data ->> 'version')::integer, 0);
begin
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  if (select auth.uid()) is null or public.app_user_id() = '' then
    raise exception using
      errcode = '42501',
      message = 'A provisioned Nexus identity is required.';
  end if;
  if new_status = 'invalid' then
    raise exception using
      errcode = '22023',
      message = 'Invalid Phase 1 material-plan status.';
  end if;
  if new.data @? '$.**.allocatedQty'
     or new.data @? '$.**.reservedQty'
     or new.data @? '$.**.allocationId' then
    raise exception using
      errcode = '22023',
      message = 'Phase 1 review cannot allocate or reserve stock.';
  end if;

  if tg_op = 'INSERT' then
    if caller_role not in ('admin', 'engineer') then
      raise exception using
        errcode = '42501',
        message = 'Only Engineering can create a Phase 1 plan.';
    end if;
    if new_status not in ('draft', 'submitted') then
      raise exception using
        errcode = '22023',
        message = 'A new Phase 1 plan must be Draft or Submitted.';
    end if;
    return new;
  end if;

  old_status := public.phase1_status_code(old.data ->> 'status');
  old_version := coalesce((old.data ->> 'version')::integer, 0);

  if caller_role = 'admin' then
    null;
  elsif caller_role = 'engineer' then
    if not (
      (old_status in ('draft', 'changes_requested')
        and new_status = old_status)
      or
      (old_status in ('draft', 'changes_requested')
        and new_status in ('submitted', 'procurement_review')
        and new_version > old_version)
      or
      (old_status = 'ready_for_approval'
        and new_status in ('approved', 'changes_requested')
        and new_version = old_version)
    ) then
      raise exception using
        errcode = '42501',
        message = 'Engineering is not allowed to perform this Phase 1 transition.';
    end if;
  elsif caller_role = 'procurement' then
    if not (
      old_status in ('submitted', 'procurement_review')
      and new_status in (
        'submitted',
        'procurement_review',
        'ready_for_approval'
      )
      and new_version = old_version
    ) then
      raise exception using
        errcode = '42501',
        message = 'Procurement is not allowed to perform this Phase 1 transition.';
    end if;
  else
    raise exception using
      errcode = '42501',
      message = 'This identity cannot change Phase 1 material plans.';
  end if;

  if old_status in ('approved', 'superseded') then
    raise exception using
      errcode = '55000',
      message = 'Approved or superseded Phase 1 plans are immutable.';
  end if;
  return new;
end;
$$;

revoke execute on function public.phase1_validate_snapshot_transition()
  from public, anon, authenticated;

drop trigger if exists phase1_validate_snapshot_transition
  on public."materialPlans";
create trigger phase1_validate_snapshot_transition
before insert or update on public."materialPlans"
for each row execute function public.phase1_validate_snapshot_transition();

create or replace function public.phase1_sync_snapshot()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_plan_id uuid;
  target_version_id uuid;
  snapshot_status text := public.phase1_status_code(new.data ->> 'status');
  snapshot_version integer := coalesce((new.data ->> 'version')::integer, 0);
  actor_user_id text := coalesce(
    new.data ->> 'updatedByUserId',
    public.app_user_id(),
    ''
  );
  actor_name text := coalesce(
    auth.jwt() -> 'app_metadata' ->> 'full_name',
    auth.jwt() ->> 'email',
    'Migration'
  );
  actor_role text := coalesce(nullif(public.app_role(), ''), 'migration');
  line_record record;
  comment_record record;
  event_record record;
  version_record jsonb;
  source_name text;
  source_comment text;
  source_event text;
begin
  insert into public.phase1_plans (
    legacy_id,
    project_id,
    status,
    current_version,
    current_owner_role,
    current_owner_user_id,
    submitted_at,
    reviewed_at,
    approved_at,
    lock_version,
    updated_at,
    updated_by_user_id
  )
  values (
    new.id,
    new.data ->> 'projectId',
    snapshot_status,
    snapshot_version,
    nullif(new.data ->> 'currentOwnerRole', ''),
    nullif(new.data ->> 'currentOwnerUserId', ''),
    nullif(new.data ->> 'submittedAt', '')::timestamptz,
    nullif(new.data ->> 'reviewedAt', '')::timestamptz,
    nullif(new.data ->> 'approvedAt', '')::timestamptz,
    1,
    new.updated_at,
    nullif(actor_user_id, '')
  )
  on conflict (legacy_id) do update
  set project_id = excluded.project_id,
      status = excluded.status,
      current_version = excluded.current_version,
      current_owner_role = excluded.current_owner_role,
      current_owner_user_id = excluded.current_owner_user_id,
      submitted_at = excluded.submitted_at,
      reviewed_at = excluded.reviewed_at,
      approved_at = excluded.approved_at,
      lock_version = public.phase1_plans.lock_version + 1,
      updated_at = excluded.updated_at,
      updated_by_user_id = excluded.updated_by_user_id
  returning id into target_plan_id;

  if snapshot_version > 0 then
    select value into version_record
    from jsonb_array_elements(coalesce(new.data -> 'versions', '[]'::jsonb))
      with ordinality as version_value(value, ordinal_position)
    where coalesce((value ->> 'version')::integer, 0) = snapshot_version
    order by ordinal_position desc
    limit 1;

    update public.phase1_plan_versions
    set status = 'superseded'
    where plan_id = target_plan_id
      and version_no < snapshot_version
      and status <> 'approved';

    insert into public.phase1_plan_versions (
      plan_id,
      version_no,
      status,
      created_at,
      created_by_user_id,
      created_by_name,
      created_by_role,
      reviewed_at,
      approved_at
    )
    values (
      target_plan_id,
      snapshot_version,
      case
        when snapshot_status = 'draft' then 'submitted'
        else snapshot_status
      end,
      coalesce(
        nullif(version_record ->> 'createdAt', '')::timestamptz,
        nullif(new.data ->> 'submittedAt', '')::timestamptz,
        new.updated_at
      ),
      coalesce(
        nullif(version_record ->> 'createdByUserId', ''),
        nullif(actor_user_id, '')
      ),
      coalesce(
        nullif(version_record ->> 'createdByName', ''),
        actor_name
      ),
      coalesce(
        nullif(version_record ->> 'createdByRole', ''),
        actor_role
      ),
      nullif(new.data ->> 'reviewedAt', '')::timestamptz,
      nullif(new.data ->> 'approvedAt', '')::timestamptz
    )
    on conflict (plan_id, version_no) do update
    set reviewed_at = excluded.reviewed_at,
        approved_at = excluded.approved_at
    returning id into target_version_id;

    if target_version_id is null then
      select id into target_version_id
      from public.phase1_plan_versions
      where plan_id = target_plan_id and version_no = snapshot_version;
    end if;

    if snapshot_status in ('submitted', 'procurement_review')
       or not exists (
         select 1
         from public.phase1_plan_lines existing_line
         where existing_line.version_id = target_version_id
       ) then
      for line_record in
        select value, ordinality
        from jsonb_array_elements(coalesce(new.data -> 'items', '[]'::jsonb))
          with ordinality
      loop
        source_name := case coalesce(
          line_record.value ->> 'proposedSource',
          '__legacy__'
        )
          when 'warehouse' then 'warehouse'
          when 'externalSupplier' then 'external_supplier'
          when 'mixed' then 'mixed'
          when '__legacy__' then case line_record.value ->> 'status'
            when 'In stock' then 'warehouse'
            when 'Arranged' then 'external_supplier'
            else 'not_reviewed'
          end
          else 'not_reviewed'
        end;
        insert into public.phase1_plan_lines (
          version_id,
          legacy_line_id,
          line_no,
          catalogue_material_id,
          category_id,
          building_id,
          item_description,
          size_text,
          model_serial_text,
          make_origin_text,
          requested_qty,
          unit_symbol,
          remarks,
          is_custom,
          proposed_source,
          on_hand_qty_snapshot,
          available_qty_snapshot,
          procurement_note,
          source_reviewed_at,
          source_reviewed_by_user_id
        )
        values (
          target_version_id,
          line_record.value ->> 'id',
          line_record.ordinality::integer,
          nullif(line_record.value ->> 'materialId', ''),
          nullif(line_record.value ->> 'categoryId', ''),
          coalesce(
            nullif(line_record.value ->> 'buildingId', ''),
            'project-wide'
          ),
          line_record.value ->> 'description',
          coalesce(line_record.value ->> 'size', ''),
          coalesce(
            nullif(line_record.value ->> 'modelSerial', ''),
            line_record.value ->> 'tagNo',
            ''
          ),
          coalesce(
            nullif(line_record.value ->> 'makeOrigin', ''),
            concat_ws(
              ' / ',
              nullif(line_record.value ->> 'brand', ''),
              nullif(line_record.value ->> 'countryOfOrigin', '')
            ),
            ''
          ),
          (line_record.value ->> 'quantity')::numeric,
          line_record.value ->> 'unitSymbol',
          coalesce(line_record.value ->> 'note', ''),
          coalesce((line_record.value ->> 'isCustom')::boolean, false),
          source_name,
          nullif(line_record.value ->> 'onHandQtySnapshot', '')::numeric,
          nullif(line_record.value ->> 'availableQtySnapshot', '')::numeric,
          coalesce(line_record.value ->> 'procurementNote', ''),
          case when source_name = 'not_reviewed' then null else new.updated_at end,
          case
            when source_name = 'not_reviewed' then null
            else nullif(actor_user_id, '')
          end
        )
        on conflict (version_id, legacy_line_id) do update
        set line_no = excluded.line_no,
            catalogue_material_id = excluded.catalogue_material_id,
            category_id = excluded.category_id,
            building_id = excluded.building_id,
            item_description = excluded.item_description,
            size_text = excluded.size_text,
            model_serial_text = excluded.model_serial_text,
            make_origin_text = excluded.make_origin_text,
            requested_qty = excluded.requested_qty,
            unit_symbol = excluded.unit_symbol,
            remarks = excluded.remarks,
            is_custom = excluded.is_custom,
            proposed_source = excluded.proposed_source,
            on_hand_qty_snapshot = excluded.on_hand_qty_snapshot,
            available_qty_snapshot = excluded.available_qty_snapshot,
            procurement_note = excluded.procurement_note,
            source_reviewed_at = excluded.source_reviewed_at,
            source_reviewed_by_user_id = excluded.source_reviewed_by_user_id;
      end loop;

      delete from public.phase1_plan_lines target
      where target.version_id = target_version_id
        and not exists (
          select 1
          from jsonb_array_elements(
            coalesce(new.data -> 'items', '[]'::jsonb)
          ) item
          where item ->> 'id' = target.legacy_line_id
        );
    end if;

    update public.phase1_plan_versions
    set status = case
          when snapshot_status = 'draft' then status
          else snapshot_status
        end,
        reviewed_at = nullif(new.data ->> 'reviewedAt', '')::timestamptz,
        approved_at = nullif(new.data ->> 'approvedAt', '')::timestamptz
    where id = target_version_id;
  end if;

  for comment_record in
    select value, ordinality
    from jsonb_array_elements(coalesce(new.data -> 'comments', '[]'::jsonb))
      with ordinality
  loop
    source_comment := coalesce(
      nullif(comment_record.value ->> 'id', ''),
      md5(
        coalesce(comment_record.value ->> 'authorName', '') || '|' ||
        coalesce(comment_record.value ->> 'text', '') || '|' ||
        coalesce(comment_record.value ->> 'timestamp', '') || '|' ||
        comment_record.ordinality::text
      )
    );
    insert into public.phase1_plan_comments (
      plan_id,
      version_no,
      source_comment_id,
      legacy_line_id,
      author_user_id,
      author_name,
      author_role,
      body,
      created_at
    )
    values (
      target_plan_id,
      snapshot_version,
      source_comment,
      nullif(comment_record.value ->> 'lineItemId', ''),
      nullif(comment_record.value ->> 'authorUserId', ''),
      comment_record.value ->> 'authorName',
      comment_record.value ->> 'authorRole',
      comment_record.value ->> 'text',
      (comment_record.value ->> 'timestamp')::timestamptz
    )
    on conflict (plan_id, source_comment_id) do nothing;
  end loop;

  for event_record in
    select value, ordinality
    from jsonb_array_elements(coalesce(new.data -> 'activity', '[]'::jsonb))
      with ordinality
  loop
    source_event := md5(
      coalesce(event_record.value ->> 'action', '') || '|' ||
      coalesce(event_record.value ->> 'timestamp', '') || '|' ||
      coalesce(event_record.value ->> 'actorUserId', '') || '|' ||
      event_record.ordinality::text
    );
    insert into public.phase1_plan_activity (
      plan_id,
      version_no,
      source_event_id,
      action,
      detail,
      actor_user_id,
      actor_name,
      actor_role,
      occurred_at
    )
    values (
      target_plan_id,
      snapshot_version,
      source_event,
      event_record.value ->> 'action',
      coalesce(event_record.value ->> 'detail', ''),
      nullif(event_record.value ->> 'actorUserId', ''),
      event_record.value ->> 'actorName',
      event_record.value ->> 'actorRole',
      (event_record.value ->> 'timestamp')::timestamptz
    )
    on conflict (plan_id, source_event_id) do nothing;
  end loop;

  return new;
end;
$$;

revoke execute on function public.phase1_sync_snapshot()
  from public, anon, authenticated;

drop trigger if exists phase1_sync_snapshot on public."materialPlans";
create trigger phase1_sync_snapshot
after insert or update on public."materialPlans"
for each row execute function public.phase1_sync_snapshot();

create or replace function public.phase1_project_visible(p_project_id text)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select
    public.app_role() in ('admin', 'procurement')
    or exists (
      select 1
      from public.projects project
      where project.id = p_project_id
        and public.app_user_id() <> ''
        and (
          project.data ->> 'assignedEngineerId' = public.app_user_id()
          or coalesce(project.data -> 'designEngineerUserIds', '[]'::jsonb)
               ? public.app_user_id()
          or (
            nullif(project.data ->> 'assignedEngineerId', '') is null
            and jsonb_array_length(
              coalesce(
                project.data -> 'designEngineerUserIds',
                '[]'::jsonb
              )
            ) = 0
          )
        )
    );
$$;

revoke execute on function public.phase1_project_visible(text)
  from public, anon;
grant execute on function public.phase1_project_visible(text)
  to authenticated, service_role;

alter table public.phase1_plans enable row level security;
alter table public.phase1_plan_versions enable row level security;
alter table public.phase1_plan_lines enable row level security;
alter table public.phase1_plan_comments enable row level security;
alter table public.phase1_plan_activity enable row level security;

revoke all on table public.phase1_plans from public, anon, authenticated;
revoke all on table public.phase1_plan_versions from public, anon, authenticated;
revoke all on table public.phase1_plan_lines from public, anon, authenticated;
revoke all on table public.phase1_plan_comments from public, anon, authenticated;
revoke all on table public.phase1_plan_activity from public, anon, authenticated;

grant select on table public.phase1_plans to authenticated;
grant select on table public.phase1_plan_versions to authenticated;
grant select on table public.phase1_plan_lines to authenticated;
grant select on table public.phase1_plan_comments to authenticated;
grant select on table public.phase1_plan_activity to authenticated;

grant all on table public.phase1_plans to service_role;
grant all on table public.phase1_plan_versions to service_role;
grant all on table public.phase1_plan_lines to service_role;
grant all on table public.phase1_plan_comments to service_role;
grant all on table public.phase1_plan_activity to service_role;

create policy phase1_plans_read
on public.phase1_plans for select
to authenticated
using (public.phase1_project_visible(project_id));

create policy phase1_versions_read
on public.phase1_plan_versions for select
to authenticated
using (
  exists (
    select 1
    from public.phase1_plans plan
    where plan.id = phase1_plan_versions.plan_id
      and public.phase1_project_visible(plan.project_id)
  )
);

create policy phase1_lines_read
on public.phase1_plan_lines for select
to authenticated
using (
  exists (
    select 1
    from public.phase1_plan_versions version
    join public.phase1_plans plan on plan.id = version.plan_id
    where version.id = phase1_plan_lines.version_id
      and public.phase1_project_visible(plan.project_id)
  )
);

create policy phase1_comments_read
on public.phase1_plan_comments for select
to authenticated
using (
  exists (
    select 1
    from public.phase1_plans plan
    where plan.id = phase1_plan_comments.plan_id
      and public.phase1_project_visible(plan.project_id)
  )
);

create policy phase1_activity_read
on public.phase1_plan_activity for select
to authenticated
using (
  exists (
    select 1
    from public.phase1_plans plan
    where plan.id = phase1_plan_activity.plan_id
      and public.phase1_project_visible(plan.project_id)
  )
);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'phase1_plans',
    'phase1_plan_versions',
    'phase1_plan_lines',
    'phase1_plan_comments',
    'phase1_plan_activity'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end;
$$;

-- Backfill any legacy Phase 1 snapshots through the same projection trigger.
update public."materialPlans"
set updated_at = updated_at;
