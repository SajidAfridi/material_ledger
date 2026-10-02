-- Forward-only follow-up to the paused staging notification candidate.
-- Keep authoritative inbox rows, device registrations, outbox outcomes and
-- historical migration bodies. Only current attention eligibility and
-- installation-specific localized presentation change. Rollback: pause
-- transport; retain additive language data and forward-correct these helpers.
-- Exact roster destinations come only from protected digest metadata.
create or replace function public.v1_notification_module_route(n public.v1_notifications)
returns text language plpgsql stable security definer set search_path='' as $$
declare v_invoice uuid; v_path text; v_team uuid; v_date date;
begin
 if n.entity_type='workforce_monthly_period' then
   return '/yorks/workforce/timesheets?period_id='||n.entity_id::text;
 elsif n.entity_type='workforce_daily_roster'
   and n.event_code='workforce_daily_attendance_missing' then
   select d.team_id,d.work_date into v_team,v_date
     from public.v1_workforce_notification_digests d
     where d.notification_id=n.id and d.digest_kind='daily_attendance_missing'
       and d.recipient_auth_user_id=n.recipient_auth_user_id
       and d.team_id=n.entity_id;
   if v_team is not null and v_date is not null then
     return '/yorks/workforce/attendance?team_id='||v_team::text
       ||'&date='||to_char(v_date,'YYYY-MM-DD');
   end if;
 elsif n.event_code like 'accounts_%' and n.project_id is not null then
   v_path:='/yorks/projects/'||n.project_id::text||'/accounts/';
   if n.entity_type='accounts_client_pdc' then
     select invoice_id into v_invoice from public.v1_accounts_client_pdcs where id=n.entity_id and project_id=n.project_id;
     if v_invoice is not null then
       return v_path||'receipts-pdc?invoice_id='||v_invoice::text||'&pdc_id='||n.entity_id::text;
     end if;
   elsif n.entity_type='accounts_client_certification' then
     select invoice_id into v_invoice from public.v1_accounts_client_certifications where id=n.entity_id and project_id=n.project_id;
     if v_invoice is not null then return v_path||'client-invoices?invoice_id='||v_invoice::text; end if;
   elsif n.entity_type='accounts_client_invoice' then
     return v_path||'client-invoices?invoice_id='||n.entity_id::text;
   elsif n.entity_type='accounts_client_claim' then
     return v_path||'client-invoices?claim_id='||n.entity_id::text;
   elsif n.entity_type='accounts_supplier_bill' then
     return v_path||'supplier-bills?bill_id='||n.entity_id::text;
   end if;
 end if;
 return null;
end; $$;
revoke all on function public.v1_notification_module_route(public.v1_notifications) from public,anon,authenticated;


