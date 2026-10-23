"""Build provenance for Git checkouts or verified, unchanged source ZIPs.

Archive builds never invoke git (which can trigger Apple's developer-tools
installer). This checks source integrity; it does not establish Apple trust.
"""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile


def digest(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as stream:
        while chunk := stream.read(1024 * 1024):
            value.update(chunk)
    return value.hexdigest()


def source_path(name):
    path = PurePosixPath(name)
    if not name or '\\' in name or path.is_absolute() or any(x in ('', '.', '..') for x in name.split('/')):
        raise ValueError('Unsafe source path: ' + name)
    return path


def verify_files(repo, files):
    repo = Path(repo).resolve()
    if not isinstance(files, dict) or not files:
        raise ValueError('Missing source file manifest')
    for name, expected in files.items():
        relative = source_path(name)
        if not re.fullmatch(r'[a-f0-9]{64}', expected):
            raise ValueError('Invalid source hash')
        target = repo.joinpath(*relative.parts)
        if any(parent.is_symlink() for parent in [target, *target.parents] if parent != repo and parent.is_relative_to(repo)):
            raise ValueError('Symlink in source path: ' + name)
        if not target.is_file() or digest(target) != expected:
            raise ValueError('Source differs from verified ZIP: ' + name)
    # These are generated build products, never alternate project inputs.
    ignored_roots = {'.local', '.godot', 'exports'}
    for current, directories, names in os.walk(repo, followlinks=False):
        current = Path(current)
        for name in list(directories):
            target = current / name
            if target.is_symlink():
                raise ValueError('Unexpected source symlink: ' + str(target.relative_to(repo)))
            if name == '__pycache__' or (current == repo and name in ignored_roots):
                directories.remove(name)
        for name in names:
            target = current / name
            relative = target.relative_to(repo)
            if target.is_symlink():
                raise ValueError('Unexpected source symlink: ' + str(relative))
            if name != '.DS_Store' and relative.as_posix() not in files:
                raise ValueError('Unexpected source file: ' + str(relative))


def verify_archive(repo, archive, expected_sha, commit):
    if not re.fullmatch(r'[a-f0-9]{40}', commit) or not re.fullmatch(r'[a-f0-9]{64}', expected_sha):
        raise ValueError('Use the full documented source commit and ZIP SHA-256')
    if Path(repo, '.git').exists():
        raise ValueError('Use a separately extracted source ZIP, not a Git checkout')
    if digest(archive) != expected_sha:
        raise ValueError('Source ZIP checksum mismatch; no build started')
    prefix = 'Aisora-' + commit + '/'
    files = {}
    seen = set()
    with zipfile.ZipFile(archive) as package:
        if len(package.infolist()) > 10000 or sum(x.file_size for x in package.infolist()) > 512 * 1024 * 1024:
            raise ValueError('Oversize source archive')
        for item in package.infolist():
            if not item.filename.startswith(prefix):
                raise ValueError('Unexpected source archive root')
            name = item.filename[len(prefix):].rstrip('/')
            if not name:
                continue
            source_path(name)
            folded = name.casefold()
            if folded in seen or stat.S_ISLNK(item.external_attr >> 16):
                raise ValueError('Duplicate path or symlink in source ZIP')
            seen.add(folded)
            if not item.is_dir():
                files[name] = hashlib.sha256(package.read(item)).hexdigest()
    for name in ['project.godot', 'tools/export_macos.py', 'updater/main.go']:
        if name not in files:
            raise ValueError('Incomplete Aisora source ZIP')
    verify_files(repo, files)
    return {'schema': 1, 'source_commit': commit, 'archive_sha256': expected_sha, 'files': files}


def source_revision(repo, include_dirty=False):
    repo = Path(repo)
    if (repo / '.git').exists():
        revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
        if include_dirty and subprocess.check_output(['git', 'status', '--porcelain'], cwd=repo):
            revision += '-dirty'
        return revision
    marker = repo / '.local/source-provenance.json'
    if not marker.is_file():
        raise ValueError('Source ZIP builds require tools/build_local_macos.py and its documented checksum')
    data = json.loads(marker.read_text())
    if data.get('schema') != 1 or not re.fullmatch(r'[a-f0-9]{40}', data.get('source_commit', '')):
        raise ValueError('Invalid source provenance')
    verify_files(repo, data.get('files'))
    return data['source_commit']
