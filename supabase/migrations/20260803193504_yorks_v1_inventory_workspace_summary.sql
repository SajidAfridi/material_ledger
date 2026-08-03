-- Yorks V1 R35: truthful role-safe inventory workspace counts. The projection
-- is limited to Procurement/Admin by the existing command guard and contains
-- operational quantities only; rates, valuation and supplier commercials are
-- never added to this response shape.

create or replace function public.v1_inventory_workspace_projection(
  p_search text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_search text := nullif(lower(btrim(coalesce(p_search, ''))), '');
begin
  if not public.v1_can_manage_inventory() then
    raise exception 'V1_INVENTORY_WORKSPACE_DENIED' using errcode = '42501';
  end if;
  return (
    with projected_items as (
      select
        item.id,
        item.is_active,
        lower(item.item_description) as description_order,
        lower(coalesce(item.brand_origin, '')) as brand_order,
        public.v1_inventory_item_projection(item.id) as item_projection
      from public.v1_inventory_items item
      where v_search is null
        or lower(item.item_description) like '%' || v_search || '%'
        or lower(coalesce(item.brand_origin, '')) like '%' || v_search || '%'
        or lower(item.unit) like '%' || v_search || '%'
    ), enriched_items as (
      select
        projected_items.*,
        projected_items.item_projection || jsonb_build_object(
          'movement_count', (
            select count(*) from public.v1_inventory_movements movement
            where movement.inventory_item_id = projected_items.id
          ),
          'last_movement_at', (
            select max(movement.created_at) from public.v1_inventory_movements movement
            where movement.inventory_item_id = projected_items.id
          )
        ) as item
      from projected_items
    )
    select jsonb_build_object(
      'items', coalesce(
        jsonb_agg(item order by description_order, brand_order),
        '[]'::jsonb
      ),
      'summary', jsonb_build_object(
        'total_active_items', count(*) filter (where is_active),
        -- Yorks V1 intentionally has no reorder-level model yet, so an item
        -- is not called low-stock until an explicit controlled threshold is
        -- introduced. Out-of-stock remains a truthful available-quantity fact.
        'low_stock_count', 0,
        'out_of_stock_count', count(*) filter (
          where is_active and (item_projection ->> 'available_qty')::numeric <= 0
        ),
        'reserved_count', count(*) filter (
          where is_active and (item_projection ->> 'reserved_qty')::numeric > 0
        ),
        -- Purchase orders/incoming supplier stock are explicitly deferred in
        -- Rev 2.0, so this fact remains zero rather than inferred from an MR.
        'incoming_count', 0
      )
    )
    from enriched_items
  );
end;
$$;

revoke all on function public.v1_inventory_workspace_projection(text)
  from public, anon;
grant execute on function public.v1_inventory_workspace_projection(text)
  to authenticated;
