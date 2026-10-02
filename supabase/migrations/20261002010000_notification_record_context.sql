-- Additive reference context for existing recipient-owned notification history.
-- Preserve inbox/outbox rows and applied migration bodies. Read permission is
-- independent from whether an old action still needs attention. Rollback by
-- forward-correcting these private read projections; no business data changes.
create or replace function public.v1_notification_record_label(n public.v1_notifications)
returns text language plpgsql stable security definer set search_path='' as $$
declare
  v_actor uuid := auth.uid(); v_request uuid; v_project uuid; v_label text;
begin
  if v_actor is null or n.recipient_auth_user_id is distinct from v_actor
    or not public.v1_current_actor_is_active() then return null; end if;

  if n.entity_type='company_material_request' then
    if not public.v1_company_material_request_readable(n.entity_id) then return null; end if;
    select r.request_number into v_label from public.v1_company_material_requests r
      where r.id=n.entity_id;

  elsif n.entity_type='material_return' then
    if not public.v1_material_return_readable(n.entity_id) then return null; end if;
    select concat_ws(U&' \00B7 ',p.project_ref,r.return_number) into v_label
      from public.v1_material_returns r join public.v1_projects p on p.id=r.project_id
      where r.id=n.entity_id and (n.project_id is null or n.project_id=r.project_id);

  elsif n.entity_type like 'accounts_%' then
    v_project := public.v1_accounts_document_target_project_id(n.entity_type,n.entity_id);
    if v_project is null or v_project is distinct from n.project_id
      or not public.v1_current_user_has_capability('view_project_accounts',v_project)
      or not public.v1_accounts_document_target_readable(n.entity_type,n.entity_id)
      then return null; end if;
    -- Accounts has its own read capabilities. Accountant need not have technical
    -- projects.view; only controlled references, never totals/names, are read.
    if n.entity_type='accounts_client_claim' then
      select concat_ws(U&' \00B7 ',p.project_ref,c.claim_reference) into v_label
        from public.v1_accounts_client_claims c join public.v1_projects p on p.id=c.project_id
        where c.id=n.entity_id and c.project_id=v_project;
    elsif n.entity_type='accounts_client_invoice' then
      select concat_ws(U&' \00B7 ',p.project_ref,i.invoice_reference) into v_label
        from public.v1_accounts_client_invoices i join public.v1_projects p on p.id=i.project_id
        where i.id=n.entity_id and i.project_id=v_project;
    elsif n.entity_type='accounts_client_certification' then
      select concat_ws(U&' \00B7 ',p.project_ref,i.invoice_reference,c.certification_reference) into v_label
        from public.v1_accounts_client_certifications c
        join public.v1_accounts_client_invoices i on i.id=c.invoice_id and i.project_id=c.project_id
        join public.v1_projects p on p.id=c.project_id
        where c.id=n.entity_id and c.project_id=v_project;
    elsif n.entity_type='accounts_client_pdc' then
      select concat_ws(U&' \00B7 ',p.project_ref,i.invoice_reference,to_char(d.cheque_date,'YYYY-MM-DD'),right(d.id::text,8)) into v_label
        from public.v1_accounts_client_pdcs d
        join public.v1_accounts_client_invoices i on i.id=d.invoice_id and i.project_id=d.project_id
        join public.v1_projects p on p.id=d.project_id
        where d.id=n.entity_id and d.project_id=v_project;
    elsif n.entity_type='accounts_supplier_bill' then
      select concat_ws(U&' \00B7 ',p.project_ref,b.supplier_invoice_reference) into v_label
        from public.v1_accounts_supplier_bills b join public.v1_projects p on p.id=b.project_id
        where b.id=n.entity_id and b.project_id=v_project;
    end if;

  elsif n.entity_type='workforce_monthly_period' then
    if not public.v1_workforce_t07_period_authorized('workforce.view',n.entity_id,false)
      then return null; end if;
    select concat_ws(U&' \00B7 ',t.team_code,to_char(p.period_month,'YYYY-MM')) into v_label
      from public.v1_workforce_monthly_periods p join public.v1_workforce_teams t on t.id=p.team_id
      where p.id=n.entity_id;

  elsif n.entity_type='workforce_daily_roster' then
    select concat_ws(U&' \00B7 ',t.team_code,to_char(d.work_date,'YYYY-MM-DD')) into v_label
      from public.v1_workforce_notification_digests d
      join public.v1_workforce_teams t on t.id=d.team_id
      where d.notification_id=n.id and d.recipient_auth_user_id=v_actor
        and d.digest_kind='daily_attendance_missing' and d.team_id=n.entity_id
        and (
          -- Reuse the exact roster read-authority check without constructing a
          -- complete worker/calendar/allocation projection. Both candidate
          -- branches use retained team/date indexes and stop at the first
          -- authorized row; no notification scans the organization roster.
          exists (select 1 from public.v1_workforce_attendance_days day
            where day.assignment_team_id_snapshot=d.team_id and day.work_date=d.work_date
              and public.v1_workforce_roster_authority_context('workforce.view',
                day.worker_id,day.work_date,day.assignment_team_id_snapshot,
                day.assignment_project_id_snapshot,day.assignment_project_scope_id_snapshot,
                day.assignment_internal_location_id_snapshot)<>'{}'::jsonb)
          or exists (select 1 from public.v1_workforce_worker_assignments candidate
            join public.v1_workforce_workers w on w.id=candidate.worker_id
            cross join lateral jsonb_to_record(public.v1_workforce_effective_assignment(w.id,d.work_date))
              a(team_id uuid,project_id uuid,project_scope_id uuid,internal_location_id uuid)
            where candidate.team_id=d.team_id and candidate.valid_from<=d.work_date
              and (candidate.valid_to is null or candidate.valid_to>=d.work_date)
              and w.current_status='active' and w.joining_date<=d.work_date
              and (w.leaving_date is null or w.leaving_date>=d.work_date)
              and a.team_id=d.team_id
              and not exists(select 1 from public.v1_workforce_attendance_days day
                where day.worker_id=w.id and day.work_date=d.work_date)
              and public.v1_workforce_roster_authority_context('workforce.view',w.id,
                d.work_date,a.team_id,a.project_id,a.project_scope_id,a.internal_location_id)<>'{}'::jsonb)
        );

  else
    v_request := public.v1_resolve_notification_request_id(n.entity_type,n.entity_id);
    if v_request is not null then
      if not public.v1_material_request_participant(v_request,v_actor) then return null; end if;
      select concat_ws(U&' \00B7 ',
          case when public.v1_permission_actor_can_view_project(r.project_id) then p.project_ref end,
          r.request_number) into v_label
        from public.v1_material_requests r join public.v1_projects p on p.id=r.project_id
        where r.id=v_request and (n.project_id is null or n.project_id=r.project_id);
    elsif n.entity_type in ('project','project_member') then
      if n.entity_type='project' then v_project:=n.entity_id;
      else select m.project_id into v_project from public.v1_project_members m where m.id=n.entity_id;
      end if;
      if not public.v1_permission_actor_can_view_project(v_project) then return null; end if;
      select p.project_ref into v_label from public.v1_projects p where p.id=v_project;
    end if;
  end if;
  -- References can be external protected identifiers. Keep control characters
  -- and unbounded strings out of presentation without reading any other field.
  return nullif(left(btrim(regexp_replace(v_label,'[[:cntrl:]]',' ','g')),180),'');
end; $$;
revoke all on function public.v1_notification_record_label(public.v1_notifications) from public,anon,authenticated;

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
      public.v1_notification_record_label(n) record_label
    from public.v1_notifications n
    where n.recipient_auth_user_id = v_actor
      and not public.v1_notification_is_chat_transport(n.event_code,n.entity_type)
      and (p_search is null or btrim(p_search)='' or (
        replace(n.event_code,'_',' ') ilike '%'||left(btrim(p_search),120)||'%'
        or public.v1_notification_record_label(n) ilike '%'||left(btrim(p_search),120)||'%'))
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
      n.created_at,n.seen_at, public.v1_notification_module_route(n) module_route,
      public.v1_notification_record_label(n) record_label
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
