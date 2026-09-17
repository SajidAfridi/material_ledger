-- Company Material Requests T03-T05: protected supply, fulfilment, custody,
-- returns and closure. Company reservations share the existing single-
-- warehouse reservation relation so project and company demand compete under
-- the same balance lock.
--
-- Data preservation: all T01/T02 requests, decisions and events remain intact.
-- Existing project reservations acquire request_kind = project without an ID
-- rewrite. Rollback is flag-off; committed stock and custody history must not
-- be deleted.

begin;

alter table public.v1_inventory_reservations
  add column if not exists request_kind text not null default 'project';
alter table public.v1_inventory_reservations
  add column if not exists company_supply_line_id uuid;
alter table public.v1_inventory_reservations
  alter column arrangement_line_id drop not null;
alter table public.v1_inventory_reservations
  drop constraint if exists v1_inventory_reservations_request_id_fkey;
alter table public.v1_inventory_reservations
  drop constraint if exists v1_inventory_reservations_arrangement_line_id_fkey;
alter table public.v1_inventory_reservations
  add constraint v1_inventory_reservations_arrangement_line_id_fkey
  foreign key (arrangement_line_id)
  references public.v1_procurement_arrangement_lines (id) on delete restrict;
alter table public.v1_inventory_reservations
  add constraint v1_inventory_reservations_request_kind_check
  check (request_kind in ('project', 'company'));

alter table public.v1_company_material_requests
  drop constraint if exists v1_company_material_requests_state_check;
alter table public.v1_company_material_requests
  add constraint v1_company_material_requests_state_check check (state in (
    'draft', 'awaiting_company_approval', 'approved_for_procurement',
    'returned_for_changes', 'rejected', 'arranging', 'ready_for_delivery',
    'partially_dispatched', 'receipt_pending', 'partially_received',
    'awaiting_beneficiary_handover', 'fulfilled', 'closed'
  ));

alter table public.v1_company_material_request_events
  drop constraint if exists v1_company_material_request_events_event_type_check;
alter table public.v1_company_material_request_events
  add constraint v1_company_material_request_events_event_type_check check (
    event_type in (
      'company_request_draft_created', 'company_request_submitted',
      'company_request_approved', 'company_request_returned',
      'company_request_rejected', 'company_request_resubmitted',
      'company_supply_plan_saved', 'company_material_dispatched',
      'company_receipt_confirmed', 'company_beneficiary_handover_confirmed',
      'company_return_submitted', 'company_return_confirmed',
      'company_return_rejected', 'company_request_closed'
    )
  );

create table public.v1_company_material_supply_plans (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  plan_version integer not null check (plan_version > 0),
  is_current boolean not null default true,
  saved_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  saved_at timestamptz not null default clock_timestamp(),
  superseded_at timestamptz,
  unique (request_id, plan_version)
);
create unique index v1_company_material_supply_plans_current_idx
  on public.v1_company_material_supply_plans (request_id) where is_current;

create table public.v1_company_material_supply_lines (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.v1_company_material_supply_plans (id)
    on delete restrict,
  request_line_id uuid not null
    references public.v1_company_material_request_lines (id) on delete restrict,
  decision text not null check (decision in ('full', 'partial', 'unavailable')),
  source_kind text check (source_kind in ('warehouse', 'external_supplier')),
  inventory_item_id uuid references public.v1_inventory_items (id) on delete restrict,
  external_supplier text,
  arranged_qty numeric(18,4) not null check (arranged_qty >= 0),
  expected_available_date date,
  follow_up_date date,
  reason text,
  created_at timestamptz not null default clock_timestamp(),
  unique (plan_id, request_line_id),
  check (
    (decision = 'full' and arranged_qty > 0 and reason is null)
    or (decision in ('partial', 'unavailable') and reason is not null
      and btrim(reason) <> '')
  ),
  check (
    (arranged_qty = 0 and source_kind is null and inventory_item_id is null
      and external_supplier is null)
    or (arranged_qty > 0 and (
      (source_kind = 'warehouse' and inventory_item_id is not null
        and external_supplier is null)
      or (source_kind = 'external_supplier' and inventory_item_id is null
        and external_supplier is not null and btrim(external_supplier) <> '')
    ))
  )
);

alter table public.v1_inventory_reservations
  add constraint v1_inventory_reservations_company_supply_line_id_fkey
  foreign key (company_supply_line_id)
  references public.v1_company_material_supply_lines (id) on delete restrict;
alter table public.v1_inventory_reservations
  add constraint v1_inventory_reservations_owner_shape_check check (
    (request_kind = 'project' and arrangement_line_id is not null
      and company_supply_line_id is null)
    or (request_kind = 'company' and arrangement_line_id is null
      and company_supply_line_id is not null)
  );

create or replace function public.v1_validate_inventory_reservation_owner()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.request_kind = 'project' and not exists (
    select 1 from public.v1_material_requests where id = new.request_id
  ) then
    raise exception 'V1_PROJECT_RESERVATION_REQUEST_INVALID' using errcode = '23503';
  elsif new.request_kind = 'company' and not exists (
    select 1 from public.v1_company_material_requests where id = new.request_id
  ) then
    raise exception 'V1_COMPANY_RESERVATION_REQUEST_INVALID' using errcode = '23503';
  end if;
  return new;
end;
$$;
drop trigger if exists v1_inventory_reservation_owner_guard
  on public.v1_inventory_reservations;
create constraint trigger v1_inventory_reservation_owner_guard
after insert or update of request_id, request_kind
on public.v1_inventory_reservations deferrable initially immediate
for each row execute function public.v1_validate_inventory_reservation_owner();

create table public.v1_company_material_dispatches (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  dispatch_number text not null unique,
  state text not null default 'receipt_pending'
    check (state in ('receipt_pending', 'received')),
  dispatched_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  dispatched_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (dispatched_by_auth_user_id, idempotency_key)
);
create table public.v1_company_material_dispatch_lines (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid not null references public.v1_company_material_dispatches (id)
    on delete restrict,
  supply_line_id uuid not null references public.v1_company_material_supply_lines (id)
    on delete restrict,
  request_line_id uuid not null references public.v1_company_material_request_lines (id)
    on delete restrict,
  inventory_item_id uuid references public.v1_inventory_items (id) on delete restrict,
  source_kind text not null check (source_kind in ('warehouse', 'external_supplier')),
  dispatched_qty numeric(18,4) not null check (dispatched_qty > 0),
  created_at timestamptz not null default clock_timestamp(),
  unique (dispatch_id, request_line_id)
);

create table public.v1_company_material_receipts (
  id uuid primary key default gen_random_uuid(),
  dispatch_id uuid not null unique references public.v1_company_material_dispatches (id)
    on delete restrict,
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  confirmed_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  confirmed_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (confirmed_by_auth_user_id, idempotency_key)
);
create table public.v1_company_material_receipt_lines (
  id uuid primary key default gen_random_uuid(),
  receipt_id uuid not null references public.v1_company_material_receipts (id)
    on delete restrict,
  dispatch_line_id uuid not null references public.v1_company_material_dispatch_lines (id)
    on delete restrict,
  request_line_id uuid not null references public.v1_company_material_request_lines (id)
    on delete restrict,
  outcome text not null check (outcome in ('received','missing','damaged','incorrect')),
  good_qty numeric(18,4) not null check (good_qty >= 0),
  exception_qty numeric(18,4) not null check (exception_qty >= 0),
  note text,
  created_at timestamptz not null default clock_timestamp(),
  unique (receipt_id, dispatch_line_id),
  check (
    (outcome = 'received' and exception_qty = 0 and good_qty > 0 and note is null)
    or (outcome <> 'received' and exception_qty > 0
      and note is not null and btrim(note) <> '')
  )
);