create or replace function public.v1_notification_page(
  p_limit integer default 100, p_before_created_at timestamptz default null,
  p_before_id uuid default null, p_unread_only boolean default false,
  p_urgent_only boolean default false, p_search text default null
) returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  v_actor uuid := auth.uid(); v_rows jsonb; v_chat jsonb; v_unread bigint;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_NOTIFICATION_LIST_DENIED' using errcode = '42501';
  end if;
  if (p_before_created_at is null) <> (p_before_id is null) then
    raise exception 'V1_NOTIFICATION_CURSOR_INVALID' using errcode = '22023';
  end if;
  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_rows from (
    select n.id notification_id, n.event_code, n.entity_type, n.entity_id,
      public.v1_resolve_notification_request_id(n.entity_type,n.entity_id) request_id,
      n.project_id,
      public.v1_resolve_notification_chat_conversation_id(n.entity_type,n.entity_id) chat_conversation_id,
      n.created_at, n.seen_at, public.v1_notification_module_route(n) module_route,
      case when public.v1_permission_actor_can_view_project(n.project_id) then
        (select concat_ws(' · ', p.project_ref, r.request_number)
          from public.v1_projects p left join public.v1_material_requests r
            on r.id=public.v1_resolve_notification_request_id(n.entity_type,n.entity_id)
          where p.id=n.project_id) else null end record_label
    from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor
      and not public.v1_notification_is_chat_transport(n.event_code,n.entity_type)
      and (p_search is null or btrim(p_search)='' or (
        replace(n.event_code,'_',' ') ilike '%'||left(btrim(p_search),120)||'%'
        or (public.v1_permission_actor_can_view_project(n.project_id) and exists(
          select 1 from public.v1_projects p left join public.v1_material_requests r
            on r.id=public.v1_resolve_notification_request_id(n.entity_type,n.entity_id)
          where p.id=n.project_id and concat_ws(' ',p.project_ref,r.request_number)
            ilike '%'||left(btrim(p_search),120)||'%'))))
      and (not p_unread_only or n.seen_at is null)
      and (not p_urgent_only or n.event_code in ('accounts_invoice_overdue','accounts_pdc_overdue'))
      and (p_before_created_at is null or (n.created_at,n.id) < (p_before_created_at,p_before_id))
    order by n.created_at desc,n.id desc
    limit greatest(1,least(coalesce(p_limit,100),200)) + 1
  ) r;
  -- Chat stays out of history and its unread total. This recipient-only feed
  -- gives foreground attention the same durable source as background push.
  -- Include fresh workflow events too so inbox filters never hide attention.
  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb) into v_chat from (
    select n.id notification_id,n.event_code,n.entity_type,n.entity_id,
      public.v1_resolve_notification_request_id(n.entity_type,n.entity_id) request_id,n.project_id,
      public.v1_resolve_notification_chat_conversation_id(n.entity_type,n.entity_id) chat_conversation_id,
      n.created_at,n.seen_at, public.v1_notification_module_route(n) module_route
    from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor and n.seen_at is null
      and n.created_at > now() - interval '5 minutes'
      and public.v1_push_notification_entity_allowed(n)
    order by n.created_at desc,n.id desc limit 100
  ) r;
  select count(*) into v_unread from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor and n.seen_at is null
      and not public.v1_notification_is_chat_transport(n.event_code,n.entity_type);
  return jsonb_build_object('records',v_rows,'attention',v_chat,'unreadCount',v_unread, 'servicePaused', (select operator_paused or circuit_open_until is not null from public.v1_push_transport_control where id));
end; $$;
revoke all on function public.v1_notification_page(integer,timestamptz,uuid,boolean,boolean,text) from public,anon;
grant execute on function public.v1_notification_page(integer,timestamptz,uuid,boolean,boolean,text) to authenticated;

-- Re-check the recipient's current entity access and unresolved action state.
-- Private helper: never accepts an actor supplied through a public RPC.
create or replace function public.v1_push_notification_entity_allowed(n public.v1_notifications)
returns boolean language plpgsql stable security definer set search_path='' as $$
declare v_actor uuid:=n.recipient_auth_user_id; v_project uuid:=n.project_id;
 v_request uuid; v_state text; v_action text; v_capability text; v_conversation uuid;
