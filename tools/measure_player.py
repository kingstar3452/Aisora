#!/usr/bin/env python3
"""Observe actual Linux app/player swaps using Mesa's hidden HUD dump.

No script injection or path override is required for an exported application.
This is a Linux development probe, not a macOS test or production dependency.
"""
import argparse
import ctypes as C
import importlib.util
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys
import threading
import time

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('matrix',ROOT/'tools/run_performance_matrix.py')
matrix=importlib.util.module_from_spec(spec);spec.loader.exec_module(matrix)


def focus_window(pid):
    x=C.CDLL('libX11.so.6');ptr=C.c_void_p;ul=C.c_ulong
    x.XOpenDisplay.argtypes=[C.c_char_p];x.XOpenDisplay.restype=ptr
    x.XDefaultRootWindow.argtypes=[ptr];x.XDefaultRootWindow.restype=ul
    x.XInternAtom.argtypes=[ptr,C.c_char_p,C.c_int];x.XInternAtom.restype=ul
    x.XQueryTree.argtypes=[ptr,ul,C.POINTER(ul),C.POINTER(ul),C.POINTER(C.POINTER(ul)),C.POINTER(C.c_uint)]
    x.XGetWindowProperty.argtypes=[ptr,ul,ul,C.c_long,C.c_long,C.c_int,ul,C.POINTER(ul),C.POINTER(C.c_int),C.POINTER(ul),C.POINTER(ul),C.POINTER(ptr)]
    x.XMapRaised.argtypes=[ptr,ul];x.XGetInputFocus.argtypes=[ptr,C.POINTER(ul),C.POINTER(C.c_int)]
    x.XSetErrorHandler.argtypes=[ptr];x.XSetErrorHandler.restype=ptr
    errors=[]
    callback=C.CFUNCTYPE(C.c_int,ptr,ptr)(lambda _d,_e:errors.append(True) or 0)
    previous=x.XSetErrorHandler(C.cast(callback,ptr))
    x.XFree.argtypes=[ptr];x.XSetInputFocus.argtypes=[ptr,ul,C.c_int,ul];x.XRaiseWindow.argtypes=[ptr,ul];x.XSync.argtypes=[ptr,C.c_int];x.XCloseDisplay.argtypes=[ptr]
    x.XGetGeometry.argtypes=[ptr,ul,C.POINTER(ul),C.POINTER(C.c_int),C.POINTER(C.c_int),C.POINTER(C.c_uint),C.POINTER(C.c_uint),C.POINTER(C.c_uint),C.POINTER(C.c_uint)]
    d=x.XOpenDisplay(os.environ.get('DISPLAY',':99').encode())
    if not d:x.XSetErrorHandler(previous);return None
    children=C.POINTER(ul)();n=C.c_uint();root=ul();parent=ul();result=None
    try:
        x.XQueryTree(d,x.XDefaultRootWindow(d),C.byref(root),C.byref(parent),C.byref(children),C.byref(n))
        atom=x.XInternAtom(d,b'_NET_WM_PID',0)
        for i in range(n.value):
            value=ptr();kind=ul();fmt=C.c_int();items=ul();remaining=ul();w=children[i]
            x.XGetWindowProperty(d,w,atom,0,1,0,0,C.byref(kind),C.byref(fmt),C.byref(items),C.byref(remaining),C.byref(value))
            found=bool(value) and fmt.value==32 and items.value and C.cast(value,C.POINTER(ul))[0]==pid
            if value:x.XFree(value)
            if found:
                x.XMapRaised(d,w);x.XSync(d,0);x.XSetInputFocus(d,w,2,0);x.XSync(d,0)
                owner=ul();revert=C.c_int();x.XGetInputFocus(d,C.byref(owner),C.byref(revert))
                if errors or owner.value!=w:continue
                xx=C.c_int();yy=C.c_int();width=C.c_uint();height=C.c_uint();border=C.c_uint();depth=C.c_uint()
                x.XGetGeometry(d,w,C.byref(root),C.byref(xx),C.byref(yy),C.byref(width),C.byref(height),C.byref(border),C.byref(depth))
                result={'window':int(w),'width':width.value,'height':height.value};break
    finally:
        if children:x.XFree(children)
        x.XCloseDisplay(d);x.XSetErrorHandler(previous)
    return result


