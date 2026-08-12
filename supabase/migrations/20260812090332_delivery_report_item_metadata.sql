-- Delivery Report line metadata trust pass.
--
-- Size/model are frozen from the submitted Material Request line, never read
-- from a mutable inventory item while rendering. Existing revision lines are
-- deterministically enriched through their immutable dispatch/request links;
-- quantities, item descriptions, identities and revision history are retained.

begin;

alter table public.v1_delivery_order_revision_lines
  add column if not exists size_text text,
  add column if not exists model_reference text;

update public.v1_delivery_order_revision_lines revision_line
set size_text = coalesce(
      revision_line.size_text,
      nullif(btrim(request_line.technical_attributes ->> 'size'), '')
    ),
    model_reference = coalesce(
      revision_line.model_reference,
      nullif(btrim(request_line.technical_attributes ->> 'model'), ''),
      nullif(btrim(request_line.technical_attributes ->> 'planning_model_tag'), ''),
      nullif(btrim(request_line.technical_attributes ->> 'equipment_tag'), '')
    )
from public.v1_material_dispatch_lines dispatch_line
join public.v1_material_request_lines request_line
  on request_line.id = dispatch_line.request_line_id
where revision_line.dispatch_line_id = dispatch_line.id
  and (revision_line.size_text is null or revision_line.model_reference is null);

do $projection$
declare
  v_definition text;
  v_replacement text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_delivery_order_projection(uuid)'::regprocedure
  );
  if position('''size'', line.size_text' in v_definition) > 0 then
    return;
  end if;
  v_replacement := replace(
    v_definition,
    $old$'item_description', line.item_description,
            'quantity', line.delivery_quantity::text,$old$,
    $new$'item_description', line.item_description,
            'size', line.size_text,
            'model', line.model_reference,
            'quantity', line.delivery_quantity::text,$new$
  );
  if v_replacement = v_definition then
    raise exception 'V1_DELIVERY_REPORT_METADATA_PROJECTION_ANCHOR_MISSING';
  end if;
  execute v_replacement;
end;
$projection$;

do $dispatch_revision$
declare
  v_definition text;
  v_replacement text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_generate_delivery_order(jsonb,uuid)'::regprocedure
  );
  if position('display_order, item_description, size_text, model_reference,' in v_definition) > 0 then
    return;
  end if;
  v_replacement := replace(
    v_definition,
    $old$display_order, item_description, good_quantity, delivery_quantity, unit$old$,
    $new$display_order, item_description, size_text, model_reference,
      good_quantity, delivery_quantity, unit$new$
  );
  v_replacement := replace(
    v_replacement,
    $old$dispatch_line.item_description,
      dispatch_line.dispatched_qty,$old$,
    $new$dispatch_line.item_description,
      nullif(btrim(request_line.technical_attributes ->> 'size'), ''),
      coalesce(
        nullif(btrim(request_line.technical_attributes ->> 'model'), ''),
        nullif(btrim(request_line.technical_attributes ->> 'planning_model_tag'), ''),
        nullif(btrim(request_line.technical_attributes ->> 'equipment_tag'), '')
      ),
      dispatch_line.dispatched_qty,$new$
  );
  if v_replacement = v_definition
     or position('display_order, item_description, size_text, model_reference,' in v_replacement) = 0
     or position('request_line.technical_attributes ->> ''size''' in v_replacement) = 0 then
    raise exception 'V1_DELIVERY_REPORT_METADATA_DISPATCH_ANCHOR_MISSING';
  end if;
  execute v_replacement;
end;
$dispatch_revision$;

do $receipt_revision$
declare
  v_definition text;
  v_replacement text;
begin
  v_definition := pg_get_functiondef(
    'public.v1_append_receipt_review_delivery_report_revision(uuid,uuid,uuid,text)'::regprocedure
  );
  if position(E'item_description,\n    size_text,\n    model_reference,' in v_definition) > 0 then
    return;
  end if;
  v_replacement := replace(
    v_definition,
    $old$item_description,
    good_quantity,$old$,
    $new$item_description,
    size_text,
    model_reference,
    good_quantity,$new$
  );
  v_replacement := replace(
    v_replacement,
    $old$dispatch_line.item_description,
    review_line.good_qty,$old$,
    $new$dispatch_line.item_description,
    nullif(btrim(request_line.technical_attributes ->> 'size'), ''),
    coalesce(
      nullif(btrim(request_line.technical_attributes ->> 'model'), ''),
      nullif(btrim(request_line.technical_attributes ->> 'planning_model_tag'), ''),
      nullif(btrim(request_line.technical_attributes ->> 'equipment_tag'), '')
    ),
    review_line.good_qty,$new$
  );
  if v_replacement = v_definition
     or position(E'item_description,\n    size_text,\n    model_reference,' in v_replacement) = 0
     or position('request_line.technical_attributes ->> ''size''' in v_replacement) = 0 then
    raise exception 'V1_DELIVERY_REPORT_METADATA_RECEIPT_ANCHOR_MISSING';
  end if;
  execute v_replacement;
end;
$receipt_revision$;

comment on column public.v1_delivery_order_revision_lines.size_text is
  'Immutable submitted-MR size context rendered beneath the Delivery Report item description.';
comment on column public.v1_delivery_order_revision_lines.model_reference is
  'Immutable submitted-MR model/tag context rendered beneath the Delivery Report item description.';

commit;
