-- Yorks R35 material-workflow trust remediation.
--
-- This migration is additive. It preserves immutable dispatch/review/document
-- rows, captures exact actor roles and controlled-document identity for new
-- events, exposes a decimal-safe canonical lifecycle projection, and closes
-- the stale-JWT notification read boundary.

begin;

-- Forward-repair an environment that may already have executed the earlier
-- unsafe blanket discriminator backfill. Preserve any revision whose signed
-- audit event proves it was generated from a dispatch, even when the command
-- also linked an already-confirmed review. Only the older receipt-derived rows
-- without that dispatch marker are eligible for forward repair.
update public.v1_delivery_order_revisions revision
   set snapshot_kind = 'receipt_review'
 where revision.snapshot_kind = 'dispatch'
   and revision.receipt_review_id is not null
   and not exists (
     select 1
     from public.v1_audit_events audit
     where audit.entity_type = 'delivery_order_revision'
       and audit.entity_id = revision.id
       and audit.event_type in (
         'delivery_order_generated', 'delivery_order_superseded'
       )
       and audit.after_data ->> 'snapshot_source' = 'dispatch'
   );

alter table public.v1_arrangement_decisions
  add column if not exists decided_by_exact_role text,
  add column if not exists decided_by_display_name_snapshot text;
alter table public.v1_procurement_arrangements
  add column if not exists saved_by_exact_role text,
  add column if not exists saved_by_display_name_snapshot text;
alter table public.v1_material_dispatches
  add column if not exists dispatched_by_exact_role text,
  add column if not exists dispatched_by_display_name_snapshot text;
alter table public.v1_receipt_reviews
  add column if not exists reviewed_by_exact_role text,
  add column if not exists reviewed_by_display_name_snapshot text;
alter table public.v1_delivery_order_revisions
  add column if not exists generated_by_exact_role text,
  add column if not exists generated_by_display_name_snapshot text,
  add column if not exists document_identity_snapshot jsonb,
  add column if not exists document_identity_verified boolean not null default false;
alter table public.v1_material_requests
  add column if not exists document_identity_snapshot jsonb,
  add column if not exists document_identity_verified boolean not null default false;
alter table public.v1_audit_events
  add column if not exists actor_display_name_snapshot text;

alter table public.v1_procurement_arrangements
  drop constraint if exists v1_procurement_arrangements_exact_role_check;
alter table public.v1_procurement_arrangements
  add constraint v1_procurement_arrangements_exact_role_check
  check (saved_by_exact_role is null or saved_by_exact_role in (
    'procurement', 'admin'
  ));

alter table public.v1_arrangement_decisions
  drop constraint if exists v1_arrangement_decisions_exact_role_check;
alter table public.v1_arrangement_decisions
  add constraint v1_arrangement_decisions_exact_role_check
  check (decided_by_exact_role is null or decided_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  ));
alter table public.v1_material_dispatches
  drop constraint if exists v1_material_dispatches_exact_role_check;
alter table public.v1_material_dispatches
  add constraint v1_material_dispatches_exact_role_check
  check (dispatched_by_exact_role is null or dispatched_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  ));
alter table public.v1_receipt_reviews
  drop constraint if exists v1_receipt_reviews_exact_role_check;
alter table public.v1_receipt_reviews
  add constraint v1_receipt_reviews_exact_role_check
  check (reviewed_by_exact_role is null or reviewed_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  ));
alter table public.v1_delivery_order_revisions
  drop constraint if exists v1_delivery_order_revisions_exact_role_check;
alter table public.v1_delivery_order_revisions
  add constraint v1_delivery_order_revisions_exact_role_check
  check (generated_by_exact_role is null or generated_by_exact_role in (
    'project_engineer', 'site_engineer', 'senior_mechanical_engineer',
    'project_manager', 'procurement', 'admin'
  ));
alter table public.v1_delivery_order_revisions
  drop constraint if exists v1_delivery_order_revisions_identity_shape_check;
alter table public.v1_delivery_order_revisions
  add constraint v1_delivery_order_revisions_identity_shape_check
  check (document_identity_snapshot is null
    or jsonb_typeof(document_identity_snapshot) = 'object');
alter table public.v1_material_requests
  drop constraint if exists v1_material_requests_identity_shape_check;
alter table public.v1_material_requests
  add constraint v1_material_requests_identity_shape_check
  check (document_identity_snapshot is null
    or jsonb_typeof(document_identity_snapshot) = 'object');

-- Historical exact roles are copied only from immutable audit evidence. Rows
-- without such evidence remain explicitly unknown instead of being inferred
-- from a current profile or normalized workflow role.
update public.v1_arrangement_decisions decision
   set decided_by_exact_role = (
     select audit.actor_exact_role
     from public.v1_audit_events audit
     where audit.entity_type = 'procurement_arrangement'
       and audit.entity_id = decision.arrangement_id
       and audit.actor_auth_user_id = decision.decided_by_auth_user_id
       and audit.event_type in ('arrangement_approved', 'arrangement_returned')
       and audit.actor_exact_role is not null
     order by audit.occurred_at desc, audit.id desc
     limit 1
   )
 where decision.decided_by_exact_role is null;

