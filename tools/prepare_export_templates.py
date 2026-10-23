#!/usr/bin/env python3
"""Optional cloud export setup; downloads official Godot templates, never app assets.
Only matching Mac/Linux files are retained. No extra application runtime dependency.
"""
import argparse
import hashlib
from pathlib import Path
import tempfile
import struct
import sys
import urllib.request
import zipfile

ARCHIVE_SHA256 = "3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8"
URL = "https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz"
FILES = {'macos.zip': '700a5759952b2260b7d894dc9bc4908d99ce9abe2964a76c6d2bddd4af4738b2', 'linux_debug.x86_64': '729766fae804184c58ab5e9819ac42f81c6d5337588c3cd7ff66bb52c57cf986', 'linux_release.x86_64': '2c78919325d7f29fa7607287c7c1eeac367ea4c94e7b8b6f5f4c6b20492f73d0', 'version.txt': '4855bd38072b77c73c45739cf6a6787d7df790a368b0a437102f352650e6186b'}

def digest(path):
    with path.open('rb') as stream:
        value = hashlib.sha256()
        while chunk := stream.read(1024 * 1024):
            value.update(chunk)
        return value.hexdigest()

def intel_template(source, output):
    """Equivalent to lipo -thin x86_64: copy the unchanged Intel Mach-O slices.
    The source archive must already match its pinned official checksum.
    """
    if digest(source) != FILES['macos.zip']:
        raise SystemExit('Mac source template checksum mismatch.')
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as src, zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as dst:
        for item in src.infolist():
            data = src.read(item)
            if item.filename.endswith(('godot_macos_release.universal', 'godot_macos_debug.universal')):
                magic, count = struct.unpack_from('>II', data)
                if magic != 0xcafebabe:
                    raise SystemExit('Unexpected universal Mach-O format.')
                for index in range(count):
                    cpu, subtype, offset, size, alignment = struct.unpack_from('>IIIII', data, 8 + index * 20)
                    if cpu == 0x01000007:
                        data = data[offset:offset + size]
                        break
                else:
                    raise SystemExit('Official template has no Intel slice.')
                if data[:4] != bytes.fromhex('cffaedfe') or struct.unpack_from('<I', data, 4)[0] != 0x01000007:
                    raise SystemExit('Invalid extracted Intel Mach-O.')
                item.filename = item.filename.removesuffix('.universal') + '.x86_64'
            dst.writestr(item, data)
    print('Prepared Intel template from verified official slices:', output)


def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, default=(Path.home() / 'Library/Application Support/Godot/export_templates/4.6.3.stable' if sys.platform == 'darwin' else repo / '.local/cloud/data/godot/export_templates/4.6.3.stable'))
    args = parser.parse_args()
    destination = args.destination.resolve()
    if all((destination / name).is_file() and digest(destination / name) == value for name, value in FILES.items()):
        print('Matching checksum-verified export templates already installed.')
        intel_template(destination / 'macos.zip', repo / '.local/export-templates/macos-intel.zip')
        return
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='aisora-templates-', dir=destination.parent) as scratch:
        archive = Path(scratch) / 'official.tpz'
        print('Downloading official 4.6.3 template archive (about 1.26 GB); only Mac/Linux files will be retained.', flush=True)
        with urllib.request.urlopen(URL, timeout=60) as response, archive.open('wb') as output:
            while chunk := response.read(1024 * 1024):
                output.write(chunk)
        if digest(archive) != ARCHIVE_SHA256:
            raise SystemExit('Official archive checksum mismatch; no downloaded binary will be used.')
        with zipfile.ZipFile(archive) as package:
            for name, expected in FILES.items():
                data = package.read('templates/' + name)
                if hashlib.sha256(data).hexdigest() != expected:
                    raise SystemExit('Inner template checksum mismatch; installation stopped.')
                (destination / name).write_bytes(data)
        print('Verified and installed matching export templates.')
        intel_template(destination / 'macos.zip', repo / '.local/export-templates/macos-intel.zip')

if __name__ == '__main__':
    main()
