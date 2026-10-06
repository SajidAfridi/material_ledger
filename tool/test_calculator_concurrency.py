#!/usr/bin/env python3
"""Exercise two real calculator writers against the seeded local database only."""
import concurrent.futures
import json
import subprocess
import threading
import uuid

CONTAINER = 'supabase_db_material_ledger'
ACTOR = '10000000-0000-4000-8000-000000000004'
CLAIMS = json.dumps({'sub': ACTOR, 'role': 'authenticated', 'app_metadata': {'role': 'admin'}})


def sql_literal(value):
    return "'" + value.replace("'", "''") + "'"


def execute(sql):
    return subprocess.run(
        ['docker', 'exec', '-i', CONTAINER, 'psql', '-U', 'postgres', '-d', 'postgres',
         '-X', '-t', '-A', '-v', 'ON_ERROR_STOP=1'],
        input=sql, text=True, capture_output=True, check=False,
    )


def command(payload, key, *, delay=False):
    return (
        'begin; set local role authenticated; '
        f"select set_config('request.jwt.claims',{sql_literal(CLAIMS)},true); "
        f'select public.v1_save_calculator({sql_literal(json.dumps(payload))}::jsonb,'
        f'{sql_literal(key)}::uuid); '
        + ('select pg_sleep(0.25); ' if delay else '') + 'commit;'
    )


def main():
    record_id = str(uuid.uuid4())
    payload = {'id': record_id, 'title': 'LOCAL calculator concurrency proof',
               'kind': 'duct', 'expected_version': 0,
               'payload': {'app': 'duct-calc', 'version': 1, 'flow': '1000'}}
    created = execute(command(payload, str(uuid.uuid4())))
    assert created.returncode == 0, created.stderr
    barrier = threading.Barrier(2)
    intents = [({**payload, 'expected_version': 1,
                 'payload': {**payload['payload'], 'flow': value}}, str(uuid.uuid4()))
               for value in ('1500', '1600')]

    def writer(index):
        barrier.wait()
        return execute(command(*intents[index], delay=True))

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(writer, range(2)))
    winners = [i for i, result in enumerate(results) if result.returncode == 0]
    assert len(winners) == 1, [r.stderr for r in results]
    assert 'CALCULATOR_VERSION_CONFLICT' in results[1 - winners[0]].stderr
    replay = execute(command(*intents[winners[0]]))
    assert replay.returncode == 0, replay.stderr
    verify = execute(
        f"select record_version from public.v1_calculators where id='{record_id}'; "
        f"select count(*) from public.v1_audit_events where entity_type='calculator' "
        f"and entity_id='{record_id}' and event_type='calculator_saved';"
    )
    assert verify.returncode == 0 and verify.stdout.splitlines() == ['2', '2'], verify.stdout
    # Keep the fixture and its audit history recoverable, outside the active library.
    archived = execute(
        'begin; set local role authenticated; '
        f"select set_config('request.jwt.claims',{sql_literal(CLAIMS)},true); "
        f"select public.v1_manage_calculator('{{\"id\":\"{record_id}\","
        f"\"expected_version\":2,\"action\":\"archive\",\"archived\":true}}'::jsonb,"
        f"'{uuid.uuid4()}'::uuid); commit;"
    )
    assert archived.returncode == 0, archived.stderr
    print('PASS: one competing writer commits; stale writer conflicts; retry is idempotent; audit preserved.')


if __name__ == '__main__':
    main()
