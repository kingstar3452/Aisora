#!/usr/bin/env python3
"""Summarize every retained run. Percentiles are medians of run percentiles.

No trimming, winsorizing or selection of fastest runs. Raw frame traces remain
in the input; ranges expose shared-host variation instead of concealing it.
"""
import argparse
import csv
import json
from pathlib import Path
import statistics


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input',type=Path)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--cases',type=Path,help='Explicit original catalogue when the recorded machine path is unavailable')
    args=parser.parse_args()
    data=json.loads(args.input.read_text());groups={}
    excluded=[record for record in data['records'] if record.get('excluded_reason')]
    for record in data['records']:
        if record.get('excluded_reason'):continue
        key=(record['case']['id'],record['revision'])
        groups.setdefault(key,[]).append(record)
    expected=int(data['method']['runs'])
    catalogue=args.cases or Path(data['method']['cases'])
    if not catalogue.exists():catalogue=Path(__file__).with_name('performance_cases.json')
    case_ids={case['id'] for case in json.loads(catalogue.read_text())}
    revisions={key for key,value in data['provenance'].items() if isinstance(value,dict) and 'runtime_sha256' in value}
    if set(groups)!={(case,revision) for case in case_ids for revision in revisions}:
        raise SystemExit('Incomplete scenario/build coverage; no final summary generated.')
    if any(len(records)!=expected for records in groups.values()):
        raise SystemExit('Incomplete repetitions; no final summary generated.')
    med=lambda records,key:statistics.median(r[key] for r in records)
    rows=[]
    for (case,revision),records in groups.items():
        frames=[r['frame'] for r in records];scripts=[r['script'] for r in records];process=[r['process'] for r in records]
        first=records[0];item=first['case']
        row={'case':case,'revision':revision,'runs':len(records),'quality':item.get('quality',0),'state':item['state'],
             'slot':item.get('slot','daytime'),'weather':item.get('weather','clear'),
             'window':f"{item.get('width',960)}x{item.get('height',600)}",'bridge':item.get('bridge','connected'),
             'paced':item.get('paced',False),'frames_per_run':first['frames']}
        for field in ['mean_ms','median_ms','p95_ms','p99_ms','fps']:row[field]=med(frames,field)
        for field in ['mean_ms','p95_ms','p99_ms']:
            row[field+'_min']=min(r[field] for r in frames);row[field+'_max']=max(r[field] for r in frames)
        row['script_mean_ms']=med(scripts,'mean_ms');row['script_p95_ms']=med(scripts,'p95_ms')
        row['cpu_percent']=med(process,'cpu_percent')
        row['rss_peak_mib']=med(process,'rss_peak_bytes')/2**20
        row['rss_growth_mib']=statistics.median((r['rss_end_bytes']-r['rss_start_bytes'])/2**20 for r in process)
        for field in ['draw_calls','primitives','video_memory_bytes','static_memory_bytes','objects']:
            row[field]=med(records,field)
        rows.append(row)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    with args.output.with_suffix('.csv').open('w') as target:
        writer=csv.DictWriter(target,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    headings=['Case','Build','Mean','Median','P95','P99','FPS','CPU %','Peak RSS MiB','P95 range']
    lines=['# Complete performance matrix','',
           f'Milliseconds except FPS, CPU and memory. Each value is the median of all {expected} valid run statistics; P95 range is min–max across repetitions. CPU covers the measured case (one logical core = 100%). RSS is sampled process memory, not physical GPU usage. Paced cases include deliberate frame waits. All raw runs and frame traces are retained separately. {len(excluded)} instrumentation-invalid samples remain in the audit data and are replaced explicitly; no slow valid run is trimmed.','',
           '| '+' | '.join(headings)+' |','| '+' | '.join(['---']*len(headings))+' |']
    for r in rows:
        values=[r['case'],r['revision']]+[f'{r[k]:.2f}' for k in ['mean_ms','median_ms','p95_ms','p99_ms','fps','cpu_percent','rss_peak_mib']]+[f"{r['p95_ms_min']:.2f}–{r['p95_ms_max']:.2f}"]
        lines.append('| '+' | '.join(values)+' |')
    args.output.with_suffix('.md').write_text('\n'.join(lines)+'\n')
    args.output.with_suffix('.json').write_text(json.dumps(rows,indent=2)+'\n')
    print(f'{len(rows)} scenario/build summaries; all {len(data["records"])} runs retained.')


if __name__=='__main__':main()
