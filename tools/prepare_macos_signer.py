#!/usr/bin/env python3
"""Install a pinned Linux-only development signer; never shipped with Aisora.
macOS uses its native /usr/bin/codesign instead. No Apple credentials are created.
"""
import hashlib
from pathlib import Path
import platform
import sys
import tarfile
import urllib.request

VERSION = '0.29.0'
ARCHIVE = 'apple-codesign-0.29.0-x86_64-unknown-linux-musl.tar.gz'
SHA256 = 'dbe85cedd8ee4217b64e9a0e4c2aef92ab8bcaaa41f20bde99781ff02e600002'
URL = 'https://github.com/indygreg/apple-platform-rs/releases/download/apple-codesign/0.29.0/' + ARCHIVE


def main():
    if sys.platform == 'darwin':
        print('macOS uses native codesign; no additional signer download required.')
        return
    if sys.platform != 'linux' or platform.machine() != 'x86_64':
        raise SystemExit('This helper supports Linux x86_64 and macOS only.')
    out = Path(__file__).resolve().parents[1] / '.local/tools/apple-codesign-0.29.0'
    out.mkdir(parents=True, exist_ok=True)
    archive = out / ARCHIVE
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        temporary = archive.with_suffix('.download')
        with urllib.request.urlopen(URL, timeout=60) as response, temporary.open('wb') as stream:
            while chunk := response.read(1024 * 1024):
                stream.write(chunk)
        if hashlib.sha256(temporary.read_bytes()).hexdigest() != SHA256:
            temporary.unlink()
            raise SystemExit('Signer checksum mismatch; refusing to install or execute it.')
        temporary.replace(archive)
    with tarfile.open(archive) as package:
        member = next(m for m in package if m.isfile() and Path(m.name).name == 'rcodesign')
        executable = out / 'rcodesign'
        executable.write_bytes(package.extractfile(member).read())
        executable.chmod(0o755)
    print('Verified development-only apple-codesign', VERSION, 'at', executable)


if __name__ == '__main__':
    main()