update public.v1_procurement_arrangements arrangement
   set saved_by_exact_role = (
     select audit.actor_exact_role
     from public.v1_audit_events audit
     where audit.entity_type = 'procurement_arrangement'
       and audit.entity_id = arrangement.id
       and audit.actor_auth_user_id = arrangement.saved_by_auth_user_id
       and audit.event_type = 'arrangement_saved'
       and audit.actor_exact_role in ('procurement', 'admin')
     order by audit.occurred_at desc, audit.id desc
     limit 1
   )
 where arrangement.saved_by_exact_role is null
   and arrangement.saved_by_auth_user_id is not null;

update public.v1_material_dispatches dispatch
   set dispatched_by_exact_role = (
     select audit.actor_exact_role
     from public.v1_audit_events audit
     where audit.entity_type = 'material_dispatch'
       and audit.entity_id = dispatch.id
       and audit.actor_auth_user_id = dispatch.dispatched_by_auth_user_id
       and audit.event_type = 'materials_dispatched'
       and audit.actor_exact_role is not null
     order by audit.occurred_at desc, audit.id desc
     limit 1
   )
 where dispatch.dispatched_by_exact_role is null;

update public.v1_receipt_reviews review
   set reviewed_by_exact_role = (
     select audit.actor_exact_role
     from public.v1_audit_events audit
     where audit.entity_type = 'receipt_review'
       and audit.entity_id = review.id
       and audit.actor_auth_user_id = review.reviewed_by_auth_user_id
       and audit.event_type = 'receipt_review_confirmed'
       and audit.actor_exact_role is not null
     order by audit.occurred_at desc, audit.id desc
     limit 1
   )
 where review.reviewed_by_exact_role is null;

update public.v1_delivery_order_revisions revision
   set generated_by_exact_role = (
     select audit.actor_exact_role
     from public.v1_audit_events audit
     where audit.entity_type = 'delivery_order_revision'
       and audit.entity_id = revision.id
       and audit.actor_auth_user_id = revision.generated_by_auth_user_id
       and audit.event_type in ('delivery_order_generated', 'delivery_order_superseded')
       and audit.actor_exact_role is not null
     order by audit.occurred_at desc, audit.id desc
     limit 1
   )
 where revision.generated_by_exact_role is null;

create or replace function public.v1_capture_arrangement_decision_exact_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.decided_by_auth_user_id = auth.uid()
    and public.v1_is_valid_role(public.v1_current_exact_role()) then
    new.decided_by_exact_role := public.v1_current_exact_role();
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into new.decided_by_display_name_snapshot
  from public.v1_profiles profile
  where profile.auth_user_id = new.decided_by_auth_user_id;
  return new;
end;
$$;

drop trigger if exists v1_arrangement_decision_capture_exact_role
  on public.v1_arrangement_decisions;
create trigger v1_arrangement_decision_capture_exact_role
before insert on public.v1_arrangement_decisions
for each row execute function public.v1_capture_arrangement_decision_exact_role();

create or replace function public.v1_capture_arrangement_saved_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.saved_by_auth_user_id is not null
    and (old.saved_by_auth_user_id is distinct from new.saved_by_auth_user_id
      or old.saved_at is distinct from new.saved_at) then
    if new.saved_by_auth_user_id = auth.uid()
      and public.v1_current_exact_role() in ('procurement', 'admin') then
      new.saved_by_exact_role := public.v1_current_exact_role();
    end if;
    select public.v1_safe_profile_display_name(
      profile.display_name, profile.auth_user_id
    ) into new.saved_by_display_name_snapshot
    from public.v1_profiles profile
    where profile.auth_user_id = new.saved_by_auth_user_id;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_arrangement_capture_saved_identity
  on public.v1_procurement_arrangements;
create trigger v1_arrangement_capture_saved_identity
before update of saved_at, saved_by_auth_user_id
on public.v1_procurement_arrangements
for each row execute function public.v1_capture_arrangement_saved_identity();

create or replace function public.v1_capture_dispatch_exact_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.dispatched_by_auth_user_id = auth.uid()
    and public.v1_is_valid_role(public.v1_current_exact_role()) then
    new.dispatched_by_exact_role := public.v1_current_exact_role();
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into new.dispatched_by_display_name_snapshot
  from public.v1_profiles profile
  where profile.auth_user_id = new.dispatched_by_auth_user_id;
  return new;
end;
$$;

drop trigger if exists v1_material_dispatch_capture_exact_role
  on public.v1_material_dispatches;
create trigger v1_material_dispatch_capture_exact_role
before insert on public.v1_material_dispatches
for each row execute function public.v1_capture_dispatch_exact_role();

