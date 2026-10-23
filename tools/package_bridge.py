#!/usr/bin/env python3
"""Package committed bridge/extension sources only. No credentials or app rebuild."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-directory', type=Path, default=ROOT / 'exports')
    args = parser.parse_args()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    def committed(name):
        return subprocess.check_output(['git', 'show', commit + ':' + name], cwd=ROOT)
    names = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', commit, '--', 'browser-controller/extension'], cwd=ROOT, text=True).splitlines()
    if not names or any(Path(name).suffix not in {'.json', '.js', '.html', '.css'} for name in names):
        raise SystemExit('Unexpected extension source files; refusing to package')
    files = {name: committed(name) for name in names}
    files['browser-controller/bridge.py'] = committed('browser-controller/bridge.py')
    files['tools/start_bridge.command'] = committed('tools/start_bridge.command')
    files['README.md'] = committed('docs/BRIDGE_PAIRING_REPAIR.md').replace(
        b'](bridge-repair-delivery.json)', b'](https://github.com/kingstar3452/Aisora/blob/dev/aisora-companion/docs/bridge-repair-delivery.json)')
    manifest = json.loads(files['browser-controller/extension/manifest.json'])
    version = re.search(rb"BRIDGE_VERSION = '([^']+)'", files['browser-controller/bridge.py'])[1].decode()
    if manifest['version'] != version or not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('Bridge/extension version mismatch')
    metadata = {'source_commit': commit, 'bridge_version': version, 'extension_version': version,
                'bridge_protocol': 1, 'standalone_compatible': 'Aisora 6.1.0-rc.2, existing protocol 1 client; no rebuild required',
                'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}}
    files['COMPONENTS.json'] = (json.dumps(metadata, indent=2) + '\n').encode()
    root = 'Aisora-bridge-extension-' + version
    output = args.output_directory.resolve()
    output.mkdir(parents=True, exist_ok=True)
    archive = output / (root + '.zip')
    temporary = archive.with_suffix('.zip.tmp')
    with zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED) as z:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(root + '/' + name, date_time=(2026, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if name.endswith('.command') else 0o644)) << 16
            z.writestr(info, data, compress_type=zipfile.ZIP_DEFLATED)
    with zipfile.ZipFile(temporary) as z:
        if z.testzip() is not None or len(z.infolist()) != len(files):
            raise SystemExit('ZIP verification failed')
        for name, data in files.items():
            if z.read(root + '/' + name) != data:
                raise SystemExit('Packaged source differs')
    temporary.replace(archive)
    sha = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(sha + '  ' + archive.name + '\n')
    report = {'archive': archive.name, 'bytes': archive.stat().st_size, 'sha256': sha, 'zip_crc': 'pass',
              'source_commit': commit, 'bridge_version': version, 'extension_version': version,
              'bridge_protocol': 1, 'source_file_hashes': 'pass', 'pairing_files_or_keys_included': False,
              'standalone_rebuilt': False, 'native_chrome_voice_tested': False, 'ventura_tested': False}
    archive.with_suffix('.zip.verification.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
