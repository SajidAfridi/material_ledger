-- Yorks R38.3 warehouse convergence: category families, authoritative
-- suggestions and separate item-master / stock-movement commands.
--
-- Data preservation:
-- * inventory item, balance, reservation, movement and import identifiers are
--   never replaced;
-- * the four seeded Air Terminal children retain their existing category IDs;
-- * only those exact seeded rows receive the deterministic family parent;
-- * no existing uncategorized item is inferred or reclassified.

create extension if not exists pg_trgm with schema extensions;

alter table public.v1_inventory_categories
  add column if not exists parent_category_id uuid
    references public.v1_inventory_categories (id) on delete restrict;

alter table public.v1_inventory_items
  add column if not exists size_text text,
  add column if not exists model_reference text,
  add column if not exists metadata_record_version integer not null default 1
    check (metadata_record_version > 0);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'v1_inventory_categories_not_own_parent_check'
      and conrelid = 'public.v1_inventory_categories'::regclass
  ) then
    alter table public.v1_inventory_categories
      add constraint v1_inventory_categories_not_own_parent_check
      check (parent_category_id is null or parent_category_id <> id);
  end if;
end;
$$;

create index if not exists v1_inventory_categories_parent_active_idx
  on public.v1_inventory_categories (parent_category_id, is_active, name);

-- Preserve the installed identities while representing the hierarchy that the
-- client approved. This is an exact seeded-row correction, never fuzzy data
-- migration.
update public.v1_inventory_categories
set name = case id
      when '41000000-0000-4000-8000-000000000002'::uuid then 'Round'
      when '41000000-0000-4000-8000-000000000003'::uuid then 'Linear Grille'
      when '41000000-0000-4000-8000-000000000004'::uuid then 'SED'
      when '41000000-0000-4000-8000-000000000005'::uuid then 'RED'
      else name
    end,
    parent_category_id = '41000000-0000-4000-8000-000000000001'::uuid,
    updated_at = clock_timestamp(),
    record_version = record_version + 1
where id in (
  '41000000-0000-4000-8000-000000000002'::uuid,
  '41000000-0000-4000-8000-000000000003'::uuid,
  '41000000-0000-4000-8000-000000000004'::uuid,
  '41000000-0000-4000-8000-000000000005'::uuid
)
and (
  parent_category_id is distinct from
    '41000000-0000-4000-8000-000000000001'::uuid
  or name is distinct from case id
    when '41000000-0000-4000-8000-000000000002'::uuid then 'Round'
    when '41000000-0000-4000-8000-000000000003'::uuid then 'Linear Grille'
    when '41000000-0000-4000-8000-000000000004'::uuid then 'SED'
    when '41000000-0000-4000-8000-000000000005'::uuid then 'RED'
  end
);

create or replace function public.v1_inventory_category_display_name(p_value text)
returns text
language plpgsql
immutable
strict
set search_path = ''
as $$
declare
  v_result text := pg_catalog.initcap(pg_catalog.regexp_replace(
    pg_catalog.lower(pg_catalog.btrim(p_value)), '[[:space:]]+', ' ', 'g'
  ));
  v_acronym text;
begin
  foreach v_acronym in array array[
    'AC','HVAC','GI','PVC','SED','RED','VCD','FD','FSD','MSFD','MFD','MSD',
    'MVCD','AHU','FCU','FAHU','VRF'
  ] loop
    v_result := pg_catalog.regexp_replace(
      v_result,
      '\m' || pg_catalog.initcap(pg_catalog.lower(v_acronym)) || '\M',
      v_acronym,
      'g'
    );
  end loop;
  return v_result;
end;
$$;

create or replace function public.v1_inventory_category_projection(
  p_category_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', category.id,
    'name', category.name,
    'parent_category_id', category.parent_category_id,
    'parent_name', parent.name,
    'display_path', case when parent.id is null then category.name
      else parent.name || ' › ' || category.name end,
    'is_system', category.is_system,
    'is_active', category.is_active,
    'record_version', category.record_version,
    'item_count', (
      select count(*) from public.v1_inventory_items item
      where item.category_id = category.id and item.is_active
    ),
    'aliases', coalesce((
      select jsonb_agg(alias.alias_name order by lower(alias.alias_name))
      from public.v1_inventory_category_aliases alias
      where alias.category_id = category.id
    ), '[]'::jsonb),
    'created_by_display_name', case
      when category.created_by_auth_user_id is null then 'Yorks standard'
      else public.v1_safe_profile_display_name(
        profile.display_name, profile.auth_user_id
      )
    end,
    'created_at', category.created_at
  )
  from public.v1_inventory_categories category
  left join public.v1_inventory_categories parent
    on parent.id = category.parent_category_id
  left join public.v1_profiles profile
    on profile.auth_user_id = category.created_by_auth_user_id
  where category.id = p_category_id;
