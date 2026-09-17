-- Company Material Requests T06: end-to-end authority, remaining-demand
-- planning and immutable company issue evidence.
--
-- Data preservation: this migration is additive. Existing requests,
-- reservations, dispatches, receipts, handovers, returns and audit events are
-- retained. Existing dispatches receive an immutable issue-note snapshot from
-- their already committed facts.
-- Rollback: disable YORKS_V1_COMPANY_MATERIAL_REQUESTS and return to the prior
-- application artifact. Preserve every issue note and operational row; use a
-- forward fix for defects instead of dropping custody or stock evidence.

begin;

create table public.v1_company_material_request_withdrawals (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests (id)
    on delete restrict,
  reason text not null check (btrim(reason) <> ''),
  approved_by_auth_user_id uuid not null references public.v1_profiles (auth_user_id)
    on delete restrict,
  approved_at timestamptz not null default clock_timestamp(),
  idempotency_key uuid not null,
  unique (approved_by_auth_user_id, idempotency_key)
);

create table public.v1_company_material_request_withdrawal_lines (
  id uuid primary key default gen_random_uuid(),
  withdrawal_id uuid not null
    references public.v1_company_material_request_withdrawals (id) on delete restrict,
  request_line_id uuid not null
    references public.v1_company_material_request_lines (id) on delete restrict,
  withdrawn_qty numeric(18,4) not null check (withdrawn_qty > 0),
  unique (withdrawal_id, request_line_id)
);

alter table public.v1_company_material_request_withdrawals enable row level security;
alter table public.v1_company_material_request_withdrawal_lines enable row level security;
revoke all on public.v1_company_material_request_withdrawals,
  public.v1_company_material_request_withdrawal_lines
  from public, anon, authenticated;
grant all on public.v1_company_material_request_withdrawals,
  public.v1_company_material_request_withdrawal_lines to service_role;

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
      'company_return_rejected', 'company_request_closed',
      'company_request_remainder_withdrawn'
    )
  );

create table public.v1_company_material_issue_notes (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.v1_company_material_requests(id)
    on delete restrict,
  dispatch_id uuid not null unique references public.v1_company_material_dispatches(id)
    on delete restrict,
  issue_note_number text not null unique,
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  created_by_auth_user_id uuid not null references public.v1_profiles(auth_user_id)
    on delete restrict,
  created_at timestamptz not null default clock_timestamp()
);

alter table public.v1_company_material_issue_notes enable row level security;
revoke all on table public.v1_company_material_issue_notes
  from public, anon, authenticated;
grant all on table public.v1_company_material_issue_notes to service_role;

create or replace function public.v1_company_material_issue_note_snapshot(
  p_dispatch_id uuid
) returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'document_type', 'company_material_issue_note',
    'request_id', request_record.id,
    'request_number', request_record.request_number,
    'dispatch_id', dispatch_record.id,
    'dispatch_number', dispatch_record.dispatch_number,
    'issued_at', dispatch_record.dispatched_at,
    'issued_by_auth_user_id', dispatch_record.dispatched_by_auth_user_id,
    'issued_by_display_name', issuer.display_name,
    'issued_by_exact_role', coalesce((
      select event_record.actor_exact_role
      from public.v1_company_material_request_events event_record
      where event_record.request_id=request_record.id
        and event_record.event_type='company_material_dispatched'
        and event_record.data->>'dispatch_id'=dispatch_record.id::text
      order by event_record.occurred_at desc limit 1
    ), issuer.canonical_role_snapshot),
    'category_name', category.display_name,
    'responsible_unit_name', unit_record.display_name,
    'purpose', request_record.purpose,
    'delivery_collection_point', request_record.delivery_collection_point,
    'beneficiary_auth_user_id', request_record.beneficiary_auth_user_id,
    'beneficiary_display_name', request_record.beneficiary_display_name,
    'authorized_receiver_auth_user_id', request_record.authorized_receiver_auth_user_id,
    'authorized_receiver_display_name', request_record.authorized_receiver_display_name,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
        'dispatch_line_id', dispatch_line.id,
        'request_line_id', request_line.id,
        'display_order', request_line.display_order,
        'item_description', request_line.item_description,
        'brand_origin', request_line.brand_origin,
        'quantity', dispatch_line.dispatched_qty::text,
        'unit', request_line.unit,
        'source_kind', dispatch_line.source_kind,
        'inventory_item_id', dispatch_line.inventory_item_id
      ) order by request_line.display_order)
      from public.v1_company_material_dispatch_lines dispatch_line
      join public.v1_company_material_request_lines request_line
        on request_line.id = dispatch_line.request_line_id
      where dispatch_line.dispatch_id = dispatch_record.id
    ), '[]'::jsonb)
  )
  from public.v1_company_material_dispatches dispatch_record
  join public.v1_company_material_requests request_record
    on request_record.id = dispatch_record.request_id
  join public.v1_company_material_request_categories category
    on category.id = request_record.category_id
  join public.v1_company_material_request_units unit_record
    on unit_record.id = request_record.responsible_unit_id
  join public.v1_profiles issuer
    on issuer.auth_user_id = dispatch_record.dispatched_by_auth_user_id
  where dispatch_record.id = p_dispatch_id;
$$;

