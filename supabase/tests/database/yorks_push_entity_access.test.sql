begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into public.v1_projects(id,project_ref,name,state,created_by_auth_user_id,created_by_role)
values('ab100000-0000-4000-8000-000000000001','PUSH-ACCESS','Push access fixture','active','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_project_scopes(id,project_id,scope_kind,scope_code,name,is_immutable)
values('ab200000-0000-4000-8000-000000000001','ab100000-0000-4000-8000-000000000001','common','common','Common / All Buildings',true);
insert into public.v1_project_members(project_id,member_auth_user_id,project_role,reason,assigned_by_auth_user_id,assigned_by_role)
values('ab100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','project_engineer','Push fixture','10000000-0000-4000-8000-000000000004','admin'),
('ab100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','site_engineer','Push fixture','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_material_requests(id,project_id,scope_id,created_by_auth_user_id,state,request_number,submitted_at)
values('ab300000-0000-4000-8000-000000000001','ab100000-0000-4000-8000-000000000001','ab200000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','submitted','PUSH-MR001',now());
insert into public.v1_notifications(id,recipient_auth_user_id,event_code,entity_type,entity_id,project_id)
select ('ab400000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 ('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 'material_request_submitted','material_request','ab300000-0000-4000-8000-000000000001','ab100000-0000-4000-8000-000000000001'
from generate_series(1,4) i;
select ok(public.v1_push_notification_entity_allowed(n),'Current recipient allowed: '||p.exact_role)
from public.v1_notifications n cross join lateral (select public.v1_permission_exact_role(n.recipient_auth_user_id) exact_role) p
where n.id::text like 'ab400%';
update public.v1_project_members set effective_to=clock_timestamp(),revoked_by_auth_user_id='10000000-0000-4000-8000-000000000004',revoked_by_role='admin',revoked_reason='Push revocation test'
where project_id='ab100000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Removed Engineering recipient blocked') from public.v1_notifications n
where n.id in ('ab400000-0000-4000-8000-000000000001','ab400000-0000-4000-8000-000000000002');
update public.v1_material_requests set state='draft',request_number=null,submitted_at=null where id='ab300000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"role":"project_engineer"}}',true);
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r
 where r->>'notification_id'='ab400000-0000-4000-8000-000000000001'),'Revoked project access suppresses fresh foreground attention');
select ok(exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'records') r
 where r->>'notification_id'='ab400000-0000-4000-8000-000000000001'),'Revocation preserves the recipient workflow history');
set local role postgres;
select ok(not public.v1_push_notification_entity_allowed(n),'Procurement cannot receive a private draft') from public.v1_notifications n where n.id='ab400000-0000-4000-8000-000000000003';
update public.v1_notifications set event_code='material_request_approval_required' where id='ab400000-0000-4000-8000-000000000004';
select ok(not public.v1_push_notification_entity_allowed(n),'Obsolete approval action blocked even for Admin') from public.v1_notifications n where n.id='ab400000-0000-4000-8000-000000000004';
update public.v1_material_requests set state='awaiting_request_approval',request_number='PUSH-MR001',submitted_at=now() where id='ab300000-0000-4000-8000-000000000001';
select ok(public.v1_push_notification_entity_allowed(n),'Current approval action accepted for Admin') from public.v1_notifications n where n.id='ab400000-0000-4000-8000-000000000004';
update public.v1_notifications set entity_id='ab300000-0000-4000-8000-000000000099' where id='ab400000-0000-4000-8000-000000000004';
select ok(not public.v1_push_notification_entity_allowed(n),'Missing target blocked even for Admin') from public.v1_notifications n where n.id='ab400000-0000-4000-8000-000000000004';
select ok(not has_function_privilege('authenticated','public.v1_push_notification_entity_allowed(public.v1_notifications)','execute'),'Clients cannot probe other recipients');
select ok(not has_function_privilege('anon','public.v1_push_notification_entity_allowed(public.v1_notifications)','execute'),'Anonymous entity probing denied');
insert into public.v1_chat_conversations(id,kind,title,created_by_auth_user_id,created_by_exact_role)
values('ab500000-0000-4000-8000-000000000001','group','Push recipient test','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_chat_members(conversation_id,auth_user_id)
values('ab500000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004');
update public.v1_notifications set event_code='team_chat_message',entity_type='chat_conversation',entity_id='ab500000-0000-4000-8000-000000000001',project_id=null
where id='ab400000-0000-4000-8000-000000000004';
select ok(public.v1_push_notification_entity_allowed(n),'Unread Chat for current member is eligible') from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","role":"authenticated","app_metadata":{"role":"admin"}}',true);
select ok(exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r
 where r->>'notification_id'='ab400000-0000-4000-8000-000000000004'),'Current unread Chat is present in protected foreground attention');
