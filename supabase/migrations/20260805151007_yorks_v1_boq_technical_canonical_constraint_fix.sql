-- R35 repair: production retained the historical column constraint after the
-- RPC allow-list was expanded. The constraint must accept exactly the same
-- non-commercial canonical fields as the trusted worksheet commands.
-- Existing data is only validated; no BOQ row, column, group or audit record
-- is rewritten.
alter table public.v1_boq_columns
  drop constraint if exists v1_boq_columns_canonical_field_check;

alter table public.v1_boq_columns
  add constraint v1_boq_columns_canonical_field_check check (canonical_field in (
    'description', 'size', 'model', 'equipment_tag', 'brand_origin',
    'quantity', 'unit', 'planning_model_tag'
  ));