begin
 if public.v1_permission_exact_role(v_actor)='' then return false; end if;
 if public.v1_notification_is_chat_transport(n.event_code,n.entity_type) then
   v_conversation:=public.v1_resolve_notification_chat_conversation_id(n.entity_type,n.entity_id);
   if not exists(select 1 from public.v1_chat_members m where m.conversation_id=v_conversation
     and m.auth_user_id=v_actor and m.left_at is null and not m.is_muted
     and (m.last_read_at is null or m.last_read_at<n.created_at)) then return false; end if;
   if exists(select 1 from public.v1_workforce_timesheet_discussions d where d.conversation_id=v_conversation) then
     return exists(select 1 from public.v1_workforce_timesheet_discussions d where d.conversation_id=v_conversation
       and public.v1_workforce_t08_period_actor_authorized(v_actor,'workforce.view',d.period_id,false));
   end if;
   return exists(select 1 from public.v1_chat_members m join public.v1_chat_conversations c on c.id=m.conversation_id
     where m.conversation_id=v_conversation and m.auth_user_id=v_actor and m.left_at is null
       and (m.last_read_at is null or m.last_read_at<n.created_at)
       and (c.material_request_id is null or public.v1_material_request_participant(c.material_request_id,v_actor))
       and (c.project_id is null or coalesce((public.v1_permission_authoritative_resolution(v_actor,
         case when c.material_request_id is not null then 'material_requests.view' else 'projects.view' end,
         c.project_id)->>'effective')::boolean,false)));
 elsif n.entity_type in ('project','project_member') then
   if n.event_code='project_member_revoked' then
     return exists(select 1 from public.v1_project_members m where m.id=n.entity_id and m.member_auth_user_id=v_actor);
   end if;
   return coalesce((public.v1_permission_authoritative_resolution(v_actor,'projects.view',v_project)->>'effective')::boolean,false);
 elsif n.entity_type='company_material_request' then
   return exists(select 1 from public.v1_company_material_requests r where r.id=n.entity_id and (
     r.created_by_auth_user_id=v_actor or
     (r.submitted_at is not null and (public.v1_permission_exact_role(v_actor)='admin'
       or v_actor in (r.beneficiary_auth_user_id,r.authorized_receiver_auth_user_id,r.approver_auth_user_id)))
     or (public.v1_permission_exact_role(v_actor)='procurement' and
       (r.state in ('approved_for_procurement','arranging','ready_for_delivery','partially_dispatched',
         'receipt_pending','partially_received','awaiting_beneficiary_handover','fulfilled','closed')
       or exists(select 1 from public.v1_company_material_request_decisions d where d.request_id=r.id and d.decision='approved'))))
     and (n.event_code<>'company_material_request_approval_requested' or r.state='awaiting_company_approval')
     and (n.event_code<>'company_material_request_dispatched' or r.state in ('partially_dispatched','receipt_pending','partially_received')));
 elsif n.entity_type='workforce_monthly_period' then
   if not public.v1_workforce_t08_period_actor_authorized(v_actor,'workforce.view',n.entity_id,false) then return false; end if;
   select current_status into v_state from public.v1_workforce_monthly_periods where id=n.entity_id;
   return case n.event_code when 'workforce_period_submitted' then v_state in ('submitted','under_review')
     when 'workforce_final_approval_required' then v_state='awaiting_final_approval'
     when 'workforce_period_returned' then v_state='returned_for_correction'
     when 'workforce_monthly_period_incomplete' then
       v_state in ('draft','ready_for_review','returned_for_correction','reopened')
       and exists(select 1 from public.v1_workforce_monthly_periods p
         join public.v1_workforce_monthly_validation_runs r on r.id=p.current_validation_run_id
         where p.id=n.entity_id and r.blocking_issue_count+r.warning_issue_count>0)
     else true end;
 elsif n.entity_type='workforce_daily_roster' then
   return exists(select 1 from public.v1_workforce_notification_digests d
     cross join public.v1_workforce_workers w
     cross join lateral public.v1_workforce_effective_assignment(w.id,d.work_date) a
     where d.notification_id=n.id and a->>'team_id'=d.team_id::text
       -- A digest records the count at creation, not a permanent missing fact.
       -- Re-check the underlying attendance before foreground or device send.
       and not exists(select 1 from public.v1_workforce_attendance_days day
         where day.worker_id=w.id and day.work_date=d.work_date
           and day.attendance_status<>'not_entered')
       and ((w.current_status='active' and w.joining_date<=d.work_date
         and (w.leaving_date is null or w.leaving_date>=d.work_date))
         or exists(select 1 from public.v1_workforce_attendance_days day
           where day.worker_id=w.id and day.work_date=d.work_date))
       and public.v1_workforce_t08_actor_has_capability(v_actor,'workforce.attendance.maintain',nullif(a->>'project_id','')::uuid)
       and public.v1_workforce_matching_responsibility(v_actor,w.id,d.work_date,
         nullif(a->>'team_id','')::uuid,nullif(a->>'project_id','')::uuid,
         nullif(a->>'project_scope_id','')::uuid,nullif(a->>'internal_location_id','')::uuid)<>'{}'::jsonb);
 elsif n.event_code like 'accounts_%' then
   v_capability:=case when n.event_code like 'accounts_pdc_%' then 'manage_pdc'
     when n.event_code='accounts_supplier_evidence_incomplete' then 'manage_supplier_bills'
     when n.event_code='accounts_supplier_bill_ready' then 'approve_supplier_bill_payment'
     when n.event_code like 'accounts_invoice_%' or n.event_code='accounts_claim_ready' then 'manage_client_invoices'
     else 'view_project_accounts' end;
   if not public.v1_accounts_notification_recipient_allowed(v_actor,v_capability,v_project) then return false; end if;
   if n.entity_type='accounts_client_invoice' then
     return exists(select 1 from public.v1_accounts_client_invoices i where i.id=n.entity_id
       and (n.event_code not in ('accounts_invoice_due_soon','accounts_invoice_overdue')
         or i.status not in ('draft','returned','cancelled','paid')));
   elsif n.entity_type='accounts_client_pdc' then
     return exists(select 1 from public.v1_accounts_client_pdcs p where p.id=n.entity_id and p.status in ('expected','received','deposited'));
   elsif n.entity_type='accounts_client_claim' then
     return exists(select 1 from public.v1_accounts_client_claims c where c.id=n.entity_id);
   elsif n.entity_type='accounts_client_certification' then
     return exists(select 1 from public.v1_accounts_client_certifications c where c.id=n.entity_id);
   elsif n.entity_type='accounts_supplier_bill' then
     return exists(select 1 from public.v1_accounts_supplier_bills b where b.id=n.entity_id and b.project_id=v_project
       and b.status<>'cancelled'
       and (n.event_code<>'accounts_supplier_evidence_incomplete' or
         (b.status='draft' and public.v1_accounts_supplier_match_status(b.id)<>'matched'))
       and (n.event_code<>'accounts_supplier_bill_ready' or
         (public.v1_accounts_supplier_match_status(b.id)='matched'
          and public.v1_accounts_supplier_paid_amount(b.id)<b.total_incl_vat)));
   end if;
   return false;
 elsif n.entity_type='material_return' then
   select project_id,state into v_project,v_state from public.v1_material_returns where id=n.entity_id;
   if not found then return false; end if;
   if n.event_code='material_return_approval_required' and v_state not in ('submitted','awaiting_approval') then return false; end if;
   if n.event_code='material_return_receipt_required' and v_state<>'dispatched' then return false; end if;
   v_capability:='returns.view';
 else
   v_request:=public.v1_resolve_notification_request_id(n.entity_type,n.entity_id);
   select project_id,state,current_action_code into v_project,v_state,v_action from public.v1_material_requests where id=v_request;
   if not found then return false; end if;
   if n.event_code in ('material_request_approval_required','material_request_updated_for_approval')
     and v_state<>'awaiting_request_approval' then return false; end if;
   if n.event_code='material_request_changes_requested' and not (
     v_state='changes_requested' or
     (v_state='arranging' and v_action='procurement_clarification_changes_required')) then return false; end if;
   if n.event_code in ('material_request_approval_requested','arrangement_review_required')
     and v_state<>'awaiting_approval' then return false; end if;
   if n.event_code='material_request_approved_for_arrangement' and
     (v_state not in ('approved_for_arrangement','arranging')
       or v_action='procurement_clarification_changes_required') then return false; end if;
   if n.event_code in ('arrangement_review_required','arrangement_ready_for_dispatch',
     'arrangement_approved','arrangement_returned','arrangement_completed_unavailable') then
     -- Only the current saved version can still require action. A superseded
     -- arrangement's queued notification never describes the replacement.
     if not exists(select 1 from public.v1_procurement_arrangements a where a.id=n.entity_id
       and a.request_id=v_request and a.is_current and a.status=case
         when n.event_code='arrangement_review_required' then 'awaiting_approval'
         when n.event_code='arrangement_returned' then 'returned'
         when n.event_code='arrangement_completed_unavailable' then 'working' else 'approved' end)
       then return false; end if;
     if n.event_code='arrangement_returned' and v_state<>'arranging' then return false; end if;
     if n.event_code='arrangement_completed_unavailable' and
       (v_state<>'arranging' or v_action<>'all_items_unavailable_review') then return false; end if;
   end if;
   if n.event_code in ('arrangement_ready_for_dispatch','arrangement_approved') then
     if v_state not in ('approved','partially_dispatched','partially_received') then return false; end if;
     -- Match the trusted dispatch cap: good receipt plus unreviewed dispatch
     -- already consumes approved quantity, while Missing/Damaged remains eligible.
     if not exists(select 1 from public.v1_material_request_line_approvals a
       join public.v1_material_request_lines l on l.id=a.request_line_id
       where l.request_id=v_request and a.arrangement_id=n.entity_id
         and a.approved_qty>
           coalesce((select sum(rl.good_qty) from public.v1_receipt_review_lines rl
             join public.v1_receipt_reviews r on r.id=rl.receipt_review_id
             join public.v1_material_dispatch_lines dl on dl.id=rl.dispatch_line_id
             where r.state='confirmed' and dl.request_line_id=l.id),0)
           +coalesce((select sum(dl.dispatched_qty) from public.v1_material_dispatch_lines dl
             join public.v1_material_dispatches d on d.id=dl.dispatch_id
             where d.state='receipt_pending' and dl.request_line_id=l.id),0)) then return false; end if;
   end if;
   if n.event_code='receipt_review_required' and not exists(
     select 1 from public.v1_material_dispatches d where d.id=n.entity_id
       and d.request_id=v_request and d.state='receipt_pending'
       and not exists(select 1 from public.v1_receipt_reviews r where r.dispatch_id=d.id)) then return false; end if;
   v_capability:=case
     when n.event_code in ('material_request_approval_required','material_request_updated_for_approval',
       'material_request_approval_requested','arrangement_review_required') then 'material_requests.approve'
     when n.event_code in ('arrangement_ready_for_dispatch','arrangement_approved') then 'dispatch.create'
     when n.event_code='receipt_review_required' then 'receipts.confirm'
     when n.event_code in ('material_request_approved_for_arrangement','arrangement_returned',
       'arrangement_completed_unavailable') then 'procurement.arrange'
     when n.event_code='material_request_changes_requested' then case
       when v_action='procurement_clarification_changes_required' then 'procurement.arrange'
       else 'material_requests.edit' end
     else null end;
   if v_capability is not null and not coalesce((public.v1_permission_authoritative_resolution(
     v_actor,v_capability,v_project)->>'effective')::boolean,false) then return false; end if;
   return public.v1_material_request_participant(v_request,v_actor);
 end if;
 return coalesce((public.v1_permission_authoritative_resolution(v_actor,v_capability,v_project)->>'effective')::boolean,false);
