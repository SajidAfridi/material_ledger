-- Presentation classification only; no historical audit events are rewritten.
insert into public.v1_audit_event_catalogue(event_type, severity) values
  ('material_request_post_approval_edit_grant_changed', 'normal'),
  ('material_request_post_approval_amendment_submitted', 'normal')
on conflict (event_type) do nothing;
