#!/usr/bin/env python3
"""Explicit, fingerprint-checked headless probes; never a rendering FPS test."""
import argparse
import hashlib
import json
from pathlib import Path
import platform
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def fingerprint(directory):
    digest = hashlib.sha256()
    files = [directory / 'project.godot'] + sorted((directory / 'scripts').glob('*.gd')) + sorted((directory / 'assets').rglob('*.gdshader'))
    for source in files:
        digest.update(source.relative_to(directory).as_posix().encode() + b'\0' + source.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', action='append', required=True, help='label=/explicit/source/archive')
    parser.add_argument('--reference-matrix', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--runs', type=int, default=3)
    args = parser.parse_args()
    if args.runs < 1:
        parser.error('At least one repetition is required')
    reference = json.loads(args.reference_matrix.read_text())['provenance']
    projects = []
    provenance = {}
    for item in args.project:
        label, path = item.split('=', 1)
        if not re.fullmatch(r'[A-Za-z0-9_-]+', label) or label in provenance:
            parser.error('Unique simple labels are required')
        directory = Path(path).resolve()
        source = (directory / '.benchmark-source-commit').read_text().strip()
        actual = {'source_commit': source, 'runtime_sha256': fingerprint(directory)}
        expected = reference[label]
        if any(actual[key] != expected[key] for key in actual):
            raise SystemExit('Profile source does not match the rendering matrix: ' + label)
        provenance[label] = {**actual, 'source_path': str(directory)}
        projects.append((label, directory))
    probes = [('stages', ROOT / 'tools/profile_phase6.gd', 'PHASE6_PROFILE '),
              ('autonomy', ROOT / 'tools/profile_autonomy.gd', 'AUTONOMY_PROFILE ')]
    provenance['harness_sha256'] = {name: hashlib.sha256(script.read_bytes()).hexdigest() for name, script, _ in probes}
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    logs = output.parent / (output.stem + '-logs')
    logs.mkdir(exist_ok=True)
    records = []
    for repetition in range(args.runs):
        for label, directory in projects if repetition % 2 == 0 else reversed(projects):
            for name, script, prefix in probes:
                result = subprocess.run([str(directory / 'tools/run_godot.sh'), '--headless', '--script', str(script)], cwd=directory, capture_output=True, text=True, timeout=180)
                text = result.stdout + result.stderr
                (logs / f'{name}-{label}-{repetition+1}.log').write_text(text)
                if result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text:
                    raise SystemExit('Headless probe failed: ' + label + '/' + name)
                data = json.loads(next(line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)))
                records.append({'revision': label, 'repetition': repetition + 1, 'probe': name, 'data': data})
                if fingerprint(directory) != provenance[label]['runtime_sha256']:
                    raise SystemExit('Runtime source changed during profiling')
                document = {'method': {'runs': args.runs, 'os': platform.platform(), 'headless': True, 'rendering_fps': False, 'authenticated_voice': False, 'note': 'Opt-in stage instrumentation; no native rendering. Sources must match the recorded complete rendering matrix.'}, 'provenance': provenance, 'records': records}
                temporary = output.with_suffix(output.suffix + '.tmp')
                temporary.write_text(json.dumps(document, indent=2) + '\n')
                temporary.replace(output)
                print(label, repetition + 1, name, flush=True)
    print('All explicit-source headless profiles complete', flush=True)


if __name__ == '__main__':
    main()