$$;

create or replace function public.v1_inventory_category_suggestions(
  p_query text,
  p_limit integer default 8
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
  v_key text;
  v_limit integer := greatest(1, least(coalesce(p_limit, 8), 20));
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_CATEGORY_SUGGEST_DENIED' using errcode = '42501';
  end if;
  if v_query is null then return '[]'::jsonb; end if;
  v_key := public.v1_inventory_category_key(v_query);
  return coalesce((
    with candidates as (
      select category.id,
        case when parent.id is null then category.name
          else parent.name || ' › ' || category.name end as display_path,
        category.name,
        parent.name as parent_name,
        alias.alias_name,
        greatest(
          extensions.similarity(category.normalized_name, v_key),
          extensions.similarity(
            public.v1_inventory_category_key(coalesce(parent.name, '')),
            v_key
          ),
          extensions.similarity(coalesce(alias.normalized_alias, ''), v_key)
        ) as similarity_score,
        case
          when category.normalized_name = v_key then 0
          when alias.normalized_alias = v_key then 1
          when category.normalized_name like v_key || '%' then 2
          when public.v1_inventory_category_key(coalesce(parent.name, ''))
            like v_key || '%' then 3
          when category.normalized_name like '%' || v_key || '%' then 4
          when alias.normalized_alias like '%' || v_key || '%' then 5
          else 6
        end as rank,
        case
          when category.normalized_name = v_key then 'exact_canonical'
          when alias.normalized_alias = v_key then 'exact_alias'
          when category.normalized_name like v_key || '%' then 'canonical_prefix'
          when alias.normalized_alias like v_key || '%' then 'alias_prefix'
          else 'related'
        end as match_kind
      from public.v1_inventory_categories category
      left join public.v1_inventory_categories parent
        on parent.id = category.parent_category_id
      left join public.v1_inventory_category_aliases alias
        on alias.category_id = category.id
      where category.is_active
        and (
          category.normalized_name like '%' || v_key || '%'
          or public.v1_inventory_category_key(coalesce(parent.name, ''))
            like '%' || v_key || '%'
          or alias.normalized_alias like '%' || v_key || '%'
          or v_key like '%' || category.normalized_name || '%'
          or extensions.similarity(category.normalized_name, v_key) >= 0.25
          or extensions.similarity(
            public.v1_inventory_category_key(coalesce(parent.name, '')),
            v_key
          ) >= 0.25
          or extensions.similarity(
            coalesce(alias.normalized_alias, ''), v_key
          ) >= 0.25
        )
    ), ranked as (
      select distinct on (id) * from candidates
      order by id, rank, similarity_score desc, lower(coalesce(alias_name, ''))
    )
    select jsonb_agg(jsonb_build_object(
      'category_id', id,
      'name', name,
      'parent_name', parent_name,
      'display_path', display_path,
      'match_kind', match_kind,
      'matched_alias', alias_name,
      'similarity_score', similarity_score
    ) order by rank, similarity_score desc, lower(display_path))
    from (
      select * from ranked
      order by rank, similarity_score desc, lower(display_path)
      limit v_limit
    ) limited
  ), '[]'::jsonb);
end;
$$;

create or replace function public.v1_resolve_inventory_category_v2(
  p_category_id uuid,
  p_new_category_name text,
  p_parent_category_id uuid,
  p_source_alias text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_category public.v1_inventory_categories%rowtype;
  v_parent public.v1_inventory_categories%rowtype;
  v_name text;
  v_key text;
  v_alias text := nullif(btrim(coalesce(p_source_alias, '')), '');
  v_alias_key text;
  v_conflict uuid;
  v_alias_id uuid;
  v_created boolean := false;
begin
  if p_category_id is not null and nullif(btrim(coalesce(p_new_category_name, '')), '') is not null then
    raise exception 'V1_INVENTORY_CATEGORY_SELECTION_AMBIGUOUS' using errcode = '22023';
  end if;
  if p_category_id is not null then
    select * into v_category from public.v1_inventory_categories
    where id = p_category_id and is_active;
    if not found then raise exception 'V1_INVENTORY_CATEGORY_NOT_FOUND' using errcode = '22023'; end if;
  else
    v_name := public.v1_inventory_category_display_name(p_new_category_name);
    v_key := public.v1_inventory_category_key(v_name);
    if v_key = '' or char_length(v_name) > 120 then
      raise exception 'V1_INVENTORY_CATEGORY_NAME_INVALID' using errcode = '22023';
    end if;
    if p_parent_category_id is not null then
      select * into v_parent from public.v1_inventory_categories
      where id = p_parent_category_id and is_active and parent_category_id is null;
      if not found then raise exception 'V1_INVENTORY_CATEGORY_PARENT_INVALID' using errcode = '22023'; end if;
    end if;
    select * into v_category from public.v1_inventory_categories
    where normalized_name = v_key and parent_category_id is not distinct from p_parent_category_id;
    if not found then
      insert into public.v1_inventory_categories (
        name, normalized_name, parent_category_id, is_system,
        created_by_auth_user_id
      ) values (v_name, v_key, p_parent_category_id, false, v_actor)
      returning * into v_category;
      v_created := true;
    elsif not v_category.is_active then
      raise exception 'V1_INVENTORY_CATEGORY_INACTIVE' using errcode = '22023';
    end if;
  end if;
  if v_alias is not null then
    v_alias_key := public.v1_inventory_category_key(v_alias);
    if v_alias_key <> '' and v_alias_key <> v_category.normalized_name then
      select category_id into v_conflict from public.v1_inventory_category_aliases
      where normalized_alias = v_alias_key;
      if v_conflict is not null and v_conflict <> v_category.id then
        raise exception 'V1_INVENTORY_CATEGORY_ALIAS_CONFLICT' using errcode = '40001';
      end if;
      insert into public.v1_inventory_category_aliases (
        category_id, alias_name, normalized_alias, created_by_auth_user_id
      ) values (
        v_category.id, public.v1_inventory_category_display_name(v_alias),
        v_alias_key, v_actor
      ) on conflict (normalized_alias) do nothing
      returning id into v_alias_id;
      if v_alias_id is not null then
        perform public.v1_write_audit_event(
          'inventory_category_alias_created','inventory_category_alias',
          v_alias_id,null,null,
          jsonb_build_object(
            'category_id',v_category.id,
            'alias',public.v1_inventory_category_display_name(v_alias)
          ),
          'Approved warehouse category alias',null
        );
      end if;
    end if;
  end if;
  return jsonb_build_object('id', v_category.id, 'created', v_created);
end;
$$;

create or replace function public.v1_inventory_item_projection(
  p_inventory_item_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'id', item.id,
    'item_code', item.item_code,
    'item_description', item.item_description,
    'category_id', item.category_id,
    'category_name', category.name,
    'category_path', case when parent.id is null then category.name
      else parent.name || ' › ' || category.name end,
    'brand_origin', item.brand_origin,
    'size_text', item.size_text,
    'model_reference', item.model_reference,
    'unit', item.unit,
    'minimum_stock', item.minimum_stock::text,
    'location_bin', item.location_bin,
    'notes', item.notes,
    'is_active', item.is_active,
    'on_hand_qty', balance.on_hand_qty::text,
    'reserved_qty', coalesce((select sum(reserved_qty - consumed_qty)
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = item.id
        and reservation.state in ('active', 'partially_consumed')), 0)::text,
    'available_qty', (balance.on_hand_qty - coalesce((select sum(reserved_qty - consumed_qty)
      from public.v1_inventory_reservations reservation
      where reservation.inventory_item_id = item.id
        and reservation.state in ('active', 'partially_consumed')), 0))::text,
    'record_version', balance.record_version,
    'metadata_record_version', item.metadata_record_version,
    'created_at', item.created_at,
    'updated_at', item.updated_at
  )
  from public.v1_inventory_items item
  join public.v1_inventory_balances balance on balance.inventory_item_id = item.id
  left join public.v1_inventory_categories category on category.id = item.category_id
  left join public.v1_inventory_categories parent on parent.id = category.parent_category_id
  where item.id = p_inventory_item_id;
$$;

create or replace function public.v1_create_inventory_item(
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
  v_existing jsonb;
  v_item_id uuid := gen_random_uuid();
  v_code text := nullif(btrim(coalesce(p_payload ->> 'item_code', '')), '');
  v_description text := nullif(btrim(coalesce(p_payload ->> 'item_description', '')), '');
  v_unit text := nullif(btrim(coalesce(p_payload ->> 'unit', '')), '');
  v_category jsonb;
  v_opening numeric(18,4) := coalesce(nullif(p_payload ->> 'opening_quantity', '')::numeric, 0);
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason', '')), '');
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload, array[
    'item_code','item_description','category_id','new_category_name',
    'new_category_parent_id','source_category_text','brand_origin','size_text',
    'model_reference','unit','minimum_stock','location_bin','notes',
    'opening_quantity','opening_reference','reason'
  ], 'create_inventory_item');
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_ITEM_CREATE_DENIED' using errcode = '42501';
  end if;
  if v_description is null or v_unit is null or v_opening < 0
    or (v_opening > 0 and v_reason is null) then
    raise exception 'V1_INVENTORY_ITEM_CREATE_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_inventory_item', p_idempotency_key, p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_category := public.v1_resolve_inventory_category_v2(
    nullif(p_payload ->> 'category_id','')::uuid,
    p_payload ->> 'new_category_name',
    nullif(p_payload ->> 'new_category_parent_id','')::uuid,
    p_payload ->> 'source_category_text'
  );
  if v_category is null then
    raise exception 'V1_INVENTORY_CATEGORY_REQUIRED' using errcode = '22023';
  end if;
  if v_code is null then
    v_code := 'INV-' || upper(substr(replace(v_item_id::text, '-', ''), 1, 8));
  end if;
  insert into public.v1_inventory_items (
    id,item_code,item_description,category_id,brand_origin,size_text,
    model_reference,unit,minimum_stock,location_bin,notes,created_by_auth_user_id
  ) values (
    v_item_id,v_code,v_description,(v_category->>'id')::uuid,
    nullif(btrim(coalesce(p_payload->>'brand_origin','')),''),
    nullif(btrim(coalesce(p_payload->>'size_text','')),''),
    nullif(btrim(coalesce(p_payload->>'model_reference','')),''),v_unit,
    nullif(p_payload->>'minimum_stock','')::numeric,
    nullif(btrim(coalesce(p_payload->>'location_bin','')),''),
    nullif(btrim(coalesce(p_payload->>'notes','')),''),v_actor
  );
  insert into public.v1_inventory_balances (inventory_item_id,on_hand_qty)
    values (v_item_id,v_opening);
  if v_opening > 0 then
    insert into public.v1_inventory_movements (
      inventory_item_id,movement_type,quantity_delta,on_hand_after_qty,
      source_entity_type,reason,actor_auth_user_id,idempotency_key
    ) values (
      v_item_id,'opening_balance',v_opening,v_opening,'inventory_opening_balance',
      concat(v_reason, case when nullif(btrim(coalesce(p_payload->>'opening_reference','')),'') is null
        then '' else ' · ' || btrim(p_payload->>'opening_reference') end),
      v_actor,p_idempotency_key
    );
  end if;
  v_response := public.v1_inventory_item_projection(v_item_id);
  perform public.v1_write_audit_event(
    'inventory_item_created','inventory_item',v_item_id,null,null,v_response,
    coalesce(v_reason,'Inventory item master created'),p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_inventory_item',p_idempotency_key,v_response
  );
  return v_response;
end;
$$;

create or replace function public.v1_adjust_inventory_stock(
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
  v_item_id uuid := nullif(p_payload ->> 'inventory_item_id','')::uuid;
  v_expected integer := nullif(p_payload ->> 'expected_version','')::integer;
  v_action text := nullif(btrim(coalesce(p_payload ->> 'action','')),'');
  v_qty numeric(18,4) := nullif(p_payload ->> 'quantity','')::numeric;
  v_delta numeric(18,4);
  v_reason text := nullif(btrim(coalesce(p_payload ->> 'reason','')),'');
  v_balance public.v1_inventory_balances%rowtype;
  v_reserved numeric(18,4);
  v_existing jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(p_payload,array[
    'inventory_item_id','expected_version','action','quantity','reason','reference'
  ],'adjust_inventory_stock');
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_ADJUST_DENIED' using errcode = '42501';
  end if;
  if v_item_id is null or v_expected is null or v_expected < 1
    or v_action not in ('add','remove','correction') or v_qty is null
    or v_qty = 0 or v_reason is null
    or (v_action <> 'correction' and v_qty < 0) then
    raise exception 'V1_INVENTORY_ADJUST_PAYLOAD_INVALID' using errcode = '22023';
  end if;
  v_delta := case v_action when 'add' then v_qty when 'remove' then -v_qty else v_qty end;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_adjust_inventory_stock',p_idempotency_key,p_payload
  );
  if v_existing is not null then return v_existing; end if;
  select balance.* into v_balance from public.v1_inventory_balances balance
  join public.v1_inventory_items item on item.id=balance.inventory_item_id
  where balance.inventory_item_id=v_item_id and item.is_active for update of balance;
  if not found then raise exception 'V1_INVENTORY_ITEM_NOT_FOUND' using errcode='22023'; end if;
  if v_balance.record_version <> v_expected then
    raise exception 'V1_INVENTORY_ITEM_VERSION_CONFLICT' using errcode='40001';
  end if;
  select coalesce(sum(reserved_qty-consumed_qty),0) into v_reserved
  from public.v1_inventory_reservations where inventory_item_id=v_item_id
    and state in ('active','partially_consumed');
  if v_balance.on_hand_qty + v_delta < v_reserved then
    raise exception 'V1_INVENTORY_ADJUSTMENT_BELOW_RESERVED' using errcode='22023';
  end if;
  update public.v1_inventory_balances set on_hand_qty=on_hand_qty+v_delta,
    record_version=record_version+1,updated_at=clock_timestamp()
  where inventory_item_id=v_item_id;
  insert into public.v1_inventory_movements (
    inventory_item_id,movement_type,quantity_delta,on_hand_after_qty,
    source_entity_type,reason,actor_auth_user_id,idempotency_key
  ) values (
    v_item_id,case when v_action='correction' then 'correction' else 'adjustment' end,
    v_delta,v_balance.on_hand_qty+v_delta,'manual_stock_movement',
    concat(v_reason,case when nullif(btrim(coalesce(p_payload->>'reference','')),'') is null
      then '' else ' · ' || btrim(p_payload->>'reference') end),
    v_actor,p_idempotency_key
  );
  v_response := public.v1_inventory_item_projection(v_item_id);
  perform public.v1_write_audit_event(
    'inventory_adjusted','inventory_item',v_item_id,null,
    jsonb_build_object('on_hand',v_balance.on_hand_qty::text),
    jsonb_build_object('on_hand',(v_balance.on_hand_qty+v_delta)::text,'action',v_action),
    v_reason,p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_adjust_inventory_stock',p_idempotency_key,v_response
  );
  return v_response;
end;
$$;

-- Existing category creation gains an optional parent while retaining its
-- installed signature and idempotency command name.
create or replace function public.v1_create_inventory_category(
  p_payload jsonb,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing jsonb;
  v_resolution jsonb;
  v_response jsonb;
begin
  perform public.v1_assert_object_keys(
    p_payload,array['name','parent_category_id'],'create_inventory_category'
  );
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_CATEGORY_CREATE_DENIED' using errcode='42501';
  end if;
  v_existing := public.v1_idempotency_get_or_claim(
    'v1_create_inventory_category',p_idempotency_key,p_payload
  );
  if v_existing is not null then return v_existing; end if;
  v_resolution := public.v1_resolve_inventory_category_v2(
    null,p_payload->>'name',nullif(p_payload->>'parent_category_id','')::uuid,null
  );
  v_response := public.v1_inventory_category_projection((v_resolution->>'id')::uuid);
  perform public.v1_write_audit_event(
    'inventory_category_created','inventory_category',(v_resolution->>'id')::uuid,
    null,null,v_response,'Warehouse category created',p_idempotency_key
  );
  perform public.v1_complete_idempotency(
    'v1_create_inventory_category',p_idempotency_key,v_response
  );
  return v_response;
end;
$$;

revoke all on function public.v1_inventory_category_suggestions(text, integer)
  from public, anon;
revoke all on function public.v1_create_inventory_item(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_adjust_inventory_stock(jsonb, uuid)
  from public, anon;
revoke all on function public.v1_resolve_inventory_category_v2(uuid,text,uuid,text)
  from public, anon, authenticated;
grant execute on function public.v1_inventory_category_suggestions(text, integer)
  to authenticated;
grant execute on function public.v1_create_inventory_item(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_adjust_inventory_stock(jsonb, uuid)
  to authenticated;
grant execute on function public.v1_inventory_category_suggestions(text, integer),
  public.v1_create_inventory_item(jsonb, uuid),
  public.v1_adjust_inventory_stock(jsonb, uuid),
  public.v1_resolve_inventory_category_v2(uuid,text,uuid,text)
  to service_role;
