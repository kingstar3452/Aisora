#!/usr/bin/env python3
"""Native Mac rebuild validation; no release/artifact upload or security bypass.

CI rebuilds this source on a Mac. It does not certify the Linux-cross-signed ZIP,
Ventura on the user's iMac, authenticated Voice, or an Internet Finder launch.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import subprocess
import sys
import time
import urllib.request

from macos_bundle import verify_zip

ROOT = Path(__file__).resolve().parents[1]
EDITOR_URL = 'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_macos.universal.zip'
EDITOR_SHA = '30630f3e9b11e10b35c1f90ba8814185dcec43fae1a48345159be7552c64bfe8'


def command(args, output, required=True, timeout=180):
    result = subprocess.run([str(x) for x in args], cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    text = result.stdout + result.stderr
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)
    print(output.name, 'exit', result.returncode, flush=True)
    if required and (result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text or '\nFAIL:' in text):
        print(text)
        raise SystemExit('Native validation failed: ' + output.name)
    return result, text


def bootstrap():
    work = ROOT / '.local/macos-ci'
    work.mkdir(parents=True, exist_ok=True)
    archive = work / 'official-editor.zip'
    with urllib.request.urlopen(EDITOR_URL, timeout=60) as response, archive.open('wb') as out:
        shutil.copyfileobj(response, out)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != EDITOR_SHA:
        raise SystemExit('Official editor checksum mismatch; refusing execution')
    subprocess.run(['/usr/bin/ditto', '-xk', str(archive), str(work)], check=True)
    godot = work / 'Godot.app/Contents/MacOS/Godot'
    if not godot.is_file():
        raise SystemExit('Missing official Godot executable')
    with Path(os.environ['GITHUB_ENV']).open('a') as out:
        out.write(f'GODOT_BIN={godot}\nAISORA_GO={shutil.which("go")}\n')
    print('Installed checksum-verified official Godot 4.6.3 editor')


def validate(archive):
    work = ROOT / '.local/macos-ci/validation'
    work.mkdir(parents=True, exist_ok=True)
    report = {'native_os': platform.platform(), 'machine': platform.machine(),
              'scope': 'Native macOS CI rebuild, not the target iMac or Linux-cross-signed archive',
              'native_voice_tested': False, 'target_imac_tested': False,
              'developer_id_signed': False, 'notarized': False,
              'bundle': verify_zip(archive)}
    command(['/usr/bin/ditto', '-xk', archive, work], work / 'ditto.log')
    app = work / 'Aisora.app'
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    report['source_commit'] = info['AisoraSourceCommit']
    for name, path in [('main', app / 'Contents/MacOS/Aisora'), ('helper', app / 'Contents/Helpers/AisoraUpdater')]:
        _, text = command(['/usr/bin/lipo', '-archs', path], work / (name + '-arch.log'))
        if text.strip() != 'x86_64':
            raise SystemExit('Unexpected native bundle architecture: ' + text)
        command(['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', path], work / (name + '-signature.log'))
    command(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', app], work / 'bundle-signature.log')
    command(['/usr/bin/codesign', '-d', '--verbose=4', app], work / 'signature-details.log')
    command([app / 'Contents/MacOS/Aisora', '--headless', '--resolution', '960x600', '--audio-driver', 'Dummy', '--quit-after', '60'], work / 'native-release-headless.log')
    report['native_release_headless_boot'] = 'pass'
    pack = app / 'Contents/Resources/Aisora.pck'
    command([ROOT / 'tools/run_godot.sh', '--headless', '--main-pack', pack, '--script', ROOT / 'tests/test_autonomy.gd'], work / 'native-packed-autonomy.log')
    report['native_packed_autonomy'] = 'pass'
    # Render the actual pack using the native Godot tool binary. This is not an
    # authenticated Voice test or a hardware performance benchmark.
    for name, script in [('body', 'render_phase6.gd'), ('face', 'render_updates.gd')]:
        command([ROOT / 'tools/run_godot.sh', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--main-pack', pack, '--script', ROOT / 'tests' / script, '--', '--output=' + str(work / ('render-' + name))], work / ('native-render-' + name + '.log'), timeout=600)
    report['native_compatibility_pack_render'] = 'pass'
    # Confirm Apple's verifier actually detects resource corruption. Never run
    # the corrupt copy and never alter the tested bundle or user installations.
    corrupt = work / 'corruption-test/Aisora.app'
    shutil.copytree(app, corrupt)
    data = corrupt / 'Contents/Resources/Aisora.pck'
    with data.open('r+b') as stream:
        stream.seek(64); value = stream.read(1); stream.seek(64); stream.write(bytes([value[0] ^ 1]))
    result, _ = command(['/usr/bin/codesign', '--verify', '--deep', '--strict', corrupt], work / 'corruption-rejection.log', required=False)
    if result.returncode == 0:
        raise SystemExit('Native verifier accepted deliberately corrupt resource')
    report['native_corruption_rejected'] = True
    # Model download quarantine by ADDING it. No xattr removal, assessment
    # disabling or trust exceptions are performed. Do not launch this copy.
    quarantined = work / 'quarantine-test/Aisora.app'
    shutil.copytree(app, quarantined)
    mark = f'0083;{int(time.time()):x};AisoraValidation;'
    for path in [quarantined, quarantined / 'Contents/MacOS/Aisora', quarantined / 'Contents/Helpers/AisoraUpdater']:
        subprocess.run(['/usr/bin/xattr', '-w', 'com.apple.quarantine', mark, str(path)], check=True)
    _, status = command(['/usr/sbin/spctl', '--status'], work / 'assessment-policy.log', required=False)
    result, text = command(['/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', quarantined], work / 'quarantine-assessment.log', required=False, timeout=60)
    report['assessment_policy'] = status.strip()
    report['quarantine_assessment'] = {'exit': result.returncode, 'output': text.strip(), 'note': 'CI policy result only; ad-hoc signing is not Developer ID or notarization. No Finder trust or user-Mac success is inferred.'}
    (work / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


def main():
    if sys.platform != 'darwin' or platform.machine() != 'x86_64':
        raise SystemExit('Run on an Intel macOS validation machine')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['bootstrap', 'validate'])
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    if args.action == 'bootstrap': bootstrap()
    else: validate(args.archive.resolve())

if __name__ == '__main__': main()