insert into public.v1_company_material_issue_notes(
  request_id, dispatch_id, issue_note_number, snapshot,
  created_by_auth_user_id, created_at
)
select dispatch_record.request_id,
  dispatch_record.id,
  replace(dispatch_record.dispatch_number, 'CM-DSP-', 'CM-ISS-'),
  public.v1_company_material_issue_note_snapshot(dispatch_record.id),
  dispatch_record.dispatched_by_auth_user_id,
  dispatch_record.dispatched_at
from public.v1_company_material_dispatches dispatch_record
on conflict (dispatch_id) do nothing;

create or replace function public.v1_capture_company_material_issue_note()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_dispatch_id uuid;
  v_dispatch public.v1_company_material_dispatches%rowtype;
begin
  if new.event_type <> 'company_material_dispatched' then return new; end if;
  begin
    v_dispatch_id := (new.data->>'dispatch_id')::uuid;
  exception when others then
    raise exception 'V1_COMPANY_ISSUE_NOTE_DISPATCH_INVALID' using errcode = '22023';
  end;
  select * into v_dispatch
  from public.v1_company_material_dispatches
  where id = v_dispatch_id and request_id = new.request_id;
  if not found then
    raise exception 'V1_COMPANY_ISSUE_NOTE_DISPATCH_INVALID' using errcode = '22023';
  end if;
  insert into public.v1_company_material_issue_notes(
    request_id, dispatch_id, issue_note_number, snapshot,
    created_by_auth_user_id, created_at
  ) values (
    new.request_id,
    v_dispatch.id,
    replace(v_dispatch.dispatch_number, 'CM-DSP-', 'CM-ISS-'),
    public.v1_company_material_issue_note_snapshot(v_dispatch.id),
    v_dispatch.dispatched_by_auth_user_id,
    v_dispatch.dispatched_at
  ) on conflict (dispatch_id) do nothing;
  return new;
end;
$$;

drop trigger if exists v1_company_material_dispatch_issue_note
  on public.v1_company_material_request_events;
create trigger v1_company_material_dispatch_issue_note
after insert on public.v1_company_material_request_events
for each row execute function public.v1_capture_company_material_issue_note();

create or replace function public.v1_company_material_issue_note_immutable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception 'V1_COMPANY_ISSUE_NOTE_IMMUTABLE' using errcode = '42501';
end;
$$;

drop trigger if exists v1_company_material_issue_note_immutable
  on public.v1_company_material_issue_notes;
create trigger v1_company_material_issue_note_immutable
before update or delete on public.v1_company_material_issue_notes
for each row execute function public.v1_company_material_issue_note_immutable();

create or replace function public.v1_company_material_handover_authority_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_request public.v1_company_material_requests%rowtype;
begin
  select * into v_request
  from public.v1_company_material_requests
  where id = new.request_id;
  if not found or new.beneficiary_auth_user_id <> v_request.beneficiary_auth_user_id then
    raise exception 'V1_COMPANY_HANDOVER_DENIED' using errcode = '42501';
  end if;
  if new.acknowledgement_basis = 'beneficiary_confirmed' then
    if new.recorded_by_auth_user_id <> v_request.beneficiary_auth_user_id
      or not public.v1_company_material_request_active_authorization(
        new.recorded_by_auth_user_id, v_request.category_id,
        v_request.responsible_unit_id, 'beneficiary'
      ) then
      raise exception 'V1_COMPANY_HANDOVER_DENIED' using errcode = '42501';
    end if;
  elsif new.acknowledgement_basis = 'authorized_receiver_witnessed' then
    if new.recorded_by_auth_user_id <> v_request.authorized_receiver_auth_user_id
      or not public.v1_company_material_request_active_authorization(
        new.recorded_by_auth_user_id, v_request.category_id,
        v_request.responsible_unit_id, 'receiver'
      ) then
      raise exception 'V1_COMPANY_HANDOVER_DENIED' using errcode = '42501';
    end if;
  else
    raise exception 'V1_COMPANY_HANDOVER_DENIED' using errcode = '42501';
  end if;
  return new;
end;
$$;

drop trigger if exists v1_company_material_handover_authority_guard
  on public.v1_company_material_handovers;
create trigger v1_company_material_handover_authority_guard
before insert on public.v1_company_material_handovers
for each row execute function public.v1_company_material_handover_authority_guard();