set local role postgres;
update public.v1_chat_members set is_muted=true where conversation_id='ab500000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Muted Chat suppresses queued push') from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r
 where r->>'notification_id'='ab400000-0000-4000-8000-000000000004'),'Muted Chat suppresses fresh foreground attention');
set local role postgres;
update public.v1_chat_members set is_muted=false where conversation_id='ab500000-0000-4000-8000-000000000001';
update public.v1_chat_members set last_read_at=clock_timestamp() where conversation_id='ab500000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Read Chat is no longer eligible') from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r
 where r->>'notification_id'='ab400000-0000-4000-8000-000000000004'),'Read Chat suppresses fresh foreground attention');
set local role postgres;
update public.v1_chat_members set last_read_at=null,left_at=clock_timestamp() where conversation_id='ab500000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Former Chat member receives no queued push') from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
set local role authenticated;
select ok(not exists(select 1 from jsonb_array_elements(public.v1_notification_page()->'attention') r
 where r->>'notification_id'='ab400000-0000-4000-8000-000000000004'),'Left Chat suppresses fresh foreground attention');
set local role postgres;
update public.v1_notifications set project_id='ab100000-0000-4000-8000-000000000001' where id='ab400000-0000-4000-8000-000000000004';
-- Resolve stable module targets without exposing commercial values.
update public.v1_notifications set event_code='accounts_claim_ready',entity_type='accounts_client_claim',entity_id='ab300000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000004';
select is(public.v1_notification_module_route(n),'/yorks/projects/ab100000-0000-4000-8000-000000000001/accounts/client-invoices?claim_id=ab300000-0000-4000-8000-000000000001','Accounts notification targets exact claim')
from public.v1_notifications n where n.id='ab400000-0000-4000-8000-000000000004';
update public.v1_notifications set event_code='workforce_period_submitted',entity_type='workforce_monthly_period'
where id='ab400000-0000-4000-8000-000000000004';
select is(public.v1_notification_module_route(n),'/yorks/workforce/timesheets?period_id=ab300000-0000-4000-8000-000000000001','Workforce notification selects exact period')
from public.v1_notifications n where n.id='ab400000-0000-4000-8000-000000000004';
select ok(not has_function_privilege('authenticated','public.v1_notification_module_route(public.v1_notifications)','execute'),'Clients cannot resolve other recipients module targets');

-- Re-establish dated memberships for the permission matrix below; historical
-- revoked membership rows above are preserved.
insert into public.v1_project_members(project_id,member_auth_user_id,project_role,reason,assigned_by_auth_user_id,assigned_by_role)
values('ab100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','project_engineer','Current action matrix','10000000-0000-4000-8000-000000000004','admin'),
('ab100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','site_engineer','Current action matrix','10000000-0000-4000-8000-000000000004','admin');

-- Exercise queued actions against real current arrangement, approved quantity,
-- dispatch and receipt facts. The notification rows remain intact throughout.
update public.v1_material_requests set state='approved_for_arrangement',current_action_code='arrangement_required'
where id='ab300000-0000-4000-8000-000000000001';
update public.v1_notifications set event_code='material_request_approved_for_arrangement',entity_type='material_request',
 entity_id='ab300000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000003';
select ok(public.v1_push_notification_entity_allowed(n),'Approved request awaiting arrangement is eligible')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_material_requests set state='arranging',current_action_code='procurement_clarification_changes_required'
where id='ab300000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Prior approval no longer prompts arrangement after clarification was returned')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_notifications set event_code='material_request_changes_requested' where id='ab400000-0000-4000-8000-000000000003';
select ok(public.v1_push_notification_entity_allowed(n),'Current Procurement clarification correction remains actionable')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_material_requests set current_action_code='arrangement_in_progress' where id='ab300000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Completed clarification correction is no longer actionable')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
insert into public.v1_material_request_lines(id,request_id,display_order,source_kind,item_description,requested_qty,unit)
values('ab310000-0000-4000-8000-000000000001','ab300000-0000-4000-8000-000000000001',1,'custom','Push quantity fixture',5,'Nos');
insert into public.v1_procurement_arrangements(id,request_id,arrangement_version,status,is_current,started_by_auth_user_id,saved_by_auth_user_id,saved_at)
values('ab320000-0000-4000-8000-000000000001','ab300000-0000-4000-8000-000000000001',1,'approved',true,
 '10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003',now());
