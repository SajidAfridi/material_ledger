-- Yorks Workforce T03 corrective policy: deny every future attendance write.
--
-- Data preservation:
-- - no attendance, audit, idempotency or configuration row is copied,
--   rewritten, backfilled or deleted;
-- - an existing future row remains readable but cannot be corrected until its
--   retained calendar-local work date arrives.
--
-- Rollback is forward-only. If the policy changes, deploy a later corrective
-- migration; do not drop retained attendance facts or rewrite accepted T03.

create or replace function public.v1_workforce_guard_future_attendance()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_calendar_today date;
begin
  begin
    v_calendar_today := (
      clock_timestamp() at time zone new.calendar_timezone_snapshot
    )::date;
  exception when invalid_parameter_value then
    raise exception 'V1_WORKFORCE_ATTENDANCE_RETAINED_TIMEZONE_INVALID'
      using errcode = '23514';
  end;

  if new.work_date > v_calendar_today then
    raise exception 'V1_WORKFORCE_ATTENDANCE_FUTURE_DATE_FORBIDDEN'
      using errcode = '22023';
  end if;
  return new;
end;
$$;

revoke all on function public.v1_workforce_guard_future_attendance()
  from public, anon, authenticated;

drop trigger if exists v1_workforce_attendance_future_date_guard
  on public.v1_workforce_attendance_days;
create trigger v1_workforce_attendance_future_date_guard
before insert or update on public.v1_workforce_attendance_days
for each row execute function public.v1_workforce_guard_future_attendance();
