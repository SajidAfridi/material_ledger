-- Stable Yorks defaults. Insert-only so an Admin's later edits always win.

insert into public."materialCategories" (id, data)
select id, jsonb_build_object(
  'id', id,
  'name', name,
  'secondaryName', secondary_name,
  'sortOrder', sort_order,
  'isCustom', false,
  'archived', false,
  'updatedAt', '2026-07-24T09:20:00.000Z',
  'updatedBy', 'V7 migration'
)
from (values
  ('cat-air-terminals', 'Air Terminals', 'ہوا کے ٹرمینلز', 0),
  ('cat-dampers-fire-control', 'Dampers & Fire Control', 'ڈیمپرز اور فائر کنٹرول', 1),
  ('cat-fans-equipment', 'Fans & Equipment', 'پنکھے اور آلات', 2),
  ('cat-ductwork-accessories', 'Ductwork & Accessories', 'ڈکٹ ورک اور لوازمات', 3),
  ('cat-piping-drain', 'Piping & Drain', 'پائپنگ اور ڈرین', 4),
  ('cat-electrical-controls', 'Electrical & Controls', 'الیکٹریکل اور کنٹرولز', 5),
  ('cat-supports-insulation', 'Supports & Insulation', 'سپورٹس اور انسولیشن', 6),
  ('cat-general-custom', 'General & Custom', 'عام اور کسٹم', 7)
) as defaults(id, name, secondary_name, sort_order)
on conflict (id) do nothing;

insert into public."materialUnits" (id, data)
select id, jsonb_build_object(
  'id', id,
  'name', name,
  'symbol', symbol,
  'secondaryName', secondary_name,
  'sortOrder', sort_order,
  'isCustom', false,
  'status', 'approved',
  'updatedAt', '2026-07-24T09:20:00.000Z',
  'updatedBy', 'V7 migration'
)
from (values
  ('unit-nos', 'Nos', 'Nos', 'عدد', 0),
  ('unit-meter', 'Meter', 'm', 'میٹر', 1),
  ('unit-cm', 'Centimeter', 'cm', 'سینٹی میٹر', 2),
  ('unit-length', 'Length', 'Length', 'لمبائی', 3),
  ('unit-set', 'Set', 'Set', 'سیٹ', 4),
  ('unit-pairs', 'Pairs', 'Pairs', 'جوڑے', 5),
  ('unit-roll', 'Roll', 'Roll', 'رول', 6),
  ('unit-box', 'Box', 'Box', 'ڈبہ', 7)
) as defaults(id, name, symbol, secondary_name, sort_order)
on conflict (id) do nothing;

insert into public."materialUnits" (id, data)
select id, jsonb_build_object(
  'id', id,
  'name', name,
  'symbol', symbol,
  'secondaryName', '',
  'sortOrder', sort_order,
  'isCustom', true,
  'status', 'pendingReview',
  'updatedAt', '2026-07-24T09:20:00.000Z',
  'updatedBy', 'Legacy migration'
)
from (values
  ('custom-unit-kg', 'Kilograms', 'kg', 100),
  ('custom-unit-tons', 'Tons', 'tons', 101),
  ('custom-unit-bags', 'Bags', 'bags', 102),
  ('custom-unit-sqft', 'Square Feet', 'sqft', 103),
  ('custom-unit-l', 'Liters', 'L', 104),
  ('custom-unit-m', 'Cubic Meters', 'm³', 105),
  ('custom-unit-rods', 'Rods', 'rods', 106),
  ('custom-unit-sheets', 'Sheets', 'sheets', 107),
  ('custom-unit-ft', 'Feet', 'ft', 108),
  ('custom-unit-in', 'Inches', 'in', 109)
) as defaults(id, name, symbol, sort_order)
on conflict (id) do nothing;
