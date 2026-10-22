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
    print('::notice title=Native validation stage::' + output.name, flush=True)
    try:
        result = subprocess.run([str(x) for x in args], cwd=ROOT, capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        parts = [error.stdout or '', error.stderr or '']
        text = ''.join(x.decode(errors='replace') if isinstance(x, bytes) else x for x in parts)
        text += '\nTIMEOUT after ' + str(timeout) + ' seconds: ' + output.name
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text)
        detail = text[-28000:].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print('::error title=Native validation timeout::' + detail, flush=True)
        raise SystemExit('Native validation timed out: ' + output.name)
    text = result.stdout + result.stderr
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(text)
    print(output.name, 'exit', result.returncode, flush=True)
    if required and (result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text or '\nFAIL:' in text):
        print(text)
        detail = text[-28000:].replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')
        print('::error title=Native Mac validation details::' + detail)
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
    report['validation_logs'] = {name: (work / name).read_text() for name in [
        'main-arch.log', 'helper-arch.log', 'bundle-signature.log',
        'signature-details.log', 'native-release-headless.log',
        'native-packed-autonomy.log', 'native-render-body.log',
        'native-render-face.log', 'corruption-rejection.log']}
    report['native_go_log'] = (work.parent / 'native-go.log').read_text()
    (work / 'report.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


def stage_draft(archive):
    # Owner-reviewable staging only. The tag is deliberately not a production
    # update version and the release is always created as a private draft.
    repo = os.environ.get('GITHUB_REPOSITORY', '')
    if repo != 'kingstar3452/Aisora':
        raise SystemExit('Refusing to stage into an unexpected repository')
    run_id = os.environ.get('GITHUB_RUN_ID', '')
    if not run_id.isdigit(): raise SystemExit('Missing native validation run ID')
    tag = 'aisora-native-validation-' + run_id
    report_path = ROOT / '.local/macos-ci/validation/report.json'
    report = json.loads(report_path.read_text())
    source = report['source_commit']
    sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    notes = report_path.with_name('draft-notes.md')
    notes.write_text('UNPUBLISHED native Intel macOS CI rebuild; publication remains held.\n\n'
        + 'Runtime code is based on 2142475 (requested autonomy defaults and actual-rig direction checks). '
        + 'Source commit: ' + source + '.\n\n'
        + 'Ad-hoc signed only: no Developer ID or notarization. Native CI does not certify '
        + 'Ventura on a 2017 iMac, an Internet Finder launch, or authenticated ChatGPT Voice. '
        + 'Keep the installed working app until review and local acceptance. The full performance report is still a release gate.\n\n'
        + 'Archive SHA-256: `' + sha + '`\n')
    exists = subprocess.run(['gh', 'release', 'view', tag, '--repo', repo, '--json', 'isDraft,assets'], capture_output=True, text=True)
    if exists.returncode == 0:
        previous = json.loads(exists.stdout)
        if not previous['isDraft']: raise SystemExit('Refusing to alter a published release')
        if previous.get('assets'): raise SystemExit('Existing validation draft has assets; refusing replacement')
    else:
        subprocess.run(['gh', 'release', 'create', tag, '--repo', repo, '--target', source, '--draft', '--prerelease', '--title', 'Unpublished native Mac validation candidate', '--notes-file', str(notes)], check=True)
    subprocess.run(['gh', 'release', 'upload', tag, str(archive), str(archive.with_suffix(archive.suffix + '.sha256')), str(report_path), '--repo', repo], check=True)
    state = subprocess.check_output(['gh', 'release', 'view', tag, '--repo', repo, '--json', 'isDraft,url'], text=True)
    if not json.loads(state)['isDraft']: raise SystemExit('Validation release must remain a draft')
    print('Owner-reviewable DRAFT only:', state)


def main():
    if sys.platform != 'darwin' or platform.machine() != 'x86_64':
        raise SystemExit('Run on an Intel macOS validation machine')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['bootstrap', 'validate', 'stage-draft'])
    parser.add_argument('--archive', type=Path)
    args = parser.parse_args()
    if args.action == 'bootstrap': bootstrap()
    elif args.action == 'validate': validate(args.archive.resolve())
    else: stage_draft(args.archive.resolve())

if __name__ == '__main__': main()
