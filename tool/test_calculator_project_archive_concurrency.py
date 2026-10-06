#!/usr/bin/env python3
"""Local-only archive/save race proof. Run `supabase db reset` afterwards.

Uses disposable committed fixtures because independent transactions must see
them. Never accepts a remote URL or credentials.
"""
import json
import subprocess
import time
import uuid

CONTAINER = 'supabase_db_material_ledger'
ADMIN = '10000000-0000-4000-8000-000000000004'
ENGINEER = '10000000-0000-4000-8000-000000000001'
PSQL = ['docker', 'exec', '-i', CONTAINER, 'psql', '-X', '-U', 'postgres',
        '-d', 'postgres', '-At', '-v', 'ON_ERROR_STOP=1']


def sql(query, *, succeeds=True):
    result = subprocess.run(PSQL, input=query, text=True, capture_output=True,
                            timeout=15)
    if succeeds:
        assert result.returncode == 0, result.stderr
    return result


def literal(value):
    return "'" + json.dumps(value).replace("'", "''") + "'::jsonb"


def actor(user, role):
    return "set local role authenticated; select set_config('request.jwt.claims'," + literal(
        {'sub': user, 'role': 'authenticated', 'app_metadata': {'role': role}}
    ) + "::text,true);"


def fixture():
    ref = 'CALC-RACE-' + uuid.uuid4().hex[:12].upper()
    project_payload = {'project_ref': ref, 'name': ref,
                       'buildings': [{'code': 'A', 'name': 'A'}],
                       'initial_members': [], 'attachments': []}
    sql('begin;' + actor(ENGINEER, 'project_engineer') +
        f"select public.v1_create_project({literal(project_payload)},'{uuid.uuid4()}');commit;")
    project = sql(f"select id from public.v1_projects where project_ref='{ref}';").stdout.strip()
    uuid.UUID(project)
    payload = {'id': str(uuid.uuid4()), 'project_id': project, 'title': ref,
               'kind': 'duct', 'expected_version': 0,
               'payload': {'app': 'duct-calc', 'version': 1, 'flow': '1000'}}
    sql('begin;' + actor(ADMIN, 'admin') +
        f"select public.v1_save_calculator({literal(payload)},'{uuid.uuid4()}');commit;")
    payload['expected_version'] = 1
    payload['title'] += ' revised'
    save = f"select public.v1_save_calculator({literal(payload)},'{uuid.uuid4()}');"
    archive = "select public.v1_archive_project(" + literal(
        {'project_id': project, 'expected_version': 1, 'reason': 'Local race fixture'}
    ) + f",'{uuid.uuid4()}');"
    return project, payload, save, archive


def session(query, name, *, marker=False):
    process = subprocess.Popen(PSQL, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, text=True)
    process.stdin.write(f"set application_name='{name}';begin;" + actor(ADMIN, 'admin') +
                        query + ('\n\\echo LOCK_HELD\n' if marker else '\n'))
    process.stdin.flush()
    if marker:
        while True:
            line = process.stdout.readline()
            assert line, process.stderr.read()
            if line.strip() == 'LOCK_HELD':
                break
    return process


def blocked(name):
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        if sql("select exists(select 1 from pg_stat_activity where application_name=" +
               f"'{name}' and cardinality(pg_blocking_pids(pid))>0);").stdout.strip() == 't':
            return
        time.sleep(0.05)
    raise AssertionError(f'{name} was not blocked by the competing project lock')


def finish(process, *, succeeds):
    output, error = process.communicate('commit;\n', timeout=10)
    if succeeds:
        assert process.returncode == 0, error
    else:
        assert process.returncode != 0 and 'CALCULATOR_PROJECT_ARCHIVED' in error, error


def main():
    info = json.loads(subprocess.check_output(['docker', 'inspect', CONTAINER], text=True))[0]
    context = json.loads(subprocess.check_output(['docker', 'context', 'inspect'], text=True))[0]
    assert context['Endpoints']['docker']['Host'].startswith('unix://'), 'Local Docker required'
    assert 'supabase/postgres' in info['Config']['Image'], 'Supabase local database required'
    held = []
    try:
        for archive_first in (True, False):
            project, payload, save, archive = fixture()
            first = session(archive if archive_first else save, 'calc_race_first', marker=True)
            held.append(first)
            second = session(save if archive_first else archive, 'calc_race_second')
            held.append(second)
            blocked('calc_race_second')
            finish(first, succeeds=True)
            finish(second, succeeds=not archive_first)
            expected = 1 if archive_first else 2
            assert sql(f"select record_version from public.v1_calculators where id='{payload['id']}';").stdout.strip() == str(expected)
            assert sql(f"select state from public.v1_projects where id='{project}';").stdout.strip() == 'archived'
            payload['expected_version'] = expected
            rejected = sql('begin;' + actor(ADMIN, 'admin') +
                           f"select public.v1_save_calculator({literal(payload)},'{uuid.uuid4()}');commit;",
                           succeeds=False)
            assert rejected.returncode != 0 and 'CALCULATOR_PROJECT_ARCHIVED' in rejected.stderr
        print('PASS: archive-first blocks save; save-first serializes archive; later saves are rejected.')
        print('Disposable local fixtures remain. Run supabase db reset before the full database gate.')
    finally:
        for process in held:
            if process.poll() is None:
                process.kill()
                process.wait()


if __name__ == '__main__':
    main()