create or replace function public.v1_capture_receipt_review_exact_role()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reviewed_by_auth_user_id = auth.uid()
    and public.v1_is_valid_role(public.v1_current_exact_role()) then
    new.reviewed_by_exact_role := public.v1_current_exact_role();
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into new.reviewed_by_display_name_snapshot
  from public.v1_profiles profile
  where profile.auth_user_id = new.reviewed_by_auth_user_id;
  return new;
end;
$$;

drop trigger if exists v1_receipt_review_capture_exact_role
  on public.v1_receipt_reviews;
create trigger v1_receipt_review_capture_exact_role
before insert on public.v1_receipt_reviews
for each row execute function public.v1_capture_receipt_review_exact_role();

create or replace function public.v1_capture_audit_actor_display_name()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into new.actor_display_name_snapshot
  from public.v1_profiles profile
  where profile.auth_user_id = new.actor_auth_user_id;
  return new;
end;
$$;

drop trigger if exists v1_audit_capture_actor_display_name
  on public.v1_audit_events;
create trigger v1_audit_capture_actor_display_name
before insert on public.v1_audit_events
for each row execute function public.v1_capture_audit_actor_display_name();

create or replace function public.v1_capture_material_request_document_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.submitted_at is null and new.submitted_at is not null then
    select jsonb_build_object(
      'project_id', project.id,
      'project_ref', project.project_ref,
      'project_name', project.name,
      'job_contract_reference', project.job_contract_reference,
      'scope_id', scope.id,
      'scope_code', scope.scope_code,
      'scope_name', scope.name,
      'main_contractor_name', (
        select party.party_name
        from public.v1_project_parties party
        where party.project_id = project.id
          and party.party_kind = 'main_contractor'
        order by party.party_order, party.id
        limit 1
      ),
      'delivery_address', scope.delivery_address,
      'material_context', new.title
    ) into new.document_identity_snapshot
    from public.v1_projects project
    join public.v1_project_scopes scope
      on scope.id = new.scope_id and scope.project_id = project.id
    where project.id = new.project_id;
    new.document_identity_verified := new.document_identity_snapshot is not null;
  end if;
  return new;
end;
$$;

drop trigger if exists v1_material_request_capture_document_identity
  on public.v1_material_requests;
create trigger v1_material_request_capture_document_identity
before update of submitted_at on public.v1_material_requests
for each row execute function public.v1_capture_material_request_document_identity();

create or replace function public.v1_capture_delivery_order_revision_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.generated_by_auth_user_id = auth.uid()
    and public.v1_is_valid_role(public.v1_current_exact_role()) then
    new.generated_by_exact_role := public.v1_current_exact_role();
  end if;
  select public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
    into new.generated_by_display_name_snapshot
  from public.v1_profiles profile
  where profile.auth_user_id = new.generated_by_auth_user_id;

  select jsonb_build_object(
    'project_id', project.id,
    'project_ref', project.project_ref,
    'project_name', project.name,
    'job_contract_reference', project.job_contract_reference,
    'scope_id', scope.id,
    'scope_code', scope.scope_code,
    'scope_name', scope.name,
    'main_contractor_name', (
      select party.party_name
      from public.v1_project_parties party
      where party.project_id = project.id
        and party.party_kind = 'main_contractor'
      order by party.party_order, party.id
      limit 1
    ),
    'delivery_address', scope.delivery_address,
    'material_context', request_record.title,
    'request_number', request_record.request_number,
    'dispatch_id', dispatch.id,
    'dispatch_number', dispatch.dispatch_number,
    'delivery_reference', dispatch.delivery_reference,
    'dispatch_date', dispatch.dispatch_date,
    'driver_name', dispatch.driver_name,
    'vehicle_reference', dispatch.vehicle_reference,
    'dispatched_at', dispatch.dispatched_at,
    'dispatched_by_display_name', coalesce(
      dispatch.dispatched_by_display_name_snapshot,
      public.v1_safe_profile_display_name(
        dispatcher.display_name, dispatcher.auth_user_id
      )
    ),
    'dispatched_by_exact_role', coalesce(
      dispatch.dispatched_by_exact_role, dispatch.dispatched_by_role
    )
  ) into new.document_identity_snapshot
  from public.v1_delivery_orders delivery_order
  join public.v1_material_requests request_record
    on request_record.id = delivery_order.request_id
  join public.v1_projects project on project.id = delivery_order.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  join public.v1_material_dispatches dispatch
    on dispatch.id = delivery_order.dispatch_id
  join public.v1_profiles dispatcher
    on dispatcher.auth_user_id = dispatch.dispatched_by_auth_user_id
  where delivery_order.id = new.delivery_order_id;
  new.document_identity_verified := new.document_identity_snapshot is not null;
  return new;
end;
$$;

drop trigger if exists v1_delivery_order_revision_capture_identity
  on public.v1_delivery_order_revisions;
create trigger v1_delivery_order_revision_capture_identity
before insert on public.v1_delivery_order_revisions
for each row execute function public.v1_capture_delivery_order_revision_identity();

