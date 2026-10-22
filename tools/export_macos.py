#!/usr/bin/env python3
"""Export and seal an Intel Mac AD-HOC REPAIR CANDIDATE, not a notarized release.

All bundle changes precede signing. Packaging preserves Unix execute bits; an
independent verifier rejects broken code/Info.plist/resource seals. Apple trust
and native Gatekeeper/launch testing are separate, unavailable on Linux.
"""
import argparse
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import zipfile

from macos_bundle import BundleError, verify_zip


def extract_export(archive, destination):
    with zipfile.ZipFile(archive) as package:
        if package.testzip() is not None:
            raise BundleError('Raw export ZIP CRC failure')
        for item in package.infolist():
            target = destination / item.filename
            if not item.filename.startswith('Aisora.app/') or not target.resolve().is_relative_to(destination.resolve()):
                raise BundleError('Unexpected raw export path')
            mode = item.external_attr >> 16
            if mode & 0o170000 == 0o120000:
                raise BundleError('Unexpected symbolic link in simple Godot bundle')
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(package.read(item))
                target.chmod(mode & 0o777 or 0o644)


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=repo / 'exports/Aisora.zip')
    parser.add_argument('--rcodesign', type=Path, default=repo / '.local/tools/apple-codesign-0.29.0/rcodesign')
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    notices = repo / 'docs/licenses/Godot-4.6.3-NOTICES.txt'
    if not notices.is_file():
        raise SystemExit('Generate engine notices before exporting.')
    if sys.platform != 'darwin' and not args.rcodesign.is_file():
        raise SystemExit('Run python3 tools/prepare_macos_signer.py before a Linux export.')
    with tempfile.TemporaryDirectory(prefix='aisora-export-', dir=output.parent) as scratch:
        work = Path(scratch)
        raw = work / 'raw.zip'
        run = subprocess.run([str(repo / 'tools/run_godot.sh'), '--headless', '--editor',
                              '--export-release', 'macOS', str(raw)], cwd=repo,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        print(run.stdout, end='')
        if run.returncode or 'SCRIPT ERROR' in run.stdout or '\nERROR:' in run.stdout or not raw.is_file():
            raise SystemExit('Godot export failed; no finished archive will be published.')
        extract_export(raw, work)
        app = work / 'Aisora.app'
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != 'local.aisora.companion':
            raise SystemExit('Unexpected bundle identity.')
        # Finish ALL content changes before signing. Never append files to the app later.
        (app / 'Contents/Resources/Godot-NOTICES.txt').write_bytes(notices.read_bytes())
        executable = app / 'Contents/MacOS/Aisora'
        executable.chmod(0o755)
        if sys.platform == 'darwin':
            subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', str(app)], check=True)
            subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        else:
            subprocess.run([str(args.rcodesign), '--config-file', os.devnull, 'sign',
                            '--timestamp-url', 'none', str(app)], check=True)
        candidate = work / 'finished.zip'
        with zipfile.ZipFile(candidate, 'w', compression=zipfile.ZIP_DEFLATED) as package:
            for path in sorted(app.rglob('*')):
                package.write(path, path.relative_to(work).as_posix())
        report = verify_zip(candidate)
        report['native_codesign_verification_performed'] = sys.platform == 'darwin'
        # An invalid candidate never overwrites an existing valid output.
        candidate.replace(output)
    output.with_suffix(output.suffix + '.sha256').write_text(report['sha256'] + '  ' + output.name + '\n')
    output.with_suffix(output.suffix + '.verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Verified ad-hoc bundle seals:', output)
    print('SHA-256:', report['sha256'])
    print('NOT Developer ID signed or notarized. Gatekeeper acceptance/native launch are unverified.')


if __name__ == '__main__':
    main()
