begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select plan(13);

select ok(
  has_function_privilege('authenticated',
    'public.v1_search_company_material_request_candidates(uuid,uuid,text,integer)',
    'execute')
  and not has_function_privilege('anon',
    'public.v1_search_company_material_request_candidates(uuid,uuid,text,integer)',
    'execute'),
  'Company catalogue search is authenticated only'
);

set local role postgres;
insert into public.v1_company_material_request_categories(id,category_code,display_name)
values('ca000000-0000-4000-8000-000000000001','composer_ppe','Composer PPE');
insert into public.v1_company_material_request_units(id,unit_code,display_name)
values('ca000000-0000-4000-8000-000000000002','COMPOSER','Composer unit');
insert into public.v1_company_material_request_authorizations(
  auth_user_id,category_id,responsible_unit_id,authority
) values
('10000000-0000-4000-8000-000000000002','ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','requester'),
('10000000-0000-4000-8000-000000000002','ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','beneficiary'),
('10000000-0000-4000-8000-000000000002','ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','receiver'),
('10000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','approver');
insert into public.v1_company_material_request_approval_routes(
  id,category_id,responsible_unit_id,primary_approver_auth_user_id,policy_version
) values('ca000000-0000-4000-8000-000000000003','ca000000-0000-4000-8000-000000000001',
  'ca000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','composer-v1');
insert into public.v1_inventory_items(
  id,item_code,item_description,category_id,brand_origin,size_text,
  model_reference,unit,created_by_auth_user_id
) values('ca000000-0000-4000-8000-000000000020','PPE-SEARCH-1','Searchable safety helmet',
  null,'3M / USA','Adjustable','H-700','Nos','10000000-0000-4000-8000-000000000003');

set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated","app_metadata":{"role":"site_engineer","app_user_id":"usr-local-site-engineer"}}',true);

select is(
  jsonb_array_length(public.v1_search_company_material_request_candidates(
    'ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','helmet',18)),
  1,
  'Authorized Company requester can discover an active catalogue item'
);
select is(
  public.v1_search_company_material_request_candidates(
    'ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','helmet',18)
    #>> '{0,size}',
  'Adjustable',
  'Catalogue search returns technical size'
);
select is(
  public.v1_search_company_material_request_candidates(
    'ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','helmet',18)
    #>> '{0,model}',
  'H-700',
  'Catalogue search returns technical model'
);
select ok(
  not ((public.v1_search_company_material_request_candidates(
    'ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','helmet',18)->0)
      ?| array['on_hand_qty','available_qty','unit_cost','total_cost','project_id']),
  'Catalogue search omits stock, commercial and project facts'
);

create temporary table cmr_composer_saved as
select public.v1_save_company_material_request_draft(jsonb_build_object(
  'request_id','ca000000-0000-4000-8000-000000000010','expected_version',0,
  'category_id','ca000000-0000-4000-8000-000000000001',
  'responsible_unit_id','ca000000-0000-4000-8000-000000000002',
  'purpose','Technical field parity','timing','normal','scheduled_date',null,
  'delivery_collection_point','Workshop issue desk',
  'beneficiary_auth_user_id','10000000-0000-4000-8000-000000000002',
  'authorized_receiver_auth_user_id','10000000-0000-4000-8000-000000000002',
  'lines',jsonb_build_array(jsonb_build_object(
    'id','ca000000-0000-4000-8000-000000000011','display_order',1,
    'item_description','Searchable safety helmet','brand_origin','3M / USA',
    'size','Adjustable','model','H-700','equipment_tag','PPE-RACK-A',
    'requested_qty','2','unit','Nos'
  )))) as response;
grant select on cmr_composer_saved to authenticated;

select is((select response #>> '{lines,0,size}' from cmr_composer_saved),'Adjustable',
  'Draft save round-trips size through the protected projection');
select is((select response #>> '{lines,0,model}' from cmr_composer_saved),'H-700',
  'Draft save round-trips model through the protected projection');
select is((select response #>> '{lines,0,equipment_tag}' from cmr_composer_saved),'PPE-RACK-A',
  'Draft save round-trips equipment tag through the protected projection');

create temporary table cmr_composer_submitted as
select public.v1_save_and_submit_company_material_request(jsonb_build_object(
  'request_id','ca000000-0000-4000-8000-000000000030','expected_version',0,
  'category_id','ca000000-0000-4000-8000-000000000001',
  'responsible_unit_id','ca000000-0000-4000-8000-000000000002',
  'purpose','Submitted technical field parity','timing','normal','scheduled_date',null,
  'delivery_collection_point','Workshop issue desk',
  'beneficiary_auth_user_id','10000000-0000-4000-8000-000000000002',
  'authorized_receiver_auth_user_id','10000000-0000-4000-8000-000000000002',
  'lines',jsonb_build_array(jsonb_build_object(
    'id','ca000000-0000-4000-8000-000000000031','display_order',1,
    'item_description','Searchable safety helmet','brand_origin','3M / USA',
    'size','Adjustable','model','H-700','equipment_tag','PPE-RACK-B',
    'requested_qty','1','unit','Nos'
  ))),'ca000000-0000-4000-8000-000000000032') as response;
grant select on cmr_composer_submitted to authenticated;
select is((select response->>'state' from cmr_composer_submitted),'awaiting_company_approval',
  'Atomic save and submit retains the established approval handoff');
select is((select response #>> '{lines,0,model}' from cmr_composer_submitted),'H-700',
  'Atomic submission retains the technical model in its response');

select throws_ok(
  $$select public.v1_search_company_material_request_candidates(
    'ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','x',18)$$,
  '22023','V1_COMPANY_MATERIAL_SEARCH_INVALID',
  'Too-short catalogue search fails closed'
);

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer","app_user_id":"usr-local-project-engineer"}}',true);
select throws_ok(
  $$select public.v1_search_company_material_request_candidates(
    'ca000000-0000-4000-8000-000000000001','ca000000-0000-4000-8000-000000000002','helmet',18)$$,
  '42501','V1_COMPANY_MATERIAL_SEARCH_DENIED',
  'Approver without requester authority cannot use the Company composer search'
);

set local role postgres;
select is((select count(*) from public.v1_company_material_request_lines
  where request_id='ca000000-0000-4000-8000-000000000010'),1::bigint,
  'Technical parity preserves the single saved line without replacement loss');

select * from finish();
rollback;
