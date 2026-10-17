#!/usr/bin/env python3
"""Sequential before/after benchmarks; standard library, no app dependencies.
Baseline must be an imported Phase 2 checkout/archive. Runs the SAME GDScript
harness against both projects; logs/results stay in ignored .local by default.
"""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--runs', type=int, default=3)
    parser.add_argument('--frames', type=int, default=180)
    parser.add_argument('--state', choices=['idle', 'talking'], default='talking')
    parser.add_argument('--presets', nargs='+', choices=['low', 'balanced', 'high'], default=['low', 'balanced', 'high'])
    parser.add_argument('--output', type=Path, default=Path('.local/performance-comparison.json'))
    args = parser.parse_args()
    if args.runs < 1 or args.frames < 60:
        parser.error('Use at least one run and 60 measured frames.')
    repo = Path(__file__).resolve().parents[1]
    baseline = args.baseline.resolve()
    harness = repo / 'tools/benchmark.gd'
    environment = dict(os.environ)
    environment.setdefault('LP_NUM_THREADS', '2')
    samples = []
    suffix = '-idle' if args.state == 'idle' else ''
    cases = [('phase2'+suffix, baseline, 0)]
    cases += [('phase3-'+name+suffix, repo, ['low', 'balanced', 'high'].index(name))
              for name in dict.fromkeys(args.presets)]
    log_dir = repo / '.local/benchmarks'
    log_dir.mkdir(parents=True, exist_ok=True)
    # Interleave versions per repetition to reduce time-of-run bias, never overlap engines.
    for repetition in range(args.runs):
        for label, project, quality in cases:
            for mode in ['cpu', 'render']:
                command = [str(project / 'tools/run_godot.sh')]
                command += ['--headless'] if mode == 'cpu' else ['--audio-driver', 'Dummy']
                command += ['--script', str(harness), '--', f'--mode={mode}',
                            f'--label={label}-{repetition+1}', f'--quality={quality}',
                            f'--frames={args.frames}', f'--state={args.state}']
                run = subprocess.run(command, cwd=project, env=environment,
                                     capture_output=True, text=True, timeout=180)
                log = run.stdout + run.stderr
                (log_dir / f'{label}-{repetition+1}-{mode}.log').write_text(log)
                records = [line.removeprefix('AISORA_BENCH ') for line in log.splitlines()
                           if line.startswith('AISORA_BENCH ')]
                if run.returncode or not records or 'SCRIPT ERROR' in log or '\nERROR:' in log:
                    raise SystemExit(f'{label} {mode} failed; see {log_dir}')
                result = json.loads(records[-1])
                result['repetition'] = repetition + 1
                samples.append(result)
                metric = result['character_tick' if mode == 'cpu' else 'frame']
                print(f'{label} #{repetition+1} {mode}: mean {metric["mean_ms"]:.3f} ms, '
                      f'p95 {metric["p95_ms"]:.3f} ms', flush=True)
    medians = {}
    for label, _, _ in cases:
        medians[label] = {}
        for mode in ['cpu', 'render']:
            subset = [r for r in samples if r['label'].startswith(label+'-') and r['mode'] == mode]
            metric = 'character_tick' if mode == 'cpu' else 'frame'
            medians[label][mode] = {field: statistics.median(r[metric][field] for r in subset)
                                    for field in ['mean_ms', 'p50_ms', 'p95_ms']}
    output = {'method': {'runs': args.runs, 'measured_frames': args.frames, 'warmup_frames': 60,
                         'state': args.state,
                         'lp_num_threads': environment['LP_NUM_THREADS'], 'uncapped': True,
                         'resolution': '960x600', 'ui_and_network': False,
                         'summary': 'Median of per-run statistics, not pooled frame percentiles.'},
              'medians': medians, 'samples': samples}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, indent=2)+'\n')
    print(json.dumps(medians, indent=2))
    print(f'Saved {args.output}')


if __name__ == '__main__':
    main()