def summary(values):
    ordered=sorted(values);n=len(values)
    return {'mean_ms':statistics.mean(values),'median_ms':statistics.median(values),'p95_ms':ordered[min(n-1,int(n*.95))],'p99_ms':ordered[min(n-1,int(n*.99))],'fps':1000/statistics.mean(values)}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--release-player',type=Path)
    parser.add_argument('--player',action='append',help='label=/absolute/release-player; repeat for standalone version comparisons')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--runs',type=int,default=3)
    parser.add_argument('--frames',type=int,default=180)
    parser.add_argument('--states',nargs='+',choices=['idle','speaking'],default=['idle','speaking'])
    args=parser.parse_args()
    if args.frames<180 or args.runs<1:parser.error('Use at least 180 measured frames and one repetition')
    if not args.player and not args.release_player:parser.error('Supply --release-player or at least one --player')
    if sys.platform!='linux':parser.error('Mesa/Gallium and Linux procfs are required. Use native Mac diagnostics separately.')
    out=args.output.resolve();directory=out.parent/out.stem;directory.mkdir(parents=True,exist_ok=True)
    player_specs=[('project-player',['/usr/local/bin/godot','--path',str(ROOT)]),('linux-release',[str(args.release_player.resolve())])] if not args.player else [(item.split('=',1)[0],[str(Path(item.split('=',1)[1]).resolve())]) for item in args.player]
    if any(not name.replace('-','').replace('_','').isalnum() for name,_ in player_specs):parser.error('Use simple alphanumeric player labels')
    records=[];state=matrix.bridge.BridgeState();request_count=[0];original_snapshot=state.snapshot
    def counted_snapshot():
        request_count[0]+=1;return original_snapshot()
    state.snapshot=counted_snapshot
    key='2'*64;mode={'speaking':False}
    server=matrix.bridge.make_server(0,key,state);server_thread=threading.Thread(target=server.serve_forever,daemon=True);server_thread.start()
    pairing=directory/'pairing.json';pairing.write_text(json.dumps({'port':server.server_port,'key':key}))
    stop=threading.Event()
    def browser():
        while not stop.wait(.1):
            if mode['speaking']:
                state.poll({'voice':'active','binding_id':'player-fixture','activity':'listening'})
                state.audio({'rms':.07+.05*math.sin(time.monotonic()*9),'capturing':True,'binding_id':'player-fixture'})
            else:
                with state.lock:state.last_browser=-math.inf;state.last_audio=-math.inf
    thread=threading.Thread(target=browser,daemon=True);thread.start()
    def save():
        out.write_text(json.dumps({'method':{'runs':args.runs,'session_bus_configured':bool(os.environ.get('DBUS_SESSION_BUS_ADDRESS')),'display_policy':os.environ.get('AISORA_TEST_DISPLAY_POLICY','unknown'),'frames':args.frames,'warmup_frames':60,'target_fps':30,'observer':'Mesa frametime_(ms), hidden HUD, one dump sample per presented frame','cpu':'procfs near measured-frame boundaries; one logical core=100%','voice':'real Python bridge; synthetic browser/audio','macos':False,'editor_ui':False,'cold_start':'all initial frame traces retained; shader caches persist per player across repetitions'},'records':records},indent=2)+'\n')
    try:
        for repetition in range(args.runs):
            players=player_specs if repetition%2==0 else list(reversed(player_specs))
            for name,engine_command in players:
                profile=directory/name
                for kind in ['data','config','cache']:(profile/kind).mkdir(parents=True,exist_ok=True)
                for state_name in args.states:
                    speaking=state_name=='speaking'
                    mode['speaking']=speaking;request_start=request_count[0];label='speaking' if speaking else 'idle';tag=f'{name}-{label}-{repetition+1}'
                    hud=directory/tag;hud.mkdir(exist_ok=True)
                    prefs=profile/'data/godot/app_userdata/Aisora';prefs.mkdir(parents=True,exist_ok=True)
                    (prefs/'settings.cfg').write_text('[display]\npreset=0\nfps=30\n[world]\noverride="daytime"\ndisplayed_slot="daytime"\n[performance]\nadaptive=false\n[phase6]\nversion=1\n')
                    env={**os.environ,'LP_NUM_THREADS':'2','XDG_DATA_HOME':str(profile/'data'),'XDG_CONFIG_HOME':str(profile/'config'),'XDG_CACHE_HOME':str(profile/'cache'),'GALLIUM_HUD':'frametime','GALLIUM_HUD_VISIBLE':'false','GALLIUM_HUD_PERIOD':'0','GALLIUM_HUD_DUMP_DIR':str(hud),'AISORA_BRIDGE_CONFIG':str(pairing)}
                    cmd=list(engine_command)
                    cmd+=['--resolution','960x600','--audio-driver','Dummy','--print-fps','--quit-after',str(args.frames+60)]
                    with (hud/'player.log').open('w') as log:
                        proc=subprocess.Popen(cmd,cwd=directory,env=env,stdout=log,stderr=subprocess.STDOUT)
                        (hud/'pid.json').write_text(json.dumps({'pid':proc.pid,'tag':tag}))
                        before=None;latest=None;samples=[];focused=None;started=time.monotonic();trace_path=hud/'frametime_(ms)'
                        while proc.poll() is None:
                            if time.monotonic()-started>max(180,(args.frames+60)/5+60):proc.kill();proc.wait();raise RuntimeError(f'{tag}: player timed out')
                            if focused is None:focused=focus_window(proc.pid)
                            try:values=[float(line) for line in trace_path.read_text().splitlines()]
                            except (OSError,ValueError):values=[]
                            sample=matrix.process_stats(proc.pid)
                            if sample and len(values)>=60:
                                if before is None:before=sample
                                latest=sample;samples.append(sample)
                            time.sleep(.02)
                    text=(hud/'player.log').read_text()
                    if proc.returncode or any(token in text for token in ['SCRIPT ERROR','ERROR:','FAIL:']):raise RuntimeError(f'{tag}: startup failed; see log')
                    values=[float(line) for line in trace_path.read_text().splitlines()]
                    if request_count[0]-request_start<5:raise RuntimeError(f'{tag}: actual player did not sustain authenticated loopback requests')
                    if len(values)<args.frames+60 or not focused:raise RuntimeError(f'{tag}: incomplete driver samples/focus')
                    record={'player':name,'state':label,'repetition':repetition+1,'bridge_requests':request_count[0]-request_start,'observed_window':focused,'frame':summary(values[60:60+args.frames]),'all_frame_trace_ms':values,'first_60':summary(values[:60])}
                    if before and latest and latest['time']>before['time']:
                        record['process']={'cpu_percent':100*(latest['cpu_seconds']-before['cpu_seconds'])/(latest['time']-before['time']),'rss_peak_bytes':max(s['rss'] for s in samples),'rss_start_bytes':before['rss'],'rss_end_bytes':latest['rss']}
                    records.append(record);save();print(tag,record['frame'],'window',focused,flush=True)
    finally:
        stop.set();thread.join();server.shutdown();server.server_close();server_thread.join();save()


if __name__=='__main__':main()
