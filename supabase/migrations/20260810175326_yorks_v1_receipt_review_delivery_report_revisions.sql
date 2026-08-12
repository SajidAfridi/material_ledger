-- Yorks R35 receipt-reviewed Delivery Report follow-up.
--
-- The dispatch Delivery Order remains an immutable record of what Procurement
-- committed.  A confirmed receipt review appends a separate immutable
-- receipt-report revision and makes it the current printable report.  This
-- means a review of 10 dispatched / 8 good is shown as 8 without rewriting
-- the original dispatch snapshot.  Confirmed material returns remain separate
-- later inventory facts and never alter either delivery evidence record.

begin;

alter table public.v1_delivery_order_revisions
  add column if not exists snapshot_kind text;

-- Global-engineer rollout introduced dispatch-time snapshots before this
-- discriminator column existed. Its immutable audit event explicitly records
-- snapshot_source=dispatch, even when a confirmed review already existed.
-- Older Batch 8 revisions have confirmed receipt provenance and no dispatch
-- source marker. Prefer the signed audit source, then the confirmed review;
-- fail closed only when neither source can prove the historical meaning.
update public.v1_delivery_order_revisions revision
   set snapshot_kind = 'dispatch'
 where revision.snapshot_kind is null
   and exists (
     select 1
     from public.v1_audit_events audit
     where audit.entity_type = 'delivery_order_revision'
       and audit.entity_id = revision.id
       and audit.event_type in (
         'delivery_order_generated', 'delivery_order_superseded'
       )
       and audit.after_data ->> 'snapshot_source' = 'dispatch'
   );

update public.v1_delivery_order_revisions revision
   set snapshot_kind = 'receipt_review'
 where revision.snapshot_kind is null
   and exists (
     select 1
     from public.v1_receipt_reviews review
     where review.id = revision.receipt_review_id
       and review.state = 'confirmed'
   );

do $$
begin
  if exists (
    select 1
    from public.v1_delivery_order_revisions revision
    where revision.snapshot_kind is null
  ) then
    raise exception 'V1_DELIVERY_ORDER_LEGACY_REVISION_PROVENANCE_AMBIGUOUS';
  end if;
end;
$$;

alter table public.v1_delivery_order_revisions
  alter column snapshot_kind set default 'dispatch';
alter table public.v1_delivery_order_revisions
  alter column snapshot_kind set not null;
alter table public.v1_delivery_order_revisions
  drop constraint if exists v1_delivery_order_revisions_snapshot_kind_check;
alter table public.v1_delivery_order_revisions
  add constraint v1_delivery_order_revisions_snapshot_kind_check
  check (snapshot_kind in ('dispatch', 'receipt_review'));

-- A receipt-reviewed report deliberately retains every dispatched line, even
-- where the confirmed good quantity is zero.  Omitting an all-missing or
-- damaged line would make the report look like an incomplete dispatch rather
-- than an auditable review result.
alter table public.v1_delivery_order_revision_lines
  drop constraint if exists v1_delivery_order_revision_lines_good_quantity_check;
alter table public.v1_delivery_order_revision_lines
  add constraint v1_delivery_order_revision_lines_good_quantity_check
  check (good_quantity >= 0);
alter table public.v1_delivery_order_revision_lines
  drop constraint if exists v1_delivery_order_revision_lines_delivery_quantity_check;
alter table public.v1_delivery_order_revision_lines
  add constraint v1_delivery_order_revision_lines_delivery_quantity_check
  check (delivery_quantity >= 0);

