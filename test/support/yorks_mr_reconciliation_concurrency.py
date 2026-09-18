"""Local-only two-connection MR reconciliation probe.
Run from the repository root after `supabase db reset --local` and pgTAP.
Requires the exact local Docker database container; has no remote connection path.
Creates one synthetic project/request. Reset the disposable local DB before rerun.
The two nested command keys are counted by outer command, not as duplicates.
"""
import subprocess,json,time
base=['docker','exec','-i','supabase_db_material_ledger','psql','-U','postgres','-d','postgres','-X','-qAt','-v','ON_ERROR_STOP=1']
def sql(s):
 r=subprocess.run(base,input=s,text=True,capture_output=True)
 if r.returncode: raise RuntimeError(r.stderr)
 return r.stdout
s=open('supabase/tests/database/yorks_v1_material_request_submission_reconciliation.test.sql').read()
setup=s[:s.index("select is(public.v1_get_material_request_submission_result(")]
setup=setup.replace('MR-RC-001','MR-CONCURRENT-002').replace('af000000','bf000000').replace('af100000','bf100000').replace('af110000','bf110000')
payload=json.loads(sql(setup+"select payload from v1_af_payload; commit;").strip().splitlines()[-1])
claims=json.dumps({'sub':'10000000-0000-4000-8000-000000000001','role':'authenticated','app_metadata':{'role':'project_engineer','app_user_id':'usr-local-project-engineer'}})
start="begin; set local role authenticated; select set_config('request.jwt.claims','"+claims+"',true);"
args="'"+json.dumps(payload).replace("'","''")+"'::jsonb, 'bf800000-0000-4000-8000-000000000010'::uuid"
call='select public.v1_save_and_submit_material_request('+args+")->>'id';"
p1=subprocess.Popen(base,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
p1.stdin.write(start+call+'select pg_sleep(2);commit;');p1.stdin.close()
time.sleep(.25)
r2=sql(start+call+'commit;')
p1.wait();out=p1.stdout.read();err=p1.stderr.read()
assert p1.returncode==0,err
rid=payload['request_id'];assert rid in out and rid in r2
countsql="select jsonb_build_object('requests',(select count(*) from public.v1_material_requests where id='%s'),'lines',(select count(*) from public.v1_material_request_lines where request_id='%s'),'audit',(select count(*) from public.v1_audit_events where entity_id='%s'),'notifications',(select count(*) from public.v1_notifications where entity_id='%s'),'keys',(select count(*) from public.v1_idempotency_keys where actor_auth_user_id='10000000-0000-4000-8000-000000000001' and command_name='v1_save_and_submit_material_request' and idempotency_key='bf800000-0000-4000-8000-000000000010'));"%(rid,rid,rid,rid)
before=json.loads(sql(countsql));assert before['requests']==1 and before['lines']==1 and before['keys']==1,before
sql(start+'select public.v1_get_material_request_submission_result('+args+');'+call+'commit;')
after=json.loads(sql(countsql));assert before==after,(before,after)
print(json.dumps({'concurrent_callers':2,'returned_same_request':True,'read_and_replay_added_side_effects':False,'counts':after}))
