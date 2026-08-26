-- Configuration Centre helper ACL hardening.
--
-- Supabase's function default privileges granted the API roles direct execute
-- privileges when the original helpers were created. Revoking only PUBLIC did
-- not remove those role-specific grants. This migration changes no data and no
-- configuration behavior; it only restores the intended trusted-RPC boundary.
--
-- Rollback is forward-only. If a future trusted server integration genuinely
-- needs one of these helpers, expose a narrow security-definer command instead
-- of granting a browser-facing role direct helper execution.

revoke all on function public.v1_assert_configuration_admin()
  from public, anon, authenticated;
revoke all on function public.v1_configuration_effective_value(text)
  from public, anon, authenticated;
revoke all on function
  public.v1_validate_configuration_setting_value(text, jsonb)
  from public, anon, authenticated;

grant execute on function public.v1_assert_configuration_admin()
  to service_role;
grant execute on function public.v1_configuration_effective_value(text)
  to service_role;
grant execute on function
  public.v1_validate_configuration_setting_value(text, jsonb)
  to service_role;