-- This helper is deliberately not callable by clients.  Its caller has
-- already established the workflow authority and idempotency boundary.  It
-- locks the Delivery Order, validates that the receipt is for the same
-- dispatch, and appends an immutable revision from server-owned review lines.
create or replace function public.v1_append_receipt_review_delivery_report_revision(
  p_delivery_order_id uuid,
  p_receipt_review_id uuid,
  p_generated_by_auth_user_id uuid,
  p_generated_by_role text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delivery_order public.v1_delivery_orders%rowtype;
  v_revision_id uuid;
  v_revision_number integer;
  v_dispatch_line_count integer;
  v_review_line_count integer;
begin
  if p_delivery_order_id is null
    or p_receipt_review_id is null
    or p_generated_by_auth_user_id is null
    or p_generated_by_role not in (
      'project_engineer', 'site_engineer', 'procurement', 'admin'
    ) then
    raise exception 'V1_DELIVERY_REPORT_RECEIPT_SNAPSHOT_INVALID'
      using errcode = '22023';
  end if;

  select * into v_delivery_order
  from public.v1_delivery_orders delivery_order
  where delivery_order.id = p_delivery_order_id
  for update;
  if not found then
    raise exception 'V1_DELIVERY_REPORT_ORDER_NOT_FOUND' using errcode = '22023';
  end if;

  perform 1
  from public.v1_receipt_reviews review
  where review.id = p_receipt_review_id
    and review.dispatch_id = v_delivery_order.dispatch_id
    and review.request_id = v_delivery_order.request_id
    and review.state = 'confirmed'
  for update;
  if not found then
    raise exception 'V1_DELIVERY_REPORT_RECEIPT_REVIEW_REQUIRED'
      using errcode = '22023';
  end if;

  select count(*) into v_dispatch_line_count
  from public.v1_material_dispatch_lines dispatch_line
  where dispatch_line.dispatch_id = v_delivery_order.dispatch_id
    and dispatch_line.dispatched_qty > 0;
  select count(*) into v_review_line_count
  from public.v1_receipt_review_lines review_line
  join public.v1_material_dispatch_lines dispatch_line
    on dispatch_line.id = review_line.dispatch_line_id
  where review_line.receipt_review_id = p_receipt_review_id
    and dispatch_line.dispatch_id = v_delivery_order.dispatch_id
    and dispatch_line.dispatched_qty > 0;
  if v_dispatch_line_count = 0
    or v_review_line_count <> v_dispatch_line_count then
    raise exception 'V1_DELIVERY_REPORT_RECEIPT_LINES_INCOMPLETE'
      using errcode = '22023';
  end if;

  select coalesce(max(revision.revision_number), 0) + 1
    into v_revision_number
  from public.v1_delivery_order_revisions revision
  where revision.delivery_order_id = v_delivery_order.id;

  insert into public.v1_delivery_order_revisions (
    delivery_order_id,
    receipt_review_id,
    revision_number,
    snapshot_kind,
    generated_by_auth_user_id,
    generated_by_role
  ) values (
    v_delivery_order.id,
    p_receipt_review_id,
    v_revision_number,
    'receipt_review',
    p_generated_by_auth_user_id,
    p_generated_by_role
  ) returning id into v_revision_id;

  insert into public.v1_delivery_order_revision_lines (
    delivery_order_revision_id,
    receipt_review_line_id,
    dispatch_line_id,
    display_order,
    item_description,
    good_quantity,
    delivery_quantity,
    unit
  )
  select
    v_revision_id,
    review_line.id,
    dispatch_line.id,
    row_number() over (
      order by request_line.display_order, dispatch_line.created_at
    )::integer,
    dispatch_line.item_description,
    review_line.good_qty,
    review_line.good_qty,
    dispatch_line.unit
  from public.v1_material_dispatch_lines dispatch_line
  join public.v1_material_request_lines request_line
    on request_line.id = dispatch_line.request_line_id
  join public.v1_receipt_review_lines review_line
    on review_line.dispatch_line_id = dispatch_line.id
   and review_line.receipt_review_id = p_receipt_review_id
  where dispatch_line.dispatch_id = v_delivery_order.dispatch_id
    and dispatch_line.dispatched_qty > 0
  order by request_line.display_order, dispatch_line.created_at;

  update public.v1_delivery_orders
     set current_revision_id = v_revision_id,
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_delivery_order.id;

  return v_revision_id;
end;
$$;

-- Receipt confirmation remains the sole authority for the good/missing/damaged
-- facts.  It now atomically appends a receipt-reviewed report revision where a
-- dispatch Delivery Order already exists, so retrying the same command cannot
-- create a duplicate report.
create or replace function public.v1_confirm_receipt(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_dispatch_id uuid;
  v_expected_request_version integer;
  v_expected_dispatch_version integer;
  v_lines jsonb;
  v_request public.v1_material_requests%rowtype;
  v_dispatch public.v1_material_dispatches%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_state_summary jsonb;
  v_line jsonb;
  v_dispatch_line_id uuid;
  v_outcome text;
  v_good_qty numeric(18, 4);
  v_note text;
  v_dispatched_qty numeric(18, 4);
  v_line_count integer;
  v_review_id uuid;
  v_good_total numeric(18, 4) := 0;
  v_dispatched_total numeric(18, 4) := 0;
  v_delivery_order_id uuid;
  v_delivery_report_revision_id uuid;
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'dispatch_id', 'expected_request_version',
      'expected_dispatch_version', 'lines'],
    'confirm_receipt'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_dispatch_id := nullif(btrim(coalesce(p_payload ->> 'dispatch_id', '')), '')::uuid;
  v_expected_request_version := nullif(
    p_payload ->> 'expected_request_version', ''
  )::integer;
  v_expected_dispatch_version := nullif(
    p_payload ->> 'expected_dispatch_version', ''
  )::integer;
  v_lines := coalesce(p_payload -> 'lines', '[]'::jsonb);
  if v_request_id is null or v_dispatch_id is null
    or v_expected_request_version is null or v_expected_dispatch_version is null
    or v_expected_request_version < 1 or v_expected_dispatch_version < 1
    or jsonb_typeof(v_lines) <> 'array' then
    raise exception 'V1_RECEIPT_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_confirm_material_receipt(v_request_id) then
    raise exception 'V1_RECEIPT_CONFIRM_DENIED' using errcode = '42501';
  end if;
  select * into v_dispatch from public.v1_material_dispatches dispatch
  where dispatch.id = v_dispatch_id and dispatch.request_id = v_request.id
  for update;
  if not found then
    raise exception 'V1_RECEIPT_DISPATCH_NOT_FOUND' using errcode = '22023';
  end if;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_confirm_receipt', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.record_version <> v_expected_request_version
    or v_dispatch.record_version <> v_expected_dispatch_version
    or v_dispatch.state <> 'receipt_pending'
    or v_request.state not in ('partially_dispatched', 'dispatched', 'partially_received') then
    raise exception 'V1_RECEIPT_STATE_OR_VERSION_INVALID' using errcode = '40001';
  end if;
  select count(*) into v_line_count from public.v1_material_dispatch_lines
  where dispatch_id = v_dispatch.id;
  if jsonb_array_length(v_lines) <> v_line_count or v_line_count = 0
    or (select count(distinct nullif(btrim(coalesce(
      value ->> 'dispatch_line_id', ''
    )), '')::uuid) from jsonb_array_elements(v_lines)) <> v_line_count then
    raise exception 'V1_RECEIPT_LINES_INCOMPLETE' using errcode = '22023';
  end if;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    perform public.v1_assert_object_keys(
      v_line, array['dispatch_line_id', 'outcome', 'good_qty', 'note'],
      'receipt_line'
    );
    v_dispatch_line_id := nullif(btrim(coalesce(
      v_line ->> 'dispatch_line_id', ''
    )), '')::uuid;
    v_outcome := coalesce(v_line ->> 'outcome', '');
    v_good_qty := nullif(v_line ->> 'good_qty', '')::numeric(18, 4);
    v_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');
    select dispatched_qty into v_dispatched_qty
    from public.v1_material_dispatch_lines
    where id = v_dispatch_line_id and dispatch_id = v_dispatch.id;
    if v_dispatched_qty is null or v_good_qty is null or v_good_qty < 0
      or v_outcome not in ('received', 'missing', 'damaged')
      or (v_outcome = 'received' and (
        v_good_qty <> v_dispatched_qty or v_note is not null
      ))
      or (v_outcome in ('missing', 'damaged') and (
        v_good_qty >= v_dispatched_qty or v_note is null
      )) then
      raise exception 'V1_RECEIPT_LINE_INVALID' using errcode = '22023';
    end if;
    v_good_total := v_good_total + v_good_qty;
    v_dispatched_total := v_dispatched_total + v_dispatched_qty;
  end loop;
  v_before := public.v1_logistics_workspace_projection(v_request.id);
  insert into public.v1_receipt_reviews (
    dispatch_id, request_id, reviewed_by_auth_user_id, reviewed_by_role
  ) values (v_dispatch.id, v_request.id, v_actor, v_role)
  returning id into v_review_id;
  for v_line in select value from jsonb_array_elements(v_lines)
  loop
    v_dispatch_line_id := (v_line ->> 'dispatch_line_id')::uuid;
    v_outcome := v_line ->> 'outcome';
    v_good_qty := (v_line ->> 'good_qty')::numeric(18, 4);
    v_note := nullif(btrim(coalesce(v_line ->> 'note', '')), '');
    select dispatched_qty into v_dispatched_qty
    from public.v1_material_dispatch_lines where id = v_dispatch_line_id;
    insert into public.v1_receipt_review_lines (
      receipt_review_id, dispatch_line_id, outcome, dispatched_qty_snapshot,
      good_qty, exception_qty, note
    ) values (
      v_review_id, v_dispatch_line_id, v_outcome, v_dispatched_qty,
      v_good_qty, v_dispatched_qty - v_good_qty, v_note
    );
  end loop;
  update public.v1_material_dispatches
     set state = case when v_good_total = v_dispatched_total then 'received'
       else 'partially_received' end,
         receipt_reviewed_at = clock_timestamp(),
         record_version = record_version + 1,
         updated_at = clock_timestamp()
   where id = v_dispatch.id;

  select delivery_order.id into v_delivery_order_id
  from public.v1_delivery_orders delivery_order
  where delivery_order.dispatch_id = v_dispatch.id
  for update;
  if found then
    v_delivery_report_revision_id :=
      public.v1_append_receipt_review_delivery_report_revision(
        v_delivery_order_id, v_review_id, v_actor, v_role
      );
  end if;

  v_state_summary := public.v1_refresh_material_request_logistics_state(v_request.id);
  insert into public.v1_notifications (
    recipient_auth_user_id, event_code, entity_type, entity_id, project_id
  )
  select profile.auth_user_id, 'receipt_review_confirmed', 'receipt_review',
    v_review_id, v_request.project_id
  from public.v1_profiles profile
  where profile.is_active and profile.canonical_role_snapshot = 'procurement';
  v_response := public.v1_logistics_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    'receipt_review_confirmed', 'receipt_review', v_review_id, v_request.project_id,
    v_before,
    jsonb_build_object(
      'dispatch_id', v_dispatch.id,
      'dispatch_number', v_dispatch.dispatch_number,
      'good_qty', v_good_total::text,
      'exception_qty', (v_dispatched_total - v_good_total)::text,
      'request_state', v_state_summary ->> 'state',
      'request_record_version', v_expected_request_version + 1,
      'delivery_report_revision_id', v_delivery_report_revision_id,
      'delivery_report_updated', v_delivery_report_revision_id is not null
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_confirm_receipt', p_idempotency_key, v_response
  );
  return v_response;
end;
$$;

-- Manual generation still produces the committed dispatch Delivery Order until
-- a review exists.  Once the receipt facts are confirmed, it deliberately
-- creates an append-only receipt-report revision rather than copying the
-- stale dispatched quantity into the current printable report.
create or replace function public.v1_generate_delivery_order(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_role text := public.v1_current_role();
  v_request_id uuid;
  v_dispatch_id uuid;
  v_expected_request_version integer;
  v_expected_dispatch_version integer;
  v_reference text;
  v_request public.v1_material_requests%rowtype;
  v_dispatch public.v1_material_dispatches%rowtype;
  v_review public.v1_receipt_reviews%rowtype;
  v_delivery_order public.v1_delivery_orders%rowtype;
  v_existing_response jsonb;
  v_before jsonb;
  v_response jsonb;
  v_revision_id uuid;
  v_revision_number integer;
  v_delivery_line_count integer;
  v_snapshot_kind text := 'dispatch';
begin
  perform public.v1_assert_object_keys(
    p_payload,
    array['request_id', 'dispatch_id', 'expected_request_version',
      'expected_dispatch_version', 'delivery_order_reference'],
    'generate_delivery_order'
  );
  v_request_id := nullif(btrim(coalesce(p_payload ->> 'request_id', '')), '')::uuid;
  v_dispatch_id := nullif(btrim(coalesce(p_payload ->> 'dispatch_id', '')), '')::uuid;
  v_expected_request_version := nullif(p_payload ->> 'expected_request_version', '')::integer;
  v_expected_dispatch_version := nullif(p_payload ->> 'expected_dispatch_version', '')::integer;
  v_reference := nullif(upper(regexp_replace(btrim(coalesce(
    p_payload ->> 'delivery_order_reference', ''
  )), '\\s+', ' ', 'g')), '');
  if v_request_id is null or v_dispatch_id is null
    or v_expected_request_version is null or v_expected_dispatch_version is null
    or v_expected_request_version < 1 or v_expected_dispatch_version < 1
    or v_reference is null then
    raise exception 'V1_DELIVERY_ORDER_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  select * into v_request
  from public.v1_material_requests request_record
  where request_record.id = v_request_id for update;
  if not found or not public.v1_can_generate_delivery_order(v_request_id) then
    raise exception 'V1_DELIVERY_ORDER_GENERATE_DENIED' using errcode = '42501';
  end if;
  select * into v_dispatch
  from public.v1_material_dispatches dispatch
  where dispatch.id = v_dispatch_id
    and dispatch.request_id = v_request.id
    and dispatch.state in (
      'dispatched', 'receipt_pending', 'partially_received', 'received'
    )
  for update;
  if not found then
    raise exception 'V1_DELIVERY_ORDER_DISPATCH_REQUIRED' using errcode = '22023';
  end if;
  select * into v_review
  from public.v1_receipt_reviews review
  where review.dispatch_id = v_dispatch.id and review.state = 'confirmed'
  for update;
  v_existing_response := public.v1_idempotency_get_or_claim(
    'v1_generate_delivery_order', p_idempotency_key, p_payload
  );
  if v_existing_response is not null then return v_existing_response; end if;
  if v_request.record_version <> v_expected_request_version
    or v_dispatch.record_version <> v_expected_dispatch_version then
    raise exception 'V1_DELIVERY_ORDER_VERSION_CONFLICT' using errcode = '40001';
  end if;
  select count(*) into v_delivery_line_count
  from public.v1_material_dispatch_lines dispatch_line
  where dispatch_line.dispatch_id = v_dispatch.id
    and dispatch_line.dispatched_qty > 0;
  if v_delivery_line_count = 0 then
    raise exception 'V1_DELIVERY_ORDER_NO_DISPATCH_LINES' using errcode = '22023';
  end if;
  v_before := public.v1_returns_documents_workspace_projection(v_request.id);
  select * into v_delivery_order
  from public.v1_delivery_orders delivery_order
  where delivery_order.dispatch_id = v_dispatch.id for update;
  if not found then
    insert into public.v1_delivery_orders (
      request_id, dispatch_id, project_id, delivery_order_reference,
      created_by_auth_user_id, created_by_role
    ) values (
      v_request.id, v_dispatch.id, v_request.project_id, v_reference,
      v_actor, v_role
    ) returning * into v_delivery_order;
  elsif v_delivery_order.delivery_order_reference <> v_reference then
    raise exception 'V1_DELIVERY_ORDER_REFERENCE_IMMUTABLE' using errcode = '22023';
  end if;

  if v_review.id is not null then
    v_snapshot_kind := 'receipt_review';
    v_revision_id := public.v1_append_receipt_review_delivery_report_revision(
      v_delivery_order.id, v_review.id, v_actor, v_role
    );
    select revision.revision_number into v_revision_number
    from public.v1_delivery_order_revisions revision
    where revision.id = v_revision_id;
  else
    select coalesce(max(revision.revision_number), 0) + 1
      into v_revision_number
    from public.v1_delivery_order_revisions revision
    where revision.delivery_order_id = v_delivery_order.id;
    insert into public.v1_delivery_order_revisions (
      delivery_order_id, receipt_review_id, revision_number, snapshot_kind,
      generated_by_auth_user_id, generated_by_role
    ) values (
      v_delivery_order.id, null, v_revision_number, 'dispatch', v_actor, v_role
    ) returning id into v_revision_id;
    insert into public.v1_delivery_order_revision_lines (
      delivery_order_revision_id, receipt_review_line_id, dispatch_line_id,
      display_order, item_description, good_quantity, delivery_quantity, unit
    )
    select
      v_revision_id,
      null,
      dispatch_line.id,
      row_number() over (
        order by request_line.display_order, dispatch_line.created_at
      )::integer,
      dispatch_line.item_description,
      dispatch_line.dispatched_qty,
      dispatch_line.dispatched_qty,
      dispatch_line.unit
    from public.v1_material_dispatch_lines dispatch_line
    join public.v1_material_request_lines request_line
      on request_line.id = dispatch_line.request_line_id
    where dispatch_line.dispatch_id = v_dispatch.id
      and dispatch_line.dispatched_qty > 0
    order by request_line.display_order, dispatch_line.created_at;
    update public.v1_delivery_orders
       set current_revision_id = v_revision_id,
           record_version = record_version + 1,
           updated_at = clock_timestamp()
     where id = v_delivery_order.id;
  end if;
  v_response := public.v1_returns_documents_workspace_projection(v_request.id);
  perform public.v1_write_audit_event(
    case when v_revision_number = 1 then 'delivery_order_generated'
      else 'delivery_order_superseded' end,
    'delivery_order_revision', v_revision_id, v_request.project_id, v_before,
    jsonb_build_object(
      'delivery_order_reference', v_reference,
      'revision_number', v_revision_number,
      'dispatch_line_count', v_delivery_line_count,
      'snapshot_source', v_snapshot_kind
    ), null, p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_generate_delivery_order', p_idempotency_key, v_response
  );
  return v_response;
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
        'generated_by_display_name', public.v1_safe_profile_display_name(
          profile.display_name, profile.auth_user_id
        ),
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

revoke all on function public.v1_append_receipt_review_delivery_report_revision(
  uuid, uuid, uuid, text
) from public, anon, authenticated;

commit;