insert into public.v1_procurement_arrangement_lines(id,arrangement_id,request_line_id,source_kind,decision,arranged_qty)
values('ab330000-0000-4000-8000-000000000001','ab320000-0000-4000-8000-000000000001','ab310000-0000-4000-8000-000000000001','external_supplier','full',5);
insert into public.v1_material_request_line_approvals(request_line_id,arrangement_line_id,arrangement_id,approved_qty,approved_by_auth_user_id)
values('ab310000-0000-4000-8000-000000000001','ab330000-0000-4000-8000-000000000001','ab320000-0000-4000-8000-000000000001',5,'10000000-0000-4000-8000-000000000004');
update public.v1_material_requests set state='approved',current_action_code='dispatch_required' where id='ab300000-0000-4000-8000-000000000001';
update public.v1_notifications set event_code='arrangement_ready_for_dispatch',entity_type='procurement_arrangement',entity_id='ab320000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000003';
select ok(public.v1_push_notification_entity_allowed(n),'Current approved arrangement with outstanding quantity is eligible')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
select is(public.v1_push_notification_entity_allowed(jsonb_populate_record(n,jsonb_build_object(
 'recipient_auth_user_id',('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid))),i in (3,4),
 'Dispatch attention follows current action permission for role '||public.v1_permission_exact_role(('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid))
from public.v1_notifications n cross join generate_series(1,4) i where n.id='ab400000-0000-4000-8000-000000000003';
update public.v1_procurement_arrangements set is_current=false where id='ab320000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Superseded arrangement cannot describe the current dispatch action')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_procurement_arrangements set is_current=true,status='awaiting_approval' where id='ab320000-0000-4000-8000-000000000001';
update public.v1_material_requests set state='awaiting_approval' where id='ab300000-0000-4000-8000-000000000001';
update public.v1_notifications set event_code='arrangement_review_required',entity_type='procurement_arrangement',entity_id='ab320000-0000-4000-8000-000000000001',project_id='ab100000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000004';
select ok(public.v1_push_notification_entity_allowed(n),'Legacy current arrangement review remains eligible')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
select is(public.v1_push_notification_entity_allowed(jsonb_populate_record(n,jsonb_build_object(
 'recipient_auth_user_id',('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid))),i in (1,4),
 'Legacy review attention follows current action permission for role '||public.v1_permission_exact_role(('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid))
from public.v1_notifications n cross join generate_series(1,4) i where n.id='ab400000-0000-4000-8000-000000000004';
update public.v1_procurement_arrangements set status='approved' where id='ab320000-0000-4000-8000-000000000001';
update public.v1_material_requests set state='approved' where id='ab300000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Already approved legacy arrangement does not request another review')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
insert into public.v1_material_dispatches(id,request_id,project_id,dispatch_number,dispatch_date,delivery_reference,state,dispatched_by_auth_user_id,dispatched_by_role)
values('ab340000-0000-4000-8000-000000000001','ab300000-0000-4000-8000-000000000001','ab100000-0000-4000-8000-000000000001','PUSH-DSP001',current_date,'PUSH-DN001','receipt_pending','10000000-0000-4000-8000-000000000003','procurement');
insert into public.v1_material_dispatch_lines(id,dispatch_id,request_line_id,arrangement_line_id,source_kind,external_supplier,item_description,unit,approved_qty_snapshot,dispatched_qty)
values('ab350000-0000-4000-8000-000000000001','ab340000-0000-4000-8000-000000000001','ab310000-0000-4000-8000-000000000001','ab330000-0000-4000-8000-000000000001','external_supplier','Push supplier','Push quantity fixture','Nos',5,5);
select ok(not public.v1_push_notification_entity_allowed(n),'Fully in-transit approved quantity suppresses ready-for-dispatch')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_material_dispatch_lines set dispatched_qty=2 where id='ab350000-0000-4000-8000-000000000001';
update public.v1_material_requests set state='partially_dispatched' where id='ab300000-0000-4000-8000-000000000001';
select ok(public.v1_push_notification_entity_allowed(n),'Partial dispatch still permits the approved outstanding quantity alert')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_material_dispatch_lines set dispatched_qty=5 where id='ab350000-0000-4000-8000-000000000001';
update public.v1_notifications set event_code='receipt_review_required',entity_type='material_dispatch',entity_id='ab340000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000004';
select ok(public.v1_push_notification_entity_allowed(n),'Exact unreviewed dispatch is eligible for receipt attention')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
select is(public.v1_push_notification_entity_allowed(jsonb_populate_record(n,jsonb_build_object(
 'recipient_auth_user_id',('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid))),i in (1,2,4),
 'Receipt attention follows current action permission for role '||public.v1_permission_exact_role(('10000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid))
from public.v1_notifications n cross join generate_series(1,4) i where n.id='ab400000-0000-4000-8000-000000000004';
insert into public.v1_receipt_reviews(id,dispatch_id,request_id,reviewed_by_auth_user_id,reviewed_by_role)
values('ab360000-0000-4000-8000-000000000001','ab340000-0000-4000-8000-000000000001','ab300000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','admin');
insert into public.v1_receipt_review_lines(id,receipt_review_id,dispatch_line_id,outcome,dispatched_qty_snapshot,good_qty,exception_qty,damaged_qty,note)
values('ab370000-0000-4000-8000-000000000001','ab360000-0000-4000-8000-000000000001','ab350000-0000-4000-8000-000000000001','damaged',5,3,2,2,'Damaged fixture');
update public.v1_material_dispatches set state='partially_received' where id='ab340000-0000-4000-8000-000000000001';
update public.v1_material_requests set state='partially_received' where id='ab300000-0000-4000-8000-000000000001';
insert into public.v1_material_dispatches(id,request_id,project_id,dispatch_number,dispatch_date,delivery_reference,state,dispatched_by_auth_user_id,dispatched_by_role)
values('ab340000-0000-4000-8000-000000000002','ab300000-0000-4000-8000-000000000001','ab100000-0000-4000-8000-000000000001','PUSH-DSP002',current_date,'PUSH-DN002','receipt_pending','10000000-0000-4000-8000-000000000003','procurement');
select ok(not public.v1_push_notification_entity_allowed(n),'Reviewed exact dispatch does not alert again while another dispatch awaits receipt')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
select ok(public.v1_push_notification_entity_allowed(n),'Damaged quantity retains approved replacement dispatch eligibility')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_receipt_review_lines set outcome='received',good_qty=5,exception_qty=0,damaged_qty=0,note=null where id='ab370000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'All approved quantity received suppresses the old dispatch action')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_material_requests set state='arranging',current_action_code='all_items_unavailable_review' where id='ab300000-0000-4000-8000-000000000001';
update public.v1_procurement_arrangements set status='working' where id='ab320000-0000-4000-8000-000000000001';
update public.v1_notifications set event_code='arrangement_completed_unavailable' where id='ab400000-0000-4000-8000-000000000003';
select ok(public.v1_push_notification_entity_allowed(n),'All-unavailable current arrangement is actionable while Procurement can revise it')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_material_requests set state='closed',current_action_code='material_request_closed' where id='ab300000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Terminal request suppresses the old all-unavailable action')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';

-- Real supplier evidence and append-only payments drive Accounts relevance.
insert into public.v1_documents(id,classification,created_by_auth_user_id,created_by_role)
select ('ab610000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'commercial','10000000-0000-4000-8000-000000000004','admin' from generate_series(1,2) i;
insert into public.v1_document_versions(id,document_id,revision_number,object_path,original_file_name,mime_type,byte_size,sha256,origin,uploaded_by_auth_user_id,uploaded_by_role)
select ('ab620000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,('ab610000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,1,
 'push/evidence-'||i||'.pdf','evidence.pdf','application/pdf',128,repeat('a',64),'uploaded','10000000-0000-4000-8000-000000000004','admin' from generate_series(1,2) i;
update public.v1_documents set current_version_id=replace(id::text,'ab610000','ab620000')::uuid where id::text like 'ab610000%';
insert into public.v1_document_links(id,document_id,project_id,entity_type,entity_id,linked_by_auth_user_id,linked_by_role)
select ('ab621000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,('ab610000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'ab100000-0000-4000-8000-000000000001','project','ab100000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','admin' from generate_series(1,2) i;
insert into public.v1_accounts_supplier_bills(id,project_id,supplier_name_snapshot,supplier_invoice_reference,invoice_date,due_date,
 ex_vat_amount,vat_rate_percent,vat_amount,total_incl_vat,po_lpo_reference,po_lpo_document_id,
 accepted_receipt_review_id,accepted_delivery_reference,supplier_invoice_document_id,created_by_auth_user_id,created_by_role,created_by_exact_role,idempotency_key)
values('ab630000-0000-4000-8000-000000000001','ab100000-0000-4000-8000-000000000001','Push supplier','PUSH-SB001',current_date,current_date,
 100,0,0,100,'PUSH-PO001','ab610000-0000-4000-8000-000000000001','ab360000-0000-4000-8000-000000000001','PUSH-DN001',
 'ab610000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003','procurement','procurement','ab640000-0000-4000-8000-000000000001');
update public.v1_notifications set event_code='accounts_supplier_bill_ready',entity_type='accounts_supplier_bill',entity_id='ab630000-0000-4000-8000-000000000001',project_id='ab100000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000004';
select ok(public.v1_push_notification_entity_allowed(n),'Matched unpaid supplier bill is ready for Accounts attention')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
update public.v1_accounts_supplier_bills set explicit_mismatch_reason='Evidence changed' where id='ab630000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Supplier bill with newly blocked evidence suppresses prior ready alert')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
update public.v1_notifications set event_code='accounts_supplier_evidence_incomplete',entity_type='accounts_supplier_bill',entity_id='ab630000-0000-4000-8000-000000000001'
where id='ab400000-0000-4000-8000-000000000003';
select ok(public.v1_push_notification_entity_allowed(n),'Current unmatched editable supplier bill prompts Procurement evidence work')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_accounts_supplier_bills set explicit_mismatch_reason=null where id='ab630000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Completed supplier evidence suppresses the old incomplete alert')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_accounts_supplier_bills set status='approved',approved_at=now(),
 approved_by_auth_user_id='10000000-0000-4000-8000-000000000004',approved_by_exact_role='admin',explicit_mismatch_reason='Evidence changed after approval'
where id='ab630000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Approved bill does not replay its editable-draft evidence task')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';
update public.v1_accounts_supplier_bills set explicit_mismatch_reason=null where id='ab630000-0000-4000-8000-000000000001';
insert into public.v1_accounts_supplier_payments(project_id,supplier_bill_id,entry_kind,payment_date,payment_method,payment_reference,amount,actor_auth_user_id,actor_role,actor_exact_role,idempotency_key)
values('ab100000-0000-4000-8000-000000000001','ab630000-0000-4000-8000-000000000001','payment',current_date,'bank','PUSH-PAY001',40,
 '10000000-0000-4000-8000-000000000004','admin','admin','ab650000-0000-4000-8000-000000000001');
select ok(public.v1_push_notification_entity_allowed(n),'Partially paid matched bill retains Accounts attention')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
insert into public.v1_accounts_supplier_payments(project_id,supplier_bill_id,entry_kind,payment_date,payment_method,payment_reference,amount,actor_auth_user_id,actor_role,actor_exact_role,idempotency_key)
values('ab100000-0000-4000-8000-000000000001','ab630000-0000-4000-8000-000000000001','payment',current_date,'bank','PUSH-PAY002',60,
 '10000000-0000-4000-8000-000000000004','admin','admin','ab650000-0000-4000-8000-000000000002');
select ok(not public.v1_push_notification_entity_allowed(n),'Fully paid bill suppresses its queued ready notification')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000004';
update public.v1_accounts_supplier_bills set status='cancelled',cancelled_at=now(),cancelled_by_auth_user_id='10000000-0000-4000-8000-000000000004',cancellation_reason='Push fixture cancellation'
where id='ab630000-0000-4000-8000-000000000001';
select ok(not public.v1_push_notification_entity_allowed(n),'Cancelled supplier bill suppresses Procurement evidence attention')
from public.v1_notifications n where id='ab400000-0000-4000-8000-000000000003';

select * from finish();
rollback;