create table public.v1_company_material_handovers (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  beneficiary_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  recorded_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  acknowledgement_basis text not null check (
    acknowledgement_basis in ('beneficiary_confirmed','authorized_receiver_witnessed')
  ),
  handed_over_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (recorded_by_auth_user_id, idempotency_key)
);
create table public.v1_company_material_handover_lines (
  id uuid primary key default gen_random_uuid(),
  handover_id uuid not null references public.v1_company_material_handovers (id)
    on delete restrict,
  receipt_line_id uuid not null references public.v1_company_material_receipt_lines (id)
    on delete restrict,
  request_line_id uuid not null references public.v1_company_material_request_lines (id)
    on delete restrict,
  handed_over_qty numeric(18,4) not null check (handed_over_qty > 0),
  unique (handover_id, receipt_line_id)
);

create table public.v1_company_material_returns (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  state text not null default 'submitted' check (state in ('submitted','confirmed','rejected')),
  reason text not null check (btrim(reason) <> ''),
  submitted_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  submitted_at timestamptz not null default clock_timestamp(),
  decided_by_auth_user_id uuid references public.v1_profiles (auth_user_id) on delete restrict,
  decided_at timestamptz,
  decision_reason text,
  reusable boolean,
  idempotency_key uuid not null,
  unique (submitted_by_auth_user_id, idempotency_key)
);
create table public.v1_company_material_return_lines (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.v1_company_material_returns (id)
    on delete restrict,
  handover_line_id uuid not null references public.v1_company_material_handover_lines (id)
    on delete restrict,
  return_qty numeric(18,4) not null check (return_qty > 0),
  unique (return_id, handover_line_id)
);

do $$ declare v_table text; begin
  foreach v_table in array array[
    'v1_company_material_supply_plans','v1_company_material_supply_lines',
    'v1_company_material_dispatches','v1_company_material_dispatch_lines',
    'v1_company_material_receipts','v1_company_material_receipt_lines',
    'v1_company_material_handovers','v1_company_material_handover_lines',
    'v1_company_material_returns','v1_company_material_return_lines'
  ] loop
    execute format('alter table public.%I enable row level security', v_table);
    execute format('revoke all on table public.%I from public, anon, authenticated', v_table);
    execute format('grant all on table public.%I to service_role', v_table);
  end loop;
end $$;

create or replace function public.v1_decide_company_material_return(
  p_return_id uuid,p_decision text,p_reusable boolean,p_reason text,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_return public.v1_company_material_returns%rowtype;
  v_existing jsonb; v_row record; v_item uuid; v_on_hand numeric(18,4);
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or public.v1_current_role()<>'procurement' then
    raise exception 'V1_COMPANY_RETURN_DECISION_DENIED' using errcode='42501'; end if;
  if p_decision not in ('confirmed','rejected')
    or (p_decision='confirmed' and p_reusable is null)
    or (p_decision='rejected' and nullif(btrim(coalesce(p_reason,'')),'') is null) then
    raise exception 'V1_COMPANY_RETURN_DECISION_INVALID' using errcode='22023'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_decide_company_material_return',
    p_idempotency_key,jsonb_build_object('return_id',p_return_id,'decision',p_decision,
    'reusable',p_reusable,'reason',p_reason));
  select * into v_return from public.v1_company_material_returns where id=p_return_id for update;
  if not found then raise exception 'V1_COMPANY_RETURN_NOT_FOUND' using errcode='22023'; end if;
  if v_existing is not null then return public.v1_company_material_request_projection(v_return.request_id); end if;
  if v_return.state<>'submitted' then
    raise exception 'V1_COMPANY_RETURN_STATE_INVALID' using errcode='40001'; end if;
  if p_decision='confirmed' and p_reusable then
    for v_item in
      select distinct dl.inventory_item_id from public.v1_company_material_return_lines retl
      join public.v1_company_material_handover_lines hl on hl.id=retl.handover_line_id
      join public.v1_company_material_receipt_lines rl on rl.id=hl.receipt_line_id
      join public.v1_company_material_dispatch_lines dl on dl.id=rl.dispatch_line_id
      where retl.return_id=p_return_id and dl.inventory_item_id is not null order by 1
    loop
      perform 1 from public.v1_inventory_balances where inventory_item_id=v_item for update;
    end loop;
    for v_row in
      select retl.id return_line_id,retl.return_qty,dl.inventory_item_id
      from public.v1_company_material_return_lines retl
      join public.v1_company_material_handover_lines hl on hl.id=retl.handover_line_id
      join public.v1_company_material_receipt_lines rl on rl.id=hl.receipt_line_id
      join public.v1_company_material_dispatch_lines dl on dl.id=rl.dispatch_line_id
      where retl.return_id=p_return_id and dl.inventory_item_id is not null
    loop
      update public.v1_inventory_balances set on_hand_qty=on_hand_qty+v_row.return_qty,
        record_version=record_version+1,updated_at=clock_timestamp()
        where inventory_item_id=v_row.inventory_item_id returning on_hand_qty into v_on_hand;
      insert into public.v1_inventory_movements(inventory_item_id,movement_type,quantity_delta,
        on_hand_after_qty,source_entity_type,source_entity_id,reason,actor_auth_user_id,idempotency_key)
        values(v_row.inventory_item_id,'return',v_row.return_qty,v_on_hand,
        'company_material_return_line',v_row.return_line_id,'Accepted reusable company return',
        v_actor,p_idempotency_key);
    end loop;
  end if;
  update public.v1_company_material_returns set state=p_decision,decided_by_auth_user_id=v_actor,
    decided_at=clock_timestamp(),decision_reason=nullif(btrim(coalesce(p_reason,'')),''),
    reusable=case when p_decision='confirmed' then p_reusable else null end where id=p_return_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_return.request_id,
    case when p_decision='confirmed' then 'company_return_confirmed' else 'company_return_rejected' end,
    v_actor,'procurement',jsonb_build_object('return_id',p_return_id,'reusable',p_reusable,
    'reason',nullif(btrim(coalesce(p_reason,'')),'')),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_decide_company_material_return',p_idempotency_key,
    public.v1_company_material_request_projection(v_return.request_id));
  return public.v1_company_material_request_projection(v_return.request_id);
end $$;

create or replace function public.v1_close_company_material_request(
  p_request_id uuid,p_expected_version integer,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request public.v1_company_material_requests%rowtype;
  v_existing jsonb; v_requested numeric(18,4); v_good numeric(18,4);
  v_handed numeric(18,4); v_open integer;
begin
  select * into v_request from public.v1_company_material_requests where id=p_request_id for update;
  if v_actor is null or not public.v1_current_actor_is_active() or not found
    or public.v1_current_role()='procurement'
    or v_actor not in (v_request.created_by_auth_user_id,
      v_request.authorized_receiver_auth_user_id,v_request.approver_auth_user_id) then
    raise exception 'V1_COMPANY_CLOSE_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_close_company_material_request',
    p_idempotency_key,jsonb_build_object('request_id',p_request_id,
    'expected_version',p_expected_version));
  if v_existing is not null then return public.v1_company_material_request_projection(p_request_id); end if;
  if v_request.state<>'fulfilled' or v_request.record_version<>p_expected_version then
    raise exception 'V1_COMPANY_CLOSE_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  select coalesce(sum(requested_qty),0) into v_requested
    from public.v1_company_material_request_lines where request_id=p_request_id;
  select coalesce(sum(rl.good_qty),0) into v_good from public.v1_company_material_receipt_lines rl
    join public.v1_company_material_receipts rec on rec.id=rl.receipt_id where rec.request_id=p_request_id;
  select coalesce(sum(hl.handed_over_qty),0) into v_handed
    from public.v1_company_material_handover_lines hl join public.v1_company_material_handovers h
    on h.id=hl.handover_id where h.request_id=p_request_id;
  select count(*) into v_open from public.v1_company_material_dispatches
    where request_id=p_request_id and state='receipt_pending';
  v_open:=v_open+(select count(*) from public.v1_company_material_returns
    where request_id=p_request_id and state='submitted');
  if v_good<v_requested or v_handed<v_good or v_open<>0 then
    raise exception 'V1_COMPANY_CLOSE_UNRESOLVED' using errcode='22023'; end if;
  update public.v1_company_material_requests set state='closed',record_version=record_version+1,
    updated_at=clock_timestamp() where id=p_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(p_request_id,'company_request_closed',v_actor,
    public.v1_current_role(),jsonb_build_object('good_received_qty',v_good,
    'handed_over_qty',v_handed),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_close_company_material_request',p_idempotency_key,
    public.v1_company_material_request_projection(p_request_id));
  return public.v1_company_material_request_projection(p_request_id);