create or replace function public.v1_save_company_material_supply_plan(
  p_payload jsonb, p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_lines jsonb;
  v_request public.v1_company_material_requests%rowtype; v_existing jsonb;
  v_plan_id uuid; v_version integer; v_line jsonb; v_request_line_id uuid;
  v_decision text; v_source text; v_item uuid; v_supplier text; v_reason text;
  v_arranged numeric(18,4); v_requested numeric(18,4); v_outstanding numeric(18,4);
  v_good numeric(18,4); v_transit numeric(18,4); v_withdrawn numeric(18,4);
  v_expected_date date;
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
  select count(*) into v_count
    from public.v1_company_material_request_lines request_line
    where request_line.request_id=v_request_id
      and request_line.requested_qty
        - coalesce((select sum(receipt_line.good_qty)
          from public.v1_company_material_receipt_lines receipt_line
          where receipt_line.request_line_id=request_line.id),0)
        - coalesce((select sum(dispatch_line.dispatched_qty)
          from public.v1_company_material_dispatch_lines dispatch_line
          join public.v1_company_material_dispatches dispatch_record
            on dispatch_record.id=dispatch_line.dispatch_id
          where dispatch_line.request_line_id=request_line.id
            and dispatch_record.state='receipt_pending'),0)
        - coalesce((select sum(withdrawal_line.withdrawn_qty)
          from public.v1_company_material_request_withdrawal_lines withdrawal_line
          where withdrawal_line.request_line_id=request_line.id),0)>0;
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
    v_requested:=null;
    select requested_qty into v_requested from public.v1_company_material_request_lines
      where id=v_request_line_id and request_id=v_request_id;
    select coalesce(sum(receipt_line.good_qty),0) into v_good
      from public.v1_company_material_receipt_lines receipt_line
      where receipt_line.request_line_id=v_request_line_id;
    select coalesce(sum(dispatch_line.dispatched_qty),0) into v_transit
      from public.v1_company_material_dispatch_lines dispatch_line
      join public.v1_company_material_dispatches dispatch_record
        on dispatch_record.id=dispatch_line.dispatch_id
      where dispatch_line.request_line_id=v_request_line_id
        and dispatch_record.state='receipt_pending';
    select coalesce(sum(withdrawal_line.withdrawn_qty),0) into v_withdrawn
      from public.v1_company_material_request_withdrawal_lines withdrawal_line
      where withdrawal_line.request_line_id=v_request_line_id;
    v_outstanding:=greatest(v_requested-v_good-v_transit-v_withdrawn,0);
    if v_requested is null or v_outstanding<=0 or v_arranged<0 or v_arranged>v_outstanding
      or v_decision not in ('full','partial','unavailable')
      or (v_decision='full' and (v_arranged<>v_outstanding or v_reason is not null))
      or (v_decision='partial' and (v_arranged<=0 or v_arranged>=v_outstanding or v_reason is null))
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

create or replace function public.v1_company_material_withdrawal_immutable()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  raise exception 'V1_COMPANY_WITHDRAWAL_IMMUTABLE' using errcode='42501';
end;
$$;

create trigger v1_company_material_withdrawal_immutable_guard
before update or delete on public.v1_company_material_request_withdrawals
for each row execute function public.v1_company_material_withdrawal_immutable();
create trigger v1_company_material_withdrawal_line_immutable_guard
before update or delete on public.v1_company_material_request_withdrawal_lines
for each row execute function public.v1_company_material_withdrawal_immutable();

create or replace function public.v1_company_material_dispatch_withdrawal_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_requested numeric(18,4);
  v_good numeric(18,4);
  v_transit numeric(18,4);
  v_withdrawn numeric(18,4);
begin
  select requested_qty into v_requested
    from public.v1_company_material_request_lines where id=new.request_line_id;
  select coalesce(sum(good_qty),0) into v_good
    from public.v1_company_material_receipt_lines where request_line_id=new.request_line_id;
  select coalesce(sum(dispatch_line.dispatched_qty),0) into v_transit
    from public.v1_company_material_dispatch_lines dispatch_line
    join public.v1_company_material_dispatches dispatch_record
      on dispatch_record.id=dispatch_line.dispatch_id
    where dispatch_line.request_line_id=new.request_line_id
      and dispatch_record.state='receipt_pending';
  select coalesce(sum(withdrawn_qty),0) into v_withdrawn
    from public.v1_company_material_request_withdrawal_lines
    where request_line_id=new.request_line_id;
  if v_requested is null
    or v_good+v_transit+v_withdrawn+new.dispatched_qty>v_requested then
    raise exception 'V1_COMPANY_DISPATCH_QUANTITY_INVALID' using errcode='22023';
  end if;
  return new;
end;
$$;

create trigger v1_company_material_dispatch_withdrawal_guard
before insert on public.v1_company_material_dispatch_lines
for each row execute function public.v1_company_material_dispatch_withdrawal_guard();

create or replace function public.v1_can_close_company_material_request(p_request_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.v1_current_actor_is_active()
    and public.v1_current_role()<>'procurement' and exists(
      select 1 from public.v1_company_material_requests request_record
      where request_record.id=p_request_id and (
        (request_record.created_by_auth_user_id=auth.uid()
          and public.v1_company_material_request_active_authorization(
            auth.uid(),request_record.category_id,request_record.responsible_unit_id,'requester'))
        or (request_record.authorized_receiver_auth_user_id=auth.uid()
          and public.v1_company_material_request_active_authorization(
            auth.uid(),request_record.category_id,request_record.responsible_unit_id,'receiver'))
        or public.v1_company_material_request_assigned_approver(request_record.id,false)
      )
    );
$$;

create or replace function public.v1_can_handover_company_material_request(p_request_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.v1_current_actor_is_active() and exists(
    select 1 from public.v1_company_material_requests request_record
    where request_record.id=p_request_id and (
      (request_record.beneficiary_auth_user_id=auth.uid()
        and public.v1_company_material_request_active_authorization(
          auth.uid(),request_record.category_id,request_record.responsible_unit_id,'beneficiary'))
      or (request_record.authorized_receiver_auth_user_id=auth.uid()
        and public.v1_company_material_request_active_authorization(
          auth.uid(),request_record.category_id,request_record.responsible_unit_id,'receiver'))
    )
  );
$$;

create or replace function public.v1_can_submit_company_material_return(p_request_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and public.v1_current_actor_is_active() and exists(
    select 1 from public.v1_company_material_requests request_record
    where request_record.id=p_request_id and (
      (request_record.created_by_auth_user_id=auth.uid()
        and public.v1_company_material_request_active_authorization(
          auth.uid(),request_record.category_id,request_record.responsible_unit_id,'requester'))
      or (request_record.beneficiary_auth_user_id=auth.uid()
        and public.v1_company_material_request_active_authorization(
          auth.uid(),request_record.category_id,request_record.responsible_unit_id,'beneficiary'))
      or (request_record.authorized_receiver_auth_user_id=auth.uid()
        and public.v1_company_material_request_active_authorization(
          auth.uid(),request_record.category_id,request_record.responsible_unit_id,'receiver'))
    )
  );
$$;

create or replace function public.v1_company_material_return_authority_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.submitted_by_auth_user_id<>auth.uid()
    or not public.v1_can_submit_company_material_return(new.request_id) then
    raise exception 'V1_COMPANY_RETURN_DENIED' using errcode='42501';
  end if;
  return new;
end;
$$;

create trigger v1_company_material_return_authority_guard
before insert on public.v1_company_material_returns
for each row execute function public.v1_company_material_return_authority_guard();

alter function public.v1_company_material_request_projection(uuid)
  rename to v1_company_material_request_projection_base;
revoke all on function public.v1_company_material_request_projection_base(uuid)
  from public,anon,authenticated;
grant execute on function public.v1_company_material_request_projection_base(uuid)
  to service_role;

create or replace function public.v1_company_material_request_projection(p_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_result jsonb;
  v_lines jsonb;
  v_can_withdraw boolean;
begin
  v_result:=public.v1_company_material_request_projection_base(p_request_id);
  select coalesce(jsonb_agg(line_record.line_value || jsonb_build_object(
      'withdrawn_qty',coalesce(quantity.withdrawn_qty,0)::text,
      'withdrawable_qty',greatest(
        (line_record.line_value->>'requested_qty')::numeric
        - (line_record.line_value->>'good_received_qty')::numeric
        - coalesce(quantity.in_transit_qty,0)
        - coalesce(quantity.withdrawn_qty,0),0)::text
    ) order by (line_record.line_value->>'display_order')::integer),'[]'::jsonb)
    into v_lines
    from jsonb_array_elements(v_result->'lines') line_record(line_value)
    left join lateral (
      select
        (select coalesce(sum(withdrawal_line.withdrawn_qty),0)
          from public.v1_company_material_request_withdrawal_lines withdrawal_line
          where withdrawal_line.request_line_id=(line_record.line_value->>'id')::uuid
        ) withdrawn_qty,
        (select coalesce(sum(dispatch_line.dispatched_qty),0)
          from public.v1_company_material_dispatch_lines dispatch_line
          join public.v1_company_material_dispatches dispatch_record
            on dispatch_record.id=dispatch_line.dispatch_id
          where dispatch_line.request_line_id=(line_record.line_value->>'id')::uuid
            and dispatch_record.state='receipt_pending'
        ) in_transit_qty
    ) quantity on true;
  v_can_withdraw:=public.v1_company_material_request_assigned_approver(
      p_request_id,false
    ) and coalesce((select bool_or(
      (line_value->>'withdrawable_qty')::numeric>0
    ) from jsonb_array_elements(v_lines) line_value),false)
    and (v_result->>'state') in (
      'approved_for_procurement','arranging','ready_for_delivery',
      'partially_received','awaiting_beneficiary_handover','fulfilled'
    );
  return jsonb_set(v_result,'{lines}',v_lines,true) || jsonb_build_object(
    'can_withdraw_remainder',v_can_withdraw,
    'can_receive',auth.uid()=(v_result->>'authorized_receiver_auth_user_id')::uuid
      and public.v1_company_material_request_active_authorization(
        auth.uid(),(v_result->>'category_id')::uuid,
        (v_result->>'responsible_unit_id')::uuid,'receiver'),
    'can_handover',public.v1_can_handover_company_material_request(p_request_id),
    'can_close',public.v1_can_close_company_material_request(p_request_id),
    'can_submit_return',public.v1_can_submit_company_material_return(p_request_id),
    'withdrawals',coalesce((select jsonb_agg(jsonb_build_object(
      'id',withdrawal.id,'reason',withdrawal.reason,
      'approved_by_auth_user_id',withdrawal.approved_by_auth_user_id,
      'approved_at',withdrawal.approved_at,
      'lines',(select jsonb_agg(jsonb_build_object(
        'request_line_id',withdrawal_line.request_line_id,
        'withdrawn_qty',withdrawal_line.withdrawn_qty::text
      ) order by withdrawal_line.request_line_id)
      from public.v1_company_material_request_withdrawal_lines withdrawal_line
      where withdrawal_line.withdrawal_id=withdrawal.id)
    ) order by withdrawal.approved_at)
    from public.v1_company_material_request_withdrawals withdrawal
    where withdrawal.request_id=p_request_id),'[]'::jsonb)
  );
end;
$$;

revoke all on function public.v1_company_material_request_projection(uuid)
  from public,anon,authenticated;
grant execute on function public.v1_company_material_request_projection(uuid)
  to authenticated,service_role;

create or replace function public.v1_withdraw_company_material_request_remainder(
  p_payload jsonb,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_actor uuid:=auth.uid(); v_request_id uuid; v_expected integer; v_reason text;
  v_lines jsonb; v_request public.v1_company_material_requests%rowtype; v_existing jsonb;
  v_withdrawal uuid; v_line jsonb; v_request_line_id uuid; v_qty numeric(18,4);
  v_requested numeric(18,4); v_good numeric(18,4); v_transit numeric(18,4);
  v_prior numeric(18,4); v_count integer; v_plan record; v_new_plan uuid;
  v_supply record; v_new_supply uuid; v_dispatched numeric(18,4);
  v_outstanding numeric(18,4); v_arranged numeric(18,4); v_total_arranged numeric(18,4):=0;
  v_total_requested numeric(18,4); v_total_good numeric(18,4);
  v_total_handed numeric(18,4); v_total_withdrawn numeric(18,4); v_open_transit integer;
  v_next_state text;
begin
  perform public.v1_assert_object_keys(p_payload,
    array['request_id','expected_version','reason','lines'],'company_remainder_withdrawal');
  begin
    v_request_id:=(p_payload->>'request_id')::uuid;
    v_expected:=(p_payload->>'expected_version')::integer;
  exception when others then
    raise exception 'V1_COMPANY_WITHDRAWAL_INVALID' using errcode='22023';
  end;
  v_reason:=nullif(btrim(coalesce(p_payload->>'reason','')),'');
  v_lines:=p_payload->'lines';
  if v_reason is null or jsonb_typeof(v_lines)<>'array' or jsonb_array_length(v_lines)=0
    or (select count(distinct value->>'request_line_id') from jsonb_array_elements(v_lines))
      <>jsonb_array_length(v_lines) then
    raise exception 'V1_COMPANY_WITHDRAWAL_INVALID' using errcode='22023';
  end if;
  v_existing:=public.v1_idempotency_get_or_claim(
    'v1_withdraw_company_material_request_remainder',p_idempotency_key,p_payload);
  if v_existing is not null then
    return public.v1_company_material_request_projection(v_request_id);
  end if;
  select * into v_request from public.v1_company_material_requests
    where id=v_request_id for update;
  if not found or v_request.record_version<>v_expected
    or v_request.state not in (
      'approved_for_procurement','arranging','ready_for_delivery',
      'partially_received','awaiting_beneficiary_handover','fulfilled'
    ) or not public.v1_company_material_request_assigned_approver(v_request_id,false) then
    raise exception 'V1_COMPANY_WITHDRAWAL_DENIED' using errcode='42501';
  end if;
  insert into public.v1_company_material_request_withdrawals(
    request_id,reason,approved_by_auth_user_id,idempotency_key
  ) values(v_request_id,v_reason,v_actor,p_idempotency_key) returning id into v_withdrawal;
  for v_line in select value from jsonb_array_elements(v_lines) loop
    perform public.v1_assert_object_keys(v_line,array['request_line_id','quantity'],
      'company_remainder_withdrawal_line');
    begin
      v_request_line_id:=(v_line->>'request_line_id')::uuid;
      v_qty:=(v_line->>'quantity')::numeric(18,4);
    exception when others then
      raise exception 'V1_COMPANY_WITHDRAWAL_LINE_INVALID' using errcode='22023';
    end;
    select requested_qty into v_requested
      from public.v1_company_material_request_lines
      where id=v_request_line_id and request_id=v_request_id for update;
    select coalesce(sum(good_qty),0) into v_good
      from public.v1_company_material_receipt_lines where request_line_id=v_request_line_id;
    select coalesce(sum(dispatch_line.dispatched_qty),0) into v_transit
      from public.v1_company_material_dispatch_lines dispatch_line
      join public.v1_company_material_dispatches dispatch_record
        on dispatch_record.id=dispatch_line.dispatch_id
      where dispatch_line.request_line_id=v_request_line_id
        and dispatch_record.state='receipt_pending';
    select coalesce(sum(withdrawn_qty),0) into v_prior
      from public.v1_company_material_request_withdrawal_lines
      where request_line_id=v_request_line_id;
    if v_requested is null or v_qty<=0 or v_qty>v_requested-v_good-v_transit-v_prior then
      raise exception 'V1_COMPANY_WITHDRAWAL_LINE_INVALID' using errcode='22023';
    end if;
    insert into public.v1_company_material_request_withdrawal_lines(
      withdrawal_id,request_line_id,withdrawn_qty
    ) values(v_withdrawal,v_request_line_id,v_qty);
  end loop;

  select * into v_plan from public.v1_company_material_supply_plans
    where request_id=v_request_id and is_current for update;
  if found then
    for v_request_line_id in select distinct supply_line.request_line_id
      from public.v1_company_material_supply_lines supply_line
      where supply_line.plan_id=v_plan.id and supply_line.inventory_item_id is not null
      order by 1
    loop
      perform 1 from public.v1_inventory_balances balance
        join public.v1_company_material_supply_lines supply_line
          on supply_line.inventory_item_id=balance.inventory_item_id
        where supply_line.plan_id=v_plan.id
          and supply_line.request_line_id=v_request_line_id for update of balance;
    end loop;
    update public.v1_inventory_reservations set state='released',
      released_at=clock_timestamp(),released_by_auth_user_id=v_actor,
      release_reason='Approved company request remainder withdrawal',
      updated_at=clock_timestamp()
      where request_kind='company' and request_id=v_request_id
        and state in ('active','partially_consumed');
    update public.v1_company_material_supply_plans set is_current=false,
      superseded_at=clock_timestamp() where id=v_plan.id;
    insert into public.v1_company_material_supply_plans(
      request_id,plan_version,saved_by_auth_user_id
    ) values(v_request_id,v_plan.plan_version+1,v_actor) returning id into v_new_plan;
    for v_supply in select supply_line.*
      from public.v1_company_material_supply_lines supply_line
      join public.v1_company_material_request_lines request_line
        on request_line.id=supply_line.request_line_id
      where supply_line.plan_id=v_plan.id order by request_line.display_order
    loop
      select requested_qty into v_requested from public.v1_company_material_request_lines
        where id=v_supply.request_line_id;
      select coalesce(sum(good_qty),0) into v_good
        from public.v1_company_material_receipt_lines where request_line_id=v_supply.request_line_id;
      select coalesce(sum(dispatch_line.dispatched_qty),0) into v_transit
        from public.v1_company_material_dispatch_lines dispatch_line
        join public.v1_company_material_dispatches dispatch_record
          on dispatch_record.id=dispatch_line.dispatch_id
        where dispatch_line.request_line_id=v_supply.request_line_id
          and dispatch_record.state='receipt_pending';
      select coalesce(sum(withdrawn_qty),0) into v_prior
        from public.v1_company_material_request_withdrawal_lines
        where request_line_id=v_supply.request_line_id;
      select coalesce(sum(dispatched_qty),0) into v_dispatched
        from public.v1_company_material_dispatch_lines where supply_line_id=v_supply.id;
      v_outstanding:=greatest(v_requested-v_good-v_transit-v_prior,0);
      v_arranged:=least(greatest(v_supply.arranged_qty-v_dispatched,0),v_outstanding);
      insert into public.v1_company_material_supply_lines(
        plan_id,request_line_id,decision,source_kind,inventory_item_id,
        external_supplier,arranged_qty,expected_available_date,follow_up_date,reason
      ) values(
        v_new_plan,v_supply.request_line_id,
        case when v_arranged=v_outstanding and v_outstanding>0 then 'full'
          when v_arranged>0 then 'partial' else 'unavailable' end,
        case when v_arranged>0 then v_supply.source_kind else null end,
        case when v_arranged>0 then v_supply.inventory_item_id else null end,
        case when v_arranged>0 then v_supply.external_supplier else null end,
        v_arranged,v_supply.expected_available_date,
        case when v_arranged<v_outstanding then v_supply.follow_up_date else null end,
        case when v_arranged=v_outstanding and v_outstanding>0 then null
          when v_outstanding=0 then 'Approved remainder withdrawn'
          else coalesce(v_supply.reason,'Supply plan revision required') end
      ) returning id into v_new_supply;
      if v_arranged>0 and v_supply.source_kind='warehouse' then
        insert into public.v1_inventory_reservations(
          inventory_item_id,request_id,request_kind,company_supply_line_id,
          reserved_qty,state,consumed_qty
        ) values(v_supply.inventory_item_id,v_request_id,'company',v_new_supply,
          v_arranged,'active',0);
      end if;
      v_total_arranged:=v_total_arranged+v_arranged;
    end loop;
  end if;

  select coalesce(sum(requested_qty),0) into v_total_requested
    from public.v1_company_material_request_lines where request_id=v_request_id;
  select coalesce(sum(withdrawal_line.withdrawn_qty),0) into v_total_withdrawn
    from public.v1_company_material_request_withdrawal_lines withdrawal_line
    join public.v1_company_material_request_lines request_line
      on request_line.id=withdrawal_line.request_line_id
    where request_line.request_id=v_request_id;
  select coalesce(sum(receipt_line.good_qty),0) into v_total_good
    from public.v1_company_material_receipt_lines receipt_line
    join public.v1_company_material_receipts receipt
      on receipt.id=receipt_line.receipt_id where receipt.request_id=v_request_id;
  select coalesce(sum(handover_line.handed_over_qty),0) into v_total_handed
    from public.v1_company_material_handover_lines handover_line
    join public.v1_company_material_handovers handover
      on handover.id=handover_line.handover_id where handover.request_id=v_request_id;
  select count(*) into v_open_transit from public.v1_company_material_dispatches
    where request_id=v_request_id and state='receipt_pending';
  v_next_state:=case
    when v_total_good>=v_total_requested-v_total_withdrawn
      and v_total_handed>=v_total_good and v_open_transit=0 then 'fulfilled'
    when v_total_good>v_total_handed then 'awaiting_beneficiary_handover'
    when v_total_good>0 then 'partially_received'
    when v_total_arranged>0 then 'ready_for_delivery'
    when v_request.state='approved_for_procurement' then 'approved_for_procurement'
    else 'arranging' end;
  update public.v1_company_material_requests set state=v_next_state,
    record_version=record_version+1,updated_at=clock_timestamp()
    where id=v_request_id;
  insert into public.v1_company_material_request_events(
    request_id,event_type,actor_auth_user_id,actor_exact_role,data,idempotency_key
  ) values(v_request_id,'company_request_remainder_withdrawn',v_actor,
    public.v1_current_role(),jsonb_build_object('withdrawal_id',v_withdrawal,
      'reason',v_reason,'lines',v_lines),p_idempotency_key);
  perform public.v1_complete_idempotency(
    'v1_withdraw_company_material_request_remainder',p_idempotency_key,
    public.v1_company_material_request_projection(v_request_id));
  return public.v1_company_material_request_projection(v_request_id);
end;
$$;

create or replace function public.v1_close_company_material_request(
  p_request_id uuid,p_expected_version integer,p_idempotency_key uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_actor uuid:=auth.uid(); v_request public.v1_company_material_requests%rowtype;
  v_existing jsonb; v_requested numeric(18,4); v_withdrawn numeric(18,4);
  v_good numeric(18,4); v_handed numeric(18,4); v_open integer;
begin
  select * into v_request from public.v1_company_material_requests where id=p_request_id for update;
  if v_actor is null or not public.v1_current_actor_is_active() or not found
    or not public.v1_can_close_company_material_request(p_request_id) then
    raise exception 'V1_COMPANY_CLOSE_DENIED' using errcode='42501'; end if;
  v_existing:=public.v1_idempotency_get_or_claim('v1_close_company_material_request',
    p_idempotency_key,jsonb_build_object('request_id',p_request_id,
    'expected_version',p_expected_version));
  if v_existing is not null then return public.v1_company_material_request_projection(p_request_id); end if;
  if v_request.state<>'fulfilled' or v_request.record_version<>p_expected_version then
    raise exception 'V1_COMPANY_CLOSE_STATE_OR_VERSION_INVALID' using errcode='40001'; end if;
  select coalesce(sum(requested_qty),0) into v_requested
    from public.v1_company_material_request_lines where request_id=p_request_id;
  select coalesce(sum(withdrawal_line.withdrawn_qty),0) into v_withdrawn
    from public.v1_company_material_request_withdrawal_lines withdrawal_line
    join public.v1_company_material_request_lines request_line
      on request_line.id=withdrawal_line.request_line_id
    where request_line.request_id=p_request_id;
  select coalesce(sum(receipt_line.good_qty),0) into v_good
    from public.v1_company_material_receipt_lines receipt_line
    join public.v1_company_material_receipts receipt on receipt.id=receipt_line.receipt_id
    where receipt.request_id=p_request_id;
  select coalesce(sum(handover_line.handed_over_qty),0) into v_handed
    from public.v1_company_material_handover_lines handover_line
    join public.v1_company_material_handovers handover on handover.id=handover_line.handover_id
    where handover.request_id=p_request_id;
  select count(*) into v_open from public.v1_company_material_dispatches
    where request_id=p_request_id and state='receipt_pending';
  v_open:=v_open+(select count(*) from public.v1_company_material_returns
    where request_id=p_request_id and state='submitted');
  if v_good<v_requested-v_withdrawn or v_handed<v_good or v_open<>0 then
    raise exception 'V1_COMPANY_CLOSE_UNRESOLVED' using errcode='22023'; end if;
  update public.v1_company_material_requests set state='closed',record_version=record_version+1,
    updated_at=clock_timestamp() where id=p_request_id;
  insert into public.v1_company_material_request_events(request_id,event_type,actor_auth_user_id,
    actor_exact_role,data,idempotency_key) values(p_request_id,'company_request_closed',v_actor,
    public.v1_current_role(),jsonb_build_object('good_received_qty',v_good,
    'handed_over_qty',v_handed,'withdrawn_qty',v_withdrawn),p_idempotency_key);
  perform public.v1_complete_idempotency('v1_close_company_material_request',p_idempotency_key,
    public.v1_company_material_request_projection(p_request_id));
  return public.v1_company_material_request_projection(p_request_id);
end $$;

revoke all on function public.v1_withdraw_company_material_request_remainder(jsonb,uuid)
  from public,anon;
grant execute on function public.v1_withdraw_company_material_request_remainder(jsonb,uuid)
  to authenticated,service_role;

create or replace function public.v1_list_company_material_request_register(
  p_view text default 'requests', p_limit integer default 100
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid:=auth.uid();
  v_role text:=public.v1_current_role();
  v_result jsonb;
begin
  if v_actor is null or not public.v1_current_actor_is_active()
    or p_view not in ('requests','planning','issue_history')
    or p_limit<1 or p_limit>200 then
    raise exception 'V1_COMPANY_REGISTER_DENIED' using errcode='42501';
  end if;
  if p_view='planning' and v_role<>'procurement' then
    raise exception 'V1_COMPANY_REGISTER_DENIED' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(row_value order by updated_at desc,row_id),'[]'::jsonb)
    into v_result
  from (
    select jsonb_build_object(
      'row_id',request_record.id,
      'request_id',request_record.id,
      'request_number',request_record.request_number,
      'record_version',request_record.record_version,
      'state',request_record.state,
      'category_name',category.display_name,
      'responsible_unit_name',unit_record.display_name,
      'purpose',request_record.purpose,
      'requester_display_name',request_record.requester_display_name,
      'beneficiary_display_name',request_record.beneficiary_display_name,
      'submitted_at',request_record.submitted_at,
      'updated_at',request_record.updated_at,
      'line_count',(select count(*) from public.v1_company_material_request_lines line_record
        where line_record.request_id=request_record.id),
      'approved_qty',(select coalesce(sum(line_record.requested_qty),0)::text
        from public.v1_company_material_request_lines line_record
        where line_record.request_id=request_record.id),
      'arranged_qty',(select coalesce(sum(supply_line.arranged_qty),0)::text
        from public.v1_company_material_supply_lines supply_line
        join public.v1_company_material_supply_plans plan_record on plan_record.id=supply_line.plan_id
        where plan_record.request_id=request_record.id and plan_record.is_current),
      'good_received_qty',(select coalesce(sum(receipt_line.good_qty),0)::text
        from public.v1_company_material_receipt_lines receipt_line
        join public.v1_company_material_receipts receipt_record on receipt_record.id=receipt_line.receipt_id
        where receipt_record.request_id=request_record.id),
      'handed_over_qty',(select coalesce(sum(handover_line.handed_over_qty),0)::text
        from public.v1_company_material_handover_lines handover_line
        join public.v1_company_material_handovers handover_record on handover_record.id=handover_line.handover_id
        where handover_record.request_id=request_record.id),
      'withdrawn_qty',(select coalesce(sum(withdrawal_line.withdrawn_qty),0)::text
        from public.v1_company_material_request_withdrawal_lines withdrawal_line
        join public.v1_company_material_request_lines line_record
          on line_record.id=withdrawal_line.request_line_id
        where line_record.request_id=request_record.id),
      'latest_issue_note_number',(select issue_note.issue_note_number
        from public.v1_company_material_issue_notes issue_note
        where issue_note.request_id=request_record.id
        order by issue_note.created_at desc limit 1)
    ) row_value, request_record.updated_at, request_record.id row_id
    from public.v1_company_material_requests request_record
    join public.v1_company_material_request_categories category on category.id=request_record.category_id
    join public.v1_company_material_request_units unit_record on unit_record.id=request_record.responsible_unit_id
    where public.v1_company_material_request_readable(request_record.id)
      and (p_view<>'planning' or request_record.state in (
        'approved_for_procurement','arranging','ready_for_delivery','partially_dispatched',
        'receipt_pending','partially_received','awaiting_beneficiary_handover','fulfilled','closed'))
      and (p_view<>'issue_history' or exists(
        select 1 from public.v1_company_material_issue_notes issue_note
        where issue_note.request_id=request_record.id))
    order by request_record.updated_at desc,request_record.id
    limit p_limit
  ) rows;
  return v_result;
end;
$$;

create or replace function public.v1_list_company_material_issue_notes(
  p_request_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_result jsonb;
begin
  if not public.v1_company_material_request_readable(p_request_id) then
    raise exception 'V1_COMPANY_MATERIAL_REQUEST_NOT_READABLE' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',issue_note.id,
    'request_id',issue_note.request_id,
    'dispatch_id',issue_note.dispatch_id,
    'issue_note_number',issue_note.issue_note_number,
    'snapshot',issue_note.snapshot,
    'created_at',issue_note.created_at
  ) order by issue_note.created_at desc),'[]'::jsonb)
  into v_result
  from public.v1_company_material_issue_notes issue_note
  where issue_note.request_id=p_request_id;
  return v_result;
end;
$$;

revoke all on function public.v1_company_material_issue_note_snapshot(uuid),
  public.v1_capture_company_material_issue_note(),
  public.v1_company_material_issue_note_immutable(),
  public.v1_company_material_handover_authority_guard(),
  public.v1_company_material_withdrawal_immutable(),
  public.v1_company_material_dispatch_withdrawal_guard(),
  public.v1_can_close_company_material_request(uuid),
  public.v1_can_handover_company_material_request(uuid),
  public.v1_can_submit_company_material_return(uuid),
  public.v1_company_material_return_authority_guard(),
  public.v1_list_company_material_request_register(text,integer),
  public.v1_list_company_material_issue_notes(uuid)
from public,anon,authenticated;
grant execute on function public.v1_list_company_material_request_register(text,integer),
  public.v1_list_company_material_issue_notes(uuid)
to authenticated;
grant execute on function public.v1_company_material_issue_note_snapshot(uuid),
  public.v1_capture_company_material_issue_note(),
  public.v1_company_material_issue_note_immutable(),
  public.v1_company_material_handover_authority_guard(),
  public.v1_company_material_withdrawal_immutable(),
  public.v1_company_material_dispatch_withdrawal_guard(),
  public.v1_can_close_company_material_request(uuid),
  public.v1_can_handover_company_material_request(uuid),
  public.v1_can_submit_company_material_return(uuid),
  public.v1_company_material_return_authority_guard()
to service_role;

commit;
