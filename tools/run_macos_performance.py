#!/usr/bin/env python3
"""Run the unchanged Low-preset state cases on native Intel Mac CI.

The original Linux launcher remains unchanged. This adapter substitutes only
process accounting and records native method metadata after completion. It
never changes cases, animation ticks, rendering quality or the scene harness.
"""
import ctypes as C
import gzip
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tarfile
import time

ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT/'.local/macos-ci/performance'
SOURCES={'r2':'bf2aee817f26da62a03187f9363580f57f71aeec',
         'rc1':'5ca43c50751a278ba5bfce462df147fc67cfffc8',
         'rc2':'2142475b0cc9f8386e64929db1486746e9115e8b'}

# Stable public Darwin RUSAGE_INFO_V0 ABI, <sys/resource.h>.
class Usage(C.Structure):
    _fields_=[('uuid',C.c_ubyte*16)]+[(name,C.c_uint64) for name in
        ['user','system','package_wakeups','interrupt_wakeups','pageins',
         'wired','resident','footprint','start','exit']]


def main():
    if sys.platform!='darwin' or platform.machine()!='x86_64':
        raise SystemExit('This probe requires native Intel macOS')
    WORK.mkdir(parents=True,exist_ok=True)
    lib=C.CDLL('/usr/lib/libproc.dylib',use_errno=True)
    lib.proc_pid_rusage.argtypes=[C.c_int,C.c_int,C.c_void_p]
    lib.proc_pid_rusage.restype=C.c_int
    def stats(pid):
        value=Usage()
        if lib.proc_pid_rusage(pid,0,C.byref(value))!=0:return None
        return {'cpu_seconds':(value.user+value.system)/1e9,
                'rss':int(value.resident),'time':time.monotonic()}
    # Verify CPU units/accounting on this host before scoring any application.
    cpu_before=time.process_time();before=stats(os.getpid())
    deadline=time.monotonic()+.3
    while time.monotonic()<deadline:pass
    after=stats(os.getpid());cpu_after=time.process_time()
    if not before or not after or after['rss']<=0:
        raise SystemExit('Native process accounting unavailable')
    observed=after['cpu_seconds']-before['cpu_seconds']
    expected=cpu_after-cpu_before
    if abs(observed-expected)>max(.01,expected*.1):
        raise SystemExit('Native CPU unit calibration failed')
    (WORK/'accounting-calibration.json').write_text(json.dumps({
        'native_os':platform.platform(),'machine':platform.machine(),
        'rusage_cpu_delta_seconds':observed,'process_time_delta_seconds':expected,
        'resident_bytes':after['rss'],'measurement':'public proc_pid_rusage RUSAGE_INFO_V0; nanoseconds converted to seconds'},indent=2)+'\n')
    for label,commit in SOURCES.items():
        subprocess.run(['git','fetch','--no-tags','origin',commit],cwd=ROOT,check=True)
        archive=WORK/(label+'.tar')
        with archive.open('wb') as out:
            subprocess.run(['git','archive',commit],cwd=ROOT,stdout=out,check=True)
        project=WORK/label;project.mkdir(exist_ok=True)
        with tarfile.open(archive) as source:source.extractall(project,filter='data')
        (project/'.benchmark-source-commit').write_text(commit+'\n')
        result=subprocess.run([str(project/'tools/run_godot.sh'),'--headless','--editor','--import'],capture_output=True,text=True,cwd=project)
        text=result.stdout+result.stderr;(WORK/(label+'-import.log')).write_text(text)
        if result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text:
            raise SystemExit(label+' import failed')
    spec=importlib.util.spec_from_file_location('original_matrix',ROOT/'tools/run_performance_matrix.py')
    matrix=importlib.util.module_from_spec(spec);spec.loader.exec_module(matrix)
    matrix.process_stats=stats
    matrix.cgroup_stats=lambda:{}
    output=WORK/'native-matrix.json'
    sys.argv=['run_performance_matrix.py']
    for label in SOURCES:sys.argv+=['--project',label+'='+str(WORK/label)]
    catalogue=json.loads((ROOT/'tools/performance_cases.json').read_text())
    cases=WORK/'native-cases.json'
    selected=[item for item in catalogue if item['id'] in {state+'-q0' for state in ['idle','speaking','listening','walking','sitting','reclining','sleeping','personality']}]
    if len(selected)!=8:raise SystemExit('Original eight Low state cases missing')
    cases.write_text(json.dumps(selected,indent=2)+'\n')
    sys.argv+=['--runs','3','--cases',str(cases),'--output',str(output)]
    matrix.main()
    data=json.loads(output.read_text())
    if len(data['records'])!=72:raise SystemExit('Incomplete native matrix')
    for r in data['records']:
        if not r.get('process'):raise SystemExit('Missing native process samples')
    data['method'].update(native_macos=True,cpu='10 Hz native proc_pid_rusage; one logical core=100%; sampled only during measured cases',
        rss='10 Hz native ri_resident_size, not GPU memory or physical footprint',
        gpu_utilization='unavailable; OpenGL adapter reported per source; no physical GPU utilization measurement',
        native_os=platform.platform(),target_imac=False,authenticated_voice=False,
        editor_ui=False,coverage='Additional original eight Low state cases, three builds, three repetitions; not the complete Linux matrix',note='Native Mac CI project-player comparison, not the user Ventura/iMac or an authenticated Voice session')
    data['method']['adapter_sha256']=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    output.write_text(json.dumps(data,indent=2)+'\n')
    subprocess.run([sys.executable,str(ROOT/'tools/summarize_performance_matrix.py'),str(output),'--output',str(WORK/'native-summary')],check=True)
    zipped=WORK/'native-matrix.json.gz'
    with zipped.open('wb') as stream:
        with gzip.GzipFile(filename='',mode='wb',fileobj=stream,mtime=0) as out:out.write(output.read_bytes())
    # Stage evidence only into this run's existing private draft, after all
    # validation. Never publish, overwrite assets or use a public artifact branch.
    tag=os.environ['AISORA_REVIEW_DRAFT']
    repo=os.environ['GITHUB_REPOSITORY']
    if repo!='kingstar3452/Aisora':raise SystemExit('Unexpected repository')
    info=json.loads(subprocess.check_output(['gh','release','view',tag,'--repo',repo,'--json','isDraft,assets'],text=True))
    if not info['isDraft']:raise SystemExit('Refusing to alter a published release')
    files=[zipped]+[WORK/('native-summary.'+suffix) for suffix in ['json','csv','md']]+[WORK/'accounting-calibration.json']
    if {x['name'] for x in info['assets']} & {x.name for x in files}:raise SystemExit('Refusing to overwrite staged evidence')
    subprocess.run(['gh','release','upload',tag,*[str(x) for x in files],'--repo',repo],check=True)
    print('Complete native comparison evidence staged into PRIVATE DRAFT only')


if __name__=='__main__':main()