end; $$;
revoke all on function public.v1_push_notification_entity_allowed(public.v1_notifications) from public,anon,authenticated;

-- Resolve only stable identifiers; protected record RPCs still authorize and
-- load the destination. No amount, name, or commercial value enters a URL.
-- Language is installation-specific; no account preference or transport
-- eligibility is broadened. Existing clients retain the English fallback.
alter table public.v1_push_device_tokens
  add column if not exists notification_language text not null default 'en'
  check (notification_language in ('en','ar','ur','hi'));
create or replace function public.v1_set_my_push_installation_language(
  p_installation_id uuid, p_language text
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_actor uuid:=auth.uid();
  v_session uuid:=nullif(auth.jwt()->>'session_id','')::uuid;
begin
  if v_actor is null or not public.v1_current_actor_is_active() then
    raise exception 'V1_PUSH_DEVICE_REGISTER_DENIED' using errcode='42501';
  end if;
  if p_language is null or p_language not in ('en','ar','ur','hi') then
    raise exception 'V1_PUSH_LANGUAGE_INVALID' using errcode='22023';
  end if;
  update public.v1_push_device_tokens t set notification_language=p_language
    where t.auth_user_id=v_actor and t.installation_id=p_installation_id
      and t.platform='web' and t.retired_at is null
      and t.auth_session_id=v_session
      and exists(select 1 from auth.sessions a where a.id=v_session
        and a.user_id=v_actor and (a.not_after is null or a.not_after>clock_timestamp()));
  return found;
end;
$$;
revoke all on function public.v1_set_my_push_installation_language(uuid,text)
  from public,anon;
grant execute on function public.v1_set_my_push_installation_language(uuid,text)
  to authenticated;