end $$;

create or replace function public.v1_confirm_company_material_receipt(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_dispatch_id uuid; v_expected integer;
  v_lines jsonb; v_request public.v1_company_material_requests%rowtype; v_dispatch record;
  v_existing jsonb; v_receipt uuid; v_line jsonb; v_dispatch_line uuid; v_outcome text;
  v_good numeric(18,4); v_exception numeric(18,4); v_note text; v_dl record;
  v_count integer; v_total_good numeric(18,4); v_requested numeric(18,4);
begin
  perform public.v1_assert_object_keys(p_payload,array['request_id','dispatch_id','expected_version','lines'],
    'company_receipt');
  begin v_request_id:=(p_payload->>'request_id')::uuid;
    v_dispatch_id:=(p_payload->>'dispatch_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then raise exception 'V1_COMPANY_RECEIPT_INVALID' using errcode='22023'; end;
  select * into v_request from public.v1_company_material_requests where id=v_request_id for update;
  if v_actor is null or not public.v1_current_actor_is_active() or not found
    or v_actor<>v_request.authorized_receiver_auth_user_id
    or not public.v1_company_material_request_active_authorization(v_actor,v_request.category_id,
      v_request.responsible_unit_id,'receiver') then
    raise exception 'V1_COMPANY_RECEIPT_DENIED' using errcode='42501'; end if;
  v_lines:=p_payload->'lines';
  v_existing:=public.v1_idempotency_get_or_claim('v1_confirm_company_material_receipt',
    p_idempotency_key,p_payload);
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  select * into v_dispatch from public.v1_company_material_dispatches where id=v_dispatch_id
    and request_id=v_request_id for update;
  if not found or v_dispatch.state<>'receipt_pending' or v_request.record_version<>v_expected
    or jsonb_typeof(v_lines)<>'array' then
    raise exception 'V1_COMPANY_RECEIPT_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  select count(*) into v_count from public.v1_company_material_dispatch_lines where dispatch_id=v_dispatch_id;
  if jsonb_array_length(v_lines)<>v_count then
    raise exception 'V1_COMPANY_RECEIPT_LINES_INVALID' using errcode='22023'; end if;
  insert into public.v1_company_material_receipts(dispatch_id,request_id,
    confirmed_by_auth_user_id,idempotency_key) values(v_dispatch_id,v_request_id,v_actor,p_idempotency_key)
    returning id into v_receipt;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['dispatch_line_id','outcome','good_qty','exception_qty','note'],
      'company_receipt_line');
    begin v_dispatch_line:=(v_line->>'dispatch_line_id')::uuid;
      v_good:=(v_line->>'good_qty')::numeric(18,4);
      v_exception:=(v_line->>'exception_qty')::numeric(18,4);
    exception when others then raise exception 'V1_COMPANY_RECEIPT_LINE_INVALID' using errcode='22023'; end;
    v_outcome:=nullif(v_line->>'outcome',''); v_note:=nullif(btrim(coalesce(v_line->>'note','')),'');
    select * into v_dl from public.v1_company_material_dispatch_lines
      where id=v_dispatch_line and dispatch_id=v_dispatch_id;
    if not found or v_outcome not in ('received','missing','damaged','incorrect')
      or v_good<0 or v_exception<0 or v_good+v_exception<>v_dl.dispatched_qty
      or (v_outcome='received' and (v_exception<>0 or v_note is not null))
      or (v_outcome<>'received' and (v_exception<=0 or v_note is null)) then
      raise exception 'V1_COMPANY_RECEIPT_LINE_INVALID' using errcode='22023'; end if;
    insert into public.v1_company_material_receipt_lines(receipt_id,dispatch_line_id,
      request_line_id,outcome,good_qty,exception_qty,note) values(v_receipt,v_dispatch_line,
      v_dl.request_line_id,v_outcome,v_good,v_exception,v_note);
  end loop;
  update public.v1_company_material_dispatches set state='received' where id=v_dispatch_id;
  select coalesce(sum(rl.good_qty),0),coalesce(sum(l.requested_qty),0)
    into v_total_good,v_requested from public.v1_company_material_request_lines l
    left join public.v1_company_material_receipt_lines rl on rl.request_line_id=l.id
    where l.request_id=v_request_id;
  update public.v1_company_material_requests set
    state=case when v_total_good>0 then 'awaiting_beneficiary_handover' else 'arranging' end,
    record_version=record_version+1,updated_at=clock_timestamp() where id=v_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_request_id,'company_receipt_confirmed',v_actor,
    public.v1_current_role(),jsonb_build_object('receipt_id',v_receipt,'dispatch_id',v_dispatch_id),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_confirm_company_material_receipt',p_idempotency_key,
    public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

create or replace function public.v1_confirm_company_material_handover(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_basis text; v_lines jsonb;
  v_request public.v1_company_material_requests%rowtype; v_existing jsonb; v_handover uuid;
  v_line jsonb; v_receipt_line uuid; v_qty numeric(18,4); v_rl record;
  v_prior numeric(18,4); v_total_good numeric(18,4); v_total_handed numeric(18,4);
  v_total_requested numeric(18,4); v_open_transit integer;
begin
  perform public.v1_assert_object_keys(p_payload,array['request_id','expected_version',
    'acknowledgement_basis','lines'],'company_handover');
  begin v_request_id:=(p_payload->>'request_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then raise exception 'V1_COMPANY_HANDOVER_INVALID' using errcode='22023'; end;
  v_basis:=nullif(p_payload->>'acknowledgement_basis',''); v_lines:=p_payload->'lines';
  select * into v_request from public.v1_company_material_requests where id=v_request_id for update;
  if v_actor is null or not public.v1_current_actor_is_active() or not found
    or v_actor not in (v_request.beneficiary_auth_user_id,v_request.authorized_receiver_auth_user_id)
    or (v_actor=v_request.beneficiary_auth_user_id and v_basis<>'beneficiary_confirmed')
    or (v_actor=v_request.authorized_receiver_auth_user_id
      and v_basis not in ('beneficiary_confirmed','authorized_receiver_witnessed')) then
    raise exception 'V1_COMPANY_HANDOVER_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_confirm_company_material_handover',
    p_idempotency_key,p_payload);
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  if v_request.record_version<>v_expected or v_request.state not in
    ('awaiting_beneficiary_handover','partially_received') or jsonb_typeof(v_lines)<>'array'
    or jsonb_array_length(v_lines)=0 then
    raise exception 'V1_COMPANY_HANDOVER_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  insert into public.v1_company_material_handovers(request_id,beneficiary_auth_user_id,
    recorded_by_auth_user_id,acknowledgement_basis,idempotency_key) values(v_request_id,
    v_request.beneficiary_auth_user_id,v_actor,v_basis,p_idempotency_key) returning id into v_handover;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['receipt_line_id','quantity'],'company_handover_line');
    begin v_receipt_line:=(v_line->>'receipt_line_id')::uuid;
      v_qty:=(v_line->>'quantity')::numeric(18,4);
    exception when others then raise exception 'V1_COMPANY_HANDOVER_LINE_INVALID' using errcode='22023'; end;
    select rl.* into v_rl from public.v1_company_material_receipt_lines rl
      join public.v1_company_material_receipts rec on rec.id=rl.receipt_id
      where rl.id=v_receipt_line and rec.request_id=v_request_id;
    select coalesce(sum(handed_over_qty),0) into v_prior
      from public.v1_company_material_handover_lines where receipt_line_id=v_receipt_line;
    if not found or v_qty<=0 or v_prior+v_qty>v_rl.good_qty then
      raise exception 'V1_COMPANY_HANDOVER_QUANTITY_INVALID' using errcode='22023'; end if;
    insert into public.v1_company_material_handover_lines(handover_id,receipt_line_id,
      request_line_id,handed_over_qty) values(v_handover,v_receipt_line,v_rl.request_line_id,v_qty);
  end loop;
  select coalesce(sum(good_qty),0) into v_total_good from public.v1_company_material_receipt_lines rl
    join public.v1_company_material_receipts rec on rec.id=rl.receipt_id where rec.request_id=v_request_id;
  select coalesce(sum(hl.handed_over_qty),0) into v_total_handed
    from public.v1_company_material_handover_lines hl join public.v1_company_material_handovers h
    on h.id=hl.handover_id where h.request_id=v_request_id;
  select coalesce(sum(requested_qty),0) into v_total_requested
    from public.v1_company_material_request_lines where request_id=v_request_id;
  select count(*) into v_open_transit from public.v1_company_material_dispatches
    where request_id=v_request_id and state='receipt_pending';
  update public.v1_company_material_requests set state=case
      when v_total_good>=v_total_requested and v_total_handed>=v_total_good and v_open_transit=0
        then 'fulfilled' else 'partially_received' end,
    record_version=record_version+1,updated_at=clock_timestamp() where id=v_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_request_id,'company_beneficiary_handover_confirmed',
    v_actor,public.v1_current_role(),jsonb_build_object('handover_id',v_handover,
    'acknowledgement_basis',v_basis),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_confirm_company_material_handover',p_idempotency_key,
    public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