-- Canonical line quantities. All arithmetic remains PostgreSQL numeric; every
-- client receives text values and never reconstructs authority from display.
create or replace function public.v1_material_request_line_lifecycle_projection(
  p_request_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with lifecycle as (
    select
      request_line.id as request_line_id,
      request_line.display_order,
      request_line.requested_qty,
      current_arrangement.arrangement_status,
      current_arrangement.decision as arrangement_decision,
      current_arrangement.source_kind,
      current_arrangement.arranged_qty,
      current_arrangement.reason as arrangement_reason,
      coalesce(approval.approved_qty, 0::numeric) as approved_qty,
      coalesce(dispatch_totals.dispatched_qty, 0::numeric) as dispatched_qty,
      coalesce(dispatch_totals.in_transit_qty, 0::numeric) as in_transit_qty,
      coalesce(review_totals.good_qty, 0::numeric) as good_qty,
      coalesce(review_totals.missing_qty, 0::numeric) as missing_qty,
      coalesce(review_totals.damaged_qty, 0::numeric) as damaged_qty
    from public.v1_material_request_lines request_line
    left join lateral (
      select arrangement.status as arrangement_status,
        arrangement_line.decision,
        arrangement_line.source_kind,
        arrangement_line.arranged_qty,
        arrangement_line.reason
      from public.v1_procurement_arrangements arrangement
      join public.v1_procurement_arrangement_lines arrangement_line
        on arrangement_line.arrangement_id = arrangement.id
       and arrangement_line.request_line_id = request_line.id
      where arrangement.request_id = request_line.request_id
        and arrangement.is_current
      order by arrangement.arrangement_version desc
      limit 1
    ) current_arrangement on true
    left join public.v1_material_request_line_approvals approval
      on approval.request_line_id = request_line.id
    left join lateral (
      select
        coalesce(sum(dispatch_line.dispatched_qty), 0::numeric) as dispatched_qty,
        coalesce(sum(dispatch_line.dispatched_qty) filter (
          where dispatch.state = 'receipt_pending'
        ), 0::numeric) as in_transit_qty
      from public.v1_material_dispatch_lines dispatch_line
      join public.v1_material_dispatches dispatch
        on dispatch.id = dispatch_line.dispatch_id
      where dispatch_line.request_line_id = request_line.id
    ) dispatch_totals on true
    left join lateral (
      select
        coalesce(sum(review_line.good_qty), 0::numeric) as good_qty,
        coalesce(sum(review_line.exception_qty) filter (
          where review_line.outcome = 'missing'
        ), 0::numeric) as missing_qty,
        coalesce(sum(review_line.exception_qty) filter (
          where review_line.outcome = 'damaged'
        ), 0::numeric) as damaged_qty
      from public.v1_receipt_review_lines review_line
      join public.v1_receipt_reviews review
        on review.id = review_line.receipt_review_id
       and review.state = 'confirmed'
      join public.v1_material_dispatch_lines dispatch_line
        on dispatch_line.id = review_line.dispatch_line_id
      where dispatch_line.request_line_id = request_line.id
    ) review_totals on true
    where request_line.request_id = p_request_id
  ), quantities as (
    select *,
      case
        when arrangement_decision = 'unavailable' then requested_qty
        when arrangement_decision = 'partial' then greatest(
          requested_qty - coalesce(arranged_qty, 0::numeric), 0::numeric
        )
        else 0::numeric
      end as cannot_provide_qty,
      greatest(approved_qty - good_qty - in_transit_qty, 0::numeric)
        as remaining_approved_qty,
      least(
        missing_qty + damaged_qty,
        greatest(approved_qty - good_qty, 0::numeric)
      ) as replacement_eligible_qty
    from lifecycle
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'request_line_id', request_line_id,
    'requested_qty', requested_qty::text,
    'arrangement_decision', arrangement_decision,
    'arrangement_status', arrangement_status,
    'source_kind', source_kind,
    'arranged_qty', coalesce(arranged_qty, 0::numeric)::text,
    'cannot_provide_qty', cannot_provide_qty::text,
    'arrangement_reason', arrangement_reason,
    'approved_qty', approved_qty::text,
    'dispatched_qty', dispatched_qty::text,
    'in_transit_qty', in_transit_qty::text,
    'reviewed_good_qty', good_qty::text,
    'reviewed_missing_qty', missing_qty::text,
    'reviewed_damaged_qty', damaged_qty::text,
    'good_qty', good_qty::text,
    'missing_qty', missing_qty::text,
    'damaged_qty', damaged_qty::text,
    'remaining_approved_qty', remaining_approved_qty::text,
    'replacement_eligible_qty', replacement_eligible_qty::text,
    'ordinary_outstanding_qty', greatest(
      remaining_approved_qty - replacement_eligible_qty, 0::numeric
    )::text,
    'fulfilled_qty', good_qty::text,
    'status', case
      when arrangement_status is null then 'Pending arrangement'
      when arrangement_status = 'awaiting_approval' then 'Awaiting approval'
      when arrangement_status = 'returned' then 'Returned to Procurement'
      when arrangement_decision = 'unavailable' or approved_qty = 0
        then 'Cannot Provide Now'
      when good_qty >= approved_qty and in_transit_qty = 0 then 'Fully received'
      when in_transit_qty > 0 then 'Awaiting receipt review'
      when replacement_eligible_qty > 0 then 'Replacement required'
      when good_qty > 0 then 'Partially received'
      when dispatched_qty = 0 then 'Not dispatched'
      else 'Partially dispatched'
    end
  ) order by display_order), '[]'::jsonb)
  from quantities;
