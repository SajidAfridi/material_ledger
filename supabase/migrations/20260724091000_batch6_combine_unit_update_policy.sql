-- Keep the same Admin + Procurement-pending authorization in one permissive
-- UPDATE policy so Postgres evaluates a single expression per write.

drop policy if exists material_units_admin_update
  on public."materialUnits";
drop policy if exists material_units_procurement_pending_update
  on public."materialUnits";

create policy material_units_update
on public."materialUnits" for update
using (
  public.app_role() = 'admin'
  or (
    public.app_role() = 'procurement'
    and coalesce((data->>'isCustom')::boolean, false)
    and data->>'status' = 'pendingReview'
  )
)
with check (
  public.app_role() = 'admin'
  or (
    public.app_role() = 'procurement'
    and coalesce((data->>'isCustom')::boolean, false)
    and data->>'status' = 'pendingReview'
  )
);