create or replace function public.v1_submit_company_material_return(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_reason text; v_lines jsonb;
  v_request public.v1_company_material_requests%rowtype; v_existing jsonb; v_return uuid;
  v_line jsonb; v_handover_line uuid; v_qty numeric(18,4); v_hl record; v_prior numeric(18,4);
begin
  perform public.v1_assert_object_keys(p_payload,array['request_id','reason','lines'],'company_return');
  begin v_request_id:=(p_payload->>'request_id')::uuid;
  exception when others then raise exception 'V1_COMPANY_RETURN_INVALID' using errcode='22023'; end;
  v_reason:=nullif(btrim(coalesce(p_payload->>'reason','')),''); v_lines:=p_payload->'lines';
  select * into v_request from public.v1_company_material_requests where id=v_request_id;
  if v_actor is null or not public.v1_current_actor_is_active() or not found
    or v_actor not in (v_request.created_by_auth_user_id,v_request.beneficiary_auth_user_id,
      v_request.authorized_receiver_auth_user_id) then
    raise exception 'V1_COMPANY_RETURN_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_submit_company_material_return',p_idempotency_key,p_payload);
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  if v_reason is null or jsonb_typeof(v_lines)<>'array' or jsonb_array_length(v_lines)=0 then
    raise exception 'V1_COMPANY_RETURN_INVALID' using errcode='22023'; end if;
  insert into public.v1_company_material_returns(request_id,reason,submitted_by_auth_user_id,idempotency_key)
    values(v_request_id,v_reason,v_actor,p_idempotency_key) returning id into v_return;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['handover_line_id','quantity'],'company_return_line');
    begin v_handover_line:=(v_line->>'handover_line_id')::uuid;
      v_qty:=(v_line->>'quantity')::numeric(18,4);
    exception when others then raise exception 'V1_COMPANY_RETURN_LINE_INVALID' using errcode='22023'; end;
    select hl.* into v_hl from public.v1_company_material_handover_lines hl
      join public.v1_company_material_handovers h on h.id=hl.handover_id
      where hl.id=v_handover_line and h.request_id=v_request_id;
    select coalesce(sum(rl.return_qty),0) into v_prior from public.v1_company_material_return_lines rl
      join public.v1_company_material_returns r on r.id=rl.return_id
      where rl.handover_line_id=v_handover_line and r.state in ('submitted','confirmed');
    if not found or v_qty<=0 or v_prior+v_qty>v_hl.handed_over_qty then
      raise exception 'V1_COMPANY_RETURN_QUANTITY_INVALID' using errcode='22023'; end if;
    insert into public.v1_company_material_return_lines(return_id,handover_line_id,return_qty)
      values(v_return,v_handover_line,v_qty);
  end loop;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_request_id,'company_return_submitted',v_actor,
    public.v1_current_role(),jsonb_build_object('return_id',v_return),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_submit_company_material_return',p_idempotency_key,
    public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