$$;

create or replace function public.v1_refresh_material_request_logistics_state(
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approved_qty numeric(18, 4);
  v_good_qty numeric(18, 4);
  v_in_transit_qty numeric(18, 4);
  v_exception_qty numeric(18, 4);
  v_remaining_qty numeric(18, 4);
  v_replacement_qty numeric(18, 4);
  v_has_review boolean;
  v_has_dispatch boolean;
  v_state text;
  v_owner text;
  v_action text;
begin
  select coalesce(sum(approval.approved_qty), 0)
    into v_approved_qty
  from public.v1_material_request_line_approvals approval
  join public.v1_material_request_lines request_line
    on request_line.id = approval.request_line_id
  where request_line.request_id = p_request_id;

  select coalesce(sum(review_line.good_qty), 0),
      coalesce(sum(review_line.exception_qty), 0), count(*) > 0
    into v_good_qty, v_exception_qty, v_has_review
  from public.v1_receipt_review_lines review_line
  join public.v1_receipt_reviews review
    on review.id = review_line.receipt_review_id
  where review.request_id = p_request_id and review.state = 'confirmed';

  select coalesce(sum(dispatch_line.dispatched_qty) filter (
      where dispatch.state = 'receipt_pending'
    ), 0), count(*) > 0
    into v_in_transit_qty, v_has_dispatch
  from public.v1_material_dispatch_lines dispatch_line
  join public.v1_material_dispatches dispatch
    on dispatch.id = dispatch_line.dispatch_id
  where dispatch.request_id = p_request_id;

  v_remaining_qty := greatest(
    v_approved_qty - v_good_qty - v_in_transit_qty, 0
  );
  v_replacement_qty := least(
    v_exception_qty, greatest(v_approved_qty - v_good_qty, 0)
  );

  if v_good_qty >= v_approved_qty and v_in_transit_qty = 0 then
    v_state := 'received';
    v_owner := 'project_engineer';
    v_action := 'material_request_close_review';
  elsif v_in_transit_qty > 0 then
    v_state := case when v_has_review or v_good_qty > 0
      then 'partially_received'
      when v_in_transit_qty >= v_approved_qty then 'dispatched'
      else 'partially_dispatched' end;
    v_owner := 'site_engineer';
    v_action := 'receipt_review_required';
  elsif v_replacement_qty > 0 then
    v_state := 'partially_received';
    v_owner := 'procurement';
    v_action := 'replacement_dispatch_required';
  elsif v_remaining_qty > 0 and (v_has_review or v_has_dispatch) then
    v_state := case when v_good_qty > 0 or v_has_review
      then 'partially_received' else 'partially_dispatched' end;
    v_owner := 'procurement';
    v_action := 'remaining_dispatch_required';
  else
    v_state := 'partially_dispatched';
    v_owner := 'procurement';
    v_action := 'dispatch_required';
  end if;

  update public.v1_material_requests request_record
     set state = v_state,
         current_action_owner_role = v_owner,
         current_action_code = v_action,
         record_version = request_record.record_version + 1,
         updated_at = clock_timestamp()
   where request_record.id = p_request_id;
  return jsonb_build_object(
    'state', v_state,
    'current_action_owner_role', v_owner,
    'current_action_code', v_action,
    'approved_qty', v_approved_qty::text,
    'good_received_qty', v_good_qty::text,
    'in_transit_qty', v_in_transit_qty::text,
    'exception_qty', v_exception_qty::text,
    'remaining_approved_qty', v_remaining_qty::text,
    'replacement_eligible_qty', v_replacement_qty::text
  );
end;
$$;

create or replace function public.v1_material_request_document_projection(
  p_request_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_include_commercial boolean := public.v1_has_capability('view_commercials');
  v_request jsonb;
  v_lifecycle jsonb;
begin
  if not public.v1_material_request_readable(p_request_id) then
    raise exception 'V1_MATERIAL_REQUEST_DOCUMENT_NOT_READABLE'
      using errcode = '42501';
  end if;
  v_lifecycle := public.v1_material_request_line_lifecycle_projection(p_request_id);
  select jsonb_build_object(
    'id', request_record.id,
    'project_id', request_record.project_id,
    'project_ref', coalesce(
      request_record.document_identity_snapshot ->> 'project_ref',
      project.project_ref
    ),
    'project_name', coalesce(
      request_record.document_identity_snapshot ->> 'project_name', project.name
    ),
    'job_contract_reference', coalesce(
      request_record.document_identity_snapshot ->> 'job_contract_reference',
      project.job_contract_reference
    ),
    'scope_id', request_record.scope_id,
    'scope_name', coalesce(
      request_record.document_identity_snapshot ->> 'scope_name', scope.name
    ),
    'scope_code', coalesce(
      request_record.document_identity_snapshot ->> 'scope_code', scope.scope_code
    ),
    'document_identity_verified', request_record.document_identity_verified,
    'state', request_record.state,
    'record_version', request_record.record_version,
    'request_number', request_record.request_number,
    'title', request_record.title,
    'timing', request_record.timing,
    'scheduled_date', request_record.scheduled_date,
    'delivery_note', request_record.delivery_note,
    'requester_display_name', request_record.requester_display_name,
    'requester_project_role', request_record.requester_project_role,
    'requester_exact_role', request_record.requester_exact_role,
    'current_action_owner_role', request_record.current_action_owner_role,
    'current_action_code', request_record.current_action_code,
    'submitted_at', request_record.submitted_at,
    'cancelled_at', request_record.cancelled_at,
    'cancellation_reason', request_record.cancellation_reason,
    'created_at', request_record.created_at,
    'updated_at', request_record.updated_at,
    'lines', coalesce((
      select jsonb_agg(public.v1_material_request_line_projection(
        line_record.id, v_include_commercial
      ) order by line_record.display_order)
      from public.v1_material_request_lines line_record
      where line_record.request_id = request_record.id
    ), '[]'::jsonb)
  ) into v_request
  from public.v1_material_requests request_record
  join public.v1_projects project on project.id = request_record.project_id
  join public.v1_project_scopes scope on scope.id = request_record.scope_id
  where request_record.id = p_request_id;

  return jsonb_build_object(
    'request', v_request,
    'project_engineers', (
      select request_record.project_engineer_snapshot
      from public.v1_material_requests request_record
      where request_record.id = p_request_id
    ),
    'arrangement', (
      select jsonb_build_object(
        'display_name', coalesce(
          arrangement.saved_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            profile.display_name, profile.auth_user_id
          )
        ),
        'role', coalesce(arrangement.saved_by_exact_role, 'procurement'),
        'reference', concat('Arrangement v', arrangement.arrangement_version),
        'acted_at', arrangement.saved_at
      )
      from public.v1_procurement_arrangements arrangement
      join public.v1_profiles profile
        on profile.auth_user_id = arrangement.saved_by_auth_user_id
      where arrangement.request_id = p_request_id
        and arrangement.saved_at is not null
      order by arrangement.arrangement_version desc
      limit 1
    ),
    'approval', (
      select jsonb_build_object(
        'display_name', coalesce(
          decision.decided_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            profile.display_name, profile.auth_user_id
          )
        ),
        'role', coalesce(decision.decided_by_exact_role, decision.decided_by_role),
        'reference', concat('Arrangement v', arrangement.arrangement_version),
        'acted_at', decision.created_at
      )
      from public.v1_arrangement_decisions decision
      join public.v1_procurement_arrangements arrangement
        on arrangement.id = decision.arrangement_id
      join public.v1_profiles profile
        on profile.auth_user_id = decision.decided_by_auth_user_id
      where decision.request_id = p_request_id
        and decision.decision = 'approved'
      order by decision.created_at desc
      limit 1
    ),
    'dispatch', (
      select jsonb_build_object(
        'display_name', coalesce(
          dispatch.dispatched_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            profile.display_name, profile.auth_user_id
          )
        ),
        'role', coalesce(
          dispatch.dispatched_by_exact_role, dispatch.dispatched_by_role
        ),
        'reference', dispatch.delivery_reference,
        'acted_at', dispatch.dispatched_at
      )
      from public.v1_material_dispatches dispatch
      join public.v1_profiles profile
        on profile.auth_user_id = dispatch.dispatched_by_auth_user_id
      where dispatch.request_id = p_request_id
      order by dispatch.dispatched_at desc, dispatch.id desc
      limit 1
    ),
    'show_line_status', jsonb_array_length(v_lifecycle) > 0,
    'line_lifecycle', v_lifecycle,
    'receipt_statuses', v_lifecycle
  );
