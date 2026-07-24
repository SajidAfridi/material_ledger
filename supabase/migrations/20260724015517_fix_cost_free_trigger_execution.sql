-- Trigger code must be able to call the non-public sanitizer while ordinary
-- authenticated users remain unable to execute the helper directly.
alter function public.app_enforce_cost_free_payload() security definer;
alter function public.app_enforce_cost_free_payload() set search_path = '';

revoke all on function public.app_enforce_cost_free_payload()
  from public, anon, authenticated;
revoke all on function public.app_strip_commercial_jsonb(jsonb)
  from public, anon, authenticated;
