import tempfile
import unittest
from pathlib import Path

from notification_producer_inventory import inventory, validate_coverage


def producer(name="emit", code="current_event", parameters="p_id uuid"):
    return f"""create or replace function public.{name}({parameters})
returns void language plpgsql as $$ begin
insert into public.v1_notifications(recipient_auth_user_id,event_code,entity_type)
values(p_id,'{code}','example'); end; $$;"""


class NotificationProducerInventoryTest(unittest.TestCase):
    def inspect(self, *sources):
        with tempfile.TemporaryDirectory() as directory:
            paths = []
            for index, source in enumerate(sources):
                path = Path(directory) / f"{index:03}.sql"
                path.write_text(source)
                paths.append(path)
            return inventory(paths)

    def test_replacement_excludes_superseded_producer_and_one_time_backfill(self):
        result = self.inspect(
            producer(code="superseded_event"),
            producer(code="current_event") + """
insert into public.v1_notifications(event_code) values('historical_backfill');
""",
        )
        self.assertEqual(set(result), {"current_event"})

    def test_renamed_retained_implementation_and_overloads_remain_active(self):
        result = self.inspect(
            producer(code="retained_base_event") + producer(code="overload_event", parameters="p_id text"),
            "alter function public.emit(uuid) rename to emit_base;" + producer(code="wrapper_event"),
        )
        self.assertEqual(set(result), {"retained_base_event", "overload_event", "wrapper_event"})

    def test_drop_excludes_only_the_dropped_signature(self):
        result = self.inspect(
            producer(code="dropped_event") + producer(code="active_overload", parameters="p_id text"),
            "drop function if exists public.emit(uuid);",
        )
        self.assertEqual(set(result), {"active_overload"})

    def test_event_column_and_case_results_exclude_audit_inputs(self):
        result = self.inspect("""create function public.emit() returns void language plpgsql as $$
begin insert into public.v1_notifications(id, recipient_auth_user_id, event_code, entity_type)
select gen_random_uuid(),auth.uid(),case audit_code when 'old_audit_event'
then 'notification_one' else 'notification_two' end,'example' from public.example;
end; $$;""")
        self.assertEqual(set(result), {"notification_one", "notification_two"})

    def test_case_variable_and_bounded_dynamic_company_decision(self):
        result = self.inspect("""create function public.emit(p_id uuid) returns void language plpgsql as $$
declare v_event text; v_decision text;
begin
if v_decision not in ('approved','rejected') then raise exception 'invalid'; end if;
v_event:=case when v_decision='approved' then 'decision_approved' else 'decision_rejected' end;
insert into public.v1_notifications(recipient_auth_user_id,event_code)
values(p_id,v_event);
insert into public.v1_notifications(recipient_auth_user_id,event_code)
values(p_id,'company_material_request_' || v_decision);
end; $$;""")
        self.assertEqual(set(result), {
            "decision_approved", "decision_rejected",
            "company_material_request_approved", "company_material_request_rejected",
        })

    def test_recipient_expansion_does_not_introduce_an_event_code(self):
        result = self.inspect("""create function public.expand() returns trigger language plpgsql as $$
begin insert into public.v1_notifications(recipient_auth_user_id,event_code)
select auth.uid(),new.event_code; return new; end; $$;""")
        self.assertEqual(result, {})

    def test_unsupported_dynamic_producer_is_an_explicit_failure(self):
        with self.assertRaisesRegex(ValueError, "Unresolved notification event variable"):
            self.inspect("""create function public.emit() returns void language plpgsql as $$
begin insert into public.v1_notifications(recipient_auth_user_id,event_code)
values(auth.uid(),runtime_code); end; $$;""")

    def test_commented_out_function_cannot_create_a_coverage_requirement(self):
        result = self.inspect(
            "/* " + producer(code="commented_event") + " */\n"
            + producer(code="live_event")
        )
        self.assertEqual(set(result), {"live_event"})

    def test_new_literal_producer_requires_catalogue_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            migrations = root / "supabase/migrations"
            migrations.mkdir(parents=True)
            (migrations / "001.sql").write_text(producer(code="uncatalogued_event"))
            with self.assertRaisesRegex(SystemExit, "uncatalogued_event"):
                validate_coverage(root, {"other_reviewed_event": {}})


if __name__ == "__main__":
    unittest.main()
