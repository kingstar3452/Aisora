#!/usr/bin/env python3
"""Focused native source-ZIP build smoke test. No user installation or publication."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys

from source_provenance import digest

ROOT = Path(__file__).resolve().parents[1]


def run(command, log, env=None, required=True, timeout=900):
    result = subprocess.run([str(x) for x in command], cwd=ROOT, env=env, capture_output=True, text=True, timeout=timeout)
    text = result.stdout + result.stderr
    log.write_text(text)
    if required and (result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text):
        print(text)
        raise SystemExit('Focused native check failed: ' + log.name)
    return {'exit': result.returncode, 'output': text}


def main():
    if sys.platform != 'darwin' or platform.machine() != 'x86_64':
        raise SystemExit('Native Intel Mac CI only')
    work = ROOT / '.local/local-build-ci'
    work.mkdir(parents=True, exist_ok=False)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True, cwd=ROOT).strip()
    archive = work / 'source.zip'
    subprocess.run(['git', 'archive', '--format=zip', '--prefix=Aisora-' + commit + '/', '-o', str(archive), commit], cwd=ROOT, check=True)
    subprocess.run(['/usr/bin/ditto', '-xk', str(archive), str(work / 'source')], check=True)
    project = work / 'source' / ('Aisora-' + commit)
    assert not (project / '.git').exists()
    guard = work / 'no-git'
    guard.mkdir()
    shim = guard / 'git'
    shim.write_text('#!/bin/sh\nprintf "called\\n" >> "$AISORA_GIT_TRIPWIRE"\nexit 97\n')
    shim.chmod(0o755)
    tripwire = work / 'unexpected-git-call'
    env = dict(os.environ, PATH=str(guard) + os.pathsep + os.environ['PATH'], AISORA_GIT_TRIPWIRE=str(tripwire))
    output = project / 'exports/local-preview'
    run([sys.executable, project / 'tools/build_local_macos.py', '--archive', archive,
         '--archive-sha256', digest(archive), '--source-commit', commit, '--output', output], work / 'build.log', env, timeout=1800)
    if tripwire.exists():
        raise SystemExit('Source-ZIP builder unexpectedly invoked git')
    receipt = json.loads((output / 'local-build-receipt.json').read_text())
    app = output / 'Aisora.app'
    boot = run([app / 'Contents/MacOS/Aisora', '--headless', '--audio-driver', 'Dummy', '--quit-after', '60'], work / 'headless.log')
    helper = run([app / 'Contents/Helpers/AisoraUpdater', '-h'], work / 'helper.log')
    # LaunchServices in CI is distinct from a human's Finder/Open Anyway test.
    try:
        launch = run(['/usr/bin/open', '-n', '-W', '--stdout', work / 'window.log', '--stderr', work / 'window-error.log',
                      app, '--args', '--audio-driver', 'Dummy', '--resolution', '960x600', '--quit-after', '30'],
                     work / 'launchservices.log', required=False, timeout=180)
    except subprocess.TimeoutExpired:
        launch = {'exit': None, 'output': 'CI LaunchServices wait timed out; no target-device launch success inferred'}
    window = (work / 'window.log').read_text() if (work / 'window.log').exists() else ''
    window_error = (work / 'window-error.log').read_text() if (work / 'window-error.log').exists() else ''
    report = {'source_commit': commit, 'native_os': platform.platform(), 'receipt': receipt,
              'git_invoked_by_archive_build': False, 'native_headless_startup': boot,
              'native_helper_startup': helper, 'ci_launchservices': launch,
              'ci_window_log': window + window_error,
              'normal_target_finder_or_open_anyway_tested': False, 'ventura_imac_tested': False,
              'runtime_changes': False, 'quarantine_or_security_policy_changed': False}
    (work / 'local-source-build-report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Verified source-ZIP export, no git/Xcode invocation, Intel main/helper, native seals and headless startup.')
    print('CI LaunchServices exit:', launch['exit'], '; actual Ventura approval/launch still requires user testing.')


if __name__ == '__main__':
    main()