end;
$$;

create or replace function public.v1_delivery_order_projection(
  p_delivery_order_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', delivery_order.id,
    'dispatch_id', delivery_order.dispatch_id,
    'delivery_order_reference', delivery_order.delivery_order_reference,
    'record_version', delivery_order.record_version,
    'current_revision_id', delivery_order.current_revision_id,
    'revisions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', revision.id,
        'revision_number', revision.revision_number,
        'snapshot_kind', revision.snapshot_kind,
        'is_current', revision.id = delivery_order.current_revision_id,
        'generated_at', revision.generated_at,
        'generated_by_display_name', coalesce(
          revision.generated_by_display_name_snapshot,
          public.v1_safe_profile_display_name(profile.display_name, profile.auth_user_id)
        ),
        'generated_by_role', coalesce(
          revision.generated_by_exact_role, revision.generated_by_role
        ),
        'document_identity_verified', revision.document_identity_verified,
        'document_identity', revision.document_identity_snapshot,
        'lines', coalesce((
          select jsonb_agg(jsonb_build_object(
            's_no', line.display_order,
            'item_description', line.item_description,
            'quantity', line.delivery_quantity::text,
            'unit', line.unit
          ) order by line.display_order)
          from public.v1_delivery_order_revision_lines line
          where line.delivery_order_revision_id = revision.id
        ), '[]'::jsonb)
      ) order by revision.revision_number desc)
      from public.v1_delivery_order_revisions revision
      join public.v1_profiles profile
        on profile.auth_user_id = revision.generated_by_auth_user_id
      where revision.delivery_order_id = delivery_order.id
    ), '[]'::jsonb)
  )
  from public.v1_delivery_orders delivery_order
  where delivery_order.id = p_delivery_order_id;
