#!/usr/bin/env python3
"""Build/test the dependency-free native helper; Go is a development tool only.

Linux can bootstrap the checksum-pinned official toolchain below. macOS builders
can set AISORA_GO to an installed Go 1.25+ executable. No Go runtime is shipped.
"""
import argparse
import hashlib
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import tarfile
import urllib.request

VERSION = 'go1.27.3'
ARCHIVE = VERSION + '.linux-amd64.tar.gz'
SHA256 = '65efbc80fdc1fa2cd2631cad5b481777a68e8725f34e89f50fc6ac714e379b40'


def toolchain(repo):
    selected = os.environ.get('AISORA_GO')
    if selected:
        return Path(selected).resolve()
    root = repo / '.local/tools' / VERSION
    executable = root / 'go/bin/go'
    if executable.is_file():
        return executable
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        raise SystemExit('Set AISORA_GO to a Go 1.25+ installation. Standalone users do not need Go.')
    root.mkdir(parents=True, exist_ok=True)
    archive = root / ARCHIVE
    with urllib.request.urlopen('https://go.dev/dl/' + ARCHIVE, timeout=60) as response, archive.open('wb') as out:
        shutil.copyfileobj(response, out)
    if hashlib.sha256(archive.read_bytes()).hexdigest() != SHA256:
        archive.unlink()
        raise SystemExit('Official Go archive checksum mismatch; refusing to execute it.')
    with tarfile.open(archive) as source:
        source.extractall(root, filter='data')
    return executable


def version(repo):
    return re.search(r'^config/version="([^"]+)"$', (repo / 'project.godot').read_text(), re.M)[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--test', action='store_true')
    parser.add_argument('--build', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    go = toolchain(repo)
    environment = dict(os.environ, GOCACHE=str(repo / '.local/updater/go-cache'),
                       GOPATH=str(repo / '.local/updater/go-path'), GOTOOLCHAIN='local', GOPROXY='off')
    if args.test:
        subprocess.run([str(go), 'test', '-count=1', '-v', './...'], cwd=repo / 'updater', env=environment, check=True)
        subprocess.run([str(go), 'vet', './...'], cwd=repo / 'updater', env=environment, check=True)
    if args.build or not args.test:
        output = args.output or repo / '.local/updater/AisoraUpdater'
        output.parent.mkdir(parents=True, exist_ok=True)
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
        if subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo):
            revision += '-dirty'
        environment.update(GOOS='darwin', GOARCH='amd64', CGO_ENABLED='0')
        subprocess.run([str(go), 'build', '-trimpath', '-buildvcs=false', '-ldflags',
                        f'-s -w -X main.buildVersion={version(repo)} -X main.sourceCommit={revision}',
                        '-o', str(output.resolve()), '.'], cwd=repo / 'updater', env=environment, check=True)
        output.with_name('Updater-NOTICES.txt').write_text(
            'Aisora updater includes the Go standard library. Development toolchain: ' + VERSION + '\n\n' +
            (go.parents[1] / 'LICENSE').read_text())
        print('Built Intel macOS helper:', output)


if __name__ == '__main__':
    main()