create or replace function public.v1_save_company_material_supply_plan(
  p_payload jsonb, p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_lines jsonb;
  v_request public.v1_company_material_requests%rowtype; v_existing jsonb;
  v_plan_id uuid; v_version integer; v_line jsonb; v_request_line_id uuid;
  v_decision text; v_source text; v_item uuid; v_supplier text; v_reason text;
  v_arranged numeric(18,4); v_requested numeric(18,4); v_expected_date date;
  v_follow_up date; v_supply_line uuid; v_on_hand numeric(18,4); v_reserved numeric(18,4);
  v_total_arranged numeric(18,4):=0; v_count integer;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or public.v1_current_role()<>'procurement' then
    raise exception 'V1_COMPANY_SUPPLY_PLAN_DENIED' using errcode='42501';
  end if;
  perform public.v1_assert_object_keys(p_payload,
    array['request_id','expected_version','lines'],'company_supply_plan');
  begin
    v_request_id:=(p_payload->>'request_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then
    raise exception 'V1_COMPANY_SUPPLY_PLAN_INVALID' using errcode='22023';
  end;
  v_lines:=p_payload->'lines';
  if v_request_id is null or v_expected<1 or jsonb_typeof(v_lines)<>'array'
    or jsonb_array_length(v_lines)=0 then
    raise exception 'V1_COMPANY_SUPPLY_PLAN_INVALID' using errcode='22023';
  end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_save_company_material_supply_plan',p_idempotency_key,p_payload);
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  select * into v_request from public.v1_company_material_requests
    where id=v_request_id for update;
  if not found or v_request.state not in
    ('approved_for_procurement','arranging','ready_for_delivery','partially_received')
    or v_request.record_version<>v_expected then
    raise exception 'V1_COMPANY_SUPPLY_PLAN_STATE_OR_VERSION_INVALID' using errcode='40001';
  end if;
  select count(*) into v_count from public.v1_company_material_request_lines where request_id=v_request_id;
  if jsonb_array_length(v_lines)<>v_count or (select count(distinct value->>'request_line_id')
      from jsonb_array_elements(v_lines))<>v_count then
    raise exception 'V1_COMPANY_SUPPLY_PLAN_LINES_INVALID' using errcode='22023';
  end if;
  for v_item in select distinct nullif(value->>'inventory_item_id','')::uuid
    from jsonb_array_elements(v_lines) where value->>'source_kind'='warehouse'
    order by 1
  loop
    perform 1 from public.v1_inventory_balances b join public.v1_inventory_items i
      on i.id=b.inventory_item_id and i.is_active where b.inventory_item_id=v_item for update of b;
    if not found then raise exception 'V1_COMPANY_SUPPLY_PLAN_ITEM_INVALID' using errcode='22023'; end if;
  end loop;
  update public.v1_inventory_reservations set state='released',released_at=clock_timestamp(),
    released_by_auth_user_id=v_actor,release_reason='Supply plan superseded',updated_at=clock_timestamp()
    where request_kind='company' and request_id=v_request_id
      and state in ('active','partially_consumed');
  update public.v1_company_material_supply_plans set is_current=false,
    superseded_at=clock_timestamp() where request_id=v_request_id and is_current;
  select coalesce(max(plan_version),0)+1 into v_version
    from public.v1_company_material_supply_plans where request_id=v_request_id;
  insert into public.v1_company_material_supply_plans(request_id,plan_version,saved_by_auth_user_id)
    values(v_request_id,v_version,v_actor) returning id into v_plan_id;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['request_line_id','decision','source_kind',
      'inventory_item_id','external_supplier','arranged_qty','expected_available_date',
      'follow_up_date','reason'],'company_supply_plan_line');
    begin
      v_request_line_id:=(v_line->>'request_line_id')::uuid;
      v_arranged:=(v_line->>'arranged_qty')::numeric(18,4);
      v_item:=nullif(v_line->>'inventory_item_id','')::uuid;
      v_expected_date:=nullif(v_line->>'expected_available_date','')::date;
      v_follow_up:=nullif(v_line->>'follow_up_date','')::date;
    exception when others then raise exception 'V1_COMPANY_SUPPLY_PLAN_LINE_INVALID' using errcode='22023'; end;
    v_decision:=nullif(btrim(coalesce(v_line->>'decision','')),'');
    v_source:=nullif(btrim(coalesce(v_line->>'source_kind','')),'');
    v_supplier:=nullif(btrim(coalesce(v_line->>'external_supplier','')),'');
    v_reason:=nullif(btrim(coalesce(v_line->>'reason','')),'');
    select requested_qty into v_requested from public.v1_company_material_request_lines
      where id=v_request_line_id and request_id=v_request_id;
    if not found or v_arranged<0 or v_arranged>v_requested
      or v_decision not in ('full','partial','unavailable')
      or (v_decision='full' and (v_arranged<>v_requested or v_reason is not null))
      or (v_decision='partial' and (v_arranged<=0 or v_arranged>=v_requested or v_reason is null))
      or (v_decision='unavailable' and (v_arranged<>0 or v_reason is null or v_follow_up is null))
      or (v_arranged>0 and v_source not in ('warehouse','external_supplier'))
      or (v_source='warehouse' and v_item is null)
      or (v_source='external_supplier' and v_supplier is null) then
      raise exception 'V1_COMPANY_SUPPLY_PLAN_LINE_INVALID' using errcode='22023';
    end if;
    insert into public.v1_company_material_supply_lines(plan_id,request_line_id,decision,
      source_kind,inventory_item_id,external_supplier,arranged_qty,expected_available_date,
      follow_up_date,reason) values(v_plan_id,v_request_line_id,v_decision,v_source,v_item,
      v_supplier,v_arranged,v_expected_date,v_follow_up,v_reason) returning id into v_supply_line;
    if v_source='warehouse' and v_arranged>0 then
      select b.on_hand_qty,coalesce(sum(r.reserved_qty-r.consumed_qty),0)
        into v_on_hand,v_reserved from public.v1_inventory_balances b
        left join public.v1_inventory_reservations r on r.inventory_item_id=b.inventory_item_id
          and r.state in ('active','partially_consumed')
        where b.inventory_item_id=v_item group by b.on_hand_qty;
      if v_on_hand-v_reserved<v_arranged then
        raise exception 'V1_COMPANY_SUPPLY_PLAN_STOCK_CAP_EXCEEDED' using errcode='22023';
      end if;
      insert into public.v1_inventory_reservations(inventory_item_id,request_id,request_kind,
        company_supply_line_id,reserved_qty,state,consumed_qty)
        values(v_item,v_request_id,'company',v_supply_line,v_arranged,'active',0);
    end if;
    v_total_arranged:=v_total_arranged+v_arranged;
  end loop;
  update public.v1_company_material_requests set
    state=case when v_total_arranged>0 then 'ready_for_delivery' else 'arranging' end,
    record_version=record_version+1,updated_at=clock_timestamp() where id=v_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,
    actor_auth_user_id,actor_exact_role,data,idempotency_key) values(v_request_id,
    'company_supply_plan_saved',v_actor,'procurement',jsonb_build_object(
      'plan_id',v_plan_id,'plan_version',v_version,'arranged_qty',v_total_arranged),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_save_company_material_supply_plan',p_idempotency_key,
    public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

create table public.v1_company_material_dispatch_reference_counter (
  singleton boolean primary key default true check(singleton),
  next_sequence integer not null default 1 check(next_sequence>0)
);
insert into public.v1_company_material_dispatch_reference_counter(singleton,next_sequence)
values(true,1) on conflict(singleton) do nothing;
alter table public.v1_company_material_dispatch_reference_counter enable row level security;
revoke all on public.v1_company_material_dispatch_reference_counter from public,anon,authenticated;
grant all on public.v1_company_material_dispatch_reference_counter to service_role;

create or replace function public.v1_dispatch_company_materials(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_lines jsonb;
  v_request public.v1_company_material_requests%rowtype; v_existing jsonb; v_line jsonb;
  v_supply uuid; v_qty numeric(18,4); v_supply_row public.v1_company_material_supply_lines%rowtype;
  v_dispatched numeric(18,4); v_good numeric(18,4); v_transit numeric(18,4);
  v_on_hand numeric(18,4); v_other_reserved numeric(18,4); v_res record;
  v_consume numeric(18,4); v_dispatch uuid; v_dispatch_line uuid; v_seq integer;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or public.v1_current_role()<>'procurement' then
    raise exception 'V1_COMPANY_DISPATCH_DENIED' using errcode='42501'; end if;
  perform public.v1_assert_object_keys(p_payload,array['request_id','expected_version','lines'],
    'company_dispatch');
  begin v_request_id:=(p_payload->>'request_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then raise exception 'V1_COMPANY_DISPATCH_INVALID' using errcode='22023'; end;
  v_lines:=p_payload->'lines';
  if jsonb_typeof(v_lines)<>'array' or jsonb_array_length(v_lines)=0 then
    raise exception 'V1_COMPANY_DISPATCH_INVALID' using errcode='22023'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_dispatch_company_materials',p_idempotency_key,p_payload);
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  select * into v_request from public.v1_company_material_requests where id=v_request_id for update;
  if not found or v_request.state not in ('ready_for_delivery','partially_dispatched','partially_received')
    or v_request.record_version<>v_expected then
    raise exception 'V1_COMPANY_DISPATCH_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  for v_supply in select distinct (value->>'supply_line_id')::uuid
    from jsonb_array_elements(v_lines) order by 1 loop
    select sl.* into v_supply_row from public.v1_company_material_supply_lines sl
      join public.v1_company_material_supply_plans sp on sp.id=sl.plan_id and sp.is_current
      where sl.id=v_supply and sp.request_id=v_request_id;
    if not found then raise exception 'V1_COMPANY_DISPATCH_LINE_INVALID' using errcode='22023'; end if;
    if v_supply_row.source_kind='warehouse' then
      perform 1 from public.v1_inventory_balances where inventory_item_id=v_supply_row.inventory_item_id for update;
    end if;
  end loop;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['supply_line_id','dispatch_qty'],'company_dispatch_line');
    begin v_supply:=(v_line->>'supply_line_id')::uuid;
      v_qty:=(v_line->>'dispatch_qty')::numeric(18,4);
    exception when others then raise exception 'V1_COMPANY_DISPATCH_LINE_INVALID' using errcode='22023'; end;
    select sl.* into v_supply_row from public.v1_company_material_supply_lines sl
      join public.v1_company_material_supply_plans sp on sp.id=sl.plan_id and sp.is_current
      where sl.id=v_supply and sp.request_id=v_request_id;
    select coalesce(sum(dl.dispatched_qty),0) into v_dispatched
      from public.v1_company_material_dispatch_lines dl where dl.supply_line_id=v_supply;
    select coalesce(sum(rl.good_qty),0) into v_good from public.v1_company_material_receipt_lines rl
      where rl.request_line_id=v_supply_row.request_line_id;
    select coalesce(sum(dl.dispatched_qty),0) into v_transit
      from public.v1_company_material_dispatch_lines dl join public.v1_company_material_dispatches d
      on d.id=dl.dispatch_id where dl.request_line_id=v_supply_row.request_line_id and d.state='receipt_pending';
    if not found or v_qty<=0 or v_dispatched+v_qty>v_supply_row.arranged_qty
      or v_good+v_transit+v_qty>(select requested_qty from public.v1_company_material_request_lines
        where id=v_supply_row.request_line_id) then
      raise exception 'V1_COMPANY_DISPATCH_QUANTITY_INVALID' using errcode='22023'; end if;
    if v_supply_row.source_kind='warehouse' then
      select on_hand_qty into v_on_hand from public.v1_inventory_balances
        where inventory_item_id=v_supply_row.inventory_item_id;
      select coalesce(sum(reserved_qty-consumed_qty),0) into v_other_reserved
        from public.v1_inventory_reservations where inventory_item_id=v_supply_row.inventory_item_id
        and request_id<>v_request_id and state in ('active','partially_consumed');
      if v_on_hand-v_other_reserved<v_qty then
        raise exception 'V1_COMPANY_DISPATCH_STOCK_CAP_EXCEEDED' using errcode='22023'; end if;
    end if;
  end loop;
  update public.v1_company_material_dispatch_reference_counter set next_sequence=next_sequence+1
    where singleton returning next_sequence-1 into v_seq;
  insert into public.v1_company_material_dispatches(request_id,dispatch_number,
    dispatched_by_auth_user_id,idempotency_key) values(v_request_id,
    'CM-DSP-'||lpad(v_seq::text,7,'0'),v_actor,p_idempotency_key) returning id into v_dispatch;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    v_supply:=(v_line->>'supply_line_id')::uuid; v_qty:=(v_line->>'dispatch_qty')::numeric(18,4);
    select * into v_supply_row from public.v1_company_material_supply_lines where id=v_supply;
    insert into public.v1_company_material_dispatch_lines(dispatch_id,supply_line_id,request_line_id,
      inventory_item_id,source_kind,dispatched_qty) values(v_dispatch,v_supply,
      v_supply_row.request_line_id,v_supply_row.inventory_item_id,v_supply_row.source_kind,v_qty)
      returning id into v_dispatch_line;
    if v_supply_row.source_kind='warehouse' then
      select * into v_res from public.v1_inventory_reservations where request_kind='company'
        and company_supply_line_id=v_supply and state in ('active','partially_consumed') for update;
      v_consume:=least(v_qty,v_res.reserved_qty-v_res.consumed_qty);
      update public.v1_inventory_reservations set consumed_qty=consumed_qty+v_consume,
        state=case when consumed_qty+v_consume=reserved_qty then 'consumed' else 'partially_consumed' end,
        updated_at=clock_timestamp() where id=v_res.id;
      update public.v1_inventory_balances set on_hand_qty=on_hand_qty-v_qty,
        record_version=record_version+1,updated_at=clock_timestamp()
        where inventory_item_id=v_supply_row.inventory_item_id returning on_hand_qty into v_on_hand;
      insert into public.v1_inventory_movements(inventory_item_id,movement_type,quantity_delta,
        on_hand_after_qty,source_entity_type,source_entity_id,reason,actor_auth_user_id,idempotency_key)
        values(v_supply_row.inventory_item_id,'dispatch',-v_qty,v_on_hand,
        'company_material_dispatch_line',v_dispatch_line,'Company material dispatch',v_actor,p_idempotency_key);
    end if;
  end loop;
  update public.v1_company_material_requests set state='receipt_pending',
    record_version=record_version+1,updated_at=clock_timestamp() where id=v_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_request_id,'company_material_dispatched',
    v_actor,'procurement',jsonb_build_object('dispatch_id',v_dispatch),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_dispatch_company_materials',p_idempotency_key,
    public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

create or replace function public.v1_company_material_request_readable(p_request_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.v1_current_actor_is_active() and exists (
    select 1 from public.v1_company_material_requests r where r.id = p_request_id and (
      r.created_by_auth_user_id = auth.uid()
      or (r.state <> 'draft' and auth.uid() in (
        r.beneficiary_auth_user_id, r.authorized_receiver_auth_user_id,
        r.approver_auth_user_id
      ))
      or (r.state in ('approved_for_procurement','arranging','ready_for_delivery',
        'partially_dispatched','receipt_pending','partially_received',
        'awaiting_beneficiary_handover','fulfilled','closed')
        and public.v1_current_role() = 'procurement')
    )
  );
$$;

create or replace function public.v1_company_material_request_projection(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v_result jsonb;
begin
  if not public.v1_company_material_request_readable(p_request_id) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE' using errcode='42501';
  end if;
  select jsonb_build_object(
    'id',r.id,'request_number',r.request_number,'state',r.state,
    'record_version',r.record_version,'category_id',c.id,'category_code',c.category_code,
    'category_name',c.display_name,'responsible_unit_id',u.id,
    'responsible_unit_code',u.unit_code,'responsible_unit_name',u.display_name,
    'purpose',r.purpose,'timing',r.timing,'scheduled_date',r.scheduled_date,
    'delivery_collection_point',r.delivery_collection_point,
    'beneficiary_auth_user_id',r.beneficiary_auth_user_id,
    'beneficiary_display_name',r.beneficiary_display_name,
    'authorized_receiver_auth_user_id',r.authorized_receiver_auth_user_id,
    'authorized_receiver_display_name',r.authorized_receiver_display_name,
    'requester_display_name',r.requester_display_name,
    'requester_exact_role',r.requester_exact_role,
    'approver_auth_user_id',r.approver_auth_user_id,
    'approver_display_name',r.approver_display_name,
    'approval_policy_version',r.approval_policy_version,
    'submitted_at',r.submitted_at,'created_at',r.created_at,'updated_at',r.updated_at,
    'can_decide',public.v1_company_material_request_assigned_approver(r.id,true),
    'can_plan',public.v1_current_role()='procurement' and r.state in
      ('approved_for_procurement','arranging','ready_for_delivery','partially_received'),
    'can_dispatch',public.v1_current_role()='procurement' and r.state in
      ('ready_for_delivery','partially_dispatched','partially_received'),
    'can_receive',auth.uid()=r.authorized_receiver_auth_user_id,
    'can_handover',auth.uid() in (r.authorized_receiver_auth_user_id,r.beneficiary_auth_user_id),
    'can_close',public.v1_current_role()<>'procurement' and auth.uid() in
      (r.created_by_auth_user_id,r.authorized_receiver_auth_user_id,r.approver_auth_user_id),
    'can_submit_return',auth.uid() in (r.created_by_auth_user_id,
      r.beneficiary_auth_user_id,r.authorized_receiver_auth_user_id),
    'can_decide_returns',public.v1_current_role()='procurement',
    'can_revise',r.state='returned_for_changes' and r.created_by_auth_user_id=auth.uid(),
    'lines',coalesce((select jsonb_agg(jsonb_build_object(
      'id',l.id,'display_order',l.display_order,'item_description',l.item_description,
      'brand_origin',l.brand_origin,'requested_qty',l.requested_qty::text,'unit',l.unit,
      'arranged_qty',coalesce(q.arranged_qty,0)::text,
      'dispatched_qty',coalesce(q.dispatched_qty,0)::text,
      'good_received_qty',coalesce(q.good_qty,0)::text,
      'handed_over_qty',coalesce(q.handed_qty,0)::text,
      'returned_qty',coalesce(q.returned_qty,0)::text
    ) order by l.display_order) from public.v1_company_material_request_lines l
    left join lateral (select
      (select sl.arranged_qty from public.v1_company_material_supply_lines sl
       join public.v1_company_material_supply_plans sp on sp.id=sl.plan_id
       where sp.request_id=r.id and sp.is_current and sl.request_line_id=l.id) arranged_qty,
      (select sum(dl.dispatched_qty) from public.v1_company_material_dispatch_lines dl
       where dl.request_line_id=l.id) dispatched_qty,
      (select sum(rl.good_qty) from public.v1_company_material_receipt_lines rl
       where rl.request_line_id=l.id) good_qty,
      (select sum(hl.handed_over_qty) from public.v1_company_material_handover_lines hl
       where hl.request_line_id=l.id) handed_qty,
      (select sum(retl.return_qty) from public.v1_company_material_return_lines retl
       join public.v1_company_material_returns ret on ret.id=retl.return_id
       join public.v1_company_material_handover_lines hl on hl.id=retl.handover_line_id
       where ret.state='confirmed' and hl.request_line_id=l.id) returned_qty
    ) q on true where l.request_id=r.id),'[]'::jsonb),
    'current_supply_plan',(select jsonb_build_object(
      'id',sp.id,'plan_version',sp.plan_version,'saved_at',sp.saved_at,
      'lines',coalesce((select jsonb_agg(jsonb_build_object(
        'id',sl.id,'request_line_id',sl.request_line_id,'decision',sl.decision,
        'source_kind',sl.source_kind,'inventory_item_id',sl.inventory_item_id,
        'external_supplier',sl.external_supplier,'arranged_qty',sl.arranged_qty::text,
        'expected_available_date',sl.expected_available_date,'follow_up_date',sl.follow_up_date,
        'reason',sl.reason
      ) order by l.display_order) from public.v1_company_material_supply_lines sl
      join public.v1_company_material_request_lines l on l.id=sl.request_line_id
      where sl.plan_id=sp.id),'[]'::jsonb)
    ) from public.v1_company_material_supply_plans sp
      where sp.request_id=r.id and sp.is_current),
    'pending_dispatches',coalesce((select jsonb_agg(jsonb_build_object(
      'id',d.id,'dispatch_number',d.dispatch_number,'dispatched_at',d.dispatched_at,
      'lines',(select jsonb_agg(jsonb_build_object(
        'id',dl.id,'request_line_id',dl.request_line_id,'supply_line_id',dl.supply_line_id,
        'dispatched_qty',dl.dispatched_qty::text
      )) from public.v1_company_material_dispatch_lines dl where dl.dispatch_id=d.id)
    ) order by d.dispatched_at) from public.v1_company_material_dispatches d
      where d.request_id=r.id and d.state='receipt_pending'),'[]'::jsonb),
    'unallocated_receipt_lines',coalesce((select jsonb_agg(jsonb_build_object(
      'id',rl.id,'request_line_id',rl.request_line_id,'good_qty',rl.good_qty::text,
      'available_qty',(rl.good_qty-coalesce((select sum(hl.handed_over_qty)
        from public.v1_company_material_handover_lines hl where hl.receipt_line_id=rl.id),0))::text
    )) from public.v1_company_material_receipt_lines rl
      join public.v1_company_material_receipts rec on rec.id=rl.receipt_id
      where rec.request_id=r.id and rl.good_qty>coalesce((select sum(hl.handed_over_qty)
        from public.v1_company_material_handover_lines hl where hl.receipt_line_id=rl.id),0)
    ),'[]'::jsonb),
    'returnable_handover_lines',coalesce((select jsonb_agg(jsonb_build_object(
      'id',hl.id,'request_line_id',hl.request_line_id,'handed_over_qty',hl.handed_over_qty::text,
      'returnable_qty',(hl.handed_over_qty-coalesce((select sum(retl.return_qty)
        from public.v1_company_material_return_lines retl
        join public.v1_company_material_returns ret on ret.id=retl.return_id
        where retl.handover_line_id=hl.id and ret.state in ('submitted','confirmed')),0))::text
    )) from public.v1_company_material_handover_lines hl
      join public.v1_company_material_handovers h on h.id=hl.handover_id
      where h.request_id=r.id and hl.handed_over_qty>coalesce((select sum(retl.return_qty)
        from public.v1_company_material_return_lines retl
        join public.v1_company_material_returns ret on ret.id=retl.return_id
        where retl.handover_line_id=hl.id and ret.state in ('submitted','confirmed')),0)
    ),'[]'::jsonb),
    'pending_returns',coalesce((select jsonb_agg(jsonb_build_object(
      'id',ret.id,'reason',ret.reason,'submitted_at',ret.submitted_at
    ) order by ret.submitted_at) from public.v1_company_material_returns ret
      where ret.request_id=r.id and ret.state='submitted'),'[]'::jsonb),
    'decisions',coalesce((select jsonb_agg(jsonb_build_object(
      'id',d.id,'decision',d.decision,'reason',d.reason,
      'request_record_version',d.request_record_version,
      'decided_by_display_name',d.decided_by_display_name,
      'decided_by_exact_role',d.decided_by_exact_role,'decided_at',d.decided_at
    ) order by d.decided_at) from public.v1_company_material_request_decisions d
      where d.request_id=r.id),'[]'::jsonb)
  ) into v_result from public.v1_company_material_requests r
  join public.v1_company_material_request_categories c on c.id=r.category_id
  join public.v1_company_material_request_units u on u.id=r.responsible_unit_id
  where r.id=p_request_id;
  return v_result;
end $$;

create or replace function public.v1_revise_and_resubmit_company_material_request(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_purpose text;
  v_delivery text; v_lines jsonb; v_request public.v1_company_material_requests%rowtype;
  v_existing jsonb; v_route record; v_line jsonb; v_line_id uuid; v_qty numeric(18,4);
  v_description text; v_brand text; v_unit text; v_count integer;
begin
  perform public.v1_assert_object_keys(p_payload,array['request_id','expected_version',
    'purpose','delivery_collection_point','lines'],'company_request_revision');
  begin v_request_id:=(p_payload->>'request_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then raise exception 'V1_COMPANY_REVISION_INVALID' using errcode='22023'; end;
  v_purpose:=nullif(btrim(coalesce(p_payload->>'purpose','')),'');
  v_delivery:=nullif(btrim(coalesce(p_payload->>'delivery_collection_point','')),'');
  v_lines:=p_payload->'lines';
  if v_purpose is null or v_delivery is null or jsonb_typeof(v_lines)<>'array'
    or jsonb_array_length(v_lines)=0 then
    raise exception 'V1_COMPANY_REVISION_INVALID' using errcode='22023'; end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_revise_and_resubmit_company_material_request',p_idempotency_key,p_payload);
  select * into v_request from public.v1_company_material_requests where id=v_request_id for update;
  if not found or v_actor is null or not public.v1_current_actor_is_active()
    or v_request.created_by_auth_user_id<>v_actor then
    raise exception 'V1_COMPANY_REVISION_DENIED' using errcode='42501'; end if;
  if v_existing is not null then return public.v1_company_material_request_projection(v_request_id); end if;
  if v_request.state<>'returned_for_changes' or v_request.record_version<>v_expected then
    raise exception 'V1_COMPANY_REVISION_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  if not public.v1_company_material_request_active_authorization(v_actor,v_request.category_id,
      v_request.responsible_unit_id,'requester')
    or not public.v1_company_material_request_active_authorization(v_request.beneficiary_auth_user_id,
      v_request.category_id,v_request.responsible_unit_id,'beneficiary')
    or not public.v1_company_material_request_active_authorization(
      v_request.authorized_receiver_auth_user_id,v_request.category_id,
      v_request.responsible_unit_id,'receiver') then
    raise exception 'V1_COMPANY_REVISION_PARTICIPANT_DENIED' using errcode='42501'; end if;
  select * into v_route from public.v1_resolve_company_material_request_approver(
    v_request.category_id,v_request.responsible_unit_id,array[v_actor,
    v_request.beneficiary_auth_user_id,v_request.authorized_receiver_auth_user_id]);
  if not found then raise exception 'V1_COMPANY_REVISION_ROUTE_UNAVAILABLE' using errcode='42501'; end if;
  select count(*) into v_count from public.v1_company_material_request_lines where request_id=v_request_id;
  if jsonb_array_length(v_lines)<>v_count or (select count(distinct value->>'id')
    from jsonb_array_elements(v_lines))<>v_count then
    raise exception 'V1_COMPANY_REVISION_LINES_INVALID' using errcode='22023'; end if;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['id','item_description','brand_origin',
      'requested_qty','unit'],'company_request_revision_line');
    begin v_line_id:=(v_line->>'id')::uuid;
      v_qty:=(v_line->>'requested_qty')::numeric(18,4);
    exception when others then raise exception 'V1_COMPANY_REVISION_LINE_INVALID' using errcode='22023'; end;
    v_description:=nullif(btrim(coalesce(v_line->>'item_description','')),'');
    v_brand:=nullif(btrim(coalesce(v_line->>'brand_origin','')),'');
    v_unit:=nullif(btrim(coalesce(v_line->>'unit','')),'');
    if v_qty<=0 or v_description is null or v_unit is null or not exists(
      select 1 from public.v1_company_material_request_lines
      where id=v_line_id and request_id=v_request_id) then
      raise exception 'V1_COMPANY_REVISION_LINE_INVALID' using errcode='22023'; end if;
    update public.v1_company_material_request_lines set item_description=v_description,
      brand_origin=v_brand,requested_qty=v_qty,unit=v_unit,updated_at=clock_timestamp()
      where id=v_line_id;
  end loop;
  update public.v1_company_material_requests set purpose=v_purpose,
    delivery_collection_point=v_delivery,state='awaiting_company_approval',
    approval_route_id=v_route.route_id,approval_policy_version=v_route.policy_version,
    approver_auth_user_id=v_route.approver_auth_user_id,
    approver_display_name=v_route.approver_display_name,
    record_version=record_version+1,updated_at=clock_timestamp() where id=v_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(v_request_id,'company_request_resubmitted',
    v_actor,public.v1_current_role(),jsonb_build_object('approval_route_id',v_route.route_id,
    'approval_policy_version',v_route.policy_version),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_revise_and_resubmit_company_material_request',
    p_idempotency_key,public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end $$;

create or replace function public.v1_list_company_material_request_work_inbox()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=auth.uid(); v_role text:=public.v1_current_role(); v_result jsonb;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_COMPANY_WORK_INBOX_DENIED' using errcode='42501'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'request_number',r.request_number,'record_version',r.record_version,
    'state',r.state,'category_name',c.display_name,'responsible_unit_name',u.display_name,
    'purpose',r.purpose,'requester_display_name',r.requester_display_name,
    'beneficiary_display_name',r.beneficiary_display_name,'submitted_at',r.submitted_at,
    'line_count',(select count(*) from public.v1_company_material_request_lines l
      where l.request_id=r.id)
  ) order by r.updated_at desc,r.id),'[]'::jsonb) into v_result
  from public.v1_company_material_requests r
  join public.v1_company_material_request_categories c on c.id=r.category_id
  join public.v1_company_material_request_units u on u.id=r.responsible_unit_id
  where
    (r.state='awaiting_company_approval'
      and public.v1_company_material_request_assigned_approver(r.id,true))
    or (r.state='returned_for_changes' and r.created_by_auth_user_id=v_actor)
    or (v_role='procurement' and (
      r.state in ('approved_for_procurement','arranging','ready_for_delivery',
        'partially_dispatched','partially_received')
      or exists(select 1 from public.v1_company_material_returns ret
        where ret.request_id=r.id and ret.state='submitted')
    ))
    or (r.state='receipt_pending' and r.authorized_receiver_auth_user_id=v_actor)
    or (r.state='awaiting_beneficiary_handover'
      and v_actor in (r.authorized_receiver_auth_user_id,r.beneficiary_auth_user_id))
    or (r.state='fulfilled' and v_role<>'procurement'
      and v_actor in (r.created_by_auth_user_id,r.authorized_receiver_auth_user_id,
        r.approver_auth_user_id));
  return v_result;
end $$;

create or replace function public.v1_notify_company_material_request_event()
returns trigger language plpgsql security definer set search_path='' as $$
declare v_request public.v1_company_material_requests%rowtype; v_recipient uuid; v_code text;
begin
  select * into v_request from public.v1_company_material_requests where id=new.request_id;
  case new.event_type
    when 'company_request_resubmitted' then v_recipient:=v_request.approver_auth_user_id; v_code:='company_material_request_approval_requested';
    when 'company_supply_plan_saved' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_supply_planned';
    when 'company_material_dispatched' then v_recipient:=v_request.authorized_receiver_auth_user_id; v_code:='company_material_request_dispatched';
    when 'company_receipt_confirmed' then v_recipient:=v_request.beneficiary_auth_user_id; v_code:='company_material_request_received';
    when 'company_beneficiary_handover_confirmed' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_handed_over';
    when 'company_return_confirmed' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_return_confirmed';
    when 'company_request_closed' then v_recipient:=v_request.created_by_auth_user_id; v_code:='company_material_request_closed';
    else return new;
  end case;
  if v_recipient is not null and v_recipient<>new.actor_auth_user_id then
    insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
      values(v_recipient,v_code,'company_material_request',new.request_id,null);
  end if;
  return new;
end $$;
drop trigger if exists v1_company_material_request_event_notification
  on public.v1_company_material_request_events;
create trigger v1_company_material_request_event_notification
after insert on public.v1_company_material_request_events
for each row execute function public.v1_notify_company_material_request_event();

revoke all on function public.v1_save_company_material_supply_plan(jsonb,uuid),
  public.v1_dispatch_company_materials(jsonb,uuid),
  public.v1_confirm_company_material_receipt(jsonb,uuid),
  public.v1_confirm_company_material_handover(jsonb,uuid),
  public.v1_submit_company_material_return(jsonb,uuid),
  public.v1_decide_company_material_return(uuid,text,boolean,text,uuid),
  public.v1_close_company_material_request(uuid,integer,uuid),
  public.v1_revise_and_resubmit_company_material_request(jsonb,uuid),
  public.v1_list_company_material_request_work_inbox()
from public,anon,authenticated;
grant execute on function public.v1_save_company_material_supply_plan(jsonb,uuid),
  public.v1_dispatch_company_materials(jsonb,uuid),
  public.v1_confirm_company_material_receipt(jsonb,uuid),
  public.v1_confirm_company_material_handover(jsonb,uuid),
  public.v1_submit_company_material_return(jsonb,uuid),
  public.v1_decide_company_material_return(uuid,text,boolean,text,uuid),
  public.v1_close_company_material_request(uuid,integer,uuid),
  public.v1_revise_and_resubmit_company_material_request(jsonb,uuid),
  public.v1_list_company_material_request_work_inbox()
to authenticated;

revoke all on function public.v1_validate_inventory_reservation_owner() from public,anon,authenticated;
grant execute on function public.v1_validate_inventory_reservation_owner() to service_role;
revoke all on function public.v1_notify_company_material_request_event() from public,anon,authenticated;
grant execute on function public.v1_notify_company_material_request_event() to service_role;

commit;