$$;

-- Add exact actor and per-dispatch context to the existing role-safe
-- workspaces without weakening their capability-controlled response shapes.
do $workspace_projections$
declare
  v_definition text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_logistics_workspace_projection(uuid)'::regprocedure
  );
  if position($find$'delivery_reference', dispatch.delivery_reference,$find$
    in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'vehicle_reference', dispatch.vehicle_reference,$find$,
      $replacement$'vehicle_reference', dispatch.vehicle_reference,
        'delivery_reference', dispatch.delivery_reference,$replacement$
    );
  end if;
  if position($find$'dispatched_by_role',$find$ in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'dispatched_at', dispatch.dispatched_at,$find$,
      $replacement$'dispatched_at', dispatch.dispatched_at,
        'dispatched_by_role', coalesce(
          dispatch.dispatched_by_exact_role, dispatch.dispatched_by_role
        ),$replacement$
    );
  end if;
  if position($find$'reviewed_by_role',$find$ in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'reviewed_at', review.reviewed_at,$find$,
      $replacement$'reviewed_at', review.reviewed_at,
            'reviewed_by_role', coalesce(
              review.reviewed_by_exact_role, review.reviewed_by_role
            ),$replacement$
    );
  end if;
  if position($find$dispatch.dispatched_by_display_name_snapshot$find$
    in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'dispatched_by_display_name', public.v1_safe_profile_display_name(
          dispatcher.display_name, dispatcher.auth_user_id
        ),$find$,
      $replacement$'dispatched_by_display_name', coalesce(
          dispatch.dispatched_by_display_name_snapshot,
          public.v1_safe_profile_display_name(
            dispatcher.display_name, dispatcher.auth_user_id
          )
        ),$replacement$
    );
  end if;
  if position($find$review.reviewed_by_display_name_snapshot$find$
    in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'reviewed_by_display_name', public.v1_safe_profile_display_name(
              reviewer.display_name, reviewer.auth_user_id
            )$find$,
      $replacement$'reviewed_by_display_name', coalesce(
              review.reviewed_by_display_name_snapshot,
              public.v1_safe_profile_display_name(
                reviewer.display_name, reviewer.auth_user_id
              )
            )$replacement$
    );
  end if;
  if position($find$'delivery_reference', dispatch.delivery_reference,$find$
      in v_definition) = 0
    or position($find$'dispatched_by_role',$find$ in v_definition) = 0
    or position($find$'reviewed_by_role',$find$ in v_definition) = 0
    or position($find$dispatch.dispatched_by_display_name_snapshot$find$
      in v_definition) = 0
    or position($find$review.reviewed_by_display_name_snapshot$find$
      in v_definition) = 0 then
    raise exception 'V1_LOGISTICS_PROJECTION_TRUST_PATCH_FAILED';
  end if;
  execute v_definition;

  v_definition := pg_get_functiondef(
    'public.v1_returns_documents_workspace_projection(uuid)'::regprocedure
  );
  if position($find$'delivery_reference', dispatch.delivery_reference,$find$
    in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'dispatch_date', dispatch.dispatch_date,$find$,
      $replacement$'dispatch_date', dispatch.dispatch_date,
        'delivery_reference', dispatch.delivery_reference,$replacement$
    );
  end if;
  if position($find$'delivery_reference', dispatch.delivery_reference,$find$
    in v_definition) = 0 then
    raise exception 'V1_RETURNS_DOCUMENTS_PROJECTION_TRUST_PATCH_FAILED';
  end if;
  execute v_definition;

  v_definition := pg_get_functiondef(
    'public.v1_arrangement_projection(uuid)'::regprocedure
  );
  if position($find$'decided_by_role',$find$ in v_definition) = 0 then
    v_definition := replace(
      v_definition,
      $find$'decision_reason', (
          select decision_record.reason
          from public.v1_arrangement_decisions decision_record
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'lines', coalesce(($find$,
      $replacement$'decision_reason', (
          select decision_record.reason
          from public.v1_arrangement_decisions decision_record
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'decided_by_display_name', (
          select coalesce(
            decision_record.decided_by_display_name_snapshot,
            public.v1_safe_profile_display_name(
              decision_profile.display_name, decision_profile.auth_user_id
            )
          )
          from public.v1_arrangement_decisions decision_record
          join public.v1_profiles decision_profile
            on decision_profile.auth_user_id = decision_record.decided_by_auth_user_id
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'decided_by_role', (
          select coalesce(
            decision_record.decided_by_exact_role,
            decision_record.decided_by_role
          )
          from public.v1_arrangement_decisions decision_record
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'decided_at', (
          select decision_record.created_at
          from public.v1_arrangement_decisions decision_record
          where decision_record.arrangement_id = arrangement.id
          order by decision_record.created_at desc limit 1
        ),
        'lines', coalesce(($replacement$
    );
  end if;
  if position($find$'decided_by_role',$find$ in v_definition) = 0
    or position($find$decision_record.decided_by_display_name_snapshot$find$
      in v_definition) = 0 then
    raise exception 'V1_ARRANGEMENT_PROJECTION_TRUST_PATCH_FAILED';
  end if;
  execute v_definition;
end;
$workspace_projections$;

create or replace function public.v1_project_audit_projection(
  p_project_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.v1_project_readable(p_project_id) then
    raise exception 'V1_AUDIT_PROJECTION_READ_DENIED' using errcode = '42501';
  end if;
  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', audit.id,
        'event_type', audit.event_type,
        'entity_type', audit.entity_type,
        'entity_id', audit.entity_id,
        'occurred_at', audit.occurred_at,
        'actor_auth_user_id', audit.actor_auth_user_id,
        'actor_display_name', coalesce(
          audit.actor_display_name_snapshot,
          public.v1_safe_profile_display_name(
            profile.display_name, profile.auth_user_id
          )
        ),
        'actor_identity_verified', audit.actor_display_name_snapshot is not null,
        'actor_role', coalesce(audit.actor_exact_role, audit.actor_role),
        'reason', audit.reason
      ) order by audit.occurred_at desc, audit.id desc
    )
    from public.v1_audit_events audit
    join public.v1_profiles profile
      on profile.auth_user_id = audit.actor_auth_user_id
    where audit.project_id = p_project_id
  ), '[]'::jsonb);
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
begin
  if auth.uid() is null or v_exact_role = ''
    or not public.v1_current_actor_is_active() then
    return false;
  end if;
  if v_exact_role = 'admin' then
    return exists (
      select 1 from public.v1_material_requests request_record
      where request_record.id = p_request_id
    );
  end if;
  select request_record.project_id into v_project_id
  from public.v1_material_requests request_record
  where request_record.id = p_request_id;
  if v_project_id is null then return false; end if;
  if v_exact_role in ('senior_mechanical_engineer', 'project_manager') then
    return true;
  end if;
  return v_exact_role = 'project_engineer'
    and public.v1_has_active_project_membership(
      v_project_id, auth.uid(), 'project_engineer'
    );
end;
$$;

drop policy if exists v1_notifications_select_recipient
  on public.v1_notifications;
create policy v1_notifications_select_recipient
on public.v1_notifications
for select
to authenticated
using (
  (select public.v1_rls_current_actor_is_active())
  and (
    recipient_auth_user_id = (select auth.uid())
    or coalesce((select auth.jwt()) -> 'app_metadata' ->> 'role', '') = 'admin'
  )
);

revoke all on function public.v1_capture_arrangement_decision_exact_role()
  from public, anon, authenticated;
revoke all on function public.v1_capture_arrangement_saved_identity()
  from public, anon, authenticated;
revoke all on function public.v1_capture_dispatch_exact_role()
  from public, anon, authenticated;
revoke all on function public.v1_capture_receipt_review_exact_role()
  from public, anon, authenticated;
revoke all on function public.v1_capture_audit_actor_display_name()
  from public, anon, authenticated;
revoke all on function public.v1_capture_material_request_document_identity()
  from public, anon, authenticated;
revoke all on function public.v1_capture_delivery_order_revision_identity()
  from public, anon, authenticated;
revoke all on function public.v1_material_request_line_lifecycle_projection(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_refresh_material_request_logistics_state(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_can_close_material_request(uuid)
  from public, anon, authenticated;
revoke all on function public.v1_material_request_document_projection(uuid)
  from public, anon;
revoke all on function public.v1_delivery_order_projection(uuid)
  from public, anon;

grant execute on function public.v1_material_request_document_projection(uuid)
  to authenticated;
grant execute on function public.v1_delivery_order_projection(uuid)
  to authenticated;

commit;
