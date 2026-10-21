#!/usr/bin/env python3
"""Export the unsigned Intel Mac test app and attach engine notices.
Run prepare_export_templates.py first. No signing/notarization or Mac execution.
"""
import argparse
import hashlib
from pathlib import Path
import plistlib
import struct
import subprocess
import zipfile


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=repo / 'exports/Aisora.zip')
    args = parser.parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    notices = repo / 'docs/licenses/Godot-4.6.3-NOTICES.txt'
    if not notices.is_file():
        raise SystemExit('Generate notices with tools/run_godot.sh --headless --script res://tools/engine_notices.gd first.')
    subprocess.run([str(repo / 'tools/run_godot.sh'), '--headless', '--editor',
                    '--export-release', 'macOS', str(output)], cwd=repo, check=True)
    with zipfile.ZipFile(output, 'a', compression=zipfile.ZIP_DEFLATED) as package:
        bad = package.testzip()
        if bad:
            raise SystemExit('Export ZIP CRC failed: ' + bad)
        names = package.namelist()
        exe = next(name for name in names if '/Contents/MacOS/' in name and not name.endswith('/'))
        data = package.read(exe)
        if data[:4] != bytes.fromhex('cffaedfe') or struct.unpack_from('<I', data, 4)[0] != 0x01000007:
            raise SystemExit('Export is not an Intel Mach-O executable.')
        info = plistlib.loads(package.read(next(name for name in names if name.endswith('/Info.plist'))))
        if info['CFBundleIdentifier'] != 'local.aisora.companion':
            raise SystemExit('Unexpected app identity.')
        if not any(name.endswith('/Contents/Resources/Aisora.pck') for name in names):
            raise SystemExit('App resource pack missing.')
        prefix = exe.split('/Contents/')[0]
        package.writestr(prefix + '/Contents/Resources/Godot-NOTICES.txt', notices.read_bytes())
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix(output.suffix + '.sha256').write_text(digest + '  ' + output.name + '\n')
    print('Verified unsigned Intel app structure:', output)
    print('SHA-256:', digest)
    print('Not executed on macOS; Ventura launch/permissions/performance require local acceptance.')


if __name__ == '__main__':
    main()
