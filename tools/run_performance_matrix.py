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
    parser.add_argument('--runs',type=int,default=3)
    parser.add_argument('--profile',action='store_true')
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
    provenance['harness_sha256']=digest(ROOT/'tools/performance_matrix.gd')
    provenance['cases_sha256']=digest(args.cases)

    def save():
        out.write_text(json.dumps({'method':{'runs':args.runs,'cases':str(args.cases),'animation_delta':1/30,'warmup_frames':60,'LP_NUM_THREADS':2,'native_macos':False,'authenticated_voice':False,'bridge':'actual Python loopback bridge; browser/audio state synthetic','cpu':'per measured case, one logical core = 100%','rss':'10 Hz Linux procfs samples during measurement','renderer_queries_enabled':args.profile,'gpu_utilization':'unavailable; llvmpipe timer queries are software-renderer timings, not physical GPU usage'},'provenance':provenance,'environments':environments,'records':records},indent=2)+'\n')
    try:
        for repetition in range(args.runs):
            # Alternate complete project order across repetitions; never overlap renderers.
            order=projects if repetition%2==0 else list(reversed(projects))
            for label,project in order:
                project=Path(project).resolve()
                env={**os.environ,'LP_NUM_THREADS':'2','AISORA_BRIDGE_CONFIG':str(pairing)}
                cmd=[str(project/'tools/run_godot.sh'),'--audio-driver','Dummy','--script',str(ROOT/'tools/performance_matrix.gd'),'--',f'--cases={args.cases.resolve()}',f'--mode_file={mode_file}',f'--profile={str(args.profile).lower()}']
                proc=subprocess.Popen(cmd,cwd=project,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
                active={'begin':None,'rss':[],'cgroup':{}};guard=threading.Lock();done=threading.Event()
                def sample():
                    while not done.wait(.1):
                        value=process_stats(proc.pid)
                        if value:
                            with guard:
                                if active['begin'] is not None:active['rss'].append(value)
                worker=threading.Thread(target=sample,daemon=True);worker.start()
                failed=False
                with (log_dir/f'{label}-{repetition+1}.log').open('w') as log:
                    for line in proc.stdout:
                        log.write(line);log.flush()
                        if 'SCRIPT ERROR' in line or line.startswith(('ERROR:','FAIL:')):failed=True
                        if line.startswith('PERF_ENV '):environments[label]=json.loads(line[9:])
                        if line.startswith('PERF_BEGIN '):
                            with guard:active['begin']=process_stats(proc.pid);active['rss']=[];active['cgroup']=cgroup_stats()
                        if line.startswith('PERF_RESULT '):
                            r=json.loads(line[12:]);r['revision']=label;r['repetition']=repetition+1
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
                code=proc.wait();done.set();worker.join()
                if code or failed:raise SystemExit(f'{label} failed; see {log_dir}')
    finally:
        stopped.set();browser_thread.join();server.shutdown();server.server_close();http_thread.join();save()
    print('Saved',out,flush=True)


if __name__=='__main__':main()
