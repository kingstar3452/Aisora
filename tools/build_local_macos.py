#!/usr/bin/env python3
"""Build a separate Intel Mac preview from verified source; never install/launch.

No git, Xcode, signing account, pip modules, quarantine changes or user-data
writes. Python 3.12+, official Godot 4.6.3 and Go are build-time requirements.
Native signing is ad-hoc: local Finder acceptance must still be tested.
"""
import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

from source_provenance import digest, source_revision, verify_archive

ROOT = Path(__file__).resolve().parents[1]


def output_directory(repo, destination):
    destination = Path(destination).resolve()
    exports = Path(repo).resolve() / 'exports'
    if exports.is_symlink():
        raise ValueError('The exports directory must not be a symlink')
    if destination == exports or not destination.is_relative_to(exports) or destination.exists():
        raise ValueError('Choose a NEW folder inside this source project\'s exports directory; existing apps/folders are never replaced')
    return destination


def checked(command, log, environment):
    print('Build step:', log.name, flush=True)
    result = subprocess.run([str(x) for x in command], cwd=ROOT, env=environment, capture_output=True, text=True)
    text = result.stdout + result.stderr
    log.write_text(text)
    if result.returncode or 'SCRIPT ERROR' in text or '\nERROR:' in text:
        raise RuntimeError('Build step failed; see ' + str(log) + '. No installed application was changed.')
    return text.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--archive-sha256', required=True)
    parser.add_argument('--source-commit', required=True)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if sys.platform != 'darwin' or platform.machine() != 'x86_64' or int(platform.mac_ver()[0].split('.')[0]) < 13:
        raise SystemExit('Run this builder on an Intel Mac with macOS 13 or later; no installation was attempted')
    if sys.version_info < (3, 12):
        raise SystemExit('Install Python 3.12+ from python.org using normal macOS approval first')
    try:
        destination = output_directory(ROOT, args.output or ROOT / 'exports' / ('local-preview-' + args.source_commit[:12]))
        proof = verify_archive(ROOT, args.archive.resolve(), args.archive_sha256, args.source_commit)
        candidates = [os.environ.get('GODOT_BIN'), shutil.which('godot'), '/Applications/Godot.app/Contents/MacOS/Godot', str(Path.home() / 'Applications/Godot.app/Contents/MacOS/Godot')]
        godot = next((Path(x).resolve() for x in candidates if x and Path(x).is_file() and os.access(x, os.X_OK)), None)
        selected_go = os.environ.get('AISORA_GO') or shutil.which('go')
        if not godot or not selected_go:
            raise ValueError('Install official Godot 4.6.3 standard and Go first, or set GODOT_BIN and AISORA_GO. No build/installation started')
        go = Path(selected_go).resolve()
        godot_version = subprocess.check_output([str(godot), '--version'], text=True).strip()
        go_version = subprocess.check_output([str(go), 'version'], text=True).strip()
        if godot_version != '4.6.3.stable.official.7d41c59c4':
            raise ValueError('Use the tested official Godot 4.6.3 standard editor')
        if not re.fullmatch(r'go version go1\.27\.3 darwin/amd64', go_version):
            raise ValueError('Use the tested official Go 1.27.3 darwin/amd64 toolchain')
        environment = dict(os.environ, GODOT_BIN=str(godot), AISORA_GO=str(go))
        destination.mkdir(parents=True, exist_ok=False)
        (ROOT / '.local').mkdir(exist_ok=True)
        (ROOT / '.local/.gdignore').touch()
        (ROOT / '.local/source-provenance.json').write_text(json.dumps(proof, indent=2) + '\n')
        # Template downloads/build caches stay in the source tree, not the
        # user's Godot installation or Aisora preferences. Official hashes are
        # checked by the existing template helper before export.
        checked([sys.executable, ROOT / 'tools/prepare_export_templates.py', '--destination', ROOT / '.local/export-templates/official'], destination / 'templates.log', environment)
        checked(['/bin/bash', ROOT / 'tools/run_godot.sh', '--headless', '--editor', '--import'], destination / 'import.log', environment)
        archive = destination / 'Aisora-phase6-macos-local.zip'
        checked([sys.executable, ROOT / 'tools/export_macos.py', '--output', archive], destination / 'export.log', environment)
        if source_revision(ROOT) != args.source_commit:
            raise ValueError('Source changed during build')
        checked(['/usr/bin/ditto', '-xk', archive, destination], destination / 'extract.log', environment)
        app = destination / 'Aisora.app'
        checked(['/usr/bin/codesign', '--verify', '--deep', '--strict', app], destination / 'signature.log', environment)
        for name, executable in [('main', app / 'Contents/MacOS/Aisora'), ('helper', app / 'Contents/Helpers/AisoraUpdater')]:
            if checked(['/usr/bin/lipo', '-archs', executable], destination / (name + '-architecture.log'), environment) != 'x86_64':
                raise ValueError('Built executable is not Intel-only')
        assessment = subprocess.run(['/usr/sbin/spctl', '--assess', '--type', 'execute', '--verbose=2', str(app)], capture_output=True, text=True)
        receipt = {'source_commit': args.source_commit, 'source_zip_sha256': args.archive_sha256,
                   'archive': str(archive), 'archive_sha256': digest(archive), 'application': str(app),
                   'godot': godot_version, 'go': go_version, 'locally_source_built': True,
                   'native_signature_integrity': 'pass', 'architecture': 'x86_64',
                   'gatekeeper_assessment': {'exit': assessment.returncode, 'output': assessment.stdout + assessment.stderr},
                   'normal_finder_launch_tested': False, 'target_imac_tested': False,
                   'developer_id_signed': False, 'notarized': False,
                   'security_policy_or_quarantine_changed': False, 'application_installed_or_launched': False}
        (destination / 'local-build-receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
        print('Built a separate local preview:', app)
        print('Local ZIP SHA-256:', receipt['archive_sha256'])
        print('Gatekeeper assessment exit:', assessment.returncode, '(recorded, never bypassed)')
        print('No app was installed/launched and no user data was changed. Back up shared Aisora data before a manual Finder test. If macOS refuses normal launch, stop.')
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))


if __name__ == '__main__':
    main()
