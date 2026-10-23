#!/usr/bin/env python3
"""Sequential repeated comparison with a real loopback bridge and fake browser.

No authenticated ChatGPT, microphone or physical GPU utilization is simulated.
Every revision receives the same cases/harness, HTTP cadence and animation ticks.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fixture_bridge',ROOT/'browser-controller/bridge.py')
bridge=importlib.util.module_from_spec(spec);spec.loader.exec_module(bridge)


def process_stats(pid):
    try:
        fields=Path(f'/proc/{pid}/stat').read_text().rsplit(')',1)[1].split()
        cpu=(int(fields[11])+int(fields[12]))/os.sysconf('SC_CLK_TCK')
        status=Path(f'/proc/{pid}/status').read_text().splitlines()
        rss=next(int(x.split()[1])*1024 for x in status if x.startswith('VmRSS:'))
        return {'cpu_seconds':cpu,'rss':rss,'time':time.monotonic()}
    except (OSError,ValueError,StopIteration):return None


def cgroup_stats():
    try:return {k:int(v) for k,v in (line.split() for line in Path('/sys/fs/cgroup/cpu.stat').read_text().splitlines())}
    except (OSError,ValueError):return {}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project',action='append',required=True,help='label=/absolute/path, repeat in desired order')
    parser.add_argument('--cases',type=Path,default=ROOT/'tools/performance_cases.json')
    parser.add_argument('--harness',type=Path,default=ROOT/'tools/performance_matrix.gd',help='Independent additional feature probe; default matrix is unchanged')
    parser.add_argument('--runs',type=int,default=3)
    parser.add_argument('--profile',action='store_true')
    parser.add_argument('--resume',type=Path,help='Retain valid completed cases from a matching earlier dataset; rerun only missing cases')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    projects=[entry.split('=',1) for entry in args.project]
    if args.runs<1:parser.error('At least one repetition is required.')
    out=args.output.resolve();out.parent.mkdir(parents=True,exist_ok=True)
    log_dir=out.parent/(out.stem+'-logs');log_dir.mkdir(exist_ok=True)
    mode_file=log_dir/'fixture-mode.json';mode_file.write_text('{}')
    state=bridge.BridgeState();key='1'*64
    server=bridge.make_server(0,key,state);http_thread=threading.Thread(target=server.serve_forever,daemon=True);http_thread.start()
    pairing=log_dir/'fixture-pairing.json';pairing.write_text(json.dumps({'port':server.server_port,'key':key}))
    stopped=threading.Event()
    def browser():
        while not stopped.wait(.1):
            try:mode=json.loads(mode_file.read_text())
            except (OSError,ValueError):continue
            if not mode.get('connected',False):
                with state.lock:state.last_browser=-math.inf;state.last_audio=-math.inf
                continue
            state.poll({'voice':mode.get('voice','inactive'),'binding_id':'matrix-fixture','project_label':'Synthetic test only','activity':'listening'})
            amplitude=.07+.05*math.sin(time.monotonic()*9) if mode.get('speaking') else 0.
            state.audio({'rms':amplitude,'capturing':mode.get('speaking',False),'binding_id':'matrix-fixture'})
    browser_thread=threading.Thread(target=browser,daemon=True);browser_thread.start()
    records=[];environments={}
    def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
    provenance={}
    for label,project in projects:
        directory=Path(project)
        fingerprint=hashlib.sha256()
        files=[directory/'project.godot']+sorted((directory/'scripts').glob('*.gd'))+sorted((directory/'assets').rglob('*.gdshader'))
        for source in files:fingerprint.update(source.relative_to(directory).as_posix().encode()+b'\0'+source.read_bytes())
        provenance[label]={'source_path':str(directory.resolve()),'runtime_sha256':fingerprint.hexdigest(),'source_commit':(directory/'.benchmark-source-commit').read_text().strip() if (directory/'.benchmark-source-commit').exists() else subprocess.run(['git','rev-parse','HEAD'],cwd=directory,capture_output=True,text=True).stdout.strip()}
    provenance['harness_sha256']=digest(args.harness)
    provenance['cases_sha256']=digest(args.cases)
    catalogue=json.loads(args.cases.read_text())
    case_ids={item['id'] for item in catalogue}
    session_bus_configured=bool(os.environ.get('DBUS_SESSION_BUS_ADDRESS'))
    display_policy=os.environ.get('AISORA_TEST_DISPLAY_POLICY','unknown')
    resumed_from=None
    if args.resume:
        prior=json.loads(args.resume.read_text())
        if any(prior['provenance'].get(field)!=provenance[field] for field in ['harness_sha256','cases_sha256']):
            raise SystemExit('Resume harness/case fingerprint differs; keep datasets separate.')
        records=prior['records'];environments=prior.get('environments',{})
        if prior['method'].get('renderer_queries_enabled',False)!=args.profile:raise SystemExit('Resume profiling mode differs')
        if bool(prior['method'].get('session_bus_configured',False))!=session_bus_configured or prior['method'].get('display_policy','unknown')!=display_policy:
            raise SystemExit('Resume desktop-session environment differs; keep datasets separate.')
        keys=[(r['revision'],r['repetition'],r['case']['id']) for r in records if not r.get('excluded_reason')]
        if len(keys)!=len(set(keys)):raise SystemExit('Duplicate valid resume cases are not allowed')
        for label,_ in projects:
            if any(r['revision']==label for r in records) and prior['provenance'][label]['runtime_sha256']!=provenance[label]['runtime_sha256']:
                raise SystemExit('Resume runtime fingerprint differs for retained '+label)
        if any(r['revision'] not in {label for label,_ in projects} or r['case']['id'] not in case_ids or not 1<=r['repetition']<=args.runs for r in records):
            raise SystemExit('Resume contains cases/builds/repetitions outside this comparison.')
        resumed_from={'path':str(args.resume.resolve()),'sha256':digest(args.resume),'note':'Existing valid cases retained. Partial batches restart in a fresh process with normal warmup; allocator high-water memory may differ.'}

    def save():
        out.write_text(json.dumps({'method':{'runs':args.runs,'session_bus_configured':session_bus_configured,'display_policy':display_policy,'cases':str(args.cases),'animation_delta':1/30,'warmup_frames':60,'LP_NUM_THREADS':2,'native_macos':False,'authenticated_voice':False,'bridge':'actual Python loopback bridge; browser/audio state synthetic','cpu':'per measured case, one logical core = 100%','rss':'10 Hz Linux procfs samples during measurement','renderer_queries_enabled':args.profile,'gpu_utilization':'unavailable; llvmpipe timer queries are software-renderer timings, not physical GPU usage'},'resumed_from':resumed_from,'provenance':provenance,'environments':environments,'records':records},indent=2)+'\n')
    try:
        for repetition in range(args.runs):
            # Alternate complete project order across repetitions; never overlap renderers.
            order=projects if repetition%2==0 else list(reversed(projects))
            for label,project in order:
                retained={r['case']['id'] for r in records if r['revision']==label and r['repetition']==repetition+1 and not r.get('excluded_reason')}
                pending=[item for item in catalogue if item['id'] not in retained]
                if not pending:
                    print(f'Skipped complete {label} repetition {repetition+1}',flush=True);continue
                effective_cases=args.cases.resolve()
                if retained:
                    effective_cases=log_dir/f'{label}-{repetition+1}-pending.json'
                    effective_cases.write_text(json.dumps(pending))
                project=Path(project).resolve()
                env={**os.environ,'LP_NUM_THREADS':'2','AISORA_BRIDGE_CONFIG':str(pairing)}
                cmd=[str(project/'tools/run_godot.sh'),'--audio-driver','Dummy','--script',str(args.harness.resolve()),'--',f'--cases={effective_cases}',f'--mode_file={mode_file}',f'--profile={str(args.profile).lower()}']
                proc=subprocess.Popen(cmd,cwd=project,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
                active={'begin':None,'rss':[],'cgroup':{}};guard=threading.Lock();done=threading.Event()
                def sample():
                    while not done.wait(.1):
                        value=process_stats(proc.pid)
                        if value:
                            with guard:
                                if active['begin'] is not None:active['rss'].append(value)
                worker=threading.Thread(target=sample,daemon=True);worker.start()
                try:
                    failed=False
                    with (log_dir/f'{label}-{repetition+1}.log').open('w') as log:
                        for line in proc.stdout:
                            log.write(line);log.flush()
                            if 'SCRIPT ERROR' in line or line.startswith(('ERROR:','FAIL:')):failed=True
                            if line.startswith('PERF_ENV '):environments[label]=json.loads(line[9:])
                            if line.startswith('PERF_BEGIN '):
                                with guard:active['begin']=process_stats(proc.pid);active['rss']=[];active['cgroup']=cgroup_stats()
                            if line.startswith('PERF_RESULT '):
                                r=json.loads(line[12:]);r['revision']=label;r['repetition']=repetition+1;r['fresh_process_resume_subset']=bool(retained)
                                with guard:
                                    begin=active['begin'];samples=active['rss'];cg_before=active['cgroup'];active['begin']=None
                                end=process_stats(proc.pid)
                                if begin and end:
                                    wall=end['time']-begin['time'];cpu=end['cpu_seconds']-begin['cpu_seconds']
                                    r['process']={'cpu_percent':100*cpu/wall,'cpu_seconds':cpu,'wall_seconds':wall,'rss_start_bytes':begin['rss'],'rss_end_bytes':end['rss'],'rss_peak_bytes':max([x['rss'] for x in samples]+[begin['rss'],end['rss']]),'rss_samples':len(samples)}
                                cg_after=cgroup_stats()
                                r['container_cpu_delta']={k:cg_after[k]-v for k,v in cg_before.items() if k in cg_after}
                                records.append(r);save()
                                print(f'{label} #{repetition+1} {r["case"]["id"]}: mean {r["frame"]["mean_ms"]:.2f} P95 {r["frame"]["p95_ms"]:.2f} P99 {r["frame"]["p99_ms"]:.2f} ms',flush=True)
                    code=proc.wait()
                finally:
                    if proc.poll() is None:
                        proc.terminate()
                        try:proc.wait(timeout=5)
                        except subprocess.TimeoutExpired:proc.kill();proc.wait()
                    done.set();worker.join()
                if code or failed:raise SystemExit(f'{label} failed; see {log_dir}')
    finally:
        stopped.set();browser_thread.join();server.shutdown();server.server_close();http_thread.join();save()
    print('Saved',out,flush=True)


if __name__=='__main__':main()
